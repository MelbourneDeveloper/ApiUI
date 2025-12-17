"""Meta tools for bundling OpenAPI endpoints into grouped tools."""

from __future__ import annotations

import json
from dataclasses import dataclass
from typing import TYPE_CHECKING, Any

from pydantic import BaseModel, Field, create_model
from result import Err, Ok, Result

from _langchain_types import ToolProtocol, create_structured_tool
from openapi_tools import (
    _execute_http_request,  # pyright: ignore[reportPrivateUsage]
    _extract_base_url,  # pyright: ignore[reportPrivateUsage]
    _sanitize_tool_name,  # pyright: ignore[reportPrivateUsage]
)

if TYPE_CHECKING:
    from collections.abc import Mapping, Sequence


@dataclass(frozen=True)
class ParamSpec:
    """Parameter specification from OpenAPI."""

    name: str
    required: bool
    param_in: str  # "path" | "query"


@dataclass(frozen=True)
class OperationSpec:
    """Operation specification from OpenAPI."""

    operation_id: str
    method: str
    path: str
    summary: str
    params: tuple[ParamSpec, ...]


def _extract_params(parameters: list[dict[str, Any]]) -> tuple[ParamSpec, ...]:
    """Extract parameter specs from OpenAPI parameters."""
    return tuple(
        ParamSpec(
            name=p.get("name", ""),
            required=p.get("required", False),
            param_in=p.get("in", "query"),
        )
        for p in parameters
    )


def _generate_operation_id(method: str, path: str) -> str:
    """Generate an operation ID from method and path."""
    # /annotations/{id} -> annotations_id
    path_part = path.strip("/").replace("/", "_").replace("{", "").replace("}", "")
    return f"{method}_{path_part}"


def extract_groups_from_tags(spec: dict[str, Any]) -> dict[str, list[str]]:
    """Extract operation groups from OpenAPI tags."""
    groups: dict[str, list[str]] = {}
    paths = spec.get("paths", {})

    for path, path_item in paths.items():
        for method in ("get", "post", "put", "patch", "delete"):
            operation = path_item.get(method)
            match operation:
                case None:
                    continue
                case op:
                    op_id = op.get("operationId") or _generate_operation_id(
                        method, path
                    )
                    tags = op.get("tags", [])
                    tag = _sanitize_tool_name(tags[0]) if tags else "default"
                    groups.setdefault(tag, []).append(op_id)

    return groups


def extract_operation(
    spec: dict[str, Any],
    operation_id: str,
) -> Result[OperationSpec, str]:
    """Find and extract an operation by its operationId."""
    paths = spec.get("paths", {})

    for path, path_item in paths.items():
        for method in ("get", "post", "put", "patch", "delete"):
            operation = path_item.get(method)
            match operation:
                case None:
                    continue
                case op:
                    actual_id = op.get("operationId") or _generate_operation_id(
                        method, path
                    )
                    match actual_id == operation_id:
                        case True:
                            return Ok(
                                OperationSpec(
                                    operation_id=operation_id,
                                    method=method,
                                    path=path,
                                    summary=op.get(
                                        "summary", op.get("description", "")
                                    ),
                                    params=_extract_params(op.get("parameters", [])),
                                )
                            )
                        case _:
                            continue

    return Err(f"Operation not found: {operation_id}")


def _format_param_signature(params: tuple[ParamSpec, ...]) -> str:
    """Format params as signature string: (required, optional?)."""
    required = [p.name for p in params if p.required]
    optional = [f"{p.name}?" for p in params if not p.required]
    return ", ".join([*required, *optional])


def build_description(
    tool_name: str,
    operations: Sequence[OperationSpec],
) -> str:
    """Build a description listing all operations."""
    lines = [f"{tool_name} - API operations", "", "Operations:"]
    for op in operations:
        sig = _format_param_signature(op.params)
        lines.append(f"- {op.operation_id}({sig}): {op.summary}")
    return "\n".join(lines)


def validate_params(
    op: OperationSpec,
    params: Mapping[str, Any],
) -> Result[dict[str, Any], str]:
    """Validate params against operation requirements."""
    required = [p.name for p in op.params if p.required]
    missing = [r for r in required if r not in params or params[r] is None]

    match missing:
        case []:
            return Ok(dict(params))
        case _:
            return Err(f"Missing required params for {op.operation_id}: {missing}")


def _build_url(base_url: str, path: str, params: dict[str, Any]) -> str:
    """Build URL with path params substituted."""
    url = f"{base_url}{path}"
    for key, value in params.items():
        url = url.replace(f"{{{key}}}", str(value))
    return url


def _get_query_params(
    path: str,
    params: dict[str, Any],
) -> dict[str, str | int | float | bool]:
    """Extract query params (those not in path)."""
    return {k: v for k, v in params.items() if f"{{{k}}}" not in path and v is not None}


def _create_meta_tool_executor(
    operations: Mapping[str, OperationSpec],
    base_url: str,
    auth_token: str | None,
) -> Any:  # noqa: ANN401
    """Create the executor function for a meta tool."""

    def execute(operation: str, params: dict[str, Any] | None = None) -> str:
        params = params or {}
        match operations.get(operation):
            case None:
                available = list(operations.keys())
                err = {"error": f"Unknown operation: {operation}", "available": available}
                return json.dumps(err)
            case op_spec:
                match validate_params(op_spec, params):
                    case Err(e):
                        return json.dumps({"error": e})
                    case Ok(validated):
                        url = _build_url(base_url, op_spec.path, validated)
                        query = _get_query_params(op_spec.path, validated)
                        headers = {"Authorization": f"Bearer {auth_token}"} if auth_token else {}
                        return _execute_http_request(op_spec.method, url, query, headers)

    return execute


def _build_args_model(
    tool_name: str,
    operation_ids: Sequence[str],
) -> type[BaseModel]:
    """Build Pydantic model for meta tool args."""
    # Create a Literal type for operations - but we need to use a workaround
    # since Literal requires actual string literals at type-check time
    op_description = f"Operation to execute. One of: {', '.join(operation_ids)}"

    params_field = Field(default=None, description="Parameters for the operation")
    return create_model(
        f"{tool_name}Args",
        operation=(str, Field(description=op_description)),
        params=(dict[str, Any] | None, params_field),
    )


def create_meta_tool(
    tool_name: str,
    operation_ids: Sequence[str],
    spec: dict[str, Any],
    base_url: str,
    auth_token: str | None,
) -> Result[ToolProtocol, str]:
    """Create a meta tool from a list of operation IDs."""
    operations: dict[str, OperationSpec] = {}

    for op_id in operation_ids:
        match extract_operation(spec, op_id):
            case Err(e):
                return Err(e)
            case Ok(op_spec):
                operations[op_id] = op_spec

    description = build_description(tool_name, list(operations.values()))
    executor = _create_meta_tool_executor(operations, base_url, auth_token)
    args_model = _build_args_model(tool_name, operation_ids)

    return Ok(
        create_structured_tool(
            func=executor,
            name=tool_name,
            description=description,
            args_schema=args_model,
        )
    )


def generate_meta_tools(
    groups: dict[str, list[str]] | None,
    spec: dict[str, Any],
    auth_token: str | None,
) -> Result[list[ToolProtocol], str]:
    """Generate meta tools from groups config or spec tags."""
    effective_groups = groups if groups else extract_groups_from_tags(spec)
    base_url = _extract_base_url(spec)

    tools: list[ToolProtocol] = []
    for tool_name, op_ids in effective_groups.items():
        match create_meta_tool(tool_name, op_ids, spec, base_url, auth_token):
            case Err(e):
                return Err(e)
            case Ok(tool):
                tools.append(tool)

    return Ok(tools)

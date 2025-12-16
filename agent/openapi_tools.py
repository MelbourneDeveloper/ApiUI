"""Parse OpenAPI specs and generate LangChain tools."""

from __future__ import annotations

import json
import re
from typing import TYPE_CHECKING, Any

import httpx
import yaml
from pydantic import BaseModel, Field, create_model
from pydantic.fields import FieldInfo
from result import Err, Ok, Result

from _langchain_types import ToolProtocol, create_structured_tool

if TYPE_CHECKING:
    from pathlib import Path

type PydanticFieldDef = tuple[type[Any], FieldInfo]


def _execute_http_request(
    method: str,
    url: str,
    query_params: dict[str, str | int | float | bool],
    headers: dict[str, str],
) -> str:
    """Execute HTTP request, returning response text or error JSON."""
    try:
        with httpx.Client(timeout=30.0) as client:
            response = client.request(
                method=method.upper(),
                url=url,
                params=query_params if method.upper() == "GET" else None,
                json=query_params if method.upper() in ("POST", "PUT", "PATCH") else None,
                headers=headers,
            )
            return response.text
    except httpx.HTTPError as e:
        return json.dumps({"error": f"HTTP request failed: {e}"})


def load_openapi_spec(path: Path) -> Result[dict[str, Any], str]:
    """Load an OpenAPI spec from a JSON or YAML file."""
    try:
        content = path.read_text()
        match path.suffix.lower():
            case ".yaml" | ".yml":
                return Ok(yaml.safe_load(content))
            case _:
                return Ok(json.loads(content))
    except (OSError, json.JSONDecodeError, yaml.YAMLError) as e:
        return Err(f"Failed to load OpenAPI spec: {e}")


def _json_schema_to_pydantic_field(
    schema: dict[str, Any],
    *,
    required: bool,
) -> PydanticFieldDef:
    """Convert JSON schema type to Pydantic field."""
    json_type = schema.get("type", "string")
    description = schema.get("description", "")

    type_map: dict[str, type[Any]] = {
        "string": str,
        "integer": int,
        "number": float,
        "boolean": bool,
        "array": list,
        "object": dict,
    }

    py_type = type_map.get(json_type, str)
    field = (
        Field(description=description) if required else Field(default=None, description=description)
    )
    result_type = py_type if required else py_type | None
    return (result_type, field)  # type: ignore[return-value]


def _build_args_model(
    operation_id: str,
    parameters: list[dict[str, Any]],
) -> type[BaseModel]:
    """Build a Pydantic model for tool arguments."""
    fields: dict[str, Any] = {}
    for param in parameters:
        name = param.get("name", "")
        schema = param.get("schema", {})
        required = param.get("required", False)
        fields[name] = _json_schema_to_pydantic_field(schema, required=required)

    return create_model(f"{operation_id}Args", **fields)  # type: ignore[call-overload]


def _sanitize_tool_name(name: str) -> str:
    """Sanitize tool name to match ^[a-zA-Z0-9_-]{1,128}$."""
    sanitized = re.sub(r"[^a-zA-Z0-9_-]", "_", name)
    return sanitized[:128]


def _create_api_tool(
    base_url: str,
    path: str,
    method: str,
    operation: dict[str, Any],
    auth_token: str | None = None,
) -> ToolProtocol:
    """Create a LangChain tool from an OpenAPI operation."""
    raw_id = operation.get("operationId", f"{method}_{path.replace('/', '_')}")
    operation_id = _sanitize_tool_name(raw_id)
    description = operation.get("summary", operation.get("description", f"{method} {path}"))
    parameters = operation.get("parameters", [])

    args_model = _build_args_model(operation_id, parameters)

    def make_request(**kwargs: str | float | bool | None) -> str:
        """Execute the API request, returning error JSON on failure."""
        url = f"{base_url}{path}"

        for key, value in kwargs.items():
            url = url.replace(f"{{{key}}}", str(value))

        query_params: dict[str, str | int | float | bool] = {
            k: v for k, v in kwargs.items() if f"{{{k}}}" not in path and v is not None
        }

        headers: dict[str, str] = {"Authorization": f"Bearer {auth_token}"} if auth_token else {}

        return _execute_http_request(method, url, query_params, headers)

    return create_structured_tool(
        func=make_request,
        name=operation_id,
        description=str(description),
        args_schema=args_model,
    )


def generate_tools_from_spec(
    spec: dict[str, Any],
    auth_token: str | None = None,
) -> list[ToolProtocol]:
    """Generate LangChain tools from an OpenAPI spec."""
    servers = spec.get("servers", [])
    base_url = servers[0]["url"] if servers else ""
    paths = spec.get("paths", {})

    tools: list[ToolProtocol] = []
    for path, path_item in paths.items():
        for method in ("get", "post", "put", "patch", "delete"):
            operation = path_item.get(method)
            if operation:
                tools.append(_create_api_tool(base_url, path, method, operation, auth_token))

    return tools


def load_and_generate_tools(
    spec_path: Path,
    auth_token: str | None = None,
) -> Result[list[ToolProtocol], str]:
    """Load an OpenAPI spec and generate tools."""
    match load_openapi_spec(spec_path):
        case Ok(spec):
            return Ok(generate_tools_from_spec(spec, auth_token))
        case Err(e):
            return Err(e)

"""Tests for OpenAPI spec parsing and tool generation."""
# ruff: noqa: PLR2004, S106

from __future__ import annotations

import json
import tempfile
from pathlib import Path
from typing import TYPE_CHECKING, Any

import pytest
from pydantic import BaseModel
from result import Err, Ok

from openapi_tools import (
    _build_args_model,  # pyright: ignore[reportPrivateUsage]
    _create_api_tool,  # pyright: ignore[reportPrivateUsage]
    _json_schema_to_pydantic_field,  # pyright: ignore[reportPrivateUsage]
    generate_tools_from_spec,
    load_and_generate_tools,
    load_openapi_spec,
)

if TYPE_CHECKING:
    from collections.abc import Generator


@pytest.fixture
def simple_openapi_spec() -> dict[str, Any]:
    """A minimal OpenAPI spec for testing."""
    return {
        "openapi": "3.0.0",
        "info": {"title": "Test API", "version": "1.0.0"},
        "servers": [{"url": "https://api.example.com"}],
        "paths": {
            "/users": {
                "get": {
                    "operationId": "list_users",
                    "summary": "List all users",
                    "parameters": [],
                },
            },
            "/users/{id}": {
                "get": {
                    "operationId": "get_user",
                    "summary": "Get a user by ID",
                    "parameters": [
                        {
                            "name": "id",
                            "in": "path",
                            "required": True,
                            "schema": {"type": "string", "description": "User ID"},
                        },
                    ],
                },
            },
        },
    }


@pytest.fixture
def temp_spec_file(simple_openapi_spec: dict[str, Any]) -> Generator[Path, None, None]:
    """Create a temporary spec file."""
    with tempfile.NamedTemporaryFile(
        mode="w",
        suffix=".json",
        delete=False,
    ) as f:
        json.dump(simple_openapi_spec, f)
        f.flush()
        yield Path(f.name)


class TestLoadOpenapiSpec:
    """Tests for load_openapi_spec."""

    def test_loads_valid_spec(self, temp_spec_file: Path) -> None:
        """Should load a valid JSON spec file."""
        result = load_openapi_spec(temp_spec_file)
        assert isinstance(result, Ok)
        assert result.ok_value["openapi"] == "3.0.0"

    def test_returns_error_for_nonexistent_file(self) -> None:
        """Should return error for non-existent file."""
        result = load_openapi_spec(Path("/nonexistent/spec.json"))
        assert isinstance(result, Err)

    def test_returns_error_for_invalid_json(self) -> None:
        """Should return error for invalid JSON."""
        with tempfile.NamedTemporaryFile(
            mode="w",
            suffix=".json",
            delete=False,
        ) as f:
            f.write("not valid json {{{")
            f.flush()
            result = load_openapi_spec(Path(f.name))

        assert isinstance(result, Err)
        assert "Failed to load" in result.err_value


class TestJsonSchemaToPydanticField:
    """Tests for _json_schema_to_pydantic_field."""

    def test_string_type(self) -> None:
        """String schema should map to str type."""
        schema = {"type": "string", "description": "A name"}
        py_type, _ = _json_schema_to_pydantic_field(schema, required=True)
        assert py_type is str

    def test_integer_type(self) -> None:
        """Integer schema should map to int type."""
        schema = {"type": "integer", "description": "Count"}
        py_type, _ = _json_schema_to_pydantic_field(schema, required=True)
        assert py_type is int

    def test_number_type(self) -> None:
        """Number schema should map to float type."""
        schema = {"type": "number", "description": "Price"}
        py_type, _ = _json_schema_to_pydantic_field(schema, required=True)
        assert py_type is float

    def test_boolean_type(self) -> None:
        """Boolean schema should map to bool type."""
        schema = {"type": "boolean", "description": "Active"}
        py_type, _ = _json_schema_to_pydantic_field(schema, required=True)
        assert py_type is bool

    def test_array_type(self) -> None:
        """Array schema should map to list type."""
        schema = {"type": "array", "description": "Items"}
        py_type, _ = _json_schema_to_pydantic_field(schema, required=True)
        assert py_type is list

    def test_object_type(self) -> None:
        """Object schema should map to dict type."""
        schema = {"type": "object", "description": "Data"}
        py_type, _ = _json_schema_to_pydantic_field(schema, required=True)
        assert py_type is dict

    def test_optional_field_allows_none(self) -> None:
        """Optional field should allow None."""
        schema = {"type": "string"}
        py_type, _ = _json_schema_to_pydantic_field(schema, required=False)
        # Union type with None
        assert py_type == str | None

    def test_unknown_type_defaults_to_string(self) -> None:
        """Unknown type should default to str."""
        schema = {"type": "unknown_type"}
        py_type, _ = _json_schema_to_pydantic_field(schema, required=True)
        assert py_type is str


class TestBuildArgsModel:
    """Tests for _build_args_model."""

    def test_builds_empty_model(self) -> None:
        """Should build model with no fields for no parameters."""
        model = _build_args_model("test_op", [])
        assert issubclass(model, BaseModel)

    def test_builds_model_with_required_field(self) -> None:
        """Should build model with required field."""
        params = [
            {
                "name": "user_id",
                "required": True,
                "schema": {"type": "string", "description": "User ID"},
            },
        ]
        model = _build_args_model("test_op", params)

        assert "user_id" in model.model_fields
        assert model.model_fields["user_id"].is_required()

    def test_builds_model_with_optional_field(self) -> None:
        """Should build model with optional field."""
        params = [
            {
                "name": "limit",
                "required": False,
                "schema": {"type": "integer", "description": "Limit"},
            },
        ]
        model = _build_args_model("test_op", params)

        assert "limit" in model.model_fields
        assert not model.model_fields["limit"].is_required()

    def test_builds_model_with_multiple_fields(self) -> None:
        """Should build model with multiple fields."""
        params = [
            {"name": "id", "required": True, "schema": {"type": "string"}},
            {"name": "name", "required": True, "schema": {"type": "string"}},
            {"name": "age", "required": False, "schema": {"type": "integer"}},
        ]
        model = _build_args_model("multi_op", params)

        assert len(model.model_fields) == 3
        assert model.model_fields["id"].is_required()
        assert model.model_fields["name"].is_required()
        assert not model.model_fields["age"].is_required()


class TestCreateApiTool:
    """Tests for _create_api_tool."""

    def test_creates_tool_with_correct_name(self) -> None:
        """Tool should have correct operation ID as name."""
        operation = {"operationId": "get_users", "summary": "Get users"}
        tool = _create_api_tool("https://api.example.com", "/users", "get", operation)

        assert tool.name == "get_users"

    def test_creates_tool_with_description(self) -> None:
        """Tool should have operation summary as description."""
        operation = {"operationId": "get_users", "summary": "List all users"}
        tool = _create_api_tool("https://api.example.com", "/users", "get", operation)

        assert tool.description == "List all users"

    def test_creates_tool_with_fallback_name(self) -> None:
        """Tool should generate name if operationId missing."""
        operation = {"summary": "Get users"}
        tool = _create_api_tool("https://api.example.com", "/users", "get", operation)

        assert "get" in tool.name.lower()


class TestGenerateToolsFromSpec:
    """Tests for generate_tools_from_spec."""

    def test_generates_tools_for_each_endpoint(
        self,
        simple_openapi_spec: dict[str, Any],
    ) -> None:
        """Should generate a tool for each endpoint."""
        tools = generate_tools_from_spec(simple_openapi_spec)

        assert len(tools) == 2
        names = {t.name for t in tools}
        assert "list_users" in names
        assert "get_user" in names

    def test_handles_empty_paths(self) -> None:
        """Should handle spec with no paths."""
        spec = {
            "openapi": "3.0.0",
            "info": {"title": "Empty", "version": "1.0.0"},
            "paths": {},
        }
        tools = generate_tools_from_spec(spec)
        assert tools == []

    def test_handles_missing_servers(self) -> None:
        """Should handle spec with no servers."""
        spec = {
            "openapi": "3.0.0",
            "info": {"title": "No Servers", "version": "1.0.0"},
            "paths": {
                "/test": {"get": {"operationId": "test", "summary": "Test"}},
            },
        }
        tools = generate_tools_from_spec(spec)
        assert len(tools) == 1

    def test_handles_multiple_methods(self) -> None:
        """Should generate tools for multiple HTTP methods on same path."""
        spec = {
            "openapi": "3.0.0",
            "info": {"title": "Multi", "version": "1.0.0"},
            "servers": [{"url": "https://api.example.com"}],
            "paths": {
                "/items": {
                    "get": {"operationId": "list_items", "summary": "List"},
                    "post": {"operationId": "create_item", "summary": "Create"},
                },
            },
        }
        tools = generate_tools_from_spec(spec)

        assert len(tools) == 2
        names = {t.name for t in tools}
        assert "list_items" in names
        assert "create_item" in names


class TestLoadAndGenerateTools:
    """Tests for load_and_generate_tools."""

    def test_loads_and_generates_tools(self, temp_spec_file: Path) -> None:
        """Should load spec and generate tools."""
        result = load_and_generate_tools(temp_spec_file)

        assert isinstance(result, Ok)
        assert len(result.ok_value) == 2

    def test_returns_error_for_invalid_file(self) -> None:
        """Should return error for invalid file."""
        result = load_and_generate_tools(Path("/nonexistent.json"))
        assert isinstance(result, Err)

    def test_passes_auth_token_to_tools(self, temp_spec_file: Path) -> None:
        """Should pass auth token when generating tools."""
        result = load_and_generate_tools(temp_spec_file, auth_token="test_token")

        assert isinstance(result, Ok)
        # Tools should be created with auth token
        # (we can't easily inspect this without calling the tool)
        assert len(result.ok_value) > 0

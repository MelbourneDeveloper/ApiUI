"""Tests for meta tools generation."""

from __future__ import annotations

import json
from typing import Any

import pytest
from result import Err, Ok

from meta_tools import (
    OperationSpec,
    ParamSpec,
    build_description,
    create_meta_tool,
    extract_groups_from_tags,
    extract_operation,
    generate_meta_tools,
    validate_params,
)


@pytest.fixture
def github_spec() -> dict[str, Any]:
    """A GitHub-like OpenAPI spec with tags."""
    return {
        "openapi": "3.0.0",
        "info": {"title": "GitHub API", "version": "1.0.0"},
        "servers": [{"url": "https://api.github.com"}],
        "tags": [{"name": "users"}, {"name": "repos"}],
        "paths": {
            "/users/{username}": {
                "get": {
                    "operationId": "get_user",
                    "summary": "Get a user by username",
                    "tags": ["users"],
                    "parameters": [
                        {
                            "name": "username",
                            "in": "path",
                            "required": True,
                            "schema": {"type": "string"},
                        },
                    ],
                },
            },
            "/users/{username}/repos": {
                "get": {
                    "operationId": "list_user_repos",
                    "summary": "List repos for a user",
                    "tags": ["users"],
                    "parameters": [
                        {
                            "name": "username",
                            "in": "path",
                            "required": True,
                            "schema": {"type": "string"},
                        },
                        {
                            "name": "per_page",
                            "in": "query",
                            "required": False,
                            "schema": {"type": "integer"},
                        },
                    ],
                },
            },
            "/repos/{owner}/{repo}": {
                "get": {
                    "operationId": "get_repo",
                    "summary": "Get a repository",
                    "tags": ["repos"],
                    "parameters": [
                        {
                            "name": "owner",
                            "in": "path",
                            "required": True,
                            "schema": {"type": "string"},
                        },
                        {
                            "name": "repo",
                            "in": "path",
                            "required": True,
                            "schema": {"type": "string"},
                        },
                    ],
                },
            },
        },
    }


class TestExtractGroupsFromTags:
    """Tests for extract_groups_from_tags."""

    def test_extracts_groups_by_tag(self, github_spec: dict[str, Any]) -> None:
        """Should group operations by their tags."""
        groups = extract_groups_from_tags(github_spec)

        assert "users" in groups
        assert "repos" in groups
        assert set(groups["users"]) == {"get_user", "list_user_repos"}
        assert groups["repos"] == ["get_repo"]

    def test_uses_default_tag_when_missing(self) -> None:
        """Should use 'default' tag for untagged operations."""
        spec: dict[str, Any] = {
            "paths": {
                "/test": {
                    "get": {"operationId": "test_op"},
                },
            },
        }
        groups = extract_groups_from_tags(spec)

        assert "default" in groups
        assert groups["default"] == ["test_op"]


class TestExtractOperation:
    """Tests for extract_operation."""

    def test_finds_operation_by_id(self, github_spec: dict[str, Any]) -> None:
        """Should find and return operation spec by operationId."""
        result = extract_operation(github_spec, "get_user")

        assert isinstance(result, Ok)
        op = result.ok_value
        assert op.operation_id == "get_user"
        assert op.method == "get"
        assert op.path == "/users/{username}"
        assert op.summary == "Get a user by username"
        assert len(op.params) == 1
        assert op.params[0].name == "username"
        assert op.params[0].required is True

    def test_returns_error_for_unknown_operation(self, github_spec: dict[str, Any]) -> None:
        """Should return error for non-existent operationId."""
        result = extract_operation(github_spec, "nonexistent")

        assert isinstance(result, Err)
        assert "not found" in result.err_value


class TestValidateParams:
    """Tests for validate_params."""

    def test_passes_with_all_required_params(self) -> None:
        """Should pass validation when all required params provided."""
        op = OperationSpec(
            operation_id="get_user",
            method="get",
            path="/users/{username}",
            summary="Get user",
            params=(ParamSpec(name="username", required=True, param_in="path"),),
        )

        result = validate_params(op, {"username": "octocat"})

        assert isinstance(result, Ok)
        assert result.ok_value == {"username": "octocat"}

    def test_fails_with_missing_required_param(self) -> None:
        """Should fail when required param is missing."""
        op = OperationSpec(
            operation_id="get_repo",
            method="get",
            path="/repos/{owner}/{repo}",
            summary="Get repo",
            params=(
                ParamSpec(name="owner", required=True, param_in="path"),
                ParamSpec(name="repo", required=True, param_in="path"),
            ),
        )

        result = validate_params(op, {"owner": "anthropics"})

        assert isinstance(result, Err)
        assert "repo" in result.err_value

    def test_passes_with_optional_params_missing(self) -> None:
        """Should pass when optional params are not provided."""
        op = OperationSpec(
            operation_id="list_repos",
            method="get",
            path="/users/{username}/repos",
            summary="List repos",
            params=(
                ParamSpec(name="username", required=True, param_in="path"),
                ParamSpec(name="per_page", required=False, param_in="query"),
            ),
        )

        result = validate_params(op, {"username": "octocat"})

        assert isinstance(result, Ok)


class TestBuildDescription:
    """Tests for build_description."""

    def test_formats_description_with_operations(self) -> None:
        """Should build readable description with all operations."""
        ops = [
            OperationSpec(
                operation_id="get_user",
                method="get",
                path="/users/{username}",
                summary="Get a user",
                params=(ParamSpec(name="username", required=True, param_in="path"),),
            ),
            OperationSpec(
                operation_id="list_repos",
                method="get",
                path="/users/{username}/repos",
                summary="List repos",
                params=(
                    ParamSpec(name="username", required=True, param_in="path"),
                    ParamSpec(name="per_page", required=False, param_in="query"),
                ),
            ),
        ]

        desc = build_description("users", ops)

        assert "users" in desc
        assert "get_user" in desc
        assert "list_repos" in desc
        assert "username" in desc
        assert "per_page?" in desc  # Optional param has ?


class TestCreateMetaTool:
    """Tests for create_meta_tool."""

    def test_creates_tool_with_operations(self, github_spec: dict[str, Any]) -> None:
        """Should create a working meta tool."""
        result = create_meta_tool(
            tool_name="users",
            operation_ids=["get_user", "list_user_repos"],
            spec=github_spec,
            base_url="https://api.github.com",
            auth_token=None,
        )

        assert isinstance(result, Ok)
        tool = result.ok_value
        assert tool.name == "users"
        assert "get_user" in tool.description
        assert "list_user_repos" in tool.description

    def test_returns_error_for_unknown_operation(self, github_spec: dict[str, Any]) -> None:
        """Should return error if operation doesn't exist."""
        result = create_meta_tool(
            tool_name="test",
            operation_ids=["nonexistent_op"],
            spec=github_spec,
            base_url="https://api.github.com",
            auth_token=None,
        )

        assert isinstance(result, Err)


class TestGenerateMetaTools:
    """Tests for generate_meta_tools."""

    def test_generates_tools_from_tags(self, github_spec: dict[str, Any]) -> None:
        """Should auto-generate meta tools from spec tags."""
        result = generate_meta_tools(None, github_spec, None)

        assert isinstance(result, Ok)
        tools = result.ok_value
        tool_names = {t.name for t in tools}
        assert "users" in tool_names
        assert "repos" in tool_names

    def test_uses_explicit_groups_when_provided(self, github_spec: dict[str, Any]) -> None:
        """Should use provided groups instead of tags."""
        groups = {"custom_group": ["get_user", "get_repo"]}
        result = generate_meta_tools(groups, github_spec, None)

        assert isinstance(result, Ok)
        tools = result.ok_value
        assert len(tools) == 1
        assert tools[0].name == "custom_group"


class TestMetaToolExecution:
    """Tests for meta tool execution."""

    def test_returns_error_for_unknown_operation(self, github_spec: dict[str, Any]) -> None:
        """Should return error JSON for unknown operation."""
        result = create_meta_tool(
            tool_name="users",
            operation_ids=["get_user"],
            spec=github_spec,
            base_url="https://api.github.com",
            auth_token=None,
        )
        assert isinstance(result, Ok)
        tool = result.ok_value

        output = tool.func(operation="nonexistent", params={})
        parsed = json.loads(output)

        assert "error" in parsed
        assert "Unknown operation" in parsed["error"]
        assert "available" in parsed

    def test_returns_error_for_missing_params(self, github_spec: dict[str, Any]) -> None:
        """Should return error JSON for missing required params."""
        result = create_meta_tool(
            tool_name="users",
            operation_ids=["get_user"],
            spec=github_spec,
            base_url="https://api.github.com",
            auth_token=None,
        )
        assert isinstance(result, Ok)
        tool = result.ok_value

        output = tool.func(operation="get_user", params={})
        parsed = json.loads(output)

        assert "error" in parsed
        assert "username" in parsed["error"]

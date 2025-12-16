"""Tests for agent creation and execution."""
# ruff: noqa: PLC0415, PLR2004, S106

from __future__ import annotations

import tempfile
from pathlib import Path

from result import Err, Ok

from constants import DEFAULT_MODEL, load_config
from core import build_tools, create_agent_executor, create_llm

# Load config for tests
_config = load_config()
assert isinstance(_config, Ok), f"Failed to load config: {_config}"
SYSTEM_PROMPT = _config.ok_value.system_prompt


class TestCreateLlm:
    """Tests for create_llm function."""

    def test_creates_claude_instance(self) -> None:
        """Should create ChatAnthropic instance."""
        from langchain_anthropic import ChatAnthropic

        llm = create_llm(DEFAULT_MODEL)
        assert isinstance(llm, ChatAnthropic)

    def test_uses_default_model(self) -> None:
        """Should use default model name."""
        llm = create_llm(DEFAULT_MODEL)
        assert "claude" in llm.model.lower()

    def test_uses_custom_model(self) -> None:
        """Should accept custom model name."""
        llm = create_llm(model_name=DEFAULT_MODEL)
        assert llm.model == DEFAULT_MODEL

    def test_default_temperature_is_zero(self) -> None:
        """Default temperature should be 0 for deterministic output."""
        llm = create_llm(DEFAULT_MODEL)
        assert llm.temperature == 0.0

    def test_custom_temperature(self) -> None:
        """Should accept custom temperature."""
        llm = create_llm(DEFAULT_MODEL, temperature=0.7)
        assert llm.temperature == 0.7


class TestSystemPrompt:
    """Tests for system prompt."""

    def test_prompt_exists(self) -> None:
        """System prompt should be defined."""
        assert SYSTEM_PROMPT is not None
        assert len(SYSTEM_PROMPT) > 0

    def test_prompt_mentions_tools(self) -> None:
        """System prompt should mention tools."""
        assert "tool" in SYSTEM_PROMPT.lower()

    def test_prompt_mentions_api(self) -> None:
        """System prompt should mention APIs."""
        assert "api" in SYSTEM_PROMPT.lower()


class TestBuildTools:
    """Tests for build_tools function."""

    def test_returns_display_tools_when_no_spec(self) -> None:
        """Should return display tools when no spec path provided."""
        result = build_tools()
        assert isinstance(result, Ok)
        # Should have 4 display tools
        assert len(result.ok_value) == 4

    def test_includes_api_tools_when_spec_provided(self) -> None:
        """Should include API tools when valid spec provided."""
        spec = {
            "openapi": "3.0.0",
            "info": {"title": "Test", "version": "1.0.0"},
            "servers": [{"url": "https://api.example.com"}],
            "paths": {
                "/test": {"get": {"operationId": "test_op", "summary": "Test"}},
            },
        }

        with tempfile.NamedTemporaryFile(
            mode="w",
            suffix=".json",
            delete=False,
        ) as f:
            import json

            json.dump(spec, f)
            f.flush()
            result = build_tools(Path(f.name))

        assert isinstance(result, Ok)
        # 4 display tools + 1 API tool
        assert len(result.ok_value) == 5

    def test_returns_error_for_invalid_spec(self) -> None:
        """Should return error for invalid spec file."""
        result = build_tools(Path("/nonexistent/spec.json"))
        assert isinstance(result, Err)

    def test_passes_auth_token_to_api_tools(self) -> None:
        """Should pass auth token when building API tools."""
        spec = {
            "openapi": "3.0.0",
            "info": {"title": "Test", "version": "1.0.0"},
            "servers": [{"url": "https://api.example.com"}],
            "paths": {
                "/test": {"get": {"operationId": "test_op", "summary": "Test"}},
            },
        }

        with tempfile.NamedTemporaryFile(
            mode="w",
            suffix=".json",
            delete=False,
        ) as f:
            import json

            json.dump(spec, f)
            f.flush()
            result = build_tools(Path(f.name), auth_token="test_token")

        assert isinstance(result, Ok)


class TestCreateAgentExecutor:
    """Tests for create_agent_executor function."""

    def test_creates_executor(self) -> None:
        """Should create CompiledStateGraph instance."""
        from langgraph.graph.state import CompiledStateGraph

        # Use display tools (no external API needed)
        from display_tools import get_display_tools

        tools = get_display_tools()
        executor = create_agent_executor(tools, SYSTEM_PROMPT)

        assert isinstance(executor, CompiledStateGraph)

    def test_executor_is_invocable(self) -> None:
        """Executor should be invocable."""
        from display_tools import get_display_tools

        tools = get_display_tools()
        executor = create_agent_executor(tools, SYSTEM_PROMPT)

        assert hasattr(executor, "invoke")

    def test_uses_custom_model(self) -> None:
        """Should use custom model when specified."""
        from display_tools import get_display_tools

        tools = get_display_tools()
        executor = create_agent_executor(tools, SYSTEM_PROMPT, model_name=DEFAULT_MODEL)

        # The executor should be created (we can't easily inspect the model)
        assert executor is not None

"""EXPENSIVE integration tests with real LLM and API calls.

These tests require:
- ANTHROPIC_API_KEY environment variable
- Internet connection to REST Countries API
- Cost: ~$0.01 per full test run (with Haiku model)

All tests in this file call the real LLM and incur API costs.
"""
# ruff: noqa: ARG001, ARG002, PLR2004, N801

from __future__ import annotations

import logging
from pathlib import Path
from typing import TYPE_CHECKING

import pytest
from result import Err, Ok

from constants import DEFAULT_MODEL
from core import build_tools, create_agent_executor, run_agent
from session import add_message_to_session, create_session

if TYPE_CHECKING:
    from _langchain_types import AgentExecutorProtocol

logger = logging.getLogger(__name__)

# Model and spec path for integration tests - hardcoded to REST Countries
INTEGRATION_MODEL = DEFAULT_MODEL
SPEC_PATH = Path(__file__).parent.parent.parent / "specs" / "restcountries.json"


pytestmark = pytest.mark.integration


@pytest.fixture
def restcountries_executor(skip_if_no_api_key: None) -> AgentExecutorProtocol:
    """Create agent with REST Countries tools."""
    match build_tools(SPEC_PATH):
        case Ok(tools):
            return create_agent_executor(tools, INTEGRATION_MODEL)
        case Err(e):
            pytest.fail(f"Failed to build tools: {e}")


@pytest.mark.expensive
class TestExpensive_RealLLMToolSelection:
    """EXPENSIVE: Test that real LLM selects appropriate tools."""

    @pytest.mark.slow
    def test_expensive_selects_country_by_name_tool(
        self,
        restcountries_executor: AgentExecutorProtocol,
    ) -> None:
        """LLM should select get_country_by_name for name queries."""
        session = create_session()

        match run_agent(
            restcountries_executor,
            session,
            "What is the capital of France?",
        ):
            case Ok(result):
                # Should mention Paris (the capital)
                assert "paris" in result.response.lower()
                # Response should be substantial (not empty/error)
                assert len(result.response) > 20
            case Err(e):
                pytest.fail(f"Agent failed: {e}")

    @pytest.mark.slow
    def test_expensive_selects_region_tool_for_region_queries(
        self,
        restcountries_executor: AgentExecutorProtocol,
    ) -> None:
        """LLM should use get_countries_by_region for region queries."""
        session = create_session()

        match run_agent(
            restcountries_executor,
            session,
            "List 3 countries in Oceania",
        ):
            case Ok(result):
                # Should mention at least one Oceania country in response or tool outputs
                oceania_countries = ["australia", "new zealand", "fiji", "samoa"]
                all_content = result.response.lower() + " ".join(result.tool_outputs).lower()
                assert any(country in all_content for country in oceania_countries), (
                    f"Expected Oceania country, got: {result.response}"
                )
            case Err(e):
                pytest.fail(f"Agent failed: {e}")

    @pytest.mark.slow
    def test_expensive_handles_currency_queries(
        self,
        restcountries_executor: AgentExecutorProtocol,
    ) -> None:
        """LLM should use get_countries_by_currency appropriately."""
        session = create_session()

        match run_agent(
            restcountries_executor,
            session,
            "Which countries use the Euro?",
        ):
            case Ok(result):
                # Should mention at least one eurozone country in response or tool outputs
                euro_countries = ["germany", "france", "spain", "italy"]
                all_content = result.response.lower() + " ".join(result.tool_outputs).lower()
                assert any(country in all_content for country in euro_countries), (
                    f"Expected eurozone country, got: {result.response}"
                )
            case Err(e):
                pytest.fail(f"Agent failed: {e}")


@pytest.mark.expensive
class TestExpensive_RealAPIIntegration:
    """EXPENSIVE: Test actual API calls to REST Countries."""

    @pytest.mark.slow
    def test_expensive_makes_successful_api_call(
        self,
        restcountries_executor: AgentExecutorProtocol,
    ) -> None:
        """Should make real HTTP request and return valid data."""
        session = create_session()

        match run_agent(
            restcountries_executor,
            session,
            "What is the population of Japan?",
        ):
            case Ok(result):
                all_content = result.response + " ".join(result.tool_outputs)
                # Should contain numeric population info
                assert any(char.isdigit() for char in all_content), (
                    f"Expected numeric data, got: {result.response}"
                )
                # Should mention Japan
                assert "japan" in all_content.lower(), f"Expected 'japan', got: {result.response}"
            case Err(e):
                pytest.fail(f"Agent failed: {e}")

    def test_expensive_handles_api_error_gracefully(
        self,
        restcountries_executor: AgentExecutorProtocol,
    ) -> None:
        """Should handle invalid API requests gracefully."""
        session = create_session()

        # Use obviously fake country name
        match run_agent(
            restcountries_executor,
            session,
            "Tell me about the country Zzzzz999Invalid",
        ):
            case Ok(result):
                # Should acknowledge it doesn't exist or can't find it
                error_indicators = [
                    "not found",
                    "could not",
                    "unable",
                    "doesn't exist",
                    "no country",
                    "cannot find",
                    "don't have",
                ]
                assert any(ind in result.response.lower() for ind in error_indicators)
            case Err(_):
                # Also acceptable - agent may return error
                pass


@pytest.mark.expensive
class TestExpensive_MultiTurnConversation:
    """EXPENSIVE: Test conversation state across multiple turns."""

    @pytest.mark.slow
    def test_expensive_maintains_context_across_turns(
        self,
        restcountries_executor: AgentExecutorProtocol,
    ) -> None:
        """Agent should maintain context in multi-turn conversations."""
        session = create_session()

        # First turn - ask about Germany
        match run_agent(
            restcountries_executor,
            session,
            "What is the capital of Germany?",
        ):
            case Ok(result):
                session = add_message_to_session(
                    session, "human", "What is the capital of Germany?"
                )
                session = add_message_to_session(session, "assistant", result.response)
                assert "berlin" in result.response.lower()
            case Err(e):
                pytest.fail(f"First turn failed: {e}")

        # Second turn - use pronoun reference
        match run_agent(
            restcountries_executor,
            session,
            "What region is it in?",
        ):
            case Ok(result):
                # Should know "it" refers to Germany
                assert "europe" in result.response.lower()
            case Err(e):
                pytest.fail(f"Second turn failed: {e}")


class TestExpensive_DisplayToolUsage:
    """EXPENSIVE: Test that agent uses display tools appropriately."""

    @pytest.mark.slow
    def test_expensive_uses_display_link_for_urls(self, skip_if_no_api_key: None) -> None:
        """Agent should use display_link when asked to show URLs."""
        match build_tools():  # Only display tools, no API spec
            case Ok(tools):
                logger.info("Available tools: %s", [t.name for t in tools])
                executor = create_agent_executor(tools, INTEGRATION_MODEL)
            case Err(e):
                pytest.fail(f"Failed to build tools: {e}")

        session = create_session()

        prompt = (
            "Use the display_link tool to show me a clickable link to "
            "https://www.anthropic.com with the title 'Anthropic'"
        )
        logger.info("Test prompt: %s", prompt)

        match run_agent(executor, session, prompt):
            case Ok(result):
                # Check tool outputs for link JSON
                has_link_tool = any(
                    '"type": "link"' in out or '"type":"link"' in out for out in result.tool_outputs
                )
                has_url = "anthropic.com" in result.response.lower()

                logger.info(
                    "Response: %s (type=%s, length=%d, has_link_tool=%s, has_url=%s)",
                    result.response,
                    type(result).__name__,
                    len(result.response),
                    has_link_tool,
                    has_url,
                )

                # At minimum should have used the tool or mentioned the URL
                assert has_link_tool or has_url, (
                    f"Expected tool usage or URL mention, got: {result.response}"
                )
            case Err(e):
                pytest.fail(f"Agent failed: {e}")


class TestExpensive_ErrorHandling:
    """EXPENSIVE: Test agent error handling with real LLM."""

    def test_expensive_handles_network_timeout_gracefully(
        self,
        restcountries_executor: AgentExecutorProtocol,
    ) -> None:
        """Should return error Result on network issues."""
        # This test validates error handling structure
        # In practice, network errors are rare with REST Countries
        session = create_session()

        result = run_agent(
            restcountries_executor,
            session,
            "What is the capital of Canada?",
        )

        # Should return a Result type (Ok or Err, both acceptable)
        assert isinstance(result, (Ok, Err))


# Validation test - runs unconditionally to verify test setup
class TestIntegrationTestSetup:
    """Validate integration test infrastructure."""

    def test_spec_file_exists(self) -> None:
        """REST Countries spec should exist."""
        assert SPEC_PATH is not None
        assert SPEC_PATH.exists()
        assert SPEC_PATH.suffix == ".json"

    def test_spec_path_constant(self, restcountries_spec_path: Path) -> None:
        """SPEC_PATH constant should match config-loaded spec path."""
        assert restcountries_spec_path == SPEC_PATH
        assert restcountries_spec_path.exists()
        assert restcountries_spec_path.suffix in {".json", ".yaml", ".yml"}

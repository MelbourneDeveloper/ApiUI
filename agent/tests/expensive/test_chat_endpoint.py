"""EXPENSIVE API endpoint tests that hit the real LLM via /chat endpoint.

These tests:
- Spin up ACTUAL FastAPI server in subprocess (production mode)
- Use httpx HTTP client to make real HTTP requests
- Hit the /chat endpoint with REAL LLM calls
- NO MOCKING - real server, real HTTP, real LLM, real money

Requirements:
- ANTHROPIC_API_KEY environment variable (FAILS HARD if not set)
- Cost: ~$0.01 per full test run
"""

from __future__ import annotations

import multiprocessing
import os
import time
from typing import TYPE_CHECKING

import httpx
import pytest
import uvicorn

if TYPE_CHECKING:
    from collections.abc import Generator

_HTTP_OK = 200
_SERVER_HOST = "127.0.0.1"
_SERVER_PORT = 8000
_BASE_URL = f"http://{_SERVER_HOST}:{_SERVER_PORT}"
_STARTUP_TIMEOUT = 10  # seconds
_EXPECTED_MESSAGE_COUNT_AFTER_ONE_EXCHANGE = 2  # human + assistant

pytestmark = [pytest.mark.integration, pytest.mark.expensive]


def _run_server() -> None:
    """Run the FastAPI server in a subprocess (production mode)."""
    # MUST set env var BEFORE importing server module
    os.environ["RATE_LIMIT"] = "10000/minute"

    from server import app  # noqa: PLC0415

    uvicorn.run(app, host=_SERVER_HOST, port=_SERVER_PORT, log_level="error")


@pytest.fixture(scope="module")
def server_process() -> Generator[multiprocessing.Process, None, None]:
    """Start the FastAPI server in a background process."""
    # FAIL HARD if ANTHROPIC_API_KEY not set in .env
    from dotenv import load_dotenv  # noqa: PLC0415

    load_dotenv()
    match os.environ.get("ANTHROPIC_API_KEY"):
        case None | "":
            pytest.fail("ANTHROPIC_API_KEY not set - integration tests require real API key!")
        case _:
            pass

    process = multiprocessing.Process(target=_run_server, daemon=True)
    process.start()

    # Wait for server to start
    client = httpx.Client(base_url=_BASE_URL)
    start_time = time.time()
    while time.time() - start_time < _STARTUP_TIMEOUT:
        try:
            response = client.get("/health")
            if response.status_code == _HTTP_OK:
                break
        except httpx.ConnectError:
            time.sleep(0.1)
    else:
        process.terminate()
        pytest.fail("Server failed to start within timeout")

    yield process

    # Cleanup
    process.terminate()
    process.join(timeout=5)
    if process.is_alive():
        process.kill()


@pytest.fixture
def client(server_process: multiprocessing.Process) -> httpx.Client:  # noqa: ARG001
    """Create an HTTP client for the running server."""
    return httpx.Client(base_url=_BASE_URL, timeout=60.0)


class TestChatWithRealLLM:
    """Tests for /chat endpoint with real LLM calls."""

    def test_simple_chat_message(
        self,
        client: httpx.Client,
    ) -> None:
        """Should handle simple chat message with real LLM."""
        # Create session
        session_response = client.post("/session")
        session_id = session_response.json()["id"]

        # Send chat message
        response = client.post(
            "/chat",
            json={"session_id": session_id, "message": "What is 2+2?"},
        )

        assert response.status_code == _HTTP_OK
        data = response.json()
        assert data["session_id"] == session_id
        assert "response" in data
        assert len(data["response"]) > 0
        assert "4" in data["response"]

    def test_chat_returns_tool_outputs(
        self,
        client: httpx.Client,
    ) -> None:
        """Should return tool outputs array."""
        session_response = client.post("/session")
        session_id = session_response.json()["id"]

        response = client.post(
            "/chat",
            json={"session_id": session_id, "message": "Show me an image of a cat"},
        )

        assert response.status_code == _HTTP_OK
        data = response.json()
        assert "tool_outputs" in data
        assert isinstance(data["tool_outputs"], list)

    def test_multi_turn_conversation(
        self,
        client: httpx.Client,
    ) -> None:
        """Should maintain conversation context across turns."""
        session_response = client.post("/session")
        session_id = session_response.json()["id"]

        # First message
        response1 = client.post(
            "/chat",
            json={"session_id": session_id, "message": "My favorite number is 7"},
        )
        assert response1.status_code == _HTTP_OK

        # Second message referencing first
        response2 = client.post(
            "/chat",
            json={"session_id": session_id, "message": "What's my favorite number?"},
        )
        assert response2.status_code == _HTTP_OK
        assert "7" in response2.json()["response"]

    def test_session_message_count_increases(
        self,
        client: httpx.Client,
    ) -> None:
        """Session message count should increase after chat."""
        session_response = client.post("/session")
        session_id = session_response.json()["id"]

        # Send message
        client.post(
            "/chat",
            json={"session_id": session_id, "message": "Hello"},
        )

        # Check session
        session_check = client.get(f"/session/{session_id}")
        assert session_check.status_code == _HTTP_OK
        assert session_check.json()["message_count"] == _EXPECTED_MESSAGE_COUNT_AFTER_ONE_EXCHANGE

    def test_chat_with_display_tools(
        self,
        client: httpx.Client,
    ) -> None:
        """Should use display tools and return structured output."""
        session_response = client.post("/session")
        session_id = session_response.json()["id"]

        response = client.post(
            "/chat",
            json={
                "session_id": session_id,
                "message": "Show me a link to anthropic.com",
            },
        )

        assert response.status_code == _HTTP_OK
        data = response.json()

        # Should have tool outputs with link
        tool_outputs = data["tool_outputs"]
        assert len(tool_outputs) > 0
        # Find link output
        link_outputs = [t for t in tool_outputs if t.get("type") == "link"]
        assert len(link_outputs) > 0
        assert "anthropic.com" in link_outputs[0]["url"]

    def test_complete_chat_flow_end_to_end(
        self,
        client: httpx.Client,
    ) -> None:
        """Test complete flow: create session, chat, verify persistence."""
        # Create session
        create_response = client.post("/session")
        assert create_response.status_code == _HTTP_OK
        session_id = create_response.json()["id"]

        # Send message
        chat_response = client.post(
            "/chat",
            json={"session_id": session_id, "message": "Say hello"},
        )
        assert chat_response.status_code == _HTTP_OK
        assert "response" in chat_response.json()

        # Verify session updated
        get_response = client.get(f"/session/{session_id}")
        assert get_response.status_code == _HTTP_OK
        assert get_response.json()["message_count"] == _EXPECTED_MESSAGE_COUNT_AFTER_ONE_EXCHANGE

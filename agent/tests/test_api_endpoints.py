"""Full API endpoint tests with real server and HTTP client.

These tests:
- Spin up the actual FastAPI server in a background process
- Use httpx HTTP client to make real requests
- Test all endpoints end-to-end
- NO MOCKING - real server, real requests
"""

from __future__ import annotations

import json
import multiprocessing
import os
import tempfile
import time
import uuid
from pathlib import Path
from typing import TYPE_CHECKING

import httpx
import pytest
import uvicorn
from result import Ok

from session import Session, create_session, get_sessions_dir, save_session

if TYPE_CHECKING:
    from collections.abc import Generator

_HTTP_OK = 200
_HTTP_NOT_FOUND = 404
_HTTP_SERVER_ERROR = 500
_HTTP_TOO_MANY_REQUESTS = 429

# Server configuration
_SERVER_HOST = "127.0.0.1"
_SERVER_PORT = 8765  # Non-standard port to avoid conflicts
_BASE_URL = f"http://{_SERVER_HOST}:{_SERVER_PORT}"
_STARTUP_TIMEOUT = 10  # seconds


def _run_server() -> None:
    """Run the FastAPI server in a subprocess."""
    # MUST set env var BEFORE importing server module
    os.environ["RATE_LIMIT"] = "10000/minute"

    from server import app  # noqa: PLC0415

    uvicorn.run(app, host=_SERVER_HOST, port=_SERVER_PORT, log_level="error")


@pytest.fixture(scope="module")
def server_process() -> Generator[multiprocessing.Process, None, None]:
    """Start the FastAPI server in a background process."""
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
    return httpx.Client(base_url=_BASE_URL)


@pytest.fixture
def temp_sessions_dir() -> Generator[Path, None, None]:
    """Create a temporary sessions directory for isolated testing."""
    with tempfile.TemporaryDirectory() as tmpdir:
        sessions_dir = Path(tmpdir) / "sessions"
        sessions_dir.mkdir(parents=True)

        # Monkey-patch the sessions directory
        original_get_sessions_dir = get_sessions_dir.__code__

        def patched_get_sessions_dir() -> Path:
            return sessions_dir

        get_sessions_dir.__code__ = patched_get_sessions_dir.__code__

        yield sessions_dir

        # Restore original function
        get_sessions_dir.__code__ = original_get_sessions_dir


class TestHealthEndpoint:
    """Tests for GET /health endpoint."""

    def test_health_check_returns_ok(self, client: httpx.Client) -> None:
        """Health endpoint should return 200 OK."""
        response = client.get("/health")

        assert response.status_code == _HTTP_OK

    def test_health_check_includes_status(self, client: httpx.Client) -> None:
        """Health check should include status field."""
        response = client.get("/health")
        data = response.json()

        assert "status" in data
        assert data["status"] in ["ok", "degraded"]

    def test_health_check_includes_checks(self, client: httpx.Client) -> None:
        """Health check should include individual checks."""
        response = client.get("/health")
        data = response.json()

        assert "checks" in data
        assert isinstance(data["checks"], dict)
        assert "llm_model" in data["checks"]


class TestSessionCreation:
    """Tests for POST /session endpoint."""

    def test_creates_new_session(self, client: httpx.Client) -> None:
        """Should create a new session and return session info."""
        response = client.post("/session")

        assert response.status_code == _HTTP_OK
        data = response.json()
        assert "id" in data
        assert "message_count" in data
        assert data["message_count"] == 0

    def test_session_id_is_valid_uuid(self, client: httpx.Client) -> None:
        """Session ID should be a valid UUID."""
        response = client.post("/session")
        data = response.json()

        # Should not raise ValueError
        session_id = uuid.UUID(data["id"])
        assert str(session_id) == data["id"]

    def test_creates_unique_sessions(self, client: httpx.Client) -> None:
        """Each POST should create a unique session."""
        response1 = client.post("/session")
        response2 = client.post("/session")

        id1 = response1.json()["id"]
        id2 = response2.json()["id"]

        assert id1 != id2

    def test_persists_session_to_disk(self, client: httpx.Client) -> None:
        """Session should be saved to disk."""
        response = client.post("/session")
        session_id = response.json()["id"]

        # Check that session file exists
        sessions_dir = get_sessions_dir()
        session_file = sessions_dir / f"{session_id}.json"
        assert session_file.exists()

        # Verify file contents
        session_data = json.loads(session_file.read_text())
        assert session_data["id"] == session_id
        assert session_data["messages"] == []


class TestSessionRetrieval:
    """Tests for GET /session/{session_id} endpoint."""

    def test_retrieves_existing_session(self, client: httpx.Client) -> None:
        """Should retrieve an existing session."""
        # Create session
        create_response = client.post("/session")
        session_id = create_response.json()["id"]

        # Retrieve it
        response = client.get(f"/session/{session_id}")

        assert response.status_code == _HTTP_OK
        data = response.json()
        assert data["id"] == session_id
        assert data["message_count"] == 0

    def test_returns_404_for_nonexistent_session(self, client: httpx.Client) -> None:
        """Should return 404 for non-existent session."""
        fake_id = str(uuid.uuid4())
        response = client.get(f"/session/{fake_id}")

        assert response.status_code == _HTTP_NOT_FOUND

    def test_returns_correct_message_count(self, client: httpx.Client) -> None:
        """Should return accurate message count."""
        # Create session with messages
        session = create_session()
        session = Session(
            id=session.id,
            messages=[
                {"role": "human", "content": "Hello"},
                {"role": "assistant", "content": "Hi there"},
            ],
            auth_tokens={},
        )
        match save_session(session):
            case Ok(_):
                pass
            case _:
                pytest.fail("Failed to save test session")

        # Retrieve and verify count
        response = client.get(f"/session/{session.id}")
        expected_message_count = 2

        assert response.status_code == _HTTP_OK
        assert response.json()["message_count"] == expected_message_count


class TestAuthTokenSubmission:
    """Tests for POST /auth/token endpoint."""

    def test_accepts_auth_token(self, client: httpx.Client) -> None:
        """Should accept and store auth token."""
        # Create session
        session_response = client.post("/session")
        session_id = session_response.json()["id"]

        # Submit token
        response = client.post(
            "/auth/token",
            json={
                "session_id": session_id,
                "provider": "github",
                "token": "ghp_test123abc",
            },
        )

        assert response.status_code == _HTTP_OK
        assert response.json()["status"] == "ok"

    def test_persists_token_to_session(self, client: httpx.Client) -> None:
        """Token should be persisted to session file (encrypted)."""
        # Create session
        session_response = client.post("/session")
        session_id = session_response.json()["id"]

        # Submit token
        client.post(
            "/auth/token",
            json={
                "session_id": session_id,
                "provider": "github",
                "token": "secret_token_xyz",
            },
        )

        # Verify persistence
        sessions_dir = get_sessions_dir()
        session_file = sessions_dir / f"{session_id}.json"
        session_data = json.loads(session_file.read_text())

        # Token should be stored (encrypted, so won't match plaintext)
        assert "github" in session_data["auth_tokens"]
        assert session_data["auth_tokens"]["github"] != ""
        assert session_data["auth_tokens"]["github"] != "secret_token_xyz"  # Encrypted

    def test_returns_404_for_invalid_session(self, client: httpx.Client) -> None:
        """Should return 404 when session doesn't exist."""
        response = client.post(
            "/auth/token",
            json={
                "session_id": "invalid-session-id",
                "provider": "github",
                "token": "token123",
            },
        )

        assert response.status_code == _HTTP_NOT_FOUND

    def test_supports_multiple_providers(self, client: httpx.Client) -> None:
        """Should support tokens for multiple providers."""
        # Create session
        session_response = client.post("/session")
        session_id = session_response.json()["id"]

        # Submit tokens for different providers
        client.post(
            "/auth/token",
            json={"session_id": session_id, "provider": "github", "token": "gh_token"},
        )
        client.post(
            "/auth/token",
            json={"session_id": session_id, "provider": "gitlab", "token": "gl_token"},
        )

        # Verify both are stored (encrypted)
        sessions_dir = get_sessions_dir()
        session_file = sessions_dir / f"{session_id}.json"
        session_data = json.loads(session_file.read_text())

        assert "github" in session_data["auth_tokens"]
        assert "gitlab" in session_data["auth_tokens"]
        assert session_data["auth_tokens"]["github"] != ""
        assert session_data["auth_tokens"]["gitlab"] != ""


class TestConfigEndpoint:
    """Tests for GET /config endpoint."""

    def test_returns_config(self, client: httpx.Client) -> None:
        """Should return configuration."""
        response = client.get("/config")

        assert response.status_code == _HTTP_OK

    def test_includes_providers_list(self, client: httpx.Client) -> None:
        """Config should include providers list."""
        response = client.get("/config")
        data = response.json()

        assert "providers" in data
        assert isinstance(data["providers"], list)


class TestChatEndpoint:
    """Tests for POST /chat endpoint.

    Note: Chat endpoint tests require ANTHROPIC_API_KEY and call real LLM.
    These are tested in test_integration.py instead.
    """

    def test_requires_valid_session(self, client: httpx.Client) -> None:
        """Chat should fail with invalid session ID."""
        response = client.post(
            "/chat",
            json={"session_id": "invalid-id", "message": "Hello"},
        )

        # Should return error (404 or 500 both indicate validation failure)
        assert response.status_code in [_HTTP_NOT_FOUND, _HTTP_SERVER_ERROR]


class TestCORSHeaders:
    """Tests for CORS middleware."""

    def test_includes_cors_credentials_header(self, client: httpx.Client) -> None:
        """Responses should include CORS credentials header."""
        response = client.get(
            "/health",
            headers={"Origin": "http://localhost:3000"},
        )

        # CORS middleware is configured - credentials header should be present
        assert "access-control-allow-credentials" in response.headers

    def test_handles_cross_origin_requests(self, client: httpx.Client) -> None:
        """Should allow cross-origin requests from localhost."""
        response = client.post(
            "/session",
            headers={"Origin": "http://localhost:3000"},
        )

        # Should succeed with CORS configured
        assert response.status_code == _HTTP_OK
        assert "access-control-allow-credentials" in response.headers


class TestEndToEndFlow:
    """End-to-end tests for complete workflows."""

    def test_complete_session_lifecycle(self, client: httpx.Client) -> None:
        """Test complete flow: create session, submit token, get session."""
        # Create session
        create_response = client.post("/session")
        assert create_response.status_code == _HTTP_OK
        session_id = create_response.json()["id"]

        # Submit auth token
        token_response = client.post(
            "/auth/token",
            json={
                "session_id": session_id,
                "provider": "test_provider",
                "token": "test_token",
            },
        )
        assert token_response.status_code == _HTTP_OK

        # Retrieve session
        get_response = client.get(f"/session/{session_id}")
        assert get_response.status_code == _HTTP_OK
        assert get_response.json()["id"] == session_id

        # Verify token was saved (encrypted)
        sessions_dir = get_sessions_dir()
        session_file = sessions_dir / f"{session_id}.json"
        session_data = json.loads(session_file.read_text())
        assert "test_provider" in session_data["auth_tokens"]
        assert session_data["auth_tokens"]["test_provider"] != ""


class TestServerLifecycle:
    """Tests for server lifecycle and basic functionality."""

    def test_server_is_running(self, client: httpx.Client) -> None:
        """Verify server is actually running."""
        response = client.get("/health")
        assert response.status_code == _HTTP_OK

    def test_handles_multiple_requests(self, client: httpx.Client) -> None:
        """Server should handle multiple requests with delay."""
        results: list[int] = []
        for _ in range(3):
            response = client.post("/session")
            results.append(response.status_code)
            time.sleep(0.1)  # Small delay to avoid any rate limiting issues

        # All should succeed
        assert all(status == _HTTP_OK for status in results)

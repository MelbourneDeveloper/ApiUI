"""Tests for FastAPI server endpoints."""
# ruff: noqa: ARG002, PLR2004

from __future__ import annotations

import json
import tempfile
import uuid
from pathlib import Path
from typing import TYPE_CHECKING
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient

from server import _parse_tool_outputs, app

if TYPE_CHECKING:
    from collections.abc import Generator

_HTTP_OK = 200
_HTTP_NOT_FOUND = 404
_HTTP_SERVER_ERROR = 500


@pytest.fixture
def client() -> TestClient:
    """Create a test client."""
    return TestClient(app)


@pytest.fixture
def temp_sessions_dir() -> Generator[Path, None, None]:
    """Create a temporary sessions directory."""
    with tempfile.TemporaryDirectory() as tmpdir:
        sessions_dir = Path(tmpdir) / "sessions"
        sessions_dir.mkdir(parents=True)
        with patch("session.get_sessions_dir", return_value=sessions_dir):
            yield sessions_dir


class TestCreateSession:
    """Tests for POST /session endpoint."""

    def test_creates_session(self, client: TestClient, temp_sessions_dir: Path) -> None:
        """Should create a new session."""
        response = client.post("/session")

        assert response.status_code == _HTTP_OK
        data = response.json()
        assert "id" in data
        assert data["message_count"] == 0

    def test_session_id_is_uuid(
        self,
        client: TestClient,
        temp_sessions_dir: Path,
    ) -> None:
        """Session ID should be a valid UUID."""
        response = client.post("/session")
        data = response.json()

        # Should not raise
        uuid.UUID(data["id"])

    def test_creates_unique_sessions(
        self,
        client: TestClient,
        temp_sessions_dir: Path,
    ) -> None:
        """Each call should create a unique session."""
        response1 = client.post("/session")
        response2 = client.post("/session")

        assert response1.json()["id"] != response2.json()["id"]

    def test_saves_session_to_disk(
        self,
        client: TestClient,
        temp_sessions_dir: Path,
    ) -> None:
        """Session should be persisted to disk."""
        response = client.post("/session")
        session_id = response.json()["id"]

        session_file = temp_sessions_dir / f"{session_id}.json"
        assert session_file.exists()


class TestGetSession:
    """Tests for GET /session/{session_id} endpoint."""

    def test_gets_existing_session(
        self,
        client: TestClient,
        temp_sessions_dir: Path,
    ) -> None:
        """Should return existing session info."""
        # Create a session first
        create_response = client.post("/session")
        session_id = create_response.json()["id"]

        # Get the session
        response = client.get(f"/session/{session_id}")

        assert response.status_code == _HTTP_OK
        assert response.json()["id"] == session_id

    def test_returns_404_for_nonexistent_session(
        self,
        client: TestClient,
        temp_sessions_dir: Path,
    ) -> None:
        """Should return 404 for non-existent session."""
        response = client.get("/session/nonexistent-id")

        assert response.status_code == _HTTP_NOT_FOUND

    def test_returns_message_count(
        self,
        client: TestClient,
        temp_sessions_dir: Path,
    ) -> None:
        """Should return correct message count."""
        create_response = client.post("/session")
        session_id = create_response.json()["id"]

        response = client.get(f"/session/{session_id}")

        assert response.json()["message_count"] == 0


class TestAuthToken:
    """Tests for POST /auth/token endpoint."""

    def test_submits_token(
        self,
        client: TestClient,
        temp_sessions_dir: Path,
    ) -> None:
        """Should accept auth token submission."""
        create_response = client.post("/session")
        session_id = create_response.json()["id"]

        response = client.post(
            "/auth/token",
            json={
                "session_id": session_id,
                "provider": "github",
                "token": "abc123",
            },
        )

        assert response.status_code == _HTTP_OK
        assert response.json()["status"] == "ok"

    def test_returns_404_for_invalid_session(
        self,
        client: TestClient,
        temp_sessions_dir: Path,
    ) -> None:
        """Should return 404 for invalid session."""
        response = client.post(
            "/auth/token",
            json={
                "session_id": "invalid-id",
                "provider": "github",
                "token": "abc123",
            },
        )

        assert response.status_code == _HTTP_NOT_FOUND

    def test_persists_token(
        self,
        client: TestClient,
        temp_sessions_dir: Path,
    ) -> None:
        """Token should be persisted to session."""
        create_response = client.post("/session")
        session_id = create_response.json()["id"]

        client.post(
            "/auth/token",
            json={
                "session_id": session_id,
                "provider": "github",
                "token": "secret123",
            },
        )

        # Check the session file - token should be encrypted
        session_file = temp_sessions_dir / f"{session_id}.json"
        data = json.loads(session_file.read_text())
        assert "github" in data["auth_tokens"]
        assert data["auth_tokens"]["github"] != "secret123"  # Should be encrypted
        assert len(data["auth_tokens"]["github"]) > 20  # Encrypted tokens are longer


class TestConfig:
    """Tests for GET /config endpoint."""

    def test_returns_config(self, client: TestClient) -> None:
        """Should return configuration."""
        response = client.get("/config")

        assert response.status_code == _HTTP_OK
        data = response.json()
        assert "providers" in data

    def test_providers_is_list(self, client: TestClient) -> None:
        """Providers should be a list."""
        response = client.get("/config")
        data = response.json()

        assert isinstance(data["providers"], list)


class TestParseToolOutputs:
    """Tests for _parse_tool_outputs helper."""

    def test_parses_single_json_object(self) -> None:
        """Should parse single JSON object with type field."""
        tool_outputs = ['{"type": "image", "url": "test.png"}']
        outputs = _parse_tool_outputs(tool_outputs)

        assert len(outputs) == 1
        assert outputs[0]["type"] == "image"

    def test_parses_multiple_json_objects(self) -> None:
        """Should parse multiple JSON objects."""
        tool_outputs = [
            '{"type": "image", "url": "a.png"}',
            '{"type": "link", "url": "b.com"}',
        ]
        outputs = _parse_tool_outputs(tool_outputs)

        assert len(outputs) == 2

    def test_ignores_json_without_type(self) -> None:
        """Should ignore JSON objects without type field."""
        tool_outputs = ['{"name": "test"}', '{"type": "image", "url": "test.png"}']
        outputs = _parse_tool_outputs(tool_outputs)

        assert len(outputs) == 1
        assert outputs[0]["type"] == "image"

    def test_handles_empty_list(self) -> None:
        """Should return empty list when no outputs."""
        outputs = _parse_tool_outputs([])

        assert outputs == []

    def test_handles_invalid_json(self) -> None:
        """Should skip invalid JSON."""
        tool_outputs = ["{not valid json}", '{"type": "link", "url": "test"}']
        outputs = _parse_tool_outputs(tool_outputs)

        assert len(outputs) == 1
        assert outputs[0]["type"] == "link"

    def test_handles_nested_json(self) -> None:
        """Should handle nested JSON objects."""
        tool_outputs = ['{"type": "chart", "data": [{"x": 1, "y": 2}]}']
        outputs = _parse_tool_outputs(tool_outputs)

        assert len(outputs) == 1
        assert outputs[0]["type"] == "chart"
        assert outputs[0]["data"] == [{"x": 1, "y": 2}]

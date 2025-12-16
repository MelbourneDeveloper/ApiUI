"""Tests for session persistence."""

from __future__ import annotations

import json
import tempfile
import uuid
from pathlib import Path
from typing import TYPE_CHECKING
from unittest.mock import patch

import pytest
from result import Err, Ok

from session import (
    Session,
    add_message_to_session,
    create_session,
    load_session,
    save_session,
    session_to_langchain_messages,
    set_auth_token,
)

if TYPE_CHECKING:
    from collections.abc import Generator

_EXPECTED_TWO_MESSAGES = 2


@pytest.fixture
def temp_sessions_dir() -> Generator[Path, None, None]:
    """Create a temporary sessions directory."""
    with tempfile.TemporaryDirectory() as tmpdir:
        sessions_dir = Path(tmpdir) / "sessions"
        sessions_dir.mkdir(parents=True)
        with patch("session.get_sessions_dir", return_value=sessions_dir):
            yield sessions_dir


class TestCreateSession:
    """Tests for create_session."""

    def test_creates_unique_id(self) -> None:
        """Each session should have a unique UUID."""
        session1 = create_session()
        session2 = create_session()
        assert session1.id != session2.id

    def test_creates_empty_messages(self) -> None:
        """New session should have empty messages."""
        session = create_session()
        assert session.messages == []

    def test_creates_empty_auth_tokens(self) -> None:
        """New session should have empty auth tokens."""
        session = create_session()
        assert session.auth_tokens == {}

    def test_id_is_valid_uuid(self) -> None:
        """Session ID should be a valid UUID string."""
        session = create_session()
        # Should not raise
        uuid.UUID(session.id)


class TestSaveSession:
    """Tests for save_session."""

    def test_saves_session_to_file(self, temp_sessions_dir: Path) -> None:
        """Session should be saved to JSON file."""
        session = create_session()
        result = save_session(session)

        assert isinstance(result, Ok)
        path = temp_sessions_dir / f"{session.id}.json"
        assert path.exists()

    def test_saved_session_is_valid_json(self, temp_sessions_dir: Path) -> None:
        """Saved file should contain valid JSON."""
        session = create_session()
        save_session(session)

        path = temp_sessions_dir / f"{session.id}.json"
        data = json.loads(path.read_text())
        assert data["id"] == session.id
        assert data["messages"] == []
        assert data["auth_tokens"] == {}

    def test_saves_session_with_messages(self, temp_sessions_dir: Path) -> None:
        """Session with messages should be saved correctly."""
        session = Session(
            id="test-123",
            messages=[{"role": "human", "content": "hello"}],
            auth_tokens={},
        )
        save_session(session)

        path = temp_sessions_dir / "test-123.json"
        data = json.loads(path.read_text())
        assert data["messages"] == [{"role": "human", "content": "hello"}]

    def test_saves_session_with_auth_tokens(self, temp_sessions_dir: Path) -> None:
        """Session with auth tokens should be saved correctly (encrypted)."""
        session = Session(
            id="test-456",
            messages=[],
            auth_tokens={"github": "token123"},
        )
        save_session(session)

        path = temp_sessions_dir / "test-456.json"
        data = json.loads(path.read_text())
        # Tokens should be encrypted, not plaintext
        _min_encrypted_token_length = 20  # Encrypted tokens are longer than plaintext
        assert "github" in data["auth_tokens"]
        assert data["auth_tokens"]["github"] != "token123"  # Should be encrypted
        assert len(data["auth_tokens"]["github"]) > _min_encrypted_token_length


class TestLoadSession:
    """Tests for load_session."""

    @pytest.mark.usefixtures("temp_sessions_dir")
    def test_loads_existing_session(self) -> None:
        """Should load a previously saved session."""
        session = create_session()
        save_session(session)

        result = load_session(session.id)
        assert isinstance(result, Ok)
        assert result.ok_value.id == session.id

    @pytest.mark.usefixtures("temp_sessions_dir")
    def test_returns_error_for_nonexistent_session(self) -> None:
        """Should return error for non-existent session."""
        result = load_session("nonexistent-id")
        assert isinstance(result, Err)
        assert "not found" in result.err_value.lower()

    @pytest.mark.usefixtures("temp_sessions_dir")
    def test_preserves_messages(self) -> None:
        """Loaded session should have same messages."""
        session = Session(
            id="test-msg",
            messages=[
                {"role": "human", "content": "hi"},
                {"role": "assistant", "content": "hello"},
            ],
            auth_tokens={},
        )
        save_session(session)

        result = load_session("test-msg")
        assert isinstance(result, Ok)
        assert result.ok_value.messages == session.messages

    @pytest.mark.usefixtures("temp_sessions_dir")
    def test_preserves_auth_tokens(self) -> None:
        """Loaded session should have same auth tokens."""
        session = Session(
            id="test-auth",
            messages=[],
            auth_tokens={"google": "abc", "github": "xyz"},
        )
        save_session(session)

        result = load_session("test-auth")
        assert isinstance(result, Ok)
        assert result.ok_value.auth_tokens == session.auth_tokens

    def test_returns_error_for_corrupted_json(self, temp_sessions_dir: Path) -> None:
        """Should return error for corrupted JSON file."""
        path = temp_sessions_dir / "corrupted.json"
        path.write_text("not valid json {{{")

        result = load_session("corrupted")
        assert isinstance(result, Err)


class TestAddMessageToSession:
    """Tests for add_message_to_session."""

    def test_adds_message(self) -> None:
        """Should add message to session."""
        session = create_session()
        updated = add_message_to_session(session, "human", "hello")

        assert len(updated.messages) == 1
        assert updated.messages[0] == {"role": "human", "content": "hello"}

    def test_preserves_existing_messages(self) -> None:
        """Should preserve existing messages."""
        session = Session(
            id="test",
            messages=[{"role": "human", "content": "first"}],
            auth_tokens={},
        )
        updated = add_message_to_session(session, "assistant", "second")

        assert len(updated.messages) == _EXPECTED_TWO_MESSAGES
        assert updated.messages[0] == {"role": "human", "content": "first"}
        assert updated.messages[1] == {"role": "assistant", "content": "second"}

    def test_returns_new_session_instance(self) -> None:
        """Should return a new session, not modify original."""
        session = create_session()
        updated = add_message_to_session(session, "human", "test")

        assert session is not updated
        assert len(session.messages) == 0
        assert len(updated.messages) == 1

    def test_preserves_auth_tokens(self) -> None:
        """Should preserve auth tokens when adding message."""
        session = Session(
            id="test",
            messages=[],
            auth_tokens={"provider": "token"},
        )
        updated = add_message_to_session(session, "human", "msg")

        assert updated.auth_tokens == {"provider": "token"}


class TestSetAuthToken:
    """Tests for set_auth_token."""

    def test_sets_new_token(self) -> None:
        """Should set a new auth token."""
        session = create_session()
        updated = set_auth_token(session, "github", "abc123")

        assert updated.auth_tokens["github"] == "abc123"

    def test_overwrites_existing_token(self) -> None:
        """Should overwrite existing token for same provider."""
        session = Session(
            id="test",
            messages=[],
            auth_tokens={"github": "old"},
        )
        updated = set_auth_token(session, "github", "new")

        assert updated.auth_tokens["github"] == "new"

    def test_preserves_other_tokens(self) -> None:
        """Should preserve tokens for other providers."""
        session = Session(
            id="test",
            messages=[],
            auth_tokens={"google": "gtoken"},
        )
        updated = set_auth_token(session, "github", "ghtoken")

        assert updated.auth_tokens["google"] == "gtoken"
        assert updated.auth_tokens["github"] == "ghtoken"

    def test_returns_new_session_instance(self) -> None:
        """Should return a new session, not modify original."""
        session = create_session()
        updated = set_auth_token(session, "provider", "token")

        assert session is not updated
        assert session.auth_tokens == {}

    def test_preserves_messages(self) -> None:
        """Should preserve messages when setting token."""
        session = Session(
            id="test",
            messages=[{"role": "human", "content": "hi"}],
            auth_tokens={},
        )
        updated = set_auth_token(session, "provider", "token")

        assert updated.messages == session.messages


class TestSessionToLangchainMessages:
    """Tests for session_to_langchain_messages."""

    def test_converts_empty_session(self) -> None:
        """Empty session should return empty list."""
        session = create_session()
        messages = session_to_langchain_messages(session)
        assert messages == []

    def test_converts_single_message(self) -> None:
        """Single message should be converted to tuple."""
        session = Session(
            id="test",
            messages=[{"role": "human", "content": "hello"}],
            auth_tokens={},
        )
        messages = session_to_langchain_messages(session)

        assert messages == [("human", "hello")]

    def test_converts_multiple_messages(self) -> None:
        """Multiple messages should be converted in order."""
        session = Session(
            id="test",
            messages=[
                {"role": "human", "content": "hi"},
                {"role": "assistant", "content": "hello"},
                {"role": "human", "content": "how are you?"},
            ],
            auth_tokens={},
        )
        messages = session_to_langchain_messages(session)

        assert messages == [
            ("human", "hi"),
            ("assistant", "hello"),
            ("human", "how are you?"),
        ]

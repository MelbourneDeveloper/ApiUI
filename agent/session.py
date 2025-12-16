"""Session persistence for agent conversations."""

from __future__ import annotations

import json
import uuid
from datetime import UTC, datetime, timedelta
from pathlib import Path

from pydantic import BaseModel, ValidationError
from result import Err, Ok, Result

from crypto import decrypt_token, encrypt_token


class Session(BaseModel):
    """Represents a chat session with conversation history and auth state."""

    id: str
    messages: list[dict[str, str]]
    auth_tokens: dict[str, str]

    model_config = {"frozen": True}


def get_sessions_dir() -> Path:
    """Get the sessions directory, creating it if needed."""
    sessions_dir = Path.home() / ".agent_chat" / "sessions"
    sessions_dir.mkdir(parents=True, exist_ok=True)
    return sessions_dir


def create_session() -> Session:
    """Create a new empty session."""
    return Session(
        id=str(uuid.uuid4()),
        messages=[],
        auth_tokens={},
    )


def save_session(session: Session) -> Result[None, str]:
    """Save session to disk with encrypted auth tokens."""
    try:
        # Encrypt auth tokens before saving
        encrypted_tokens = {}
        for provider, token in session.auth_tokens.items():
            match encrypt_token(token):
                case Ok(encrypted):
                    encrypted_tokens[provider] = encrypted
                case Err(e):
                    return Err(f"Failed to encrypt token for {provider}: {e}")

        # Create session dict with encrypted tokens
        session_dict = session.model_dump()
        session_dict["auth_tokens"] = encrypted_tokens

        path = get_sessions_dir() / f"{session.id}.json"
        path.write_text(json.dumps(session_dict, indent=2))
        return Ok(None)
    except OSError as e:
        return Err(f"Failed to save session: {e}")


def load_session(session_id: str) -> Result[Session, str]:
    """Load session from disk and decrypt auth tokens."""
    try:
        path = get_sessions_dir() / f"{session_id}.json"
        match path.exists():
            case False:
                return Err(f"Session not found: {session_id}")
            case True:
                # Load session data
                session_data = json.loads(path.read_text())

                # Decrypt auth tokens
                decrypted_tokens = {}
                for provider, encrypted_token in session_data.get("auth_tokens", {}).items():
                    match decrypt_token(encrypted_token):
                        case Ok(decrypted):
                            decrypted_tokens[provider] = decrypted
                        case Err(e):
                            return Err(f"Failed to decrypt token for {provider}: {e}")

                session_data["auth_tokens"] = decrypted_tokens
                return Ok(Session.model_validate(session_data))
    except (OSError, json.JSONDecodeError, ValidationError) as e:
        return Err(f"Failed to load session: {e}")


def add_message_to_session(
    session: Session,
    role: str,
    content: str,
) -> Session:
    """Add a message to the session (returns new session)."""
    return Session(
        id=session.id,
        messages=[*session.messages, {"role": role, "content": content}],
        auth_tokens=session.auth_tokens,
    )


def set_auth_token(session: Session, provider: str, token: str) -> Session:
    """Set an auth token for a provider (returns new session)."""
    return Session(
        id=session.id,
        messages=session.messages,
        auth_tokens={**session.auth_tokens, provider: token},
    )


def session_to_langchain_messages(
    session: Session,
) -> list[tuple[str, str]]:
    """Convert session messages to LangChain message tuples."""
    return [(msg["role"], msg["content"]) for msg in session.messages]


def cleanup_old_sessions(max_age_days: int = 30) -> Result[int, str]:
    """Delete sessions older than max_age_days.

    Returns:
        Number of sessions deleted
    """
    try:
        sessions_dir = get_sessions_dir()
        cutoff_time = datetime.now(tz=UTC) - timedelta(days=max_age_days)
        deleted_count = 0

        for session_file in sessions_dir.glob("*.json"):
            match session_file.stat().st_mtime:
                case mtime if datetime.fromtimestamp(mtime, tz=UTC) < cutoff_time:
                    session_file.unlink()
                    deleted_count += 1
                case _:
                    pass

        return Ok(deleted_count)
    except OSError as e:
        return Err(f"Failed to cleanup sessions: {e}")

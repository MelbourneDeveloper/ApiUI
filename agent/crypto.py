"""Encryption utilities for sensitive data."""

from __future__ import annotations

import base64
from pathlib import Path

from cryptography.fernet import Fernet
from result import Err, Ok, Result


def _get_encryption_key_path() -> Path:
    """Get path to encryption key file."""
    return Path.home() / ".agent_chat" / "encryption.key"


def _load_or_create_key() -> bytes:
    """Load existing encryption key or create new one."""
    key_path = _get_encryption_key_path()
    key_path.parent.mkdir(parents=True, exist_ok=True)

    match key_path.exists():
        case True:
            return key_path.read_bytes()
        case False:
            key = Fernet.generate_key()
            key_path.write_bytes(key)
            # Secure file permissions (owner read/write only)
            key_path.chmod(0o600)
            return key


def encrypt_token(token: str) -> Result[str, str]:
    """Encrypt auth token for storage.

    Returns:
        Base64-encoded encrypted token
    """
    try:
        key = _load_or_create_key()
        cipher = Fernet(key)
        encrypted_bytes = cipher.encrypt(token.encode("utf-8"))
        return Ok(base64.b64encode(encrypted_bytes).decode("utf-8"))
    except (OSError, ValueError) as e:
        return Err(f"Encryption failed: {e}")


def decrypt_token(encrypted_token: str) -> Result[str, str]:
    """Decrypt auth token from storage.

    Args:
        encrypted_token: Base64-encoded encrypted token

    Returns:
        Original plaintext token
    """
    try:
        key = _load_or_create_key()
        cipher = Fernet(key)
        encrypted_bytes = base64.b64decode(encrypted_token.encode("utf-8"))
        decrypted_bytes = cipher.decrypt(encrypted_bytes)
        return Ok(decrypted_bytes.decode("utf-8"))
    except (OSError, ValueError) as e:
        return Err(f"Decryption failed: {e}")

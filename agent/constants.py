"""Application constants and configuration."""

from __future__ import annotations

import json
import os
from dataclasses import dataclass, field
from pathlib import Path
from urllib.parse import urlencode

from result import Err, Ok, Result

DEFAULT_MODEL = "claude-haiku-4-5"
_CONFIG_PATH = Path(__file__).parent / "config" / "agent_config.json"

GOOGLE_AUTH_URL = "https://accounts.google.com/o/oauth2/v2/auth"
GOOGLE_CALENDAR_SCOPES = "https://www.googleapis.com/auth/calendar.readonly"


@dataclass(frozen=True)
class OAuthProvider:
    """OAuth provider configuration."""

    name: str
    client_id: str
    auth_url: str
    scopes: str
    redirect_uri: str

    def build_auth_url(self, state: str) -> str:
        """Build the full OAuth authorization URL."""
        params = {
            "client_id": self.client_id,
            "redirect_uri": self.redirect_uri,
            "response_type": "token",
            "scope": self.scopes,
            "state": state,
        }
        return f"{self.auth_url}?{urlencode(params)}"


@dataclass(frozen=True)
class AgentConfig:
    """Agent configuration loaded from config file."""

    llm_model: str
    openapi_spec_path: Path
    system_prompt: str
    oauth_providers: tuple[OAuthProvider, ...] = field(default_factory=tuple)
    tool_mode: str = "individual"  # "individual" or "meta"
    meta_tool_groups: dict[str, list[str]] = field(  # pyright: ignore[reportUnknownVariableType]
        default_factory=dict,
    )


def _load_oauth_providers() -> tuple[OAuthProvider, ...]:
    """Load OAuth providers from environment variables."""
    providers: list[OAuthProvider] = []
    google_client_id = os.getenv("GOOGLE_CLIENT_ID")
    google_redirect_uri = os.getenv("GOOGLE_REDIRECT_URI", "http://localhost:8080/oauth/callback")
    match google_client_id:
        case None:
            pass
        case client_id:
            providers.append(
                OAuthProvider(
                    name="google",
                    client_id=client_id,
                    auth_url=GOOGLE_AUTH_URL,
                    scopes=GOOGLE_CALENDAR_SCOPES,
                    redirect_uri=google_redirect_uri,
                )
            )
    return tuple(providers)


def load_config(config_path: Path | None = None) -> Result[AgentConfig, str]:
    """Load configuration from JSON file.

    Args:
        config_path: Path to config JSON file. Defaults to config/agent_config.json

    Returns:
        Result containing AgentConfig or error message
    """
    path = config_path or _CONFIG_PATH

    match path.exists():
        case False:
            return Err(f"Config file not found: {path}")
        case True:
            pass

    config_data: dict[str, str] = json.loads(path.read_text(encoding="utf-8"))

    match config_data.get("openapi_spec_path"):
        case None:
            return Err("openapi_spec_path is required in config")
        case spec_path_str:
            spec_path = Path(spec_path_str)
            match spec_path.exists():
                case False:
                    return Err(f"OpenAPI spec not found: {spec_path}")
                case True:
                    pass

    match config_data.get("system_prompt_path"):
        case None:
            return Err("system_prompt_path is required in config")
        case prompt_path_str:
            prompt_path = Path(prompt_path_str)
            match prompt_path.exists():
                case False:
                    return Err(f"System prompt file not found: {prompt_path}")
                case True:
                    system_prompt = prompt_path.read_text(encoding="utf-8").strip()

    raw_groups = config_data.get("meta_tool_groups", {})
    groups: dict[str, list[str]] = raw_groups if isinstance(raw_groups, dict) else {}

    return Ok(
        AgentConfig(
            llm_model=config_data.get("llm_model", DEFAULT_MODEL),
            openapi_spec_path=spec_path,
            system_prompt=system_prompt,
            oauth_providers=_load_oauth_providers(),
            tool_mode=str(config_data.get("tool_mode", "individual")),
            meta_tool_groups=groups,
        )
    )

"""FastAPI server for the agent chat API."""

from __future__ import annotations

import json
import logging
import os
import uuid
from logging.handlers import RotatingFileHandler
from pathlib import Path
from typing import Any

import structlog
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
from pydantic import BaseModel
from result import Err, Ok
from slowapi import Limiter
from slowapi.middleware import SlowAPIMiddleware
from slowapi.util import get_remote_address

from constants import load_config
from core import AgentResult, build_tools, create_agent_executor, run_agent
from session import (
    add_message_to_session,
    cleanup_old_sessions,
    create_session,
    load_session,
    save_session,
    set_auth_token,
)

# Load environment variables from .env file
load_dotenv()


def _setup_logging() -> structlog.stdlib.BoundLogger:
    """Configure structured logging with file and console output."""
    log_file = Path(__file__).parent / "agent.log"

    file_handler = RotatingFileHandler(
        log_file,
        maxBytes=10 * 1024 * 1024,  # 10MB
        backupCount=5,
    )
    file_handler.setLevel(logging.INFO)

    console_handler = logging.StreamHandler()
    console_handler.setLevel(logging.INFO)

    # Configure root logger to capture all module logs
    root_logger = logging.getLogger()
    root_logger.setLevel(logging.INFO)
    root_logger.addHandler(file_handler)
    root_logger.addHandler(console_handler)

    structlog.configure(
        processors=[
            structlog.contextvars.merge_contextvars,
            structlog.processors.add_log_level,
            structlog.processors.TimeStamper(fmt="iso"),
            structlog.processors.JSONRenderer(),
        ],
        wrapper_class=structlog.stdlib.BoundLogger,
        logger_factory=structlog.stdlib.LoggerFactory(),
    )
    return structlog.get_logger()


logger = _setup_logging()

# Rate limiting configuration from environment
RATE_LIMIT = os.getenv("RATE_LIMIT", "10/minute")
limiter = Limiter(key_func=get_remote_address, default_limits=[RATE_LIMIT])


app = FastAPI(title="Agent Chat API", version="0.1.0")
app.state.limiter = limiter
app.add_middleware(SlowAPIMiddleware)

# CORS configuration from environment
CORS_ORIGINS = os.getenv("CORS_ORIGINS", "*").split(",")

app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class ConfigLoadError(RuntimeError):
    """Raised when configuration fails to load."""


# Load configuration from file
match load_config():
    case Ok(config):
        _config = config
        logger.info(
            "config_loaded",
            llm_model=config.llm_model,
            openapi_spec_path=str(config.openapi_spec_path),
        )
    case Err(e):
        raise ConfigLoadError(e)

SPEC_PATH = _config.openapi_spec_path
DEFAULT_MODEL = _config.llm_model
SYSTEM_PROMPT = _config.system_prompt
OAUTH_PROVIDERS = _config.oauth_providers
TOOL_MODE = _config.tool_mode
META_TOOL_GROUPS = _config.meta_tool_groups


class ChatRequest(BaseModel):
    """Chat request payload."""

    session_id: str
    message: str


class ChatResponse(BaseModel):
    """Chat response payload."""

    session_id: str
    response: str
    tool_outputs: list[dict[str, Any]]


class SessionResponse(BaseModel):
    """Session info response."""

    id: str
    message_count: int


class AuthTokenRequest(BaseModel):
    """Auth token submission."""

    session_id: str
    provider: str
    token: str


class ConfigResponse(BaseModel):
    """OAuth configuration response."""

    providers: list[dict[str, str]]


@app.post("/session", response_model=SessionResponse)
def create_new_session() -> SessionResponse:
    """Create a new chat session."""
    request_id = str(uuid.uuid4())
    logger.info("create_session_request", request_id=request_id)

    session = create_session()
    match save_session(session):
        case Ok(_):
            logger.info("create_session_success", request_id=request_id, session_id=session.id)
            return SessionResponse(id=session.id, message_count=0)
        case Err(e):
            logger.error("create_session_failed", request_id=request_id, error=e)
            raise HTTPException(status_code=500, detail=e)


@app.get("/session/{session_id}", response_model=SessionResponse)
def get_session(session_id: str) -> SessionResponse:
    """Get session info."""
    match load_session(session_id):
        case Ok(session):
            return SessionResponse(id=session.id, message_count=len(session.messages))
        case Err(e):
            raise HTTPException(status_code=404, detail=e)


@app.post("/chat", response_model=ChatResponse)
@limiter.limit(RATE_LIMIT)  # type: ignore[misc]
def chat(request: Request, chat_request: ChatRequest) -> ChatResponse:  # noqa: ARG001
    """Send a message and get a response."""
    request_id = str(uuid.uuid4())
    logger.info(
        "chat_request",
        request_id=request_id,
        session_id=chat_request.session_id,
        message=chat_request.message,
    )

    # Load session
    match load_session(chat_request.session_id):
        case Ok(session):
            pass
        case Err(e):
            logger.error(
                "session_load_failed",
                request_id=request_id,
                session_id=chat_request.session_id,
                error=e,
            )
            raise HTTPException(status_code=404, detail=e)

    # Get auth token if available
    auth_token = session.auth_tokens.get("default")

    # Get OAuth URL for the request_auth tool (if Google provider is configured)
    oauth_auth_url: str | None = None
    match OAUTH_PROVIDERS:
        case (google_provider, *_) if google_provider.name == "google":
            oauth_auth_url = google_provider.build_auth_url(state=session.id)
        case _:
            pass

    # Build tools
    spec_path = SPEC_PATH if SPEC_PATH and SPEC_PATH.exists() else None
    groups = META_TOOL_GROUPS if META_TOOL_GROUPS else None
    match build_tools(spec_path, auth_token, oauth_auth_url, TOOL_MODE, groups):
        case Ok(tools):
            logger.info("tools_built", request_id=request_id, tool_count=len(tools))
        case Err(e):
            logger.error("tools_build_failed", request_id=request_id, error=e)
            raise HTTPException(status_code=500, detail=e)

    # Create and run agent with configurable timeout
    timeout_str = os.getenv("LLM_TIMEOUT")
    timeout = float(timeout_str) if timeout_str else None
    executor = create_agent_executor(tools, SYSTEM_PROMPT, DEFAULT_MODEL, timeout=timeout)

    agent_result: AgentResult
    match run_agent(executor, session, chat_request.message):
        case Ok(result):
            agent_result = result
            logger.info(
                "agent_response",
                request_id=request_id,
                response=agent_result.response,
                raw_tool_outputs=agent_result.tool_outputs,
            )
        case Err(e):
            logger.error("agent_failed", request_id=request_id, error=e)
            raise HTTPException(status_code=500, detail=e)

    # Update session with messages
    session = add_message_to_session(session, "human", chat_request.message)
    session = add_message_to_session(session, "assistant", agent_result.response)

    match save_session(session):
        case Ok(_):
            pass
        case Err(e):
            logger.error("session_save_failed", request_id=request_id, error=e)
            raise HTTPException(status_code=500, detail=e)

    # Parse tool outputs from tool messages (JSON strings)
    tool_outputs = _parse_tool_outputs(agent_result.tool_outputs)

    logger.info(
        "chat_complete",
        request_id=request_id,
        parsed_tool_outputs=tool_outputs,
    )

    return ChatResponse(
        session_id=session.id,
        response=agent_result.response,
        tool_outputs=tool_outputs,
    )


_OAUTH_CALLBACK_HTML = """<!DOCTYPE html>
<html>
<head><title>Authentication Complete</title></head>
<body>
<h1>Authentication Complete</h1>
<p id="status">Processing...</p>
<script>
(function() {
    const hash = window.location.hash.substring(1);
    const params = new URLSearchParams(hash);
    const token = params.get('access_token');
    const state = params.get('state');
    const statusEl = document.getElementById('status');

    if (!token || !state) {
        statusEl.textContent = 'Error: Missing token or state parameter';
        return;
    }

    fetch('/auth/token', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({session_id: state, provider: 'google', token: token})
    })
    .then(r => r.json())
    .then(data => {
        statusEl.textContent = 'Success! You can close this window and return to the app.';
    })
    .catch(e => {
        statusEl.textContent = 'Error: ' + e.message;
    });
})();
</script>
</body>
</html>"""


@app.get("/oauth/callback")
def oauth_callback() -> HTMLResponse:
    """OAuth callback page that extracts token from URL fragment."""
    return HTMLResponse(content=_OAUTH_CALLBACK_HTML)


@app.post("/auth/token")
def submit_auth_token(request: AuthTokenRequest) -> dict[str, str]:
    """Submit an OAuth token for a session."""
    match load_session(request.session_id):
        case Ok(session):
            pass
        case Err(e):
            raise HTTPException(status_code=404, detail=e)

    session = set_auth_token(session, request.provider, request.token)

    match save_session(session):
        case Ok(_):
            return {"status": "ok"}
        case Err(e):
            raise HTTPException(status_code=500, detail=e)


@app.get("/health")
def health_check() -> dict[str, Any]:
    """Health check endpoint."""
    health_status: dict[str, Any] = {"status": "ok", "checks": {}}

    # Check if spec file exists
    match SPEC_PATH:
        case None:
            health_status["checks"]["openapi_spec"] = "not_configured"
        case path if path.exists():
            health_status["checks"]["openapi_spec"] = "ok"
        case _:
            health_status["checks"]["openapi_spec"] = "missing"
            health_status["status"] = "degraded"

    # Check LLM model is configured
    match DEFAULT_MODEL:
        case "":
            health_status["checks"]["llm_model"] = "not_configured"
            health_status["status"] = "degraded"
        case _:
            health_status["checks"]["llm_model"] = "ok"

    return health_status


@app.get("/config", response_model=ConfigResponse)
def get_config() -> ConfigResponse:
    """Get OAuth configuration."""
    providers = [
        {
            "name": provider.name,
            "client_id": provider.client_id,
            "auth_url": provider.auth_url,
            "scopes": provider.scopes,
            "redirect_uri": provider.redirect_uri,
        }
        for provider in OAUTH_PROVIDERS
    ]
    return ConfigResponse(providers=providers)


@app.post("/admin/cleanup-sessions")
def cleanup_sessions() -> dict[str, Any]:
    """Cleanup old sessions (admin endpoint)."""
    max_age = int(os.getenv("SESSION_MAX_AGE_DAYS", "30"))
    match cleanup_old_sessions(max_age):
        case Ok(count):
            return {"status": "ok", "deleted_count": count}
        case Err(e):
            raise HTTPException(status_code=500, detail=e)


def _parse_tool_outputs(tool_outputs: list[str]) -> list[dict[str, Any]]:
    """Parse tool output JSON strings into dicts."""
    parsed: list[dict[str, Any]] = []
    for output in tool_outputs:
        try:
            obj = json.loads(output)
            match obj:
                case {"type": _}:
                    parsed.append(obj)
                case _:
                    pass
        except json.JSONDecodeError:
            pass
    return parsed


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)  # noqa: S104

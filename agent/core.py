"""LangChain agent setup and conversation handling."""

from __future__ import annotations

import logging
from dataclasses import dataclass
from typing import TYPE_CHECKING, Any

from result import Err, Ok, Result
from tenacity import retry, retry_if_exception_type, stop_after_attempt, wait_exponential

from _langchain_types import (
    AgentExecutorProtocol,
    ChatModelProtocol,
    ToolProtocol,
    create_chat_anthropic,
    create_react_agent_executor,
)
from constants import DEFAULT_MODEL
from display_tools import get_display_tools
from meta_tools import generate_meta_tools
from openapi_tools import load_and_generate_tools, load_openapi_spec

# Minimum size for a JSON blob to be considered a raw API dump (not an inline example)
_MIN_JSON_BLOB_SIZE = 100

if TYPE_CHECKING:
    from pathlib import Path

    from session import Session

logger = logging.getLogger("core")


def create_llm(
    model_name: str,
    temperature: float = 0.0,
    timeout: float | None = None,
) -> ChatModelProtocol:
    """Create the LLM instance."""
    return create_chat_anthropic(
        model_name=model_name,
        temperature=temperature,
        timeout=timeout,
    )


def build_tools(
    spec_path: Path | None = None,
    auth_token: str | None = None,
    oauth_auth_url: str | None = None,
    tool_mode: str = "individual",
    meta_tool_groups: dict[str, list[str]] | None = None,
) -> Result[list[ToolProtocol], str]:
    """Build all tools for the agent."""
    display_tools: list[ToolProtocol] = get_display_tools(oauth_auth_url)

    match (spec_path, tool_mode):
        case (None, _):
            return Ok(display_tools)
        case (_, "meta"):
            return _merge_meta_tools(display_tools, spec_path, auth_token, meta_tool_groups)
        case _:
            return _merge_api_tools(display_tools, spec_path, auth_token)


def _merge_api_tools(
    display_tools: list[ToolProtocol],
    spec_path: Path,
    auth_token: str | None,
) -> Result[list[ToolProtocol], str]:
    """Merge display tools with API tools from spec."""
    match load_and_generate_tools(spec_path, auth_token):
        case Ok(api_tools):
            return Ok([*display_tools, *api_tools])
        case Err(e):
            return Err(e)


def _merge_meta_tools(
    display_tools: list[ToolProtocol],
    spec_path: Path,
    auth_token: str | None,
    groups: dict[str, list[str]] | None,
) -> Result[list[ToolProtocol], str]:
    """Merge display tools with meta tools from spec."""
    match load_openapi_spec(spec_path):
        case Err(e):
            return Err(e)
        case Ok(spec):
            match generate_meta_tools(groups, spec, auth_token):
                case Ok(meta_tools):
                    return Ok([*display_tools, *meta_tools])
                case Err(e):
                    return Err(e)


def create_agent_executor(
    tools: list[ToolProtocol],
    system_prompt: str,
    model_name: str = DEFAULT_MODEL,
    timeout: float | None = None,
) -> AgentExecutorProtocol:
    """Create the agent executor using langgraph."""
    llm = create_llm(model_name, timeout=timeout)
    return create_react_agent_executor(
        llm,
        tools,
        prompt=system_prompt,
    )


@retry(
    retry=retry_if_exception_type((TimeoutError, ConnectionError)),
    stop=stop_after_attempt(3),
    wait=wait_exponential(multiplier=1, min=2, max=10),
)
def _invoke_with_retry(
    executor: AgentExecutorProtocol,
    messages: list[dict[str, str]],
) -> dict[str, Any]:
    """Invoke executor with retry logic for transient failures."""
    return executor.invoke({"messages": messages})


@dataclass(frozen=True)
class AgentResult:
    """Result from running the agent."""

    response: str
    tool_outputs: list[str]


def run_agent(
    executor: AgentExecutorProtocol,
    session: Session,
    user_input: str,
) -> Result[AgentResult, str]:
    """Run the agent with the given input and session history."""
    try:
        messages = _build_messages(session, user_input)
        result: dict[str, Any] = _invoke_with_retry(executor, messages)
        response, tool_outputs = _extract_response_and_tools(result)
        return Ok(AgentResult(response=response, tool_outputs=tool_outputs))
    except Exception as e:  # noqa: BLE001
        return Err(f"Agent error: {e}")


def _build_messages(session: Session, user_input: str) -> list[dict[str, str]]:
    """Build messages list from session history and new input."""
    messages: list[dict[str, str]] = [
        {"role": msg["role"], "content": msg["content"]} for msg in session.messages
    ]
    messages.append({"role": "user", "content": user_input})
    return messages


def _extract_text_from_content(content: str | list[dict[str, Any]]) -> str:
    """Extract text from AIMessage content (handles string or list of blocks)."""
    match content:
        case str():
            return content
        case list():
            return "".join(
                block.get("text", "")
                for block in content
                if isinstance(block, dict) and block.get("type") == "text"
            )
        case _:
            return ""


def _extract_response_and_tools(result: dict[str, Any]) -> tuple[str, list[str]]:
    """Extract response text and tool outputs from agent result.

    Returns:
        Tuple of (AI response text, list of tool output JSON strings)
    """
    output_messages: list[Any] = result.get("messages", [])
    ai_content = ""
    tool_outputs: list[str] = []

    # Log all messages for debugging - show message types
    msg_types = [msg.__class__.__name__ for msg in output_messages]
    logger.info("Message types in result: %s", msg_types)

    for msg in reversed(output_messages):
        msg_type = msg.__class__.__name__
        content_preview = str(getattr(msg, "content", ""))[:200]
        logger.info("Processing %s: %s", msg_type, content_preview)

        match msg_type:
            case "AIMessage" if hasattr(msg, "content") and not ai_content:
                ai_content = _extract_text_from_content(msg.content)
                logger.info("AI response: %s", ai_content[:500] if ai_content else "")
            case "ToolMessage" if hasattr(msg, "content"):
                tool_output = str(msg.content)
                tool_outputs.insert(0, tool_output)
                logger.info("Tool output: %s", tool_output[:500])
            case _:
                logger.info("Skipping message type: %s", msg_type)

    logger.info(
        "Extracted: %d messages, AI content length=%d, tool outputs=%d",
        len(output_messages),
        len(ai_content),
        len(tool_outputs),
    )
    return ai_content, tool_outputs

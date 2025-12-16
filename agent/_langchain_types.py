"""Type-safe wrappers for LangChain libraries lacking proper type inference."""

from __future__ import annotations

from typing import TYPE_CHECKING, Any, Protocol, cast, runtime_checkable

if TYPE_CHECKING:
    from collections.abc import Callable, Sequence

    from pydantic import BaseModel

type ToolInput = str | dict[str, Any]


@runtime_checkable
class ToolProtocol(Protocol):
    """Protocol for LangChain-compatible tools."""

    name: str
    description: str

    def invoke(
        self,
        input_data: ToolInput,
        config: Any = None,  # noqa: ANN401
        **kwargs: Any,  # noqa: ANN401
    ) -> Any:  # noqa: ANN401
        """Invoke the tool with input."""
        ...


@runtime_checkable
class ChatModelProtocol(Protocol):
    """Protocol for LangChain chat models."""

    @property
    def model(self) -> str:
        """Model identifier."""
        ...

    @property
    def temperature(self) -> float:
        """Temperature setting."""
        ...


@runtime_checkable
class AgentExecutorProtocol(Protocol):
    """Protocol for compiled agent graphs."""

    def invoke(
        self,
        input_data: dict[str, Any],
        config: Any = None,  # noqa: ANN401
        **kwargs: Any,  # noqa: ANN401
    ) -> dict[str, Any]:
        """Execute the agent with input."""
        ...


def create_chat_anthropic(
    *,
    model_name: str = "claude-sonnet-4-20250514",
    temperature: float = 0.0,
    timeout: float | None = None,
    **kwargs: Any,  # noqa: ANN401
) -> ChatModelProtocol:
    """Create a ChatAnthropic instance with proper type inference."""
    from langchain_anthropic import ChatAnthropic  # noqa: PLC0415

    instance: object = ChatAnthropic(
        model_name=model_name,
        temperature=temperature,
        timeout=timeout,
        **kwargs,
    )
    return cast("ChatModelProtocol", instance)


def create_structured_tool(
    *,
    func: Callable[..., str],
    name: str,
    description: str,
    args_schema: type[BaseModel],
) -> ToolProtocol:
    """Create a StructuredTool with proper type inference."""
    from langchain_core.tools import StructuredTool  # noqa: PLC0415

    factory = getattr(StructuredTool, "from_function")  # noqa: B009
    tool: object = factory(
        func=func,
        name=name,
        description=description,
        args_schema=args_schema,
    )
    return cast("ToolProtocol", tool)


def create_react_agent_executor(
    model: ChatModelProtocol,
    tools: Sequence[ToolProtocol],
    *,
    prompt: str | None = None,
) -> AgentExecutorProtocol:
    """Create a React agent executor with proper type inference."""
    from langgraph.prebuilt import (  # noqa: PLC0415
        create_react_agent,  # pyright: ignore[reportUnknownVariableType,reportDeprecated]
    )

    graph: object = create_react_agent(  # pyright: ignore[reportUnknownVariableType,reportDeprecated]
        model,  # type: ignore[arg-type]
        list(tools),  # type: ignore[arg-type]
        prompt=prompt,
    )
    return cast("AgentExecutorProtocol", graph)

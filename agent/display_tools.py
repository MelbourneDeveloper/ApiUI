"""Display tools for sending rich content to Flutter client."""

from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import Any, TypeVar

from pydantic import BaseModel

from _langchain_types import ToolProtocol, create_structured_tool

TArgs = TypeVar("TArgs", bound=BaseModel)


class DisplayImage(BaseModel):
    """Image display payload."""

    type: str = "image"
    url: str
    alt: str = ""


class DisplayLink(BaseModel):
    """Link display payload."""

    type: str = "link"
    url: str
    title: str = ""


class DisplayChart(BaseModel):
    """Chart display payload."""

    type: str = "chart"
    chart_type: str
    data: list[dict[str, Any]]
    title: str = ""
    x_label: str = ""
    y_label: str = ""


class DisplayFile(BaseModel):
    """File display payload."""

    type: str = "file"
    name: str
    content: str
    mime_type: str = "application/octet-stream"


class AuthRequired(BaseModel):
    """Auth required signal."""

    type: str = "auth_required"
    provider: str
    auth_url: str


class RequestAuthArgs(BaseModel):
    """Arguments for request_auth tool."""

    provider: str = "google"


class DisplayImageArgs(BaseModel):
    """Arguments for display_image tool."""

    url: str
    alt: str = ""


class DisplayLinkArgs(BaseModel):
    """Arguments for display_link tool."""

    url: str
    title: str = ""


class DisplayChartArgs(BaseModel):
    """Arguments for display_chart tool."""

    chart_type: str
    data: list[dict[str, Any]]
    title: str = ""
    x_label: str = ""
    y_label: str = ""


class DisplayFileArgs(BaseModel):
    """Arguments for display_file tool."""

    name: str
    content: str
    mime_type: str = "text/plain"


@dataclass(frozen=True)
class TypedTool[TArgs: BaseModel](ABC):
    """Type-safe tool definition that can be converted to LangChain BaseTool."""

    name: str
    description: str
    args_schema: type[TArgs]

    @abstractmethod
    def execute(self, args: TArgs) -> str:
        """Execute the tool with typed arguments."""

    def to_langchain_tool(self) -> ToolProtocol:
        """Convert to LangChain BaseTool."""

        def _invoke(**kwargs: TArgs) -> str:  # type: ignore[misc]
            return self.execute(self.args_schema(**kwargs))

        return create_structured_tool(
            func=_invoke,
            name=self.name,
            description=self.description,
            args_schema=self.args_schema,
        )


@dataclass(frozen=True)
class DisplayImageTool(TypedTool[DisplayImageArgs]):
    """Tool to display an image to the user."""

    name: str = "display_image"
    description: str = "Display an image to the user. Use this when you want to show an image."
    args_schema: type[DisplayImageArgs] = DisplayImageArgs

    def execute(self, args: DisplayImageArgs) -> str:
        return DisplayImage(url=args.url, alt=args.alt).model_dump_json()


@dataclass(frozen=True)
class DisplayLinkTool(TypedTool[DisplayLinkArgs]):
    """Tool to display a clickable link to the user."""

    name: str = "display_link"
    description: str = "Display a clickable link to the user."
    args_schema: type[DisplayLinkArgs] = DisplayLinkArgs

    def execute(self, args: DisplayLinkArgs) -> str:
        return DisplayLink(url=args.url, title=args.title or args.url).model_dump_json()


@dataclass(frozen=True)
class DisplayChartTool(TypedTool[DisplayChartArgs]):
    """Tool to display a chart to the user."""

    name: str = "display_chart"
    description: str = "Display a chart to the user. chart_type can be bar, line, pie, or scatter."
    args_schema: type[DisplayChartArgs] = DisplayChartArgs

    def execute(self, args: DisplayChartArgs) -> str:
        return DisplayChart(
            chart_type=args.chart_type,
            data=args.data,
            title=args.title,
            x_label=args.x_label,
            y_label=args.y_label,
        ).model_dump_json()


@dataclass(frozen=True)
class DisplayFileTool(TypedTool[DisplayFileArgs]):
    """Tool to display/download a file to the user."""

    name: str = "display_file"
    description: str = "Display/download a file to the user."
    args_schema: type[DisplayFileArgs] = DisplayFileArgs

    def execute(self, args: DisplayFileArgs) -> str:
        return DisplayFile(
            name=args.name,
            content=args.content,
            mime_type=args.mime_type,
        ).model_dump_json()


def create_request_auth_tool(auth_url: str) -> ToolProtocol:
    """Create a request_auth tool with the given auth URL baked in."""

    def _request_auth(**_kwargs: object) -> str:
        return AuthRequired(provider="google", auth_url=auth_url).model_dump_json()

    return create_structured_tool(
        func=_request_auth,
        name="request_auth",
        description=(
            "Request user authentication with Google. Use this tool when you receive "
            "a 401 Unauthorized or 403 Forbidden error from an API call, or when the "
            "user asks to sign in or authenticate. This will display a sign-in button."
        ),
        args_schema=RequestAuthArgs,
    )


def get_display_tools(oauth_auth_url: str | None = None) -> list[ToolProtocol]:
    """Get all display tools as LangChain BaseTools."""
    tools: list[TypedTool[Any]] = [
        DisplayImageTool(),
        DisplayLinkTool(),
        DisplayChartTool(),
        DisplayFileTool(),
    ]
    result = [tool.to_langchain_tool() for tool in tools]
    match oauth_auth_url:
        case None:
            pass
        case url:
            result.append(create_request_auth_tool(url))
    return result


def request_auth(provider: str, auth_url: str) -> str:
    """Create an auth required response."""
    return AuthRequired(provider=provider, auth_url=auth_url).model_dump_json()


display_image: ToolProtocol = DisplayImageTool().to_langchain_tool()
display_link: ToolProtocol = DisplayLinkTool().to_langchain_tool()
display_chart: ToolProtocol = DisplayChartTool().to_langchain_tool()
display_file: ToolProtocol = DisplayFileTool().to_langchain_tool()

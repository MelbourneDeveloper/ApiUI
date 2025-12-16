"""Tests for display tools."""
# ruff: noqa: PLR2004

from __future__ import annotations

import json

from display_tools import (
    AuthRequired,
    DisplayChart,
    DisplayFile,
    DisplayImage,
    DisplayLink,
    display_chart,
    display_file,
    display_image,
    display_link,
    get_display_tools,
    request_auth,
)


class TestDisplayImage:
    """Tests for DisplayImage model and tool."""

    def test_model_with_url_only(self) -> None:
        """Should create model with just URL."""
        image = DisplayImage(url="https://example.com/img.png")
        assert image.type == "image"
        assert image.url == "https://example.com/img.png"
        assert image.alt == ""

    def test_model_with_alt_text(self) -> None:
        """Should create model with alt text."""
        image = DisplayImage(url="https://example.com/img.png", alt="A cat")
        assert image.alt == "A cat"

    def test_model_serializes_to_json(self) -> None:
        """Should serialize to valid JSON."""
        image = DisplayImage(url="https://example.com/img.png", alt="Test")
        data = json.loads(image.model_dump_json())

        assert data["type"] == "image"
        assert data["url"] == "https://example.com/img.png"
        assert data["alt"] == "Test"


class TestDisplayImageTool:
    """Tests for display_image tool function."""

    def test_returns_json_string(self) -> None:
        """Tool should return JSON string."""
        result = display_image.invoke({"url": "https://example.com/img.png"})
        data = json.loads(result)

        assert data["type"] == "image"
        assert data["url"] == "https://example.com/img.png"

    def test_includes_alt_text(self) -> None:
        """Tool should include alt text."""
        result = display_image.invoke(
            {"url": "https://example.com/img.png", "alt": "My image"},
        )
        data = json.loads(result)

        assert data["alt"] == "My image"


class TestDisplayLink:
    """Tests for DisplayLink model and tool."""

    def test_model_with_url_only(self) -> None:
        """Should create model with just URL."""
        link = DisplayLink(url="https://example.com")
        assert link.type == "link"
        assert link.url == "https://example.com"
        assert link.title == ""

    def test_model_with_title(self) -> None:
        """Should create model with title."""
        link = DisplayLink(url="https://example.com", title="Example Site")
        assert link.title == "Example Site"

    def test_model_serializes_to_json(self) -> None:
        """Should serialize to valid JSON."""
        link = DisplayLink(url="https://example.com", title="Test")
        data = json.loads(link.model_dump_json())

        assert data["type"] == "link"
        assert data["url"] == "https://example.com"
        assert data["title"] == "Test"


class TestDisplayLinkTool:
    """Tests for display_link tool function."""

    def test_returns_json_string(self) -> None:
        """Tool should return JSON string."""
        result = display_link.invoke({"url": "https://example.com"})
        data = json.loads(result)

        assert data["type"] == "link"
        assert data["url"] == "https://example.com"

    def test_uses_url_as_title_when_empty(self) -> None:
        """Tool should use URL as title when title is empty."""
        result = display_link.invoke({"url": "https://example.com", "title": ""})
        data = json.loads(result)

        assert data["title"] == "https://example.com"


class TestDisplayChart:
    """Tests for DisplayChart model and tool."""

    def test_model_with_required_fields(self) -> None:
        """Should create model with required fields."""
        chart = DisplayChart(
            chart_type="bar",
            data=[{"x": 1, "y": 2}],
        )
        assert chart.type == "chart"
        assert chart.chart_type == "bar"
        assert chart.data == [{"x": 1, "y": 2}]

    def test_model_with_all_fields(self) -> None:
        """Should create model with all fields."""
        chart = DisplayChart(
            chart_type="line",
            data=[{"x": 0, "y": 0}, {"x": 1, "y": 1}],
            title="Test Chart",
            x_label="X Axis",
            y_label="Y Axis",
        )
        assert chart.title == "Test Chart"
        assert chart.x_label == "X Axis"
        assert chart.y_label == "Y Axis"

    def test_model_serializes_to_json(self) -> None:
        """Should serialize to valid JSON."""
        chart = DisplayChart(
            chart_type="pie",
            data=[{"label": "A", "value": 10}],
            title="Pie Chart",
        )
        data = json.loads(chart.model_dump_json())

        assert data["type"] == "chart"
        assert data["chart_type"] == "pie"
        assert data["title"] == "Pie Chart"


class TestDisplayChartTool:
    """Tests for display_chart tool function."""

    def test_returns_json_string(self) -> None:
        """Tool should return JSON string."""
        result = display_chart.invoke(
            {
                "chart_type": "bar",
                "data": [{"x": 1, "y": 2}],
            },
        )
        data = json.loads(result)

        assert data["type"] == "chart"
        assert data["chart_type"] == "bar"

    def test_includes_labels(self) -> None:
        """Tool should include axis labels."""
        result = display_chart.invoke(
            {
                "chart_type": "line",
                "data": [],
                "title": "Test",
                "x_label": "X",
                "y_label": "Y",
            },
        )
        data = json.loads(result)

        assert data["x_label"] == "X"
        assert data["y_label"] == "Y"


class TestDisplayFile:
    """Tests for DisplayFile model and tool."""

    def test_model_with_required_fields(self) -> None:
        """Should create model with required fields."""
        file = DisplayFile(name="test.txt", content="Hello")
        assert file.type == "file"
        assert file.name == "test.txt"
        assert file.content == "Hello"
        assert file.mime_type == "application/octet-stream"

    def test_model_with_custom_mime_type(self) -> None:
        """Should create model with custom mime type."""
        file = DisplayFile(
            name="data.json",
            content='{"key": "value"}',
            mime_type="application/json",
        )
        assert file.mime_type == "application/json"

    def test_model_serializes_to_json(self) -> None:
        """Should serialize to valid JSON."""
        file = DisplayFile(name="test.txt", content="test", mime_type="text/plain")
        data = json.loads(file.model_dump_json())

        assert data["type"] == "file"
        assert data["name"] == "test.txt"
        assert data["content"] == "test"
        assert data["mime_type"] == "text/plain"


class TestDisplayFileTool:
    """Tests for display_file tool function."""

    def test_returns_json_string(self) -> None:
        """Tool should return JSON string."""
        result = display_file.invoke({"name": "test.txt", "content": "Hello"})
        data = json.loads(result)

        assert data["type"] == "file"
        assert data["name"] == "test.txt"
        assert data["content"] == "Hello"

    def test_default_mime_type_is_text(self) -> None:
        """Tool should default to text/plain mime type."""
        result = display_file.invoke({"name": "test.txt", "content": "Hello"})
        data = json.loads(result)

        assert data["mime_type"] == "text/plain"


class TestAuthRequired:
    """Tests for AuthRequired model."""

    def test_model_creation(self) -> None:
        """Should create model with required fields."""
        auth = AuthRequired(
            provider="github",
            auth_url="https://github.com/oauth/authorize",
        )
        assert auth.type == "auth_required"
        assert auth.provider == "github"
        assert auth.auth_url == "https://github.com/oauth/authorize"

    def test_model_serializes_to_json(self) -> None:
        """Should serialize to valid JSON."""
        auth = AuthRequired(
            provider="google",
            auth_url="https://accounts.google.com/oauth",
        )
        data = json.loads(auth.model_dump_json())

        assert data["type"] == "auth_required"
        assert data["provider"] == "google"
        assert data["auth_url"] == "https://accounts.google.com/oauth"


class TestRequestAuth:
    """Tests for request_auth function."""

    def test_returns_json_string(self) -> None:
        """Should return JSON string."""
        result = request_auth("github", "https://github.com/oauth")
        data = json.loads(result)

        assert data["type"] == "auth_required"
        assert data["provider"] == "github"
        assert data["auth_url"] == "https://github.com/oauth"


class TestGetDisplayTools:
    """Tests for get_display_tools function."""

    def test_returns_all_display_tools(self) -> None:
        """Should return all four display tools."""
        tools = get_display_tools()
        assert len(tools) == 4

    def test_returns_correct_tools(self) -> None:
        """Should return the correct tool objects."""
        tools = get_display_tools()
        names = {t.name for t in tools}

        assert "display_image" in names
        assert "display_link" in names
        assert "display_chart" in names
        assert "display_file" in names

    def test_tools_are_callable(self) -> None:
        """All tools should be callable."""
        tools = get_display_tools()
        for tool in tools:
            assert callable(tool.invoke)

    def test_includes_request_auth_when_oauth_url_provided(self) -> None:
        """Should include request_auth tool when oauth_auth_url is provided."""
        tools = get_display_tools(oauth_auth_url="https://example.com/oauth")
        names = {t.name for t in tools}

        assert len(tools) == 5
        assert "request_auth" in names

    def test_request_auth_tool_returns_correct_url(self) -> None:
        """request_auth tool should return the configured auth URL."""
        auth_url = "https://accounts.google.com/oauth?client_id=123"
        tools = get_display_tools(oauth_auth_url=auth_url)
        request_auth_tool = next(t for t in tools if t.name == "request_auth")

        result = request_auth_tool.invoke({})
        data = json.loads(result)

        assert data["type"] == "auth_required"
        assert data["provider"] == "google"
        assert data["auth_url"] == auth_url

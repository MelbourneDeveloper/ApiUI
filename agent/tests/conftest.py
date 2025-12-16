"""Pytest configuration and shared fixtures."""

from __future__ import annotations

import logging
import os
import sys
from pathlib import Path

import pytest

# Add parent directory to path so tests can import modules
sys.path.insert(0, str(Path(__file__).parent.parent))

# Configure logging to show in pytest output
logging.basicConfig(
    level=logging.INFO,
    format="%(levelname)s - %(name)s - %(message)s",
)


@pytest.fixture
def skip_if_no_api_key() -> None:
    """Fail hard if ANTHROPIC_API_KEY not set."""
    match os.environ.get("ANTHROPIC_API_KEY"):
        case None | "":
            pytest.fail("ANTHROPIC_API_KEY not set - integration tests require real API key!")
        case _:
            pass


@pytest.fixture
def restcountries_spec_path() -> Path:
    """Provide path to REST Countries OpenAPI spec."""
    return Path(__file__).parent.parent / "specs" / "restcountries.json"

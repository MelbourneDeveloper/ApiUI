Spec: SPEC.md

## Docs

[LangChain](https://reference.langchain.com/python/langchain/langchain/)
[LangChain-Core](https://reference.langchain.com/python/langchain_core/)

## Rules

### General
- **No literals** - use constants! Especially, URLs and model names. DO NOT DUPLICATE
- **No duplication** - search before adding, move instead of copy (HIGHEST PRIORITY)
- **No global state**
- **Default model is claude-haiku-4-5** - the only way to override this is with config
- **No mocks** - avoid unless absolutely necessary
- **No consecutive logs/prints** - use string interpolation
- **No example API specific code** - anything about rest countries = ⛔️ ILLEGAL 
- **No placeholders** - if code is incomplete, throw an exception
- **No skipping tests** - unskip any you find. ANY SKIP = ⛔️ ILLEGAL
- **Tests fail hard** - no allowances or warning prints
- **Functions < 20 lines, files < 500 LOC**
- **No print** - use logging framework
- **No git commands** unless explicitly requested

### Python
- **Strict typing** - pyright strict mode, `Result[T, E]` for fallible functions (no throwing)
- **No classes** - top-level functions only, FP style
- **No if statements** - use `match` pattern matching exclusively
- **Ruff ALL** - all lint rules enabled except D, COM812, ISC001
- **Agent prompts are all configurable** - no hard coding agent prompts

### Dart
- **No if statements** - use pattern matching switch expressions or ternaries (exception: inside arrays/maps for declarative use)
- **No `late` keyword**
- **No throwing** - use `Result` types from nadz package
- **Linting** - austerity package must be installed
- Run `dart fix --apply` before manually fixing lints


This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Conversational AI agent that dynamically exposes any public API (via OpenAPI spec) as tools, with a Flutter chat client. The agent server uses LangChain with multi-model support (Claude, GPT-4, etc.) and auto-generates tools from OpenAPI specs.

## Commands

### Python Agent (in `agent/` directory)
```bash
# Install dependencies (use venv)
cd agent && python -m venv .venv && source .venv/bin/activate && pip install -e ".[dev]"

# Run server
uvicorn server:app --reload

# Lint and type check
sh lint.sh                    # Runs ruff + pyright
ruff check .                  # Linter only
ruff format --check .         # Format check
pyright .                     # Type check (strict mode)

# Tests
pytest                        # All tests
pytest tests/test_session.py  # Single file
pytest -k "test_name"         # Single test
```

### Flutter App (in `flutter_app/` directory)
```bash
# Get dependencies
flutter pub get

# Run app
flutter run

# Lint
dart fix --apply              # Auto-fix lint issues first
dart analyze                  # Then check remaining issues

# Tests
flutter test                  # All tests
flutter test test/foo_test.dart  # Single file
```

## Architecture

```
Flutter App (HTTP) ──► Agent Server ──► Public APIs
                      │
                      ├─ OpenAPI Parser → auto-generates tools
                      ├─ Display Tools → structured JSON for UI
                      └─ Session Manager → persists to ~/.agent_chat/sessions/
```

**Agent Server** (`agent/`): FastAPI server with LangChain agent. Tools are auto-generated from OpenAPI specs in `specs/`. Display tools return typed JSON that Flutter renders (images, links, charts, files).

**Flutter App** (`flutter_app/`): Chat UI that renders markdown, images, charts (nimble_charts), and handles OAuth flows.


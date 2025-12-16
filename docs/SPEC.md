# ApiUI - Specification

Chat with any API. Supply an OpenAPI spec, get a conversational interface with built-in visualization.

## Architecture

```
Flutter App ◄──HTTP──► Agent Server ──► Any API (via OpenAPI)
    │                       │
    │                       ├─ OpenAPI Parser → auto-generates tools
    │                       ├─ Display Tools → rich UI (charts, images, files)
    │                       └─ Sessions → encrypted, disk-persisted
    │
    └─ Renders: markdown, images, charts, links, files, OAuth prompts
```

## Agent Server

**Stack**: FastAPI + LangChain + Claude (configurable)

### API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/session` | Create new session |
| `GET` | `/session/{id}` | Get session info |
| `POST` | `/chat` | Send message, get response |
| `POST` | `/auth/token` | Submit OAuth token |
| `GET` | `/config` | Get OAuth config |
| `GET` | `/health` | Health check |

### Tool Types

**API Tools** - Auto-generated from OpenAPI spec
- Supports GET, POST, PUT, PATCH, DELETE
- Bearer token auth
- Path/query parameter handling

**Display Tools** - Return structured JSON for Flutter UI
```
display_image  → {type: "image", url, alt}
display_link   → {type: "link", url, title}
display_chart  → {type: "chart", chart_type: "bar|line|pie", data, labels}
display_file   → {type: "file", name, content, mime_type}
request_auth   → {type: "auth_required", provider, auth_url}
```

**Meta Tools** - Bundle related endpoints to avoid tool explosion
```json
// 900 endpoints → ~10 grouped tools
{
  "tool_mode": "meta",
  "meta_tool_groups": {
    "github_users": ["get_user", "list_user_repos"],
    "github_repos": ["get_repo", "search_repos"]
  }
}
```

### Sessions

- Stored in `~/.agent_chat/sessions/{id}.json`
- Auth tokens encrypted with Fernet
- Message history preserved
- Auto-cleanup after 30 days

## Flutter App

**Features**:
- Markdown rendering
- Network images
- Interactive charts (bar, line, pie via `nimble_charts`)
- Clickable links
- File downloads
- OAuth sign-in prompts

**OAuth Flow**:
1. Agent returns `{type: "auth_required", auth_url: "..."}`
2. App opens browser for OAuth
3. Token captured → `POST /auth/token`
4. Conversation continues

## Configuration

`agent/config/agent_config.json`:
```json
{
  "llm_model": "claude-haiku-4-5",
  "openapi_spec_path": "specs/github.yaml",
  "tool_mode": "meta",
  "oauth_providers": [{"name": "google", "scopes": ["calendar"]}]
}
```

**Environment Variables**:
- `ANTHROPIC_API_KEY` - Required
- `GOOGLE_CLIENT_ID` / `GOOGLE_REDIRECT_URI` - For OAuth
- `RATE_LIMIT` - API rate limiting (default: 10/minute)
- `CORS_ORIGINS` - Allowed origins

## Included Specs

- GitHub API (`github.yaml`)
- Google Calendar (`google_calendar.yaml`)
- REST Countries (`restcountries.json`)

## Adding a New API

1. Drop OpenAPI spec (JSON/YAML) in `agent/specs/`
2. Update `openapi_spec_path` in config
3. Optionally configure `meta_tool_groups` for large specs
4. Restart server

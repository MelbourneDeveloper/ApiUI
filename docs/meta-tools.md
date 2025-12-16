# Meta Tools

Bundle endpoints into grouped tools so the LLM doesn't choke on 900 individual tools.

## Grouping Sources

### 1. Auto-extract from OpenAPI tags (default)

OpenAPI specs define tags per-operation:
```yaml
# google_calendar.yaml
tags:
  - name: acl
  - name: calendars
  - name: events
paths:
  /calendars/{calendarId}:
    get:
      operationId: calendar.calendars.get
      tags:
        - calendars  # ← auto-groups into "calendars" meta tool
```

Result: 8 tags → 8 meta tools (acl, calendarList, calendars, channels, colors, events, freebusy, settings)

### 2. Explicit config override

For specs without tags, or to customize grouping:

`agent/config/agent_config.json`:
```json
{
  "tool_mode": "meta",
  "meta_tool_groups": {
    "github_users": ["get_user", "list_user_repos"],
    "github_repos": ["get_repo", "search_repos"],
    "github_issues": ["list_repo_issues", "get_issue"],
    "github_prs": ["list_pull_requests", "get_pull_request"]
  }
}
```

Config takes precedence over auto-extraction when provided.

## Mapping

| Config Group | operationIds | Endpoints |
|--------------|--------------|-----------|
| `github_users` | `get_user`, `list_user_repos` | `GET /users/{username}`, `GET /users/{username}/repos` |
| `github_repos` | `get_repo`, `search_repos` | `GET /repos/{owner}/{repo}`, `GET /search/repositories` |
| `github_issues` | `list_repo_issues`, `get_issue` | `GET /repos/{owner}/{repo}/issues`, `GET /repos/{owner}/{repo}/issues/{issue_number}` |
| `github_prs` | `list_pull_requests`, `get_pull_request` | `GET /repos/{owner}/{repo}/pulls`, `GET /repos/{owner}/{repo}/pulls/{pull_number}` |

## Invocation

```python
github_repos(operation="get_repo", params={"owner": "anthropics", "repo": "claude"})
# → GET https://api.github.com/repos/anthropics/claude
```

8 endpoints → 4 tools

## Files to Modify

| File | Changes |
|------|---------|
| `agent/meta_tools.py` | **NEW** - meta tool generation |
| `agent/constants.py` | Add `tool_mode`, `meta_tool_groups` to `AgentConfig` |
| `agent/core.py` | Branch on `tool_mode` to use meta tools |
| `agent/config/agent_config.json` | Add config above |
| `agent/tests/test_meta_tools.py` | **NEW** - tests |

## Implementation

### 1. Update `constants.py`

```python
@dataclass(frozen=True)
class AgentConfig:
    llm_model: str
    openapi_spec_path: Path
    system_prompt: str
    oauth_providers: tuple[OAuthProvider, ...] = field(default_factory=tuple)
    tool_mode: Literal["individual", "meta"] = "individual"
    meta_tool_groups: dict[str, list[str]] = field(default_factory=dict)
```

### 2. Create `meta_tools.py`

```python
@dataclass(frozen=True)
class ParamSpec:
    name: str
    required: bool
    param_in: str  # "path" | "query"

@dataclass(frozen=True)
class OperationSpec:
    operation_id: str
    method: str
    path: str
    summary: str
    params: tuple[ParamSpec, ...]

def extract_groups_from_tags(spec: dict) -> dict[str, list[str]]  # tag -> [operationIds]
def extract_operation(spec: dict, operation_id: str) -> Result[OperationSpec, str]
def validate_params(op: OperationSpec, params: dict) -> Result[dict, str]
def create_meta_tool(tool_name: str, op_ids: list[str], spec: dict, base_url: str, auth: str | None) -> Result[ToolProtocol, str]
def generate_meta_tools(groups: dict[str, list[str]] | None, spec: dict, auth: str | None) -> Result[list[ToolProtocol], str]
    # If groups is None, auto-extract from spec tags
```

### 3. Wire up in `core.py`

```python
match tool_mode:
    case "meta":
        return generate_meta_tools(meta_tool_groups, spec, auth_token)
    case _:
        return load_and_generate_tools(spec_path, auth_token)
```

## Flow

```
github_repos(operation="get_repo", params={"owner": "anthropics", "repo": "claude"})
    ↓
find OperationSpec for "get_repo" → method="get", path="/repos/{owner}/{repo}"
    ↓
validate_params → owner required, repo required → OK
    ↓
GET https://api.github.com/repos/anthropics/claude
```

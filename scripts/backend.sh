#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AGENT_DIR="$SCRIPT_DIR/../agent"
API="${1:-github}"

cd "$AGENT_DIR" || exit 1

# Create venv if needed
if [ ! -d ".venv" ]; then
  echo "Creating venv..."
  python3 -m venv .venv
  .venv/bin/pip install -e ".[dev]"
fi

# Check .env exists
[ -f ".env" ] || { echo "Error: $AGENT_DIR/.env not found"; exit 1; }

# Configure based on API
case "$API" in
  github)
    SPEC="specs/github.yaml"
    PROMPT="config/system_prompt_github.txt"
    ;;
  restcountries)
    SPEC="specs/restcountries.json"
    PROMPT="config/system_prompt_restcountries.txt"
    ;;
  *)
    echo "Usage: $0 [github|restcountries]"
    echo "Default: github"
    exit 1
    ;;
esac

cat > config/agent_config.json << EOF
{
  "llm_model": "claude-haiku-4-5",
  "openapi_spec_path": "$SPEC",
  "system_prompt_path": "$PROMPT",
  "tool_mode": "meta"
}
EOF

echo "Starting backend with $API API..."
exec .venv/bin/python -m uvicorn server:app --reload --host 127.0.0.1 --port 8000

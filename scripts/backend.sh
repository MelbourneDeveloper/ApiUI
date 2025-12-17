#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AGENT_DIR="$SCRIPT_DIR/../agent"
CONFIG="${1:-config/github.json}"

cd "$AGENT_DIR" || exit 1

# Create venv if needed
if [ ! -d ".venv" ]; then
  echo "Creating venv..."
  python3 -m venv .venv
  .venv/bin/pip install -e ".[dev]"
fi

# Check .env exists
[ -f ".env" ] || { echo "Error: $AGENT_DIR/.env not found"; exit 1; }

# Check config file exists
[ -f "$CONFIG" ] || { echo "Error: Config file $CONFIG not found"; exit 1; }

cp "$CONFIG" config/agent_config.json

echo "Starting backend with config $CONFIG..."
exec .venv/bin/python -m uvicorn server:app --reload --host 127.0.0.1 --port 8000

#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
AGENT_DIR="$PROJECT_ROOT/agent"
FLUTTER_DIR="$PROJECT_ROOT/flutter_app"
PID_FILE="/tmp/agent_chat.pid"
LOG_FILE="/tmp/agent_chat_backend.log"

cleanup() {
  echo "Cleaning up..."
  [ -f "$PID_FILE" ] && kill "$(cat "$PID_FILE")" 2>/dev/null && rm "$PID_FILE"
}

detect_ip() {
  local ip=""
  ip=$(ifconfig 2>/dev/null | grep 'inet ' | grep -v '127.0.0.1' | head -1 | awk '{print $2}' | sed 's/addr://')
  [ -z "$ip" ] && ip=$(ip addr show 2>/dev/null | grep 'inet ' | grep -v '127.0.0.1' | head -1 | awk '{print $2}' | cut -d'/' -f1)
  [ -z "$ip" ] && ip=$(ipconfig getifaddr en0 2>/dev/null)
  [ -z "$ip" ] && ip="127.0.0.1"
  echo "$ip"
}

configure_api() {
  local api="${1:-github}"
  cd "$AGENT_DIR" || exit 1
  case "$api" in
    github)
      SPEC="specs/github.yaml"
      PROMPT="config/system_prompt_github.txt"
      ;;
    restcountries)
      SPEC="specs/restcountries.json"
      PROMPT="config/system_prompt_restcountries.txt"
      ;;
    *)
      echo "Unknown API: $api (use github or restcountries)"
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
}

ensure_venv() {
  cd "$AGENT_DIR" || exit 1
  [ -d ".venv" ] && return 0
  echo "Creating venv..."
  python3 -m venv .venv
  .venv/bin/pip install -e ".[dev]"
}

start_backend_bg() {
  local api=$1
  ensure_venv
  configure_api "$api"
  cd "$AGENT_DIR" || exit 1
  [ -f ".env" ] || { echo "Error: $AGENT_DIR/.env not found"; exit 1; }
  echo "Starting backend (background) with $api API..."
  nohup .venv/bin/python -m uvicorn server:app --host 0.0.0.0 --port 8000 > "$LOG_FILE" 2>&1 &
  echo $! > "$PID_FILE"
  echo "Backend PID: $(cat "$PID_FILE")"

  for i in {1..30}; do
    curl -sf http://localhost:8000/health > /dev/null 2>&1 && { echo "Backend ready"; return 0; }
    echo "Waiting... ($i/30)"
    sleep 1
  done
  echo "Backend failed to start"
  cat "$LOG_FILE"
  exit 1
}

run_flutter() {
  local ip=$1
  cd "$FLUTTER_DIR" || exit 1
  flutter pub get
  echo "Running Flutter app (API: http://$ip:8000)"
  flutter run --dart-define=API_BASE_URL="http://$ip:8000"
}

run_tests() {
  local ip=$1
  cd "$FLUTTER_DIR" || exit 1
  flutter pub get
  echo "Running integration tests (API: http://$ip:8000)"
  flutter test integration_test/widget_test.dart --dart-define=API_BASE_URL="http://$ip:8000" -d macos || {
    echo "Tests failed"
    tail -50 "$LOG_FILE"
    exit 1
  }
  echo "Tests passed"
}

usage() {
  echo "Usage: $0 <command> [api]"
  echo ""
  echo "Commands:"
  echo "  app [api]   Run backend + Flutter app (api: github or restcountries, default: github)"
  echo "  test [api]  Run backend + integration tests"
  exit 1
}

[ $# -eq 0 ] && usage

case "$1" in
  app)
    trap cleanup EXIT INT TERM
    start_backend_bg "${2:-github}"
    run_flutter "$(detect_ip)"
    ;;
  test)
    trap cleanup EXIT INT TERM
    start_backend_bg "${2:-github}"
    run_tests "$(detect_ip)"
    ;;
  *)
    usage
    ;;
esac

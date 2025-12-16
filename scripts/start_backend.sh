#!/bin/bash
# Shared backend startup script - source this from other scripts
# Usage: source scripts/start_backend.sh

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
AGENT_DIR="$PROJECT_ROOT/agent"
AGENT_PID_FILE="/tmp/agent_chat_test.pid"
BACKEND_LOG="/tmp/agent_chat_backend.log"

# Cleanup function
backend_cleanup() {
  echo -e "${YELLOW}Cleaning up...${NC}"
  [ -f "$AGENT_PID_FILE" ] && kill "$(cat "$AGENT_PID_FILE")" 2>/dev/null && rm "$AGENT_PID_FILE"
  echo -e "${GREEN}Cleanup complete${NC}"
}

# Function to detect local IP address (platform-agnostic)
detect_ip() {
  local ip=""

  # Try ifconfig first (works on Mac and some Linux)
  ip=$(ifconfig 2>/dev/null | grep 'inet ' | grep -v '127.0.0.1' | head -1 | awk '{print $2}' | sed 's/addr://')

  # Try ip command (Linux)
  [ -z "$ip" ] && ip=$(ip addr show 2>/dev/null | grep 'inet ' | grep -v '127.0.0.1' | head -1 | awk '{print $2}' | cut -d'/' -f1)

  # Try hostname -I (Linux)
  [ -z "$ip" ] && ip=$(hostname -I 2>/dev/null | awk '{print $1}')

  # Mac-specific fallback
  [ -z "$ip" ] && ip=$(ipconfig getifaddr en0 2>/dev/null)

  # Default to localhost if all else fails
  [ -z "$ip" ] && ip="127.0.0.1"

  echo "$ip"
}

# Check if .env exists
check_env() {
  [ -f "$AGENT_DIR/.env" ] || {
    echo -e "${RED}Error: $AGENT_DIR/.env not found${NC}"
    echo "Backend requires ANTHROPIC_API_KEY in .env file"
    exit 1
  }
}

# Start backend server
start_backend() {
  echo -e "${YELLOW}Starting backend server...${NC}"

  cd "$AGENT_DIR" || exit 1

  # REQUIRE Python 3.12 - fail hard otherwise
  PYTHON_BIN=".venv/bin/python3"

  [ ! -f "$PYTHON_BIN" ] && { echo -e "${RED}Error: .venv/bin/python3 not found. Run: python3.12 -m venv .venv && .venv/bin/pip install -e '.[dev]'${NC}"; exit 1; }

  PYTHON_VERSION=$($PYTHON_BIN -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")' 2>/dev/null)
  [ "$PYTHON_VERSION" != "3.12" ] && { echo -e "${RED}Error: Python 3.12 required, got $PYTHON_VERSION. Recreate venv: rm -rf .venv && python3.12 -m venv .venv && .venv/bin/pip install -e '.[dev]'${NC}"; exit 1; }

  echo -e "${YELLOW}Using Python: $PYTHON_BIN${NC}"

  # Start server
  nohup $PYTHON_BIN -m uvicorn server:app --host 0.0.0.0 --port 8000 > "$BACKEND_LOG" 2>&1 &
  echo $! > "$AGENT_PID_FILE"

  echo -e "${GREEN}Backend started with PID $(cat "$AGENT_PID_FILE")${NC}"

  # Wait for backend to be ready
  echo -e "${YELLOW}Waiting for backend to be ready...${NC}"
  sleep 2  # Give server time to bind to port

  for i in {1..30}; do
    if curl -sf http://localhost:8000/health > /dev/null 2>&1; then
      echo -e "${GREEN}Backend is ready!${NC}"
      return 0
    fi
    echo -e "${YELLOW}Attempt $i/30...${NC}"
    sleep 1
  done

  echo -e "${RED}Backend failed to start. Check logs at $BACKEND_LOG${NC}"
  cat "$BACKEND_LOG"
  exit 1
}

# Verify backend is reachable at IP address
verify_backend_at_ip() {
  local ip=$1
  local url="http://$ip:8000/health"

  echo -e "${YELLOW}Verifying backend reachable at $url...${NC}"

  if curl -sf "$url" > /dev/null 2>&1; then
    echo -e "${GREEN}Backend reachable at IP $ip${NC}"
    return 0
  fi

  echo -e "${RED}Error: Backend not reachable at $url${NC}"
  echo -e "${RED}The Flutter app will not be able to connect!${NC}"
  echo -e "${YELLOW}Localhost check:${NC}"
  curl -sf "http://localhost:8000/health" && echo -e "${GREEN}localhost works${NC}" || echo -e "${RED}localhost also fails${NC}"
  echo -e "${YELLOW}Backend logs:${NC}"
  tail -20 "$BACKEND_LOG"
  exit 1
}

#!/bin/bash
set -e

# Get script directory and source shared backend functions
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/start_backend.sh"

# Set trap for cleanup on exit
trap backend_cleanup EXIT INT TERM

# Run Flutter app
run_flutter_app() {
  local ip=$1
  local base_url="http://$ip:8000"

  echo -e "${YELLOW}Running Flutter app...${NC}"
  echo -e "${YELLOW}API Base URL: $base_url${NC}"

  cd "$PROJECT_ROOT/flutter_app" || exit 1

  flutter run --dart-define=API_BASE_URL="$base_url"
}

# Main execution
main() {
  echo -e "${GREEN}=== Flutter App Runner ===${NC}"

  check_env

  local ip
  ip=$(detect_ip)
  echo -e "${YELLOW}Detected IP address: $ip${NC}"

  start_backend

  verify_backend_at_ip "$ip"

  run_flutter_app "$ip"
}

main

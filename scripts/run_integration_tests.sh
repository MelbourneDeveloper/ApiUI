#!/bin/bash
set -e

# Get script directory and source shared backend functions
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/start_backend.sh"

# Set trap for cleanup on exit
trap backend_cleanup EXIT INT TERM

# Run Flutter integration tests
run_tests() {
  local ip=$1
  local base_url="http://$ip:8000"

  echo -e "${YELLOW}Running integration tests...${NC}"
  echo -e "${YELLOW}API Base URL: $base_url${NC}"

  cd "$PROJECT_ROOT/flutter_app" || exit 1

  # Run integration tests with dart-define for base URL
  flutter test integration_test/widget_test.dart \
    --dart-define=API_BASE_URL="$base_url" \
    -d macos || {
    echo -e "${RED}Integration tests failed${NC}"
    echo -e "${YELLOW}Backend logs:${NC}"
    tail -50 "$BACKEND_LOG"
    exit 1
  }

  echo -e "${GREEN}Integration tests passed!${NC}"
}

# Main execution
main() {
  echo -e "${GREEN}=== Flutter Integration Test Runner ===${NC}"

  check_env

  local ip
  ip=$(detect_ip)
  echo -e "${YELLOW}Detected IP address: $ip${NC}"

  start_backend

  verify_backend_at_ip "$ip"

  run_tests "$ip"

  echo -e "${GREEN}=== All tests completed successfully ===${NC}"
}

main

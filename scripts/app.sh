#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FLUTTER_DIR="$SCRIPT_DIR/../flutter_app"

cd "$FLUTTER_DIR" || exit 1

# Get dependencies
flutter pub get

# Run app
exec flutter run

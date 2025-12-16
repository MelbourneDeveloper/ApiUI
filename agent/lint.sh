#!/bin/bash
set -e

cd "$(dirname "$0")"

echo "=== Running Ruff (linter + formatter check) ==="
ruff check .
ruff format --check .

echo ""
echo "=== Running Pyright (strict type checking) ==="
pyright .

echo ""
echo "=== Running Vulture (dead code detection) ==="
.venv/bin/vulture . .vulture_whitelist.py --exclude .venv --min-confidence 80

echo ""
echo "✓ All checks passed"

#!/usr/bin/env bash
#
# Validate Precommit: Ensures code changes meet precommit standards
#
# Runs after Edit/Write operations to validate code quality.
# Only runs on Elixir files.
#
# Exit codes:
#   0 - Validation passed
#   1 - Validation failed (blocks operation)
#   2 - Not applicable (not an Elixir file)

set -euo pipefail

# Get file path from environment or args
FILE_PATH="${CLAUDE_TOOL_FILE_PATH:-${1:-}}"

if [[ -z "$FILE_PATH" ]]; then
  # No file path, skip validation
  exit 2
fi

# Only validate Elixir files
if [[ ! "$FILE_PATH" =~ \.(ex|exs)$ ]]; then
  exit 2
fi

# Check if we're in a mix project
if [[ ! -f "mix.exs" ]]; then
  # Not in a mix project, skip validation
  exit 2
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Validation mode (can be disabled)
VALIDATE_ON_EDIT="${ELIXIR_VALIDATE_ON_EDIT:-1}"

if [[ "$VALIDATE_ON_EDIT" != "1" ]]; then
  # Validation disabled
  exit 0
fi

echo "🔍 Validating Elixir code quality..."

# Check if file compiles
echo "  Checking compilation..."
if ! mix compile --force --warnings-as-errors &>/dev/null; then
  echo -e "${RED}❌ Compilation failed with warnings as errors${NC}" >&2
  echo -e "${YELLOW}Run 'mix compile --warnings-as-errors' to see details${NC}" >&2
  exit 1
fi

# Check if file is formatted
echo "  Checking formatting..."
if ! mix format --check-formatted "$FILE_PATH" &>/dev/null; then
  echo -e "${YELLOW}⚠️  File needs formatting${NC}" >&2
  echo -e "${YELLOW}Run 'mix format' to fix${NC}" >&2
  # Don't block on formatting, just warn
fi

# Check credo if available
if mix help credo &>/dev/null; then
  echo "  Running Credo..."
  if ! mix credo --strict "$FILE_PATH" &>/dev/null; then
    echo -e "${YELLOW}⚠️  Credo found issues${NC}" >&2
    echo -e "${YELLOW}Run 'mix credo --strict $FILE_PATH' to see details${NC}" >&2
    # Don't block on credo, just warn
  fi
fi

echo -e "${GREEN}✅ Validation passed${NC}"
exit 0

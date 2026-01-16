#!/usr/bin/env bash
#
# Validate Dependencies: Checks that required dependencies are installed
#
# Verifies:
#   - credo is in mix.exs deps
#   - styler is in mix.exs deps
#   - styler is configured in .formatter.exs
#
# Exit codes:
#   0 - All required dependencies present
#   1 - Missing required dependencies (warning only)
#   2 - Not in a mix project

set -euo pipefail

# Colors
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

# Check if we're in a mix project
if [[ ! -f "mix.exs" ]]; then
  exit 2
fi

WARNINGS=0

# Check for credo in mix.exs
if ! grep -q ':credo' mix.exs; then
  echo -e "${YELLOW}⚠️  Missing dependency: credo${NC}" >&2
  echo "Add to mix.exs:" >&2
  echo '  {:credo, "~> 1.7", only: [:dev, :test], runtime: false}' >&2
  WARNINGS=$((WARNINGS + 1))
fi

# Check for styler in mix.exs
if ! grep -q ':styler' mix.exs; then
  echo -e "${YELLOW}⚠️  Missing dependency: styler${NC}" >&2
  echo "Add to mix.exs:" >&2
  echo '  {:styler, "~> 1.0", only: [:dev, :test], runtime: false}' >&2
  WARNINGS=$((WARNINGS + 1))
fi

# Check for styler in .formatter.exs
if [[ -f ".formatter.exs" ]]; then
  if ! grep -q 'plugins:.*Styler' .formatter.exs && ! grep -q 'Styler' .formatter.exs; then
    echo -e "${YELLOW}⚠️  Styler not configured in .formatter.exs${NC}" >&2
    echo "Add to .formatter.exs:" >&2
    echo '  plugins: [Styler],' >&2
    WARNINGS=$((WARNINGS + 1))
  fi
else
  echo -e "${YELLOW}⚠️  No .formatter.exs found${NC}" >&2
  echo "Create .formatter.exs with:" >&2
  echo '[' >&2
  echo '  plugins: [Styler],' >&2
  echo '  inputs: ["*.{ex,exs}", "{config,lib,test}/**/*.{ex,exs}"]' >&2
  echo ']' >&2
  WARNINGS=$((WARNINGS + 1))
fi

if [[ $WARNINGS -gt 0 ]]; then
  echo -e "${YELLOW}Found $WARNINGS dependency warnings${NC}" >&2
  echo -e "${YELLOW}These are recommendations for production-quality Elixir development${NC}" >&2
  # Don't block, just warn
  exit 0
else
  echo -e "${GREEN}✅ All required dependencies configured${NC}"
  exit 0
fi

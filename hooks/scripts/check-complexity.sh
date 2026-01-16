#!/usr/bin/env bash
#
# Check Complexity: Analyzes code complexity and warns on high complexity
#
# Exit codes:
#   0 - Complexity acceptable
#   1 - Complexity too high (warning only, doesn't block)
#   2 - Not applicable

set -euo pipefail

FILE_PATH="${1:-}"

if [[ -z "$FILE_PATH" ]] || [[ ! -f "$FILE_PATH" ]]; then
  exit 2
fi

# Only check Elixir files
if [[ ! "$FILE_PATH" =~ \.(ex|exs)$ ]]; then
  exit 2
fi

# Colors
YELLOW='\033[1;33m'
NC='\033[0m'

# Simple complexity heuristics
check_function_length() {
  local file="$1"
  local max_length=50

  # Count lines between 'def' and 'end'
  # This is a simplified check
  local long_functions=$(awk '/def / {start=NR} /^  end$/ && start {if (NR-start > '$max_length') print "Function starting at line " start " is " (NR-start) " lines"}' "$file")

  if [[ -n "$long_functions" ]]; then
    echo -e "${YELLOW}⚠️  Long functions detected (>$max_length lines):${NC}" >&2
    echo "$long_functions" >&2
    echo -e "${YELLOW}Consider breaking into smaller functions${NC}" >&2
  fi
}

check_nesting_depth() {
  local file="$1"
  local max_depth=4

  # Check for deep nesting (simplified)
  local deep_nesting=$(grep -n '^\s\{20,\}' "$file" || true)

  if [[ -n "$deep_nesting" ]]; then
    echo -e "${YELLOW}⚠️  Deep nesting detected (>5 levels):${NC}" >&2
    echo "$deep_nesting" | head -5 >&2
    echo -e "${YELLOW}Consider extracting functions or using 'with' for railway-oriented programming${NC}" >&2
  fi
}

check_parameter_count() {
  local file="$1"
  local max_params=5

  # Check for functions with many parameters
  local many_params=$(grep -n 'def \w\+([^)]\{60,\})' "$file" || true)

  if [[ -n "$many_params" ]]; then
    echo -e "${YELLOW}⚠️  Functions with many parameters detected:${NC}" >&2
    echo "$many_params" | head -5 >&2
    echo -e "${YELLOW}Consider using a map or struct to group parameters${NC}" >&2
  fi
}

# Run checks
check_function_length "$FILE_PATH"
check_nesting_depth "$FILE_PATH"
check_parameter_count "$FILE_PATH"

# These are warnings only, never block
exit 0

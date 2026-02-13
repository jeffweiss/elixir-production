#!/usr/bin/env bash
#
# Quick Validate: Fast per-edit feedback for Elixir files
#
# Runs after Edit/Write operations. Only checks compilation and formatting
# on the changed file. Non-blocking — warnings only.
#
# For full precommit enforcement, see enforce-precommit.sh
#
# Exit codes:
#   0 - Validation passed
#   1 - Compilation failed (warning reported)
#   2 - Not applicable (not an Elixir file or not a mix project)
#
# Environment variables:
#   ELIXIR_VALIDATE_ON_EDIT=0     - Disable per-edit validation
#   ELIXIR_PRODUCTION_SAFE_MODE   - No effect (this script is already read-only)

set -euo pipefail

FILE_PATH="${CLAUDE_TOOL_FILE_PATH:-${1:-}}"

if [[ -z "$FILE_PATH" ]]; then
  exit 2
fi

# Only validate Elixir files
if [[ ! "$FILE_PATH" =~ \.(ex|exs)$ ]]; then
  exit 2
fi

# Check if we're in a mix project
if [[ ! -f "mix.exs" ]]; then
  exit 2
fi

# Respect disable flag
VALIDATE_ON_EDIT="${ELIXIR_VALIDATE_ON_EDIT:-1}"
if [[ "$VALIDATE_ON_EDIT" != "1" ]]; then
  exit 0
fi

# Safe mode: quick-validate is already non-blocking and read-only, so no
# additional restrictions needed. Document for consistency with enforce-precommit.sh.
# ELIXIR_PRODUCTION_SAFE_MODE has no effect here — this script never runs tests.

# Quick compile check (not --force, just incremental)
if ! mix compile --warnings-as-errors 2>/dev/null; then
  echo "⚠️  Compilation warnings/errors detected. Run: mix compile --warnings-as-errors" >&2
fi

# Quick format check on just this file
if ! mix format --check-formatted "$FILE_PATH" 2>/dev/null; then
  echo "⚠️  File needs formatting: $FILE_PATH. Run: mix format" >&2
fi

exit 0

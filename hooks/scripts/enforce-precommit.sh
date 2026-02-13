#!/usr/bin/env bash
#
# Enforce Precommit: BLOCKING gate before git commit/push
#
# Runs the full mix precommit suite. If any check fails, the commit
# is blocked until all issues are fixed.
#
# This script is referenced by hooks.json as a PreToolUse hook on
# Bash:git commit* and Bash:git push*.
#
# Exit codes:
#   0 - All precommit checks passed, commit may proceed
#   1 - Precommit checks failed, commit blocked
#   2 - Not applicable (not a mix project, or SPIKE mode)

set -euo pipefail

# Not in a mix project — don't block
if [[ ! -f "mix.exs" ]]; then
  exit 2
fi

# Check for SPIKE mode override
if [[ "${ELIXIR_SPIKE_MODE:-0}" == "1" ]]; then
  echo "⚠️  SPIKE mode: precommit enforcement skipped. Debt tracked in .claude/spike-debt.md" >&2
  exit 0
fi

echo "🔒 Precommit gate: running full quality checks before commit..."
echo ""

FAILED=0

# 1. Compile with warnings as errors
echo "1/4 Compiling with --warnings-as-errors..."
if mix compile --warnings-as-errors 2>&1; then
  echo "✅ Compilation passed"
else
  echo "❌ Compilation failed — fix warnings/errors before committing" >&2
  FAILED=1
fi
echo ""

# 2. Format check
echo "2/4 Checking formatting..."
if mix format --check-formatted 2>&1; then
  echo "✅ Formatting correct"
else
  echo "❌ Files need formatting — run: mix format" >&2
  FAILED=1
fi
echo ""

# 3. Credo strict
echo "3/4 Running Credo (strict)..."
if mix help credo &>/dev/null; then
  if mix credo --strict 2>&1; then
    echo "✅ Credo passed"
  else
    echo "❌ Credo found issues — fix before committing" >&2
    FAILED=1
  fi
else
  echo "⚠️  Credo not installed — skipping (add {:credo, \"~> 1.7\"} to mix.exs)"
fi
echo ""

# 4. Tests
echo "4/4 Running tests..."
if mix test 2>&1; then
  echo "✅ All tests passed"
else
  echo "❌ Tests failed — fix before committing" >&2
  FAILED=1
fi
echo ""

if [[ "$FAILED" -eq 1 ]]; then
  echo "🚫 COMMIT BLOCKED: precommit checks failed." >&2
  echo "Fix all issues above, then try committing again." >&2
  exit 1
fi

echo "✅ All precommit checks passed — commit may proceed."
exit 0

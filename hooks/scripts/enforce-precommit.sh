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
#
# Environment variables:
#   ELIXIR_SPIKE_MODE=1        - Skip all precommit checks
#   ELIXIR_PRODUCTION_SAFE_MODE=1 - Run compile + format only (no tests, no credo)

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

# Safe mode: restrict to compile + format only (no test execution, no credo side effects)
SAFE_MODE="${ELIXIR_PRODUCTION_SAFE_MODE:-0}"
if [[ "$SAFE_MODE" == "1" ]]; then
  echo "🛡️  Safe mode: running compile + format checks only (tests and credo skipped)"
  echo ""

  FAILED=0

  echo "1/2 Compiling with --warnings-as-errors..."
  if mix compile --warnings-as-errors 2>&1; then
    echo "✅ Compilation passed"
  else
    echo "❌ Compilation failed" >&2
    echo "   Re-run:  mix compile --warnings-as-errors" >&2
    FAILED=1
  fi
  echo ""

  echo "2/2 Checking formatting..."
  if mix format --check-formatted 2>&1; then
    echo "✅ Formatting correct"
  else
    echo "❌ Formatting check failed" >&2
    echo "   Fix:     mix format" >&2
    FAILED=1
  fi
  echo ""

  if [[ "$FAILED" -eq 1 ]]; then
    echo "🚫 COMMIT BLOCKED: safe mode checks failed." >&2
    echo "" >&2
    echo "Fix issues above, then re-run. For full checks: unset ELIXIR_PRODUCTION_SAFE_MODE" >&2
    exit 1
  fi

  echo "✅ Safe mode checks passed — commit may proceed."
  echo "   Note: Tests and credo were skipped. Run full suite before release: mix precommit"
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
  echo "❌ Compilation failed" >&2
  echo "   Re-run:  mix compile --warnings-as-errors" >&2
  echo "   Common:  Unused variables (prefix with _), missing imports, deprecated functions" >&2
  FAILED=1
fi
echo ""

# 2. Format check
echo "2/4 Checking formatting..."
if mix format --check-formatted 2>&1; then
  echo "✅ Formatting correct"
else
  echo "❌ Formatting check failed" >&2
  echo "   Fix:     mix format" >&2
  echo "   Re-run:  mix format --check-formatted" >&2
  FAILED=1
fi
echo ""

# 3. Credo strict
echo "3/4 Running Credo (strict)..."
if mix help credo &>/dev/null; then
  if mix credo --strict 2>&1; then
    echo "✅ Credo passed"
  else
    echo "❌ Credo strict check failed" >&2
    echo "   Re-run:  mix credo --strict" >&2
    echo "   Common:  Long functions (extract), TODO comments, naming conventions, unused params" >&2
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
  echo "❌ Tests failed" >&2
  echo "   Re-run:  mix test" >&2
  echo "   Focused: mix test path/to/failing_test.exs:LINE_NUMBER" >&2
  echo "   Common:  Assertion mismatches, missing setup, changed function signatures" >&2
  FAILED=1
fi
echo ""

if [[ "$FAILED" -eq 1 ]]; then
  echo "🚫 COMMIT BLOCKED: precommit checks failed." >&2
  echo "" >&2
  echo "Fix all issues above, then re-run: mix precommit" >&2
  echo "Or run all checks manually:" >&2
  echo "  mix compile --warnings-as-errors && mix format && mix credo --strict && mix test" >&2
  exit 1
fi

echo "✅ All precommit checks passed — commit may proceed."
exit 0

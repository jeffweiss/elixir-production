#!/usr/bin/env bash
#
# Session Start: Bootstrap elixir-production plugin for every session
#
# Loads non-negotiable rules and checks environment.
# Does NOT load project-learnings.md (agents pull that when needed).

set -euo pipefail

cat <<'EOF'

## Elixir Production Plugin Active

### Non-Negotiable Rules

1. **Precommit before commit**: Run `mix precommit` (or `mix compile --warnings-as-errors && mix format && mix credo --strict && mix test`) before EVERY `git commit`. No exceptions.
2. **TDD**: Write tests before implementation. Red → Green → Refactor.
3. **Tagged tuples**: Use `{:ok, value}` / `{:error, reason}` for all fallible operations.
4. **Typespecs**: `@spec` on every public function.

### Before Any Commit

<EXTREMELY-IMPORTANT>
You MUST run `mix precommit` and verify it passes BEFORE running `git commit`.
If `mix precommit` fails, fix ALL failures before committing.
This is not optional. This is not negotiable. "I'll fix it after" is not acceptable.
</EXTREMELY-IMPORTANT>

### Available Commands

- `/precommit` — Run full quality gate (compile, format, credo, test)
- `/feature <desc>` — Guided feature implementation with TDD
- `/review [file]` — Code review against production standards
- `/spike <goal>` — Rapid prototyping (tracks debt)
- `/learn <pattern>` — Capture project knowledge

### Skills Available

Use `elixir-production:production-quality` for precommit workflow and quality ladder.
Use `elixir-production:elixir-patterns` for idiomatic OTP/Phoenix patterns.
Use `elixir-production:phoenix-liveview` for LiveView streams, forms, hooks.

EOF

# Check if we're in a mix project
if [[ -f "mix.exs" ]]; then
  # Check for precommit alias
  if ! grep -q 'precommit:' mix.exs 2>/dev/null; then
    echo "⚠️  No 'precommit' alias found in mix.exs. Run /precommit to set one up."
  fi

  # Check for required deps
  if ! grep -q ':credo' mix.exs 2>/dev/null; then
    echo "⚠️  Missing :credo dependency. Add {:credo, \"~> 1.7\", only: [:dev, :test], runtime: false}"
  fi
  if ! grep -q ':styler' mix.exs 2>/dev/null; then
    echo "⚠️  Missing :styler dependency. Add {:styler, \"~> 1.0\", only: [:dev, :test], runtime: false}"
  fi
fi

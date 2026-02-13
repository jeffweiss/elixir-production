---
name: enforcing-precommit
description: Use when about to run git commit, git push, or claim implementation is complete in an Elixir project — requires running mix precommit and confirming output before any commit or completion claim
---

# Enforcing Precommit

## Overview

Running `mix precommit` before every commit is not optional. Partial checks are not precommit. "Tests pass" is not precommit. Time pressure is not an exemption.

**Violating the letter of this rule is violating the spirit of this rule.**

## The Iron Law

```
NO COMMIT WITHOUT MIX PRECOMMIT PASSING — ALL FOUR CHECKS
```

All four checks. Every time. No exceptions.

1. `mix compile --warnings-as-errors`
2. `mix format`
3. `mix credo --strict`
4. `mix test`

If the project has a `precommit` alias in `mix.exs`, run `mix precommit`. Otherwise run all four commands in sequence. Both are equivalent.

## The Gate Function

```
BEFORE running git commit or git push:

1. RUN:    mix precommit (or all 4 checks in sequence)
2. READ:   Full output — check exit code of EACH step
3. VERIFY: Did ALL FOUR checks pass with zero failures?
   - If NO:  Fix failures. Re-run. Do not commit.
   - If YES: Proceed with git commit.
4. ONLY THEN: Run git commit

Skip any step = broken commit. Not "probably fine." Broken.
```

## Red Flags — STOP Before Committing

- About to run `git commit` without having run precommit in this session
- "Tests pass" (tests are 1 of 4 checks — not precommit)
- "I already ran format" (format is 1 of 4 checks — not precommit)
- "It's a small change" (small changes break builds)
- "The fix is obvious" (obvious fixes skip tests and introduce regressions)
- "User said be quick" (speed is not an exemption)
- Ran only 1-2 of the 4 checks and calling it done
- ANY plan to commit before all 4 checks pass

**All of these mean: STOP. Run full precommit. Then commit.**

## Rationalization Prevention

| Excuse | Reality |
|--------|---------|
| "Tests pass, that's enough" | Tests are 1 of 4 checks. Credo catches bugs tests miss. Format prevents noisy diffs. Compile catches warnings. |
| "It's just a doc change" | Doc changes can fail format, credo, and even compile (doctests). Run precommit. |
| "User said make it quick" | A broken commit wastes more time than precommit takes. Speed is not an exemption. |
| "I ran format and compile already" | Cherry-picking is not precommit. Run all 4. |
| "The fix is obvious" | Obvious fixes skip regression tests. Obvious fixes ship bugs. Run precommit. |
| "I'll fix it in the next commit" | Broken code in version control is broken code in production. Fix now. |
| "CI will catch it" | Local precommit is faster feedback. Don't push problems to CI. |
| "SPIKE mode" | Even SPIKE has a precommit (compile + format). Only skip if `ELIXIR_SPIKE_MODE=1` is set. |

## Quick Reference

| Situation | Action |
|-----------|--------|
| About to commit ANY change | Run `mix precommit` first |
| About to push | Run `mix precommit` first |
| About to say "implementation complete" | Run `mix precommit` first |
| About to hand off to reviewer | Run `mix precommit` first |
| Precommit fails | Fix ALL failures, re-run, THEN commit |
| No precommit alias in mix.exs | Run all 4 checks manually, then create the alias |

## Common Mistakes

- **Running `mix test` alone and committing** — tests are 1 of 4 gates
- **Skipping credo because "it's just style"** — credo catches real bugs (unused vars, unreachable code, complexity)
- **Committing format fixes separately** — run `mix format` as part of precommit, include in same commit
- **Not re-running after fixes** — if precommit failed and you fixed something, run the FULL suite again

## Related Skills

- **production-quality**: The precommit ladder (L0-L3) and what each check catches
- **elixir-patterns**: Idiomatic patterns that pass credo strict mode

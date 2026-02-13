---
name: production-quality
description: Use when preparing code for production, running mix precommit, mix compile warnings-as-errors, mix credo --strict, mix format, mix test failures, adding typespecs, evaluating security posture, checking migration safety, or reviewing code before committing
---

# Production Quality

## Overview

Production readiness is an escalation ladder — L0 (compiles) through L7 (documented). Most features should reach at least L3 before merge.

## Escalation Ladder

| Level | Gate | Command/Check |
|-------|------|---------------|
| L0 | Compiles cleanly | `mix compile --warnings-as-errors` (includes set-theoretic type checks on 1.18+) |
| L1 | Formatted | `mix format` (with Styler) |
| L2 | Static analysis | `mix credo --strict` |
| L3 | Tested | `mix test` — all ok/error paths, edge cases |
| L4 | Typed | `@spec` on every public function, concrete types (compiler infers many types on 1.18+, specs remain valuable for API documentation) |
| L5 | Secure | OWASP defenses: parameterized queries, escaped output, changeset validation |
| L6 | Observable | Telemetry on all 4 layers (OS/VM, framework, app, user) |
| L7 | Documented | `@moduledoc`, `@doc` with examples, "why" comments |

**Precommit gate** (L0-L3 automated):
```elixir
# mix.exs aliases
precommit: ["compile --warnings-as-errors", "deps.unlock --unused", "format", "credo --strict", "test"]
```

## Common Mistakes

- **Skipping L2 (static analysis)**: Credo catches naming issues, long functions, and anti-patterns that code review misses
- **Treating L6 (observability) as optional**: You can't fix what you can't see — add telemetry before production, not after the first incident
- **Unsafe migrations**: Adding indexes or changing column types without `concurrently: true` or multi-step deployment causes downtime
- **Silent error handling**: 92% of catastrophic failures come from incorrect error handling — test every `{:error, _}` branch
- **Zombie metrics**: Metrics nobody acts on are waste. If it can't drive a decision, delete it

## Reference Files

- `escalation-ladder.md` — Full Production Readiness Ladder (L0-L7 with code examples, gate criteria)
- `testing.md` — Testing strategy, TDD, error handling imperative, documentation standards
- `property-based-testing.md` — StreamData generators, custom generators, property patterns (roundtrip, idempotency, oracle, metamorphic), shrinking, Ecto integration
- `security.md` — SQL injection, XSS, CSRF, input validation, secrets management, timing attacks, magic link auth
- `observability.md` — Telemetry layers, span conventions, tracing-as-analytics, alerting, gray failures, degraded mode, process labels
- `database.md` — Safe Ecto migrations, isolation level warnings, dependency SLAs, performance guidelines
- `ecto-preloading.md` — N+1 detection and prevention, preload strategies (join, subquery, inline), LiveView preloading
- `error-handling.md` — Crash early patterns, strict-then-loosen, complexity analysis
- `deployment.md` — Mix releases, health checks (liveness/readiness), graceful shutdown, Docker, Fly.io/K8s patterns
- `configuration.md` — config.exs vs runtime.exs, compile_env vs get_env, runtime secrets, config providers

## Commands

- **`/precommit`** — Enforces L0-L3 automatically (compile, format, credo, test)
- **`/review [file]`** — Comprehensive review against L4-L7 standards
- **`/spike-migrate`** — Upgrade SPIKE code to production quality

## Related Skills

- **elixir-patterns**: GenServer, Supervisor, OTP patterns
- **cognitive-complexity**: Ousterhout principles, deep modules, reducing complexity
- **performance-analyzer**: Benchmarking, profiling, latency analysis
- **enforcing-precommit**: Iron law enforcement for precommit before commits

---
name: elixir-patterns
description: Use when structuring Elixir code, deciding whether to use GenServer or plain functions, designing supervision trees, handling overload or unbounded message queues, organizing Phoenix contexts, or needing idiomatic OTP patterns
---

# Elixir Patterns

## Overview

Start with pure functions. Escalate to processes only when you need runtime concerns — fault isolation, parallelism, or state across calls. Separate domain logic from temporal logic.

## Pattern Escalation

| Level | What | Reach For |
|-------|------|-----------|
| L0 | Pure functions, pipes, Enum | Data transformation with no side effects |
| L1 | Tagged tuples, `with` | Operations that can fail |
| L2 | Ecto.Changeset | Validating external input at boundaries |
| L3 | GenServer (or ETS) | State that persists across calls |
| L4 | Supervisors | Automatic crash recovery |
| L5 | Registry, Task, DynamicSupervisor | Dynamic process pools, concurrent work |
| L6 | Phoenix Contexts, Protocols | Domain architecture boundaries |

```
What are you solving?
  Transform data, no side effects      → Level 0 (pure functions)
  Operations that can fail              → Level 1 (tagged tuples, with)
  Validating external input             → Level 2 (Ecto.Changeset)
  Need state across calls               → Level 3 (GenServer, consider ETS first)
  Process might crash                   → Level 4 (Supervision)
  Many dynamic processes to coordinate  → Level 5 (Registry, Task, DynamicSupervisor)
  Organizing modules into domains       → Level 6 (Contexts, Protocols, Behaviours)
```

## Common Mistakes

- **Reaching for GenServer too early**: Most business logic is pure functions. A GenServer adds memory, serialization, and complexity. Only justified by runtime benefits.
- **Single Global Process on multiple nodes**: GenServer-as-cache diverges silently across nodes. Default to the database for consistency.
- **Unbounded queues**: Every queue must be bounded. Unbounded queues are a latent memory leak.
- **Circuit breakers as default resilience**: They convert partial failures into complete failures. Prefer token bucket retries.
- **Returning error tuples nobody can act on**: If nothing actionable exists, raise instead.

## Reference Files

- `escalation-ladder.md` — Full Pattern Escalation Ladder (Levels 0-6 with code examples and decision triggers)
- `otp-patterns.md` — GenServer, Supervisor, Registry, Task, Protocol, SGP anti-pattern, init guarantees, BEAM nuances
- `state-machines.md` — :gen_statem vs GenServer decision, state timeouts, postpone, state enter callbacks, why not :gen_event
- `overload-management.md` — Back-pressure, load-shedding, circuit breaker critique, token bucket retries, adaptive concurrency
- `domain-patterns.md` — Phoenix contexts, code quality patterns, pattern matching, tagged tuples, changesets
- `references/contexts.md` — Full context design patterns, boundaries, anti-patterns, testing
- `async-processing.md` — GenServer vs Oban vs Broadway decision framework, Oban worker patterns, Broadway pipeline architecture, testing
- `metaprogramming.md` — When to use macros (last resort), how `use` works, quote/unquote, DSL patterns, hygiene, debugging, common mistakes

## Commands

- **`/feature <desc>`** — Guided feature implementation using these patterns
- **`/review [file]`** — Review code against idiomatic OTP/Phoenix standards
- **`/cognitive-audit`** — Analyze module complexity and suggest refactors

## Related Skills

- **distributed-systems**: Multi-node clustering, consensus, CRDTs
- **production-quality**: Testing, security, observability
- **cognitive-complexity**: Ousterhout principles, deep modules
- **phoenix-liveview**: LiveView-specific patterns

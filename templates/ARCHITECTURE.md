# Architecture

Brief, stable overview of this project's structure. Updated when architecture changes, not when implementation details change.

> "Locating where to make changes takes 10x longer than writing the patch." — matklad

## System Overview

[1-3 sentences: What this system does and who it serves.]

## Codemap

Coarse-grained modules and their responsibilities. Named by module (use symbol search to find them), not linked.

```
lib/my_app/
  accounts/          # User identity, authentication, authorization
    accounts.ex      # Public API — all user-facing operations go through here
  products/          # Product catalog, categories, inventory
    products.ex      # Public API
  orders/            # Order lifecycle, payments, fulfillment
    orders.ex        # Public API
  workers/           # Oban background jobs (email, cleanup, sync)

lib/my_app_web/
  controllers/       # Thin HTTP adapters — no business logic
  live/              # LiveView UI — delegates to contexts
  components/        # Reusable UI components
```

[Replace with your actual project structure. Keep entries to ~15-25 lines. Only list modules that aren't obvious from their names.]

## Architectural Invariants

Rules this codebase enforces. Violations should be caught by tests, credo rules, or code review. **Invariants expressed as absences are the most important** — things deliberately kept separate.

1. **Context boundaries are database boundaries.** No Ecto query in one context joins tables owned by another context. Cross-context data access goes through public API functions.

2. **Controllers and resolvers are thin adapters.** They translate HTTP/GraphQL to context calls and context results to HTTP/GraphQL responses. No business logic, no Repo calls.

3. **Side effects live at boundaries.** Context functions are the outermost boundary for business logic. External calls (HTTP, email, queues) happen in workers or dedicated modules, never in schemas or embedded logic.

4. **Authorization happens in contexts, not controllers.** `current_scope` or `current_user` is passed into context functions. Contexts decide what a user can see/do.

5. **Schemas don't know about other contexts.** A schema may `belongs_to` within its own context, but cross-context associations use IDs, not associations.

[Replace with your actual invariants. 5-8 is a good number. Each should be mechanically checkable.]

## Cross-Cutting Concerns

Patterns that apply across the entire codebase.

- **Error handling**: All fallible operations return `{:ok, value}` or `{:error, reason}`. Use `with` for chaining. Never raise for expected failures.
- **Background work**: All async work goes through Oban. No bare `Task.async` in production code.
- **Configuration**: Loaded at startup via runtime config. Validated at the boundary where it's loaded, not where it's consumed.
- **Testing**: Async by default. Mox for external dependencies. Property-based tests for serialization/parsing.
- **Telemetry**: All context operations emit telemetry events. Metrics/logging attached via handlers, not inline.

## Layer Diagram

```
┌─────────────────────────────────────────┐
│  Web Layer (controllers, live, router)  │  ← Thin adapters, no logic
├─────────────────────────────────────────┤
│  Context Layer (public API modules)     │  ← Business logic, authorization
├─────────────────────────────────────────┤
│  Schema Layer (Ecto schemas, queries)   │  ← Data access, validation
├─────────────────────────────────────────┤
│  Infrastructure (Repo, Oban, PubSub)    │  ← Side effects, external systems
└─────────────────────────────────────────┘

Dependency direction: top → bottom only.
Web never bypasses contexts. Contexts never call web.
Schemas never call contexts.
```

## What This Document Is Not

- **Not a tutorial.** See README for setup and getting started.
- **Not a design doc.** Architecture decisions and their rationale go in `.claude/project-learnings.md`.
- **Not exhaustive.** Only things a newcomer couldn't discover by reading the code.

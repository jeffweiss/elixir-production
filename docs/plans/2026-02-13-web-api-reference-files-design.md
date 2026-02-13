# Web API Reference Files Design

**Date**: 2026-02-13
**Location**: `skills/elixir-patterns/` (flat files alongside existing references)
**Files**: 4 new reference files

## Files

### 1. `web-api-design.md` — API Design Philosophy

Principles that apply regardless of REST or GraphQL:

- **Error contracts** — Consistent error shapes, how errors flow from contexts through controllers/resolvers to the wire, error code catalogs
- **Pagination** — Cursor-based vs offset, Ecto patterns for both, relay-style connections for GraphQL
- **Authentication & authorization** — Plug pipelines for REST, Absinthe middleware for GraphQL, where auth decisions live (context module, not controller/resolver)
- **Versioning** — URL path vs header vs schema evolution, why Elixir apps usually don't need heavy versioning
- **Rate limiting & input validation** — Validate at the boundary, rate limit per-client, size limits on request bodies and query depth
- **API response conventions** — JSON:API-style envelopes vs flat responses

### 2. `web-api-rest-vs-graphql.md` — Decision Framework

Decision tree and comparison table (following async-processing.md pattern):

- **When REST wins** — Simple CRUD, public APIs, caching, file uploads, webhooks, server-to-server
- **When GraphQL wins** — Client-driven data fetching, multiple frontend consumers, deeply nested data, rapid frontend iteration
- **When both** — REST for external/public, GraphQL for internal/frontend
- **Anti-pattern: GraphQL for everything** — Small APIs with one consumer don't benefit

### 3. `web-api-rest.md` — REST with Phoenix

Pitfalls and best practices:

- **Fat controllers** — Logic belongs in contexts, controllers are adapters
- **Router organization** — Scope by version and auth, pipeline plugs, avoid deep nesting
- **Fallback controllers** — `action_fallback` for centralized error rendering
- **Param handling** — Changeset-based validation, embedded schemas for non-DB input
- **Testing** — ConnTest patterns

### 4. `web-api-graphql.md` — GraphQL with Absinthe

The Absinthe pitfalls file:

- **N+1 queries** — Dataloader is required, not optional. Setup, common misconfiguration
- **Resolver bloat** — Resolvers are thin adapters, business logic in contexts
- **Schema organization** — Split by domain, `import_types`, type modules mirror contexts
- **Authorization** — Absinthe middleware, not inline checks
- **Query complexity & depth limiting** — `Absinthe.Middleware.Complexity`, max depth
- **Subscriptions pitfalls** — Memory pressure, pubsub config
- **Input types vs regular types** — `input_object` vs `object`
- **Error handling** — Changeset errors to GraphQL errors
- **Testing** — Direct resolver tests vs endpoint tests

## Cross-References to Agents

### PR Reviewer (`agents/pr-reviewer.md`)

Add a new decision point to the "Decision Points" section:

- **API changes detected**: If the diff touches controllers, routers, Absinthe schemas, or resolvers, reference `elixir-patterns/web-api-*.md` files for API-specific standards (error contracts, N+1 queries, resolver bloat, REST controller patterns).

### Elixir Reviewer (`agents/elixir-reviewer.md`)

Add to the "REQUIRED BACKGROUND" section:

- `elixir-production:elixir-patterns` web-api references — when reviewing controller, router, or Absinthe schema/resolver code

Add API-specific item to the review checklist (step 4):

- API patterns if applicable (85%+): thin controllers/resolvers, Dataloader for GraphQL, error contracts

## Version Bump

Bump version to 2.3.0 in:
- `.claude-plugin/plugin.json`
- `README.md` (Status & Roadmap heading and footer version line)

## SKILL.md Update

Add four entries to the Reference Files section of `skills/elixir-patterns/SKILL.md`.

## README.md Update

Increment reference file count in the architecture tree description for elixir-patterns.

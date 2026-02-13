# Web API Reference Files Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add four web API reference files to the elixir-patterns skill covering API design philosophy, REST vs GraphQL decision framework, REST/Phoenix pitfalls, and Absinthe/GraphQL pitfalls, with cross-references from reviewer agents.

**Architecture:** Four flat markdown files in `skills/elixir-patterns/` following the established reference file conventions (decision trees, comparison tables, code examples, common mistakes). Agent files updated with API-specific detection and review criteria. Version bumped to 2.3.0.

**Tech Stack:** Markdown reference files for Claude Code plugin (elixir-production)

---

### Task 1: Create `web-api-design.md` — API Design Philosophy

**Files:**
- Create: `skills/elixir-patterns/web-api-design.md`

**Step 1: Write the file**

The file covers principles that apply regardless of REST or GraphQL. Follow the established reference file conventions: start with a decision framework or overview, use comparison tables, include code examples with good/bad patterns.

Sections to include:

1. **Overview** — APIs are boundary code. Domain logic lives in contexts; controllers and resolvers are thin adapters that translate between wire format and context calls.

2. **Error Contracts** — Consistent error shapes flowing from contexts to the wire.
   - Context functions return tagged tuples: `{:ok, result}`, `{:error, :not_found}`, `{:error, changeset}`
   - Controllers/resolvers translate these to wire format (HTTP status codes or GraphQL error extensions)
   - Table mapping common context errors to HTTP statuses and GraphQL error types
   - Anti-pattern: leaking internal error details to clients
   - Code example: a fallback controller and an Absinthe error middleware both handling the same context errors

3. **Pagination** — Cursor-based vs offset comparison table
   - When to use each (offset for simple UIs, cursor for infinite scroll/real-time)
   - Ecto patterns for both approaches with code examples
   - Relay-style connections for GraphQL (edges/nodes/pageInfo)
   - Anti-pattern: offset pagination on large tables without index support

4. **Authentication & Authorization** — Where auth decisions live
   - Auth happens at the boundary (Plug pipeline for REST, Absinthe context for GraphQL)
   - Authorization logic lives in context modules, not controllers/resolvers
   - Code example: Plug pipeline that loads current_user, context function that checks permissions
   - Anti-pattern: authorization checks scattered across resolvers

5. **Versioning** — Comparison table of approaches
   - URL path (`/api/v1/`) — simple, explicit, easy to deprecate
   - Accept header — cleaner URLs, harder to test
   - Schema evolution (additive changes only) — preferred for GraphQL
   - Why most Elixir apps don't need heavy versioning (additive changes + deprecation)

6. **Input Validation** — Validate at the boundary
   - Use Ecto embedded schemas for non-DB input validation
   - Rate limiting per-client (ETS counter pattern from overload-management.md)
   - Request body size limits
   - GraphQL query depth and complexity limits
   - Code example: embedded schema for API input validation

**Step 2: Commit**

```bash
git add skills/elixir-patterns/web-api-design.md
git commit -m "Add web API design philosophy reference"
```

---

### Task 2: Create `web-api-rest-vs-graphql.md` — Decision Framework

**Files:**
- Create: `skills/elixir-patterns/web-api-rest-vs-graphql.md`

**Step 1: Write the file**

Follow the async-processing.md pattern with a decision tree and comparison table.

Sections to include:

1. **Decision Framework** — ASCII decision tree
   ```
   Who consumes this API?
     Single frontend you control
       → Simple data model (mostly CRUD)? → REST
       → Complex/nested data, rapid frontend iteration? → GraphQL
     Multiple frontends with different data needs
       → GraphQL (clients fetch exactly what they need)
     External/public consumers
       → REST (universally understood, cacheable, stable)
     Server-to-server integration
       → REST (simpler, no schema overhead)
     Need real-time updates?
       → Phoenix Channels/LiveView (not GraphQL subscriptions unless already using GraphQL)
   ```

2. **Comparison Table** — REST vs GraphQL across dimensions
   - Caching (REST wins: HTTP cache, CDN-friendly)
   - Overfetching/underfetching (GraphQL wins: client specifies fields)
   - File uploads (REST wins: multipart natively; GraphQL needs workarounds)
   - Tooling maturity (REST wins: broad, universal; GraphQL: growing)
   - Schema/documentation (GraphQL wins: self-documenting introspection)
   - Learning curve (REST wins: simpler mental model)
   - N+1 prevention (REST: eager loading in controller; GraphQL: requires Dataloader)
   - Error handling (REST: HTTP status codes; GraphQL: always 200, errors in body)

3. **When Both** — REST for external/public API, GraphQL for internal/frontend. Common pattern in Phoenix: REST controllers alongside Absinthe router.

4. **Anti-patterns**
   - GraphQL for everything: small API with one consumer doesn't benefit from schema/Dataloader/subscription overhead
   - REST for deeply nested data: results in chatty APIs or overfetching with compound endpoints
   - GraphQL subscriptions when Phoenix Channels would be simpler and more efficient

**Step 2: Commit**

```bash
git add skills/elixir-patterns/web-api-rest-vs-graphql.md
git commit -m "Add REST vs GraphQL decision framework reference"
```

---

### Task 3: Create `web-api-rest.md` — REST with Phoenix

**Files:**
- Create: `skills/elixir-patterns/web-api-rest.md`

**Step 1: Write the file**

Sections to include:

1. **Overview** — Phoenix controllers are adapters between HTTP and your context layer. They parse params, call context functions, and render responses. If a controller function is longer than ~10 lines, logic is leaking out of the context.

2. **Fat Controllers** — The #1 REST anti-pattern
   - Bad: business logic, Ecto queries, and conditional branching in the controller
   - Good: controller calls one context function, pattern-matches the result, renders
   - Code example: fat controller refactored to thin controller + context function

3. **Router Organization**
   - Scope by API version and auth requirement
   - Use pipeline plugs for cross-cutting concerns (auth, content type, rate limiting)
   - Avoid deeply nested resources (max 2 levels: `/users/:id/orders`, not `/users/:id/orders/:oid/items/:iid`)
   - Code example: well-organized router with scopes and pipelines

4. **Fallback Controllers** — `action_fallback` for centralized error rendering
   - Map context error tuples to HTTP responses in one place
   - Code example: FallbackController handling `{:error, :not_found}`, `{:error, :unauthorized}`, `{:error, changeset}`

5. **Parameter Handling**
   - Never trust raw params: validate with changesets or embedded schemas
   - Use embedded schemas for input that doesn't map to a DB table
   - Code example: embedded schema for search params with validation

6. **JSON Rendering**
   - Phoenix.View vs Jason.Encoder: prefer explicit view modules for complex resources
   - Consistent response shapes: `%{data: resource}` for success, `%{errors: [...]}` for errors
   - Anti-pattern: rendering entire Ecto schemas (leaks internal fields, breaks on association changes)

7. **Testing**
   - Test through the router (ConnTest), not by calling controller functions directly
   - Test the full request cycle: request → auth → params → context → response
   - Code example: ConnTest for a CRUD endpoint covering success and error cases

8. **Common Mistakes**
   - Putting business logic in controllers
   - Not using `action_fallback` (error handling duplicated across actions)
   - Deeply nested routes that create brittle URLs
   - Rendering raw Ecto schemas to JSON (leaks internal fields)
   - Not validating query params (accepting arbitrary filters/sorts)
   - Missing rate limiting on public endpoints

**Step 2: Commit**

```bash
git add skills/elixir-patterns/web-api-rest.md
git commit -m "Add REST with Phoenix reference"
```

---

### Task 4: Create `web-api-graphql.md` — GraphQL with Absinthe

**Files:**
- Create: `skills/elixir-patterns/web-api-graphql.md`

**Step 1: Write the file**

This is the largest file — the Absinthe pitfalls reference. Sections to include:

1. **Overview** — Absinthe is powerful but has sharp edges. The common failure mode is treating resolvers like controllers and putting business logic in them. Resolvers are adapters — they call context functions and format the results for GraphQL.

2. **N+1 Queries — Dataloader Is Required**
   - The problem: each resolver that loads an association fires a separate query
   - Dataloader batches these automatically — it is not optional for production Absinthe
   - Code example: setting up Dataloader with an Ecto source
   - Code example: resolver using Dataloader vs naive resolver
   - Common misconfiguration: forgetting to add Dataloader to the Absinthe context, not calling `Dataloader.add_source` for each context, wrong cardinality (`:one` vs `:many`)
   - Testing: verify batch queries are emitted (Ecto.Adapters.SQL.Sandbox log inspection)

3. **Resolver Bloat**
   - Resolvers should be 3-5 lines: load context → call function → return result
   - Bad: resolver with conditionals, Ecto queries, business rules
   - Good: resolver that delegates to context function
   - Code example: bloated resolver refactored to thin resolver + context
   - Rule: if you need to `import Ecto.Query` in a resolver, logic has leaked

4. **Schema Organization**
   - Split types by domain: `AccountTypes`, `ProductTypes`, etc.
   - Use `import_types` in the root schema
   - Type modules mirror context boundaries (AccountTypes ↔ Accounts context)
   - Code example: root schema importing domain type modules
   - Anti-pattern: monolithic schema file with all types and resolvers

5. **Authorization**
   - Use Absinthe middleware, not inline permission checks in resolvers
   - Code example: authorization middleware that checks current_user permissions
   - Pattern: load current_user in Absinthe context (via Plug), check permissions in middleware, resolve in resolver
   - Anti-pattern: `if current_user.admin?` in every resolver

6. **Query Complexity & Depth Limiting**
   - Prevent expensive queries from external clients
   - `Absinthe.Middleware.Complexity` — assign cost to fields, reject queries above threshold
   - Max depth limiting — prevent deeply nested queries
   - Code example: complexity configuration on expensive fields
   - Rule of thumb: set max depth to 10 and max complexity to 1000, adjust based on schema shape

7. **Input Types vs Object Types**
   - `input_object` for mutation arguments, `object` for query return types
   - Never reuse the same type for both — they evolve independently
   - Code example: separate input and output types for User
   - Anti-pattern: sharing types between input and output (breaks when you add computed fields)

8. **Error Handling**
   - Resolvers return `{:ok, result}` or `{:error, message_or_changeset}`
   - Changeset errors need translation to GraphQL format
   - Code example: middleware or helper that converts changeset errors to structured GraphQL errors
   - Use error extensions for machine-readable codes: `%{message: "...", extensions: %{code: "NOT_FOUND"}}`
   - Anti-pattern: raising exceptions in resolvers (crashes the query, poor client experience)

9. **Subscriptions Pitfalls**
   - Each subscription holds WebSocket state — thousands of subscriptions = significant memory
   - Use Phoenix.PubSub as the backend, not the default in-memory store (doesn't work in clustered deploys)
   - Scope subscriptions tightly (subscribe to specific resource IDs, not broad topics)
   - Consider Phoenix Channels instead if you're not already using GraphQL heavily
   - Anti-pattern: subscribing to all changes on a type, then filtering client-side

10. **Testing Absinthe**
    - Test through the GraphQL endpoint (ConnTest + query string), not by calling resolvers directly
    - Code example: testing a query with variables
    - Code example: testing a mutation with error cases
    - Test Dataloader batching: enable SQL logging and assert batch queries
    - Test subscriptions: `Absinthe.Subscription.publish/3` in tests

11. **Common Mistakes** — consolidated table
    - No Dataloader (N+1 on every nested field)
    - Business logic in resolvers (should be in contexts)
    - Monolithic schema file (split by domain)
    - Inline authorization (use middleware)
    - No query complexity limits (DoS via deep/wide queries)
    - Reusing types for input and output
    - Raising in resolvers (return error tuples)
    - In-memory subscription store in clustered deploys
    - Not testing through the endpoint

**Step 2: Commit**

```bash
git add skills/elixir-patterns/web-api-graphql.md
git commit -m "Add Absinthe/GraphQL pitfalls reference"
```

---

### Task 5: Update `skills/elixir-patterns/SKILL.md`

**Files:**
- Modify: `skills/elixir-patterns/SKILL.md:45-52` (Reference Files section)

**Step 1: Add four new entries to the Reference Files list**

Add after the existing `metaprogramming.md` entry:

```markdown
- `web-api-design.md` — API design philosophy: error contracts, pagination, auth boundaries, versioning, input validation
- `web-api-rest-vs-graphql.md` — Decision framework: when to choose REST, GraphQL, or both, with comparison table
- `web-api-rest.md` — REST with Phoenix: thin controllers, router organization, fallback controllers, param validation, testing
- `web-api-graphql.md` — GraphQL with Absinthe: Dataloader (required), thin resolvers, schema organization, auth middleware, complexity limits, subscriptions, testing
```

**Step 2: Commit**

```bash
git add skills/elixir-patterns/SKILL.md
git commit -m "Add web API references to elixir-patterns SKILL.md"
```

---

### Task 6: Update `agents/pr-reviewer.md`

**Files:**
- Modify: `agents/pr-reviewer.md:39-42` (Decision Points section)

**Step 1: Add API detection decision point**

Add a new bullet after the existing decision points:

```markdown
- **API changes detected**: If the diff touches controllers, routers (`router.ex`), Absinthe schemas, or resolvers, consult `elixir-patterns/web-api-*.md` references for API-specific standards (error contracts, N+1 queries, resolver bloat, Dataloader usage, REST controller patterns).
```

**Step 2: Commit**

```bash
git add agents/pr-reviewer.md
git commit -m "Add API detection to PR reviewer decision points"
```

---

### Task 7: Update `agents/elixir-reviewer.md`

**Files:**
- Modify: `agents/elixir-reviewer.md:15-18` (REQUIRED BACKGROUND section)
- Modify: `agents/elixir-reviewer.md:26-31` (Review checklist step 4)

**Step 1: Add web API background reference**

Add to the REQUIRED BACKGROUND section after the existing entries:

```markdown
- `elixir-production:elixir-patterns` web-api references — when reviewing controller, router, or Absinthe schema/resolver code
```

**Step 2: Add API pattern to review checklist**

Add to the review checklist items in step 4:

```markdown
   - API patterns if applicable (85%+): thin controllers/resolvers, Dataloader for GraphQL, consistent error contracts, no business logic in boundary code
```

**Step 3: Commit**

```bash
git add agents/elixir-reviewer.md
git commit -m "Add API review criteria to elixir reviewer"
```

---

### Task 8: Update `README.md` and version

**Files:**
- Modify: `.claude-plugin/plugin.json:3` (version)
- Modify: `README.md` (version references, architecture tree, elixir-patterns reference count)

**Step 1: Bump version to 2.3.0**

In `.claude-plugin/plugin.json`, change `"version": "2.2.0"` to `"version": "2.3.0"`.

In `README.md`, update:
- Status heading: `### ✅ Fully Implemented (v2.3.0)`
- Footer version: `**Version**: 2.3.0 - ...`
- Architecture tree: update elixir-patterns reference count from `8 reference files` to `12 reference files (OTP, async processing, macros, state machines, web API design, REST, GraphQL, overload management)`

**Step 2: Commit**

```bash
git add .claude-plugin/plugin.json README.md
git commit -m "Bump version to 2.3.0"
```

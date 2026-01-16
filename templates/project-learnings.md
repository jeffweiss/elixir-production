# Project Knowledge Base

**Auto-updated by Claude Code agents**. This file captures project-specific patterns, conventions, and decisions discovered during development.

## How to Use This File

- **Before starting new features**: Read relevant sections to understand project patterns
- **During development**: Agents automatically update with new patterns
- **Manual updates**: Use `/learn <pattern>` command to document discoveries
- **Team knowledge**: Share insights, gotchas, and successful approaches

---

## Architecture Decisions

Document significant architectural choices with context and rationale.

### [Date] Example: Feature X uses GenServer pool

**Decision**: Use pooled GenServers for feature X instead of single process

**Rationale**:
- Expected 1000+ concurrent requests
- Benchmarks showed single process bottleneck at 500 req/s
- Pool of 10 workers handles 5000+ req/s with minimal memory increase

**Implementation**: See `lib/my_app/feature_x/worker_pool.ex`

**References**: PR #123, bench/feature_x_benchmark.exs

---

## Domain Conventions

Project-specific patterns and naming conventions.

### Example: User Context Conventions

**Pattern**: Always pass `current_scope` as first argument to context functions

```elixir
# Good
Accounts.list_users(current_scope, filters)
Accounts.get_user(current_scope, user_id)

# Avoid
Accounts.list_users(filters, current_scope)
```

**Rationale**: Consistent authorization checking at context boundary

### Example: Timestamp Handling

**Convention**: Store all timestamps in UTC, convert to user timezone in views

**Implementation**:
- Database: `inserted_at`, `updated_at` in UTC
- LiveView: `Calendar.strftime(timestamp, "%B %d, %Y", user.timezone)`
- API: Return ISO8601 strings in UTC

---

## Performance Patterns

Documented performance optimizations and their results.

### Example: Product Queries

**Pattern**: Always preload `[:category, :vendor]` for product queries

```elixir
# Good - Single query with joins
products = Repo.all(from p in Product, preload: [:category, :vendor])

# Avoid - N+1 queries
products = Repo.all(Product)  # Then category/vendor loaded per product
```

**Benchmarks**: Reduced product list query from 1200ms to 45ms (25x improvement)

**Context**: Product list view, 500 products average

### Example: Search Implementation

**Pattern**: Use trigram indexes for fuzzy text search

```sql
CREATE INDEX products_name_trgm_idx ON products
  USING gin (name gin_trgm_ops);
```

**Query**:
```elixir
from p in Product,
  where: fragment("? % ?", p.name, ^search_term),
  order_by: fragment("similarity(?, ?) DESC", p.name, ^search_term)
```

**Performance**: 50ms average for 100k products

---

## Common Gotchas

Mistakes we've made and how to avoid them.

### Example: LiveView Stream IDs

**Problem**: Stream IDs must be unique across all streams on same socket

**Solution**: Use consistent prefix format

```elixir
# Good
stream(socket, :products, products, id_fn: &"product-#{&1.id}")
stream(socket, :categories, categories, id_fn: &"category-#{&1.id}")

# Avoid - ID collision risk
stream(socket, :products, products)  # Uses just integer ID
stream(socket, :categories, categories)  # Uses just integer ID
```

**Reference**: Bug #456, fixed in PR #457

### Example: Form Validation

**Problem**: LiveView form validation wasn't running on first render

**Solution**: Create changeset in mount, always call `to_form/2`

```elixir
def mount(_params, _session, socket) do
  changeset = MySchema.changeset(%MySchema{}, %{})
  {:ok, assign(socket, form: to_form(changeset))}
end
```

**Reference**: PR #234

---

## Testing Patterns

Testing approaches that work well for this project.

### Example: Factory Usage

**Pattern**: Use `build` for in-memory, `insert` for database tests

```elixir
# Unit tests - no DB
test "validates email format" do
  user = build(:user, email: "invalid")
  changeset = User.changeset(user, %{})
  refute changeset.valid?
end

# Integration tests - needs DB
test "creates user with valid data" do
  attrs = params_for(:user)
  assert {:ok, user} = Accounts.create_user(attrs)
  assert user.email == attrs.email
end
```

### Example: Async Test Guidelines

**Rule**: All tests async unless hitting shared resources

```elixir
# Can be async - isolated data
use MyApp.DataCase, async: true

# Must be sync - shared DB sequences
use MyApp.DataCase, async: false  # When using serial DB resources
```

**Exceptions**:
- Tests using database sequences
- Tests with external API calls (use Mox instead)
- Tests with file system changes

---

## Migration Notes

Track significant refactorings and technical debt resolution.

### [Date] Example: Migrated Feature A from SPIKE

**What changed**:
- Added comprehensive typespecs (15 functions)
- Implemented full error handling (5 error cases)
- Created test suite (23 tests, criticality 7-9)
- Added O(n) complexity analysis and benchmarks

**Effort**: ~4 hours (original SPIKE was 30 mins)

**Reference**: PR #789

**Learnings**:
- SPIKE good for UI exploration
- Migration straightforward with clear patterns
- Tests caught 2 edge cases not in SPIKE

### [Date] Example: Refactored B for O(n) from O(n²)

**Problem**: Product search was O(n²) with nested loops

**Solution**: Changed to hash map lookup (O(n) preprocessing + O(n) lookup)

**Results**:
- Before: 2.3s for 1000 products
- After: 12ms for 1000 products
- Before: 45s for 5000 products
- After: 58ms for 5000 products

**Reference**: bench/product_search_benchmark.exs, PR #890

**Tradeoff**: Additional 8MB memory for lookup table (acceptable)

---

## Code Review Insights

Patterns identified during code reviews.

### Example: Recurring Issue - Missing Error Handling

**Pattern**: Several PRs missed error handling for external API calls

**Solution**: Added to review checklist:
- [ ] All external calls wrapped in error handling
- [ ] Timeouts configured for HTTP requests
- [ ] Retry logic for transient failures
- [ ] Circuit breaker for repeated failures

### Example: Style Preference - With vs Case

**Convention**: Prefer `with` for sequential operations, `case` for branching logic

```elixir
# Good - sequential operations
with {:ok, user} <- authenticate(token),
     {:ok, org} <- get_organization(user),
     {:ok, perms} <- check_permissions(user, org) do
  {:ok, perms}
end

# Good - branching logic
case user.role do
  :admin -> handle_admin(user)
  :member -> handle_member(user)
  :guest -> handle_guest(user)
end
```

---

## Distributed Systems Patterns

Patterns for clustering, consensus, and distributed operations.

### Example: Using Distributed Erlang for PubSub

**Pattern**: Phoenix.PubSub with distributed Erlang for multi-node broadcasts

**Configuration**:
```elixir
config :my_app, MyApp.PubSub,
  name: MyApp.PubSub,
  adapter: Phoenix.PubSub.PG2
```

**Scale limit**: Works well up to 50 nodes (full-mesh clustering)

**Future**: Plan to migrate to Partisan if exceeding 30 nodes

### Example: Handling Split-Brain Scenarios

**Problem**: Network partition caused duplicate job processing

**Solution**: Added distributed lock with quorum

```elixir
case :global.set_lock({:job_lock, job_id}, [node() | Node.list()], 5000) do
  true ->
    process_job(job_id)
    :global.del_lock({:job_lock, job_id})
  false ->
    {:error, :locked}
end
```

**Reference**: PR #567

---

## Algorithm Choices

Documented algorithm selections with research backing.

### Example: Using HyperLogLog for Unique Counts

**Problem**: Needed unique visitor counts with minimal memory

**Solution**: Implemented HyperLogLog algorithm via `:hyperloglog` library

**Tradeoff**:
- Exact count: 8 bytes per user × 1M users = 8MB
- HyperLogLog: 12KB fixed memory, ~2% error rate
- Error acceptable for analytics use case

**Reference**: Research paper (Flajolet et al., 2007), PR #678

---

## Cognitive Complexity Notes

Areas identified as high cognitive burden and improvements made.

### Example: Refactored Order Processing for Clarity

**Problem**: `OrderProcessor.process/1` had cyclomatic complexity of 45

**Ousterhout analysis**:
- Shallow module with complex interface (8 parameters)
- Mixed abstraction levels (DB queries next to business logic)
- Information leakage (callers needed to know processing steps)

**Solution**:
- Created deep module with simple interface: `process(order)`
- Pulled complexity downward into private functions
- Separated concerns: validation → processing → notification

**Result**:
- Complexity reduced to 8
- New team member understood in 10 minutes (was 2 hours before)
- Onboarding docs updated

**Reference**: PR #789, `.claude/cognitive-audit-report.md`

---

## Team Knowledge

Insights and tips from team members.

### Example: Debugging LiveView Issues

**Tip**: Add `|> IO.inspect(label: "DEBUG")` in LiveView pipelines

**Better**: Use Chrome DevTools to inspect LiveView events:
1. Open Network tab
2. Filter for "live_patch" or "live_reload"
3. Inspect WebSocket frames

### Example: Testing LiveView Forms

**Pattern**: Test form validation before submission

```elixir
test "validates required fields", %{conn: conn} do
  {:ok, lv, _html} = live(conn, ~p"/users/new")

  # Trigger validation
  lv |> element("form") |> render_change(%{user: %{email: ""}})

  # Check error message appears
  assert lv |> has_element?("span.error", "can't be blank")
end
```

---

## Future Considerations

Features or improvements we're planning.

### Example: Consider Partisan for Large Cluster

**Context**: Currently using Distributed Erlang with 15 nodes

**Threshold**: If we exceed 30 nodes, evaluate Partisan

**Rationale**:
- Distributed Erlang uses full-mesh (O(n²) connections)
- Partisan supports partial mesh and gossip protocols
- Research shows Partisan scales to 1000+ nodes

**References**:
- Partisan GitHub: https://github.com/lasp-lang/partisan
- Research: "Partisan: Scaling the Distributed Actor Runtime" (Meiklejohn et al.)

---

## Notes for Future Readers

- This file grows organically - don't delete old learnings
- Date entries to track evolution
- Link to PRs, benchmarks, and research when relevant
- Use `/learn` command to add new patterns
- Review this file at sprint start for context

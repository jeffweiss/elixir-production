---
name: production-quality
description: Use when looking up typespec syntax, security checklists (SQL injection, XSS, input validation), testing patterns (property-based, integration, TDD), or documentation standards for Elixir modules and functions
---

# Production Quality Skill

**Type:** Reference

This skill provides comprehensive knowledge of production-quality standards, workflows, and best practices for Elixir development. It covers precommit workflows, testing strategies, type specifications, documentation requirements, and security considerations.

## Production Readiness Escalation Ladder

Start at the top. Each level builds on the previous — don't skip ahead.

### Level 0: It Compiles Cleanly

The absolute minimum. Zero warnings, zero errors.

| Check | Command | What It Catches |
|-------|---------|-----------------|
| Compilation | `mix compile --warnings-as-errors` | Syntax errors, undefined functions, unused variables, type mismatches |

```elixir
# ❌ Warning: variable "context" is unused
def process(user, context), do: user.name

# ✅ Prefix unused vars with underscore
def process(user, _context), do: user.name
```

**This level means**: The code runs. Nothing more.

**Move to Level 1 when**: Code compiles. Always.

### Level 1: Consistent Formatting

Automated, zero-debate style. Run once, never think about it again.

| Check | Command | What It Does |
|-------|---------|--------------|
| Format + Styler | `mix format` | Consistent style, sorted aliases/imports, simplified pipes |

**Required** `.formatter.exs`:
```elixir
[
  plugins: [Styler],
  inputs: ["*.{ex,exs}", "{config,lib,test}/**/*.{ex,exs}"],
  line_length: 98
]
```

**This level means**: Any developer can read any file without style friction.

**Move to Level 2 when**: Code is formatted. Always.

### Level 2: Static Analysis Passes

Catch common mistakes, naming issues, and anti-patterns before tests run.

| Check | Command | What It Catches |
|-------|---------|-----------------|
| Credo strict mode | `mix credo --strict` | Naming inconsistencies, long functions, missing moduledocs, duplicated code, design anti-patterns |

| Common Credo Issue | Fix |
|-------------------|-----|
| Function too long (>40 lines) | Extract with `with` or helper functions |
| Module missing `@moduledoc` | Add module documentation or `@moduledoc false` for internal modules |
| Nested `if`/`case` | Flatten with pattern matching or `with` |
| Single-pipe `\|>` | Remove pipe, use direct function call |

**This level means**: Code follows community conventions and avoids common pitfalls.

**Move to Level 3 when**: No Credo warnings. Always.

### Level 3: Tested

Confidence that the code works — and keeps working when changed.

| Test Type | Proportion | Speed | What It Covers |
|-----------|-----------|-------|----------------|
| Unit tests | ~70% | <1ms each | Pure functions, business logic, edge cases |
| Integration tests | ~25% | <100ms each | Database operations, context functions, Mox-ed external services |
| E2E tests | ~5% | Seconds | LiveView flows, full API request/response |
| Property-based | As needed | Varies | Invariants across random input (StreamData) |

| Test Quality Check | Standard |
|-------------------|----------|
| All `{:ok, _}` paths tested | Required |
| All `{:error, _}` paths tested | Required |
| Edge cases (empty, nil, boundary values) | Required |
| Descriptive test names | `"returns error when email already exists"` not `"test email"` |
| Async when no shared state | `use MyApp.DataCase, async: true` |

```elixir
# Cover the full result space
describe "create_user/1" do
  test "creates user with valid attributes" do
    assert {:ok, %User{}} = Accounts.create_user(valid_attrs())
  end

  test "returns error with invalid email" do
    assert {:error, changeset} = Accounts.create_user(%{email: "bad"})
    assert "invalid format" in errors_on(changeset).email
  end

  test "returns error with duplicate email" do
    insert(:user, email: "taken@example.com")
    assert {:error, changeset} = Accounts.create_user(%{email: "taken@example.com"})
    assert "has already been taken" in errors_on(changeset).email
  end
end
```

**This level means**: You can refactor with confidence. Regressions are caught.

**Move to Level 4 when**: Tests cover all happy and error paths.

### Level 4: Typed

Type specifications on all public functions. Catches interface misunderstandings at boundaries.

| Standard | Example |
|----------|---------|
| `@spec` on every public function | `@spec get_user(integer()) :: {:ok, User.t()} \| {:error, :not_found}` |
| Custom `@type` for complex structures | `@type create_attrs :: %{required(:name) => String.t(), ...}` |
| Concrete types, not `any()` or `term()` | `String.t()` not `any()`, `User.t()` not `map()` |
| All error cases included in spec | Don't omit `:error` variants |
| Schema modules define `t()` type | `@type t :: %__MODULE__{name: String.t(), ...}` |

```elixir
@type create_result :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}

@spec create_user(%{required(:name) => String.t(), required(:email) => String.t()}) ::
        create_result()
def create_user(attrs) do
  %User{}
  |> User.changeset(attrs)
  |> Repo.insert()
end
```

**This level means**: Another developer can use your module without reading its implementation.

**Move to Level 5 when**: All public APIs have specs.

### Level 5: Secure

Defend against the OWASP top 10 relevant to Elixir/Phoenix.

| Threat | Defense | Elixir Mechanism |
|--------|---------|-----------------|
| SQL injection | Parameterized queries | Ecto queries with `^variable` — never string interpolation |
| XSS | Auto-escaped output | HEEx `<%= %>` escapes by default; avoid `raw/1` |
| Unvalidated input | Changeset validation at every boundary | `cast/3` → `validate_required/2` → `validate_format/3` |
| Mass assignment | Explicit field allowlists | `cast(struct, params, [:allowed, :fields])` — not `Map.merge` |
| Insecure secrets | Runtime env vars | `System.get_env("SECRET")` in `runtime.exs` — never in source |
| Missing auth checks | Router scopes + context checks | `pipe_through [:require_authenticated_user]` + per-action authorization |
| Timing attacks | Constant-time comparison | `Plug.Crypto.secure_compare/2` for tokens; Argon2/Bcrypt for passwords |

**This level means**: The app is defensible against common web attacks.

**Move to Level 6 when**: Security practices are applied consistently.

### Level 6: Observable

You can't fix what you can't see. Observability is structured insight layered at the right abstraction levels — not "visibility into everything."

| Layer | What to Measure | Elixir Tools |
|-------|----------------|--------------|
| OS/VM | Memory, CPU, scheduler utilization, GC | `:erlang.system_info/1`, `:erlang.statistics/1`, `recon` |
| Framework | Request latency, queue depths, pool utilization | `Telemetry`, `:telemetry.attach/4` |
| Application | Business metrics, context operation counts, error rates | Custom `Telemetry` events, StatsD/Prometheus |
| User | Satisfaction, error pages served, timeout rates | Application-level tracking |

```elixir
# Telemetry that tells a story for the person paged at 3am
:telemetry.execute(
  [:my_app, :orders, :create],
  %{duration: duration, queue_time: sojourn},
  %{status: status, payment_method: method}
)
```

**Log facts, not interpretations**: Logs should record what happened, not what you think it means. Interpretations become wrong as the system evolves; facts remain useful forever.

```elixir
# ❌ Interpretation — misleading when the real cause is something else
Logger.warning("Database seems slow, possible network issue")

# ✅ Facts — lets the reader (or future you) draw correct conclusions
Logger.info("Database query completed",
  query_time_ms: 1547,
  rows_returned: 0,
  connection_pool_wait_ms: 1200
)
```

**Operator Experience (OX)**: Design telemetry for the person who gets paged at 3am. Every metric should answer: What changed? What's the impact? Where's the bottleneck?

**Avoid zombie metrics**: Metrics collected but never looked at, or that can't drive a decision, are waste. MTBF and MTTR are often zombie metrics — they measure averages that obscure actual failure modes. A metric's value is the behavior it drives. If nobody acts on it, delete it.

**Use monotonic time**: `System.monotonic_time/1` for measuring durations, never `DateTime.utc_now()`. Wall clock can jump (NTP adjustments, VM migration).

**A 100% healthy system is suspicious**: If monitoring shows zero errors, zero latency spikes, and zero warnings, the most likely explanation is broken monitoring — not a perfect system.

**This level means**: When something goes wrong in production, you can diagnose it without adding new instrumentation.

**Move to Level 7 when**: Telemetry covers all four layers and drives actionable alerts.

### Level 7: Documented

Code explains itself. Documentation explains why.

| What to Document | Where | Standard |
|-----------------|-------|----------|
| Context purpose and public API | `@moduledoc` on context module | What it manages, key operations, examples |
| Function contract | `@doc` + `@spec` | What it does, return values, examples with `iex>` |
| Why a decision was made | Code comments | Link to ADR, ticket, or design doc |
| Non-obvious business rules | Code comments | Explain the *why*, not the *what* |
| Internal modules | `@moduledoc false` | Explicitly mark as internal |

```elixir
@doc """
Authenticates a user by email and password.

Returns `{:ok, user}` if valid, `{:error, :unauthorized}` otherwise.
Uses constant-time comparison to prevent timing attacks.

## Examples

    iex> authenticate("alice@example.com", "correct_password")
    {:ok, %User{}}

    iex> authenticate("alice@example.com", "wrong_password")
    {:error, :unauthorized}
"""
@spec authenticate(String.t(), String.t()) :: {:ok, User.t()} | {:error, :unauthorized}
```

**This level means**: A new developer can onboard by reading the code. The codebase is self-documenting.

### Escalation Decision Flowchart

```
Where is the code in its lifecycle?
  Just written / SPIKE            → Level 0 (compile clean)
  Ready for precommit             → Level 1 (formatted) + Level 2 (Credo)
  Ready for tests                 → Level 3 (tested)
  Ready for team consumption      → Level 4 (typed)
  Ready for production deploy     → Level 5 (secure)
  Ready for production operations → Level 6 (observable)
  Ready for long-term maintenance → Level 7 (documented)
```

**The precommit gate**: Levels 0-3 are automated and enforced on every commit via a `mix precommit` alias:
```elixir
# mix.exs aliases
precommit: ["compile --warnings-as-errors", "deps.unlock --unused", "format", "credo --strict", "test"]
```

If the project does not have this alias, create it in `mix.exs` before running precommit checks. The alias ensures the quality ladder is enforced consistently both inside and outside Claude Code.

## Precommit Workflow

**Every commit must pass these four checks in order:**

### 1. Compilation with Warnings as Errors

```bash
mix compile --warnings-as-errors
```

**What it checks**:
- All code compiles successfully
- No compiler warnings
- No unused variables
- No ambiguous function calls

**Common failures**:
```elixir
# Unused variable
def process(user, _context) do  # ❌ _context unused
  user.name
end

# Fix: Remove or use
def process(user, _context) do  # ✅ _ prefix indicates intentionally unused
  user.name
end
```

### 2. Code Formatting with Styler

```bash
mix format
```

**What it does**:
- Formats code to consistent style
- Runs Styler plugin for automatic improvements
- Sorts aliases and imports
- Fixes pipe formatting

**Required configuration** (`.formatter.exs`):
```elixir
[
  plugins: [Styler],
  inputs: ["*.{ex,exs}", "{config,lib,test}/**/*.{ex,exs}"],
  line_length: 98
]
```

**Styler improvements**:
- Sorts module directives (alias, import, require)
- Simplifies pipes
- Removes unnecessary parentheses
- Consistent spacing

### 3. Static Analysis with Credo

```bash
mix credo --strict
```

**What it checks**:
- Code consistency
- Common mistakes
- Readability issues
- Best practices

**Priority categories**:
- **Consistency**: naming, module organization
- **Readability**: complexity, function length
- **Refactoring opportunities**: duplicate code
- **Warnings**: potential bugs
- **Design**: anti-patterns

**Common issues**:
```elixir
# Long function
def process_order(order) do  # ❌ 60 lines
  # ... many lines ...
end

# Fix: Extract smaller functions
def process_order(order) do  # ✅
  with {:ok, validated} <- validate_order(order),
       {:ok, processed} <- process_payment(validated),
       {:ok, order} <- create_order_record(processed) do
    {:ok, order}
  end
end
```

### 4. Test Suite

```bash
mix test
```

**What it checks**:
- All tests pass
- No flaky tests
- Test coverage adequate
- No pending tests in production code

**Test organization**:
```elixir
defmodule MyApp.AccountsTest do
  use MyApp.DataCase, async: true

  describe "create_user/1" do
    test "creates user with valid attributes" do
      attrs = %{name: "Alice", email: "alice@example.com"}
      assert {:ok, user} = Accounts.create_user(attrs)
      assert user.name == "Alice"
    end

    test "returns error with invalid email" do
      attrs = %{name: "Alice", email: "invalid"}
      assert {:error, changeset} = Accounts.create_user(attrs)
      assert "invalid format" in errors_on(changeset).email
    end

    test "returns error with missing required fields" do
      assert {:error, changeset} = Accounts.create_user(%{})
      assert changeset.errors[:name]
      assert changeset.errors[:email]
    end
  end
end
```

## Type Specifications

**All public functions must have typespecs.**

### Basic Typespecs

```elixir
@spec get_user(integer()) :: {:ok, User.t()} | {:error, :not_found}
def get_user(id) do
  case Repo.get(User, id) do
    nil -> {:error, :not_found}
    user -> {:ok, user}
  end
end

@spec list_users(keyword()) :: [User.t()]
def list_users(opts \\\\ []) do
  Repo.all(User, opts)
end
```

### Custom Types

```elixir
@type user_id :: pos_integer()
@type email :: String.t()
@type create_attrs :: %{
  required(:name) => String.t(),
  required(:email) => email(),
  optional(:age) => pos_integer()
}
@type create_result :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}

@spec create_user(create_attrs()) :: create_result()
def create_user(attrs) do
  %User{}
  |> User.changeset(attrs)
  |> Repo.insert()
end
```

### Guidelines

**Do**:
- Use concrete types (`String.t()`, not `term()`)
- Document complex return types with `@type`
- Use `User.t()` for schema types
- Include all error cases in spec

**Don't**:
```elixir
# Too generic
@spec process(any()) :: any()

# Missing error cases
@spec get_user(integer()) :: User.t()  # What about not found?

# Inconsistent
@spec create_user(map) :: tuple()  # Be specific
```

## Testing Strategy

### Test-Driven Development (TDD)

**Process**:
1. **Red**: Write failing test
2. **Green**: Implement minimal code to pass
3. **Refactor**: Improve design while keeping tests passing

```elixir
# 1. Red - Write failing test
test "authenticates user with valid credentials" do
  user = insert(:user, email: "alice@example.com", password: "secret123")

  assert {:ok, authenticated_user} = Accounts.authenticate("alice@example.com", "secret123")
  assert authenticated_user.id == user.id
end

# 2. Green - Implement
def authenticate(email, password) do
  case Repo.get_by(User, email: email) do
    nil -> {:error, :unauthorized}
    user -> verify_password(user, password)
  end
end

# 3. Refactor - Improve while tests still pass
def authenticate(email, password) do
  email
  |> get_by_email()
  |> verify_password(password)
end
```

### Test Coverage Goals

**Unit Tests** (70% of tests):
- Test individual functions
- Pure logic, no side effects
- Fast execution (<1ms per test)
- Async when possible

```elixir
test "formats name correctly" do
  assert format_name("alice") == "Alice"
  assert format_name("ALICE") == "Alice"
  assert format_name("") == ""
end
```

**Integration Tests** (25% of tests):
- Test module interactions
- Database operations
- External service mocking with Mox
- Medium execution (<100ms per test)

```elixir
test "creates user and sends welcome email" do
  expect(EmailMock, :send, fn email ->
    assert email.to == "alice@example.com"
    assert email.subject == "Welcome"
    {:ok, %{id: "email-123"}}
  end)

  assert {:ok, user} = Accounts.register_user(%{
    name: "Alice",
    email: "alice@example.com"
  })

  assert user.name == "Alice"
end
```

**End-to-End Tests** (5% of tests):
- Test full workflows
- LiveView interactions
- API endpoints
- Slow execution (can be seconds)

```elixir
test "user can register and login", %{conn: conn} do
  # Visit registration page
  {:ok, lv, _html} = live(conn, ~p"/register")

  # Fill out form
  lv
  |> element("form")
  |> render_submit(%{user: %{email: "alice@example.com", password: "secret123"}})

  # Should redirect to dashboard
  assert_redirect(lv, ~p"/dashboard")
end
```

### Property-Based Testing

Use StreamData for exploring the input space systematically. Property-based tests found 25 bugs in a 60,000-line codebase that unit tests missed — they're particularly effective at finding edge cases humans don't think of.

**Core approach**: Define data generators, state invariants, and let the framework find counterexamples. When a test fails, the framework **shrinks** the input to the minimal reproducing case.

```elixir
use ExUnitProperties

property "name formatting is idempotent" do
  check all name <- string(:alphanumeric) do
    formatted_once = format_name(name)
    formatted_twice = format_name(formatted_once)
    assert formatted_once == formatted_twice
  end
end

property "list sorting never loses elements" do
  check all list <- list_of(integer()) do
    sorted = Enum.sort(list)
    assert Enum.count(list) == Enum.count(sorted)
    assert Enum.all?(list, &(&1 in sorted))
  end
end

# Stateful property test — model-based testing
property "cache behaves like a map" do
  check all ops <- list_of(one_of([
    tuple({constant(:put), string(:alphanumeric), integer()}),
    tuple({constant(:get), string(:alphanumeric)})
  ])) do
    # Run same operations against cache and a map, compare results
    {cache_results, _} = Enum.reduce(ops, {[], Cache.new()}, &run_cache_op/2)
    {map_results, _} = Enum.reduce(ops, {[], %{}}, &run_map_op/2)
    assert cache_results == map_results
  end
end
```

**When to use property-based tests**:
- Serialization/deserialization roundtrips (`decode(encode(x)) == x`)
- Invariants that must hold for all inputs (sorting, filtering, transformation)
- State machine behavior (model against a simpler reference implementation)
- Anything with "for all X, Y should hold" shape

### Testing Best Practices

```elixir
# ✅ Descriptive test names
test "returns error when email already exists"

# ❌ Vague test names
test "test email"

# ✅ Arrange-Act-Assert pattern
test "updates user successfully" do
  # Arrange
  user = insert(:user, name: "Alice")
  attrs = %{name: "Alice Updated"}

  # Act
  {:ok, updated} = Accounts.update_user(user, attrs)

  # Assert
  assert updated.name == "Alice Updated"
end

# ✅ One assertion per test (when possible)
test "validates email format" do
  assert {:error, changeset} = create_user(%{email: "invalid"})
  assert "invalid format" in errors_on(changeset).email
end

test "validates email presence" do
  assert {:error, changeset} = create_user(%{email: ""})
  assert "can't be blank" in errors_on(changeset).email
end
```

## Documentation Standards

### Module Documentation

```elixir
defmodule MyApp.Accounts do
  @moduledoc """
  The Accounts context manages user accounts and authentication.

  This context handles:
  - User registration and management
  - Authentication and session management
  - Password reset workflows
  - Email verification

  ## Examples

      iex> Accounts.register_user(%{email: "alice@example.com", password: "secret"})
      {:ok, %User{}}

      iex> Accounts.authenticate("alice@example.com", "secret")
      {:ok, %User{}}

  """
end
```

### Function Documentation

```elixir
@doc """
Authenticates a user by email and password.

Returns `{:ok, user}` if credentials are valid, or `{:error, :unauthorized}`
if the email doesn't exist or password doesn't match.

## Examples

    iex> authenticate("alice@example.com", "correct_password")
    {:ok, %User{email: "alice@example.com"}}

    iex> authenticate("alice@example.com", "wrong_password")
    {:error, :unauthorized}

    iex> authenticate("nonexistent@example.com", "password")
    {:error, :unauthorized}

"""
@spec authenticate(String.t(), String.t()) ::
  {:ok, User.t()} | {:error, :unauthorized}
def authenticate(email, password) do
  # Implementation
end
```

### Code Comments

**Do comment**:
- Why decisions were made
- Non-obvious business rules
- Performance considerations
- Security concerns

```elixir
# Use constant-time comparison to prevent timing attacks
defp verify_password(password, hashed) do
  Argon2.verify_pass(password, hashed)
end

# Preload associations to avoid N+1 queries
# Typical dashboard loads 50-200 products
def list_products_for_dashboard(user_id) do
  from(p in Product,
    where: p.user_id == ^user_id,
    preload: [:category, :vendor]  # Required for display
  )
  |> Repo.all()
end
```

**Don't comment**:
- What the code does (should be obvious)
- Redundant information

```elixir
# ❌ Obvious
# Get user by ID
def get_user(id), do: Repo.get(User, id)

# ❌ Redundant
# This function creates a user
def create_user(attrs) do
  # Create changeset
  changeset = User.changeset(%User{}, attrs)
  # Insert into database
  Repo.insert(changeset)
end
```

## Security Practices

### Input Validation

```elixir
# ✅ Validate all user input with Ecto.Changeset
def create_user(attrs) do
  %User{}
  |> cast(attrs, [:name, :email, :age])
  |> validate_required([:name, :email])
  |> validate_format(:email, ~r/@/)
  |> validate_number(:age, greater_than: 0)
  |> Repo.insert()
end

# ❌ Don't trust input
def create_user(attrs) do
  Repo.insert(%User{
    name: attrs["name"],  # Unvalidated!
    email: attrs["email"]
  })
end
```

### SQL Injection Prevention

```elixir
# ✅ Use Ecto's parameterized queries
def find_by_email(email) do
  from(u in User, where: u.email == ^email)
  |> Repo.one()
end

# ❌ Don't interpolate into queries
def find_by_email(email) do
  query = "SELECT * FROM users WHERE email = '#{email}'"  # SQL injection!
  Ecto.Adapters.SQL.query!(Repo, query)
end
```

### XSS Prevention

```elixir
# Phoenix.HTML escapes by default
<p><%= @user_input %></p>  # ✅ Escaped automatically

# Explicit escape
<p><%= Phoenix.HTML.html_escape(@user_input) %></p>

# Raw HTML (use with caution)
<p><%= raw(@trusted_html) %></p>  # ❌ Only if you trust the source
```

### Authentication & Authorization

```elixir
# Scope routes by authentication
scope "/", MyAppWeb do
  pipe_through [:browser, :require_authenticated_user]

  live "/dashboard", DashboardLive
  live "/settings", SettingsLive
end

# Check permissions in context
def delete_post(user, post) do
  if user.id == post.author_id or user.admin? do
    Repo.delete(post)
  else
    {:error, :unauthorized}
  end
end
```

### Secrets Management

```elixir
# ✅ Use runtime configuration
config :my_app, MyApp.Mailer,
  adapter: Swoosh.Adapters.Sendgrid,
  api_key: System.get_env("SENDGRID_API_KEY")

# ❌ Don't commit secrets
config :my_app, MyApp.Mailer,
  api_key: "SG.abc123..."  # Never commit!
```

## Performance Guidelines

### Database Optimization

```elixir
# ✅ Preload associations to avoid N+1
products = Repo.all(from p in Product, preload: [:category, :vendor])

# ❌ N+1 query problem
products = Repo.all(Product)  # 1 query
Enum.map(products, & &1.category)  # N more queries

# ✅ Use indexes for frequent queries
create index(:products, [:user_id])
create index(:products, [:category_id, :status])

# ✅ Select only needed fields
from(u in User, select: [:id, :name, :email])
```

### Caching Strategies

```elixir
# ETS for process-local cache
:ets.new(:cache, [:named_table, :public, read_concurrency: true])

# Cachex for more features
{:ok, _} = Cachex.start_link(:my_cache)
Cachex.get(:my_cache, key)
Cachex.put(:my_cache, key, value, ttl: :timer.hours(1))
```

## Complexity Analysis

Before implementing algorithms, analyze complexity with real-world data:

```elixir
@doc """
Matches products with similar users.

Complexity: O(n × m) where n = products, m = users
Real-world: 10,000 products × 1,000 active users = 10M operations
Estimated: ~100ms with in-memory processing

Considered O(n + m) hash-map approach but memory overhead (80MB)
not justified for current scale.
"""
def find_recommendations(user_id) do
  # Implementation
end
```

**When to benchmark**:
- O(n²) or higher complexity
- Core business logic with performance requirements
- Uncertain about approach tradeoffs

Use Benchee for microbenchmarks (see benchmark command).

## Production Operations Principles

### Start Strict, Loosen Later

Postel's Law ("be liberal in what you accept") is dangerous when applied broadly. Starting permissive means you'll eventually depend on every input variation you accepted — and can never tighten. Start strict: reject anything unexpected. Loosen deliberately when real use cases demand it.

```elixir
# ✅ Start strict — reject unknown fields
def changeset(struct, attrs) do
  struct
  |> cast(attrs, @known_fields)  # Unknown fields silently dropped by cast
  |> validate_required(@required_fields)
  |> validate_inclusion(:status, @valid_statuses)
end

# ❌ Don't accept anything and figure it out later
def process(params) do
  # "Be liberal" — now you can never change what params looks like
  Map.merge(@defaults, params)
end
```

### Crash Early, Not Silently

Silent corruption is worse than a crash. A crash is visible, logged, and restarted. Silent corruption propagates through the system, corrupting data and causing failures far from the root cause.

```elixir
# ✅ Crash early — fail where the problem is
def process_payment(%{amount: amount}) when amount > 0, do: # ...
def process_payment(%{amount: amount}) do
  raise ArgumentError, "payment amount must be positive, got: #{inspect(amount)}"
end

# ❌ Silent corruption — bad data propagates
def process_payment(%{amount: amount}) do
  amount = max(amount, 0)  # Silently "fix" invalid data
  # Now debugging why orders have $0 charges is a nightmare
end
```

## Additional References

For deeper dive into quality practices:
- `${CLAUDE_PLUGIN_ROOT}/skills/production-quality/references/typespecs.md`
- `${CLAUDE_PLUGIN_ROOT}/skills/production-quality/references/error-handling.md`
- `${CLAUDE_PLUGIN_ROOT}/skills/production-quality/references/testing.md`

## Success Metrics

Production-quality code achieves:
- ✅ Zero precommit failures
- ✅ 100% typespec coverage for public APIs
- ✅ Comprehensive test coverage (critical paths: 100%)
- ✅ Clear documentation with examples
- ✅ Security best practices applied
- ✅ Performance characteristics understood

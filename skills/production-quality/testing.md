# Testing Strategy

## The Error Handling Imperative

A study of 198 catastrophic failures in distributed systems found that **92% were caused by incorrect error handling** — not algorithmic bugs (Yuan et al., "Simple Testing Can Prevent Most Critical Failures"). Of those, **77% could be reproduced with unit tests**. Three patterns caused nearly all of them:

1. **Ignored errors**: `catch` blocks that swallow exceptions or error tuples matched but not acted on
2. **TODO/FIXME error handlers**: Placeholder handlers that were never implemented (`# TODO: handle this properly`)
3. **Overly broad exception catching**: `rescue _ ->` or `catch :exit, _ ->` that masks real failures

```elixir
# ❌ Pattern 1: Ignored error
case Repo.insert(changeset) do
  {:ok, record} -> record
  {:error, _changeset} -> nil  # Silently returns nil — caller has no idea it failed
end

# ❌ Pattern 2: TODO handler
try do
  ExternalService.call(params)
rescue
  _ -> nil  # TODO: handle this properly
end

# ❌ Pattern 3: Overly broad catch
try do
  risky_operation()
catch
  :exit, _ -> :ok  # Swallows ALL exit reasons — hides real failures
end
```

**Actionable rule**: Write explicit error-handling tests for every `{:error, _}` branch and every `rescue`/`catch` block. If a test doesn't exist for the error path, it's likely broken.

## Test-Driven Development (TDD)

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

## Test Coverage Goals

**Unit Tests** (70% of tests):
- Test individual functions
- Pure logic, no side effects
- Fast execution (<1ms per test)
- Async when possible

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

```elixir
test "user can register and login", %{conn: conn} do
  {:ok, lv, _html} = live(conn, ~p"/register")

  lv
  |> element("form")
  |> render_submit(%{user: %{email: "alice@example.com", password: "secret123"}})

  assert_redirect(lv, ~p"/dashboard")
end
```

## Property-Based Testing

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

## Parameterized Tests (Elixir 1.18+)

Run the same test module multiple times under different parameters — useful for testing against different adapters, configurations, or data sets.

```elixir
defmodule MyApp.CacheTest do
  use ExUnit.Case, async: true,
    parameterize: [
      %{adapter: MyApp.Cache.ETS},
      %{adapter: MyApp.Cache.Redis},
      %{adapter: MyApp.Cache.InMemory}
    ]

  test "get returns nil for missing key", %{adapter: adapter} do
    cache = start_supervised!({adapter, []})
    assert adapter.get(cache, "missing") == nil
  end

  test "put and get roundtrip", %{adapter: adapter} do
    cache = start_supervised!({adapter, []})
    :ok = adapter.put(cache, "key", "value")
    assert adapter.get(cache, "key") == "value"
  end
end
```

**When to use parameterized tests**:
- Testing behaviour implementations across multiple adapters
- Verifying consistent behavior across database backends
- Testing with different configuration options
- Any "same tests, different context" pattern

## Testing Best Practices

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
"""
@spec authenticate(String.t(), String.t()) ::
  {:ok, User.t()} | {:error, :unauthorized}
```

### Code Comments

**Do comment**: Why decisions were made, non-obvious business rules, performance considerations, security concerns.

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
    preload: [:category, :vendor]
  )
  |> Repo.all()
end
```

**Don't comment**: What the code does (should be obvious), redundant information.

## Production Experiments (Scientist Pattern)

Run old code (control) and new code (candidate) side-by-side in production. Always return the control result — safe by default. Capture durations, exceptions, and mismatches for analysis without risking user-facing behavior.

```elixir
# Using alchemy (elixir-toniq)
experiment =
  Alchemy.new("billing-calculation")
  |> Alchemy.control(fn -> OldBilling.calculate(invoice) end)
  |> Alchemy.candidate(fn -> NewBilling.calculate(invoice) end)
  |> Alchemy.run()

# experiment.value contains the control result (always returned to caller)
# experiment.mismatched? flags when control and candidate disagree
# experiment.control.duration / experiment.candidate.duration for timing comparison
```

**Key properties**:
- **Sequential execution**: Control runs first, then candidate — avoids timeout surprises from parallel execution doubling resource usage
- **Safe by default**: Candidate exceptions are captured, never propagated to the caller
- **Observable**: Publish mismatches, durations, and exceptions to your telemetry pipeline for analysis

**When to use**: Safe refactoring of critical paths, algorithm migration, database query optimization — anywhere you need confidence that new code produces identical results before switching over.

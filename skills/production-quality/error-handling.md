# Error Handling

## Crash Early, Not Silently

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

## Start Strict, Loosen Later

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

## Quality Assurance is a Data Mining Problem

At sufficient scale, quality assurance shifts from "run the test suite" to "analyze production telemetry for anomalies" (Hamilton). Unit and integration tests catch known failure modes. Production metrics catch unknown failure modes. Invest in both, but as system scale grows, the ratio shifts toward observability.

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

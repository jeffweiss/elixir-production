# Property-Based Testing with StreamData

## Overview

Property-based tests define **properties that must hold for all inputs**, then let the framework generate random inputs and find counterexamples. When a test fails, StreamData **shrinks** the input to the minimal reproducing case.

Property-based tests found 25 bugs in a 60,000-line codebase that unit tests missed — they're effective at finding edge cases humans don't think of.

## Built-In Generators

| Generator | Produces | Example Values |
|-----------|----------|---------------|
| `integer()` | Any integer | -42, 0, 999 |
| `positive_integer()` | >= 1 | 1, 42, 10000 |
| `float()` | Any float | -3.14, 0.0, 99.9 |
| `binary()` | Binary strings | `<<0, 255, 128>>` |
| `string(:alphanumeric)` | Alphanumeric strings | "aB3", "xY" |
| `string(:ascii)` | ASCII strings | "hello!", "#$%" |
| `string(:printable)` | Printable unicode | "héllo", "日本" |
| `atom(:alphanumeric)` | Atoms | :foo, :bar_baz |
| `boolean()` | true/false | true, false |
| `bitstring()` | Bit strings | `<<1::3>>` |
| `iodata()` | IO data | ["hello", [" ", "world"]] |
| `iolist()` | IO lists | [?h, "ello"] |
| `term()` | Any Erlang term | Anything |
| `constant(value)` | Always the same value | `constant(:ok)` → :ok |

### Collection Generators

| Generator | Produces |
|-----------|----------|
| `list_of(gen)` | List of generated values |
| `list_of(gen, min_length: 1, max_length: 10)` | Bounded list |
| `nonempty(list_of(gen))` | Non-empty list |
| `uniq_list_of(gen, min_length: 1)` | List with unique elements |
| `map_of(key_gen, value_gen)` | Map with generated keys/values |
| `fixed_map(%{key: gen})` | Map with fixed keys, generated values |
| `keyword_of(gen)` | Keyword list |
| `tuple({gen1, gen2, ...})` | Fixed-size tuple |
| `optional(gen)` | Value or nil |
| `one_of([gen1, gen2])` | Randomly pick a generator |
| `frequency([{weight, gen}])` | Weighted random pick |

## Composing Custom Generators

### map/2 — Transform Generated Values

```elixir
# Generate emails
def email_gen do
  gen all name <- string(:alphanumeric, min_length: 3),
          domain <- member_of(["example.com", "test.org", "mail.co"]) do
    "#{String.downcase(name)}@#{domain}"
  end
end

# Generate money amounts (cents as integers)
def money_gen do
  map(integer(0..999_999), &{:cents, &1})
end
```

### bind/2 — Dependent Generation

When one generated value determines how to generate the next:

```elixir
# Generate a list and an index into that list
def list_and_index_gen do
  gen all list <- nonempty(list_of(integer())),
          index <- integer(0..(length(list) - 1)) do
    {list, index}
  end
end
```

### filter/2 — Constrain Values

Use sparingly — too much filtering causes StreamData to give up:

```elixir
# Generate even integers
even_gen = filter(integer(), &(rem(&1, 2) == 0))

# Better: generate and transform (no filtering needed)
even_gen = map(integer(), &(&1 * 2))
```

### Domain-Specific Generators

```elixir
defmodule MyApp.Generators do
  use ExUnitProperties

  def user_attrs_gen do
    gen all name <- string(:alphanumeric, min_length: 1, max_length: 50),
            email <- email_gen(),
            age <- integer(18..120) do
      %{name: name, email: email, age: age}
    end
  end

  def email_gen do
    gen all local <- string(:alphanumeric, min_length: 3, max_length: 20),
            domain <- member_of(["gmail.com", "example.com", "company.org"]) do
      "#{String.downcase(local)}@#{domain}"
    end
  end

  def date_range_gen do
    gen all start_days <- integer(0..365),
            duration <- integer(1..30) do
      start = Date.add(Date.utc_today(), -start_days)
      finish = Date.add(start, duration)
      {start, finish}
    end
  end

  def money_gen(min \\ 0, max \\ 1_000_000) do
    gen all cents <- integer(min..max) do
      %Money{amount: cents, currency: :USD}
    end
  end
end
```

## Common Property Patterns

### 1. Roundtrip / Symmetry

If you encode then decode, you get the original back:

```elixir
property "JSON encode/decode roundtrip" do
  check all value <- one_of([integer(), float(), string(:printable), boolean()]) do
    assert value == value |> Jason.encode!() |> Jason.decode!()
  end
end

property "changeset roundtrip" do
  check all attrs <- user_attrs_gen() do
    changeset = User.changeset(%User{}, attrs)
    if changeset.valid? do
      assert changeset.changes.name == attrs.name
      assert changeset.changes.email == attrs.email
    end
  end
end
```

### 2. Idempotency

Applying an operation twice gives the same result as once:

```elixir
property "formatting is idempotent" do
  check all name <- string(:alphanumeric) do
    once = format_name(name)
    twice = format_name(once)
    assert once == twice
  end
end

property "normalizing email is idempotent" do
  check all email <- email_gen() do
    assert normalize_email(email) == normalize_email(normalize_email(email))
  end
end
```

### 3. Invariants

Properties that must always hold:

```elixir
property "sorting preserves length and elements" do
  check all list <- list_of(integer()) do
    sorted = Enum.sort(list)
    assert length(sorted) == length(list)
    assert Enum.all?(list, &(&1 in sorted))
  end
end

property "filtering never adds elements" do
  check all list <- list_of(integer()),
            threshold <- integer() do
    filtered = Enum.filter(list, &(&1 > threshold))
    assert length(filtered) <= length(list)
    assert Enum.all?(filtered, &(&1 > threshold))
  end
end
```

### 4. Oracle / Model Testing

Test your implementation against a simpler reference:

```elixir
property "our cache behaves like a Map" do
  check all operations <- list_of(
    one_of([
      tuple({constant(:put), string(:alphanumeric), integer()}),
      tuple({constant(:get), string(:alphanumeric)}),
      tuple({constant(:delete), string(:alphanumeric)})
    ]),
    max_length: 50
  ) do
    # Run same operations against cache and a plain map
    {cache_results, _cache} = run_operations(operations, Cache.new())
    {map_results, _map} = run_operations_on_map(operations, %{})
    assert cache_results == map_results
  end
end
```

### 5. Commutativity / Associativity

Order or grouping doesn't matter:

```elixir
property "merging maps is commutative for disjoint keys" do
  check all map1 <- map_of(string(:alphanumeric), integer()),
            map2 <- map_of(string(:alphanumeric), integer()) do
    # Only commutative for disjoint keys
    if MapSet.disjoint?(MapSet.new(Map.keys(map1)), MapSet.new(Map.keys(map2))) do
      assert Map.merge(map1, map2) == Map.merge(map2, map1)
    end
  end
end

property "CRDT merge is commutative" do
  check all ops1 <- list_of(crdt_op_gen()),
            ops2 <- list_of(crdt_op_gen()) do
    crdt_a = apply_ops(CRDT.new(), ops1)
    crdt_b = apply_ops(CRDT.new(), ops2)
    assert CRDT.merge(crdt_a, crdt_b) == CRDT.merge(crdt_b, crdt_a)
  end
end
```

### 6. Metamorphic Relations

If you transform the input in a known way, the output should transform predictably:

```elixir
property "doubling all prices doubles the total" do
  check all items <- nonempty(list_of(
    fixed_map(%{name: string(:alphanumeric), price: positive_integer()})
  )) do
    original_total = calculate_total(items)
    doubled_items = Enum.map(items, &%{&1 | price: &1.price * 2})
    doubled_total = calculate_total(doubled_items)
    assert doubled_total == original_total * 2
  end
end
```

## Testing with Ecto

### Generating Valid Changesets

```elixir
property "valid user attrs always produce valid changesets" do
  check all attrs <- user_attrs_gen() do
    changeset = User.changeset(%User{}, attrs)
    assert changeset.valid?, "Invalid changeset: #{inspect(changeset.errors)}"
  end
end
```

### Database Property Tests

```elixir
property "insert then fetch returns same data" do
  check all attrs <- user_attrs_gen(), max_runs: 50 do
    {:ok, user} = Repo.insert(User.changeset(%User{}, attrs))
    fetched = Repo.get!(User, user.id)
    assert fetched.name == attrs.name
    assert fetched.email == attrs.email
  end
end
```

**Note**: Database property tests should use `max_runs: 50` or lower — 100 inserts per test run adds up in CI.

## Configuration

```elixir
# Default: 100 iterations per property
property "example" do
  check all value <- integer() do
    # runs 100 times with different values
  end
end

# Override per-test
property "thorough check" do
  check all value <- integer(), max_runs: 500 do
    # runs 500 times
  end
end

# Override globally in config/test.exs
config :stream_data,
  max_runs: if(System.get_env("CI"), do: 200, else: 50)
```

**Guidance**: 50 runs for database tests, 100 for pure logic (default), 500+ for security-critical or serialization code.

## Shrinking

When StreamData finds a failing input, it **shrinks** it to the minimal reproducing case. This is automatic for built-in generators.

### When Shrinking Breaks

```elixir
# ❌ filter can prevent shrinking — StreamData may give up
check all x <- filter(integer(), &(&1 > 100 and rem(&1, 7) == 0)) do
  # ...
end

# ✅ Generate and transform instead — shrinking works naturally
check all x <- map(integer(15..1000), &(&1 * 7)) do
  # ...
end
```

**Rule**: Prefer `map` over `filter`. Every `filter` rejection wastes a generation attempt and can block shrinking. If you must filter, keep the rejection rate under ~50%.

## Common Mistakes

- **Testing implementation instead of properties**: `assert my_sort(list) == Enum.sort(list)` is an oracle test, not a property test. True properties are like "output is sorted" + "output has same elements" — they don't reference a specific implementation.
- **Too much filtering**: `filter(integer(), &(&1 > 0 and &1 < 10 and rem(&1, 2) == 0))` rejects most values. Generate precisely: `map(integer(1..5), &(&1 * 2))`.
- **Forgetting `max_runs` for DB tests**: Default 100 iterations with DB inserts is slow. Set `max_runs: 50` or lower.
- **Not extracting generators into a module**: Copy-pasting generators across tests leads to inconsistency. Put domain generators in `MyApp.Generators` and import them.
- **Only testing happy paths**: Properties should cover error cases too. Generate invalid inputs and verify your code returns `{:error, _}` rather than crashing.
- **Ignoring shrink output**: When a property fails, StreamData shows both the original failing input and the shrunk minimal case. Read the shrunk case — it's the most useful debugging information.

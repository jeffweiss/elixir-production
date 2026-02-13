# Concurrent Data Structures

Beyond `:atomics` and `:counters` — patterns for safe concurrent access on the BEAM.

## Decision Table

| Need | Tool | Why |
|------|------|-----|
| Concurrent counter | `:atomics` / `:counters` | Lock-free, no process bottleneck |
| Concurrent read-heavy cache | ETS with `read_concurrency: true` | Optimized reader locks |
| Concurrent read+write | ETS with `write_concurrency: true` | Per-key lock striping |
| Compare-and-swap (CAS) | `:atomics.compare_exchange/4` | Lock-free conditional updates |
| Concurrent boolean flags | `:atomics` (0/1 values) | Faster than ETS for simple flags |
| Write-heavy counting | `:counters` with `:write_concurrency` | Distributed counters, eventual read |
| Coordinated state changes | GenServer / `:gen_statem` | When you need serialization |

## :atomics — Lock-Free Integer Operations

```elixir
# Create atomic reference with 10 integer slots
ref = :atomics.new(10, signed: true)

# Atomic operations — safe from any process, no locks
:atomics.put(ref, 1, 42)           # Set slot 1 to 42
:atomics.get(ref, 1)                # => 42
:atomics.add(ref, 1, 5)             # Atomic add: 42 + 5 = 47
:atomics.sub(ref, 1, 3)             # Atomic subtract: 47 - 3 = 44
:atomics.exchange(ref, 1, 100)      # Swap, returns old value: 44
```

### Compare-and-Swap (CAS)

The fundamental building block for lock-free algorithms. Updates a value only if it still equals the expected value:

```elixir
ref = :atomics.new(1, signed: false)
:atomics.put(ref, 1, 10)

# Only update if current value is 10
case :atomics.compare_exchange(ref, 1, 10, 20) do
  :ok -> :updated        # Was 10, now 20
  actual -> {:conflict, actual}  # Someone else changed it
end
```

**CAS retry loop** — for lock-free concurrent updates:

```elixir
def atomic_max(ref, index, new_value) do
  current = :atomics.get(ref, index)
  if new_value > current do
    case :atomics.compare_exchange(ref, index, current, new_value) do
      :ok -> :ok
      _current -> atomic_max(ref, index, new_value)  # Retry
    end
  else
    :ok
  end
end
```

### Practical Pattern: Feature Flags

```elixir
defmodule MyApp.FeatureFlags do
  @flags %{new_ui: 1, beta_api: 2, dark_mode: 3}

  def init do
    ref = :atomics.new(map_size(@flags), signed: false)
    :persistent_term.put(:feature_flags_ref, ref)
  end

  def enabled?(flag) do
    ref = :persistent_term.get(:feature_flags_ref)
    :atomics.get(ref, @flags[flag]) == 1
  end

  def enable(flag) do
    ref = :persistent_term.get(:feature_flags_ref)
    :atomics.put(ref, @flags[flag], 1)
  end

  def disable(flag) do
    ref = :persistent_term.get(:feature_flags_ref)
    :atomics.put(ref, @flags[flag], 0)
  end
end
```

## :counters — High-Throughput Counting

`:counters` with `:write_concurrency` distributes updates across multiple cache lines, avoiding contention at the cost of slightly stale reads:

```elixir
# Write-optimized counters (reads may lag slightly)
ref = :counters.new(5, [:write_concurrency])

# Concurrent increments from many processes — minimal contention
:counters.add(ref, 1, 1)

# Read (eventually consistent with write_concurrency)
:counters.get(ref, 1)
```

| Option | `:atomics` | `:counters` | `:counters` + `:write_concurrency` |
|--------|-----------|-------------|-----------------------------------|
| Read speed | Fast | Fast | Slightly slower (aggregates shards) |
| Write contention | Some (single cache line) | Some | Minimal (sharded) |
| CAS support | Yes | No | No |
| Best for | Flags, CAS patterns | Moderate counting | High-throughput counting |

## ETS Concurrency Patterns

### Optimistic Locking with :ets.update_counter

```elixir
# Atomic increment — no GenServer needed
:ets.update_counter(:stats, :request_count, {2, 1}, {:request_count, 0})

# Conditional update — only increment if below limit
case :ets.update_counter(:rate_limits, key, {2, 1, limit, limit}, {key, 0}) do
  count when count <= limit -> :allow
  _ -> :deny
end
```

### Read-Copy-Update Pattern

For data that's read far more than written — write a full new version, readers always get a consistent snapshot:

```elixir
defmodule MyApp.ConfigCache do
  def init do
    :ets.new(:config_cache, [:set, :named_table, :public, read_concurrency: true])
  end

  # Write: replace entire value atomically
  def update(key, value) do
    :ets.insert(:config_cache, {key, value})  # Atomic for single row
  end

  # Read: always gets consistent value (either old or new, never partial)
  def get(key) do
    case :ets.lookup(:config_cache, key) do
      [{^key, value}] -> {:ok, value}
      [] -> :error
    end
  end
end
```

## When NOT to Use Lock-Free Structures

Use a GenServer or `:gen_statem` when you need:
- **Multi-key atomicity**: Updating two values that must be consistent with each other
- **Complex invariants**: State transitions that depend on multiple conditions
- **Sequential processing**: Operations that must happen in strict order
- **Request-reply**: Caller needs to wait for the result of the update

Lock-free structures are for **independent, commutative operations** where occasional retries are acceptable.

## Common Mistakes

- **Using GenServer for concurrent counters**: Serializes all updates through one process mailbox. Use `:atomics` or `:counters`.
- **Assuming ETS reads are atomic for multi-key**: Single row operations are atomic, but reading two rows is not — another process can modify between reads.
- **Not using `write_concurrency` for high-write ETS**: Default ETS serializes writes on a single lock. Set the option for concurrent writers.
- **Infinite CAS retry loops**: If contention is very high, CAS loops can spin. Add backoff or reconsider if a GenServer is more appropriate.
- **Using `:atomics` for complex state**: Atomics only store integers. For complex state with invariants, use GenServer or ETS.

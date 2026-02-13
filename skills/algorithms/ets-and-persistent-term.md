# ETS and Persistent Term

## ETS (Erlang Term Storage)

In-memory key-value store shared between processes. The most important "advanced" data structure in production Elixir — every non-trivial application uses it eventually.

### When to Use ETS

```
Need shared state across processes?
  NO  → Use Map in a single process
  YES → Read-heavy (>90% reads)?
          YES → Is data rarely updated (config, lookup tables)?
                  YES → :persistent_term (fastest reads, expensive writes)
                  NO  → ETS (fast reads, decent writes)
          NO  → Write-heavy?
                  YES → :counters/:atomics for numeric data
                        ETS with :write_concurrency for general data
                  NO  → GenServer if access pattern is sequential
                        ETS if access pattern is concurrent
```

### Table Types

| Type | Duplicate Keys | Ordering | Use When |
|------|---------------|----------|----------|
| `:set` | No (last write wins) | None | Key-value lookup (most common) |
| `:ordered_set` | No | Key order | Range queries, iteration in order |
| `:bag` | Yes (unique {key, value} pairs) | None | One-to-many relationships |
| `:duplicate_bag` | Yes (allows identical rows) | None | Event logs, audit trails |

### Creating Tables

```elixir
# Basic key-value cache
:ets.new(:my_cache, [:set, :named_table, :public, read_concurrency: true])

# High-write table (e.g., rate limiting)
:ets.new(:rate_limits, [:set, :named_table, :public,
  read_concurrency: true, write_concurrency: true])

# Ordered for range queries
:ets.new(:leaderboard, [:ordered_set, :named_table, :public, read_concurrency: true])
```

### Concurrency Options

| Option | Effect | Use When |
|--------|--------|----------|
| `read_concurrency: true` | Optimizes for concurrent reads | Read-heavy workloads (caches, lookups) |
| `write_concurrency: true` | Reduces write contention | Many processes writing simultaneously |
| `decentralized_counters: true` | Distributes `info/size` counters | High-volume tables where you call `:ets.info(tab, :size)` |

**Default**: No concurrency optimizations. Always set `read_concurrency: true` for shared lookup tables.

### Common Patterns

**Cache with TTL**:
```elixir
defmodule MyApp.Cache do
  def get(key) do
    case :ets.lookup(:my_cache, key) do
      [{^key, value, expires_at}] ->
        if System.monotonic_time(:second) < expires_at,
          do: {:ok, value},
          else: :miss
      [] -> :miss
    end
  end

  def put(key, value, ttl_seconds \\ 300) do
    expires_at = System.monotonic_time(:second) + ttl_seconds
    :ets.insert(:my_cache, {key, value, expires_at})
  end
end
```

**Rate Limiter**:
```elixir
defmodule MyApp.RateLimiter do
  def check(key, limit, window_seconds) do
    now = System.monotonic_time(:second)
    window_start = now - window_seconds

    # Atomic update_counter — no GenServer bottleneck
    case :ets.update_counter(:rate_limits, key, {2, 1}, {key, 0, now}) do
      count when count <= limit -> {:allow, count}
      count -> {:deny, count}
    end
  end
end
```

**Match Specifications for Queries**:
```elixir
# Find all users with score > 100
match_spec = [{{:"$1", :"$2", :"$3"}, [{:>, :"$3", 100}], [:"$$"]}]
:ets.select(:users, match_spec)

# Or use the friendlier :ets.fun2ms/1 (compile-time only)
import :ets, only: [fun2ms: 1]
ms = fun2ms(fn {name, _email, score} when score > 100 -> name end)
:ets.select(:users, ms)
```

### Ownership and Lifecycle

ETS tables are owned by the process that creates them. **If the owner dies, the table is deleted.** Always create ETS tables in a supervised process:

```elixir
# ❌ Creating in a transient process — table vanishes on crash
def some_function do
  :ets.new(:my_table, [:named_table])
end

# ✅ Creating in a supervised GenServer or Application callback
def init(_) do
  :ets.new(:my_table, [:named_table, :public, read_concurrency: true])
  {:ok, %{}}
end
```

For tables that must survive owner crashes, use `:ets.give_away/3` or the `heir` option.

### ETS vs Map vs GenServer

| Dimension | Map (in GenServer) | ETS | Winner |
|-----------|-------------------|-----|--------|
| Read latency (1 reader) | ~0.1μs | ~0.5μs | Map |
| Read latency (100 concurrent readers) | Bottlenecked on GenServer mailbox | ~0.5μs each | ETS |
| Write latency | ~0.1μs | ~1μs | Map |
| Write concurrency | Serialized | Concurrent (with option) | ETS |
| Memory overhead | Low (process heap) | Higher (separate memory) | Map |
| GC impact | Collected with process | Not GC'd (separate allocation) | ETS for large data |
| Pattern matching | Full Elixir patterns | Match specifications | Map |
| Persistence | None | None (use DETS or dump to DB) | Neither |

**Rule of thumb**: If only one process reads/writes, use a Map in that process. If multiple processes need concurrent access, use ETS.

## :persistent_term

Global read-optimized storage. Reads are essentially free — the value is copied directly from a shared heap. But writes trigger a global GC pass across all processes.

### When to Use

- Application configuration that rarely changes
- Compiled patterns, regexes, or lookup tables
- Module-level constants that are too large for module attributes
- Router dispatch tables, feature flags

### When NOT to Use

- Data that changes more than once per minute
- Per-request or per-user data
- Anything with frequent updates — each write triggers global GC

### Usage

```elixir
# Store (expensive — triggers global GC)
:persistent_term.put(:my_app_config, %{
  feature_flags: %{new_ui: true, beta_api: false},
  rate_limits: %{api: 1000, search: 100}
})

# Read (essentially free — no copy, direct reference)
config = :persistent_term.get(:my_app_config)
config.feature_flags.new_ui  # true

# Delete (also triggers global GC)
:persistent_term.erase(:my_app_config)
```

### Production Pattern: Config Module

```elixir
defmodule MyApp.Config do
  def load do
    :persistent_term.put({__MODULE__, :settings}, %{
      max_upload_size: 10_000_000,
      session_ttl: 3600,
      feature_flags: load_feature_flags()
    })
  end

  def get(key) do
    :persistent_term.get({__MODULE__, :settings})[key]
  end

  # Call sparingly — triggers global GC
  def update_feature_flag(flag, value) do
    settings = :persistent_term.get({__MODULE__, :settings})
    updated = put_in(settings, [:feature_flags, flag], value)
    :persistent_term.put({__MODULE__, :settings}, updated)
  end
end
```

### :persistent_term vs ETS vs Application.get_env

| Dimension | :persistent_term | ETS | Application.get_env |
|-----------|-----------------|-----|-------------------|
| Read speed | Fastest (~10ns) | Fast (~500ns) | Slow (~1μs, goes through GenServer) |
| Write cost | Very expensive (global GC) | Fast (~1μs) | Moderate |
| Concurrency | Lockless reads | Lock-free with options | Serialized |
| Update frequency | Rarely (minutes/hours) | Freely | Freely |
| Memory model | Shared heap (no copy) | Separate allocation (copied) | Process heap (copied) |

## New ETS Functions (OTP 27+)

### Combined Traversal: first_lookup / next_lookup

Combines key lookup and value fetch in one call — faster than separate `first` + `lookup`:

```elixir
# ❌ Two operations per step (OTP 26 and earlier)
key = :ets.first(table)
[{^key, value}] = :ets.lookup(table, key)
next_key = :ets.next(table, key)

# ✅ One operation per step (OTP 27+)
{key, [{^key, value}]} = :ets.first_lookup(table)
{next_key, [{^next_key, next_value}]} = :ets.next_lookup(table, key)

# Reverse traversal
{last_key, entries} = :ets.last_lookup(table)
{prev_key, entries} = :ets.prev_lookup(table, last_key)
```

### Upsert with Default: update_element/4

Update an element if it exists, or insert a default if it doesn't — atomic, no race condition:

```elixir
# ❌ Race condition between lookup and insert (OTP 26 and earlier)
case :ets.lookup(table, key) do
  [{^key, _old}] -> :ets.update_element(table, key, {2, new_value})
  [] -> :ets.insert(table, {key, new_value})
end

# ✅ Atomic upsert (OTP 27+)
:ets.update_element(table, key, {2, new_value}, {key, default_value})
```

## Common Mistakes

- **Using Application.get_env in hot paths**: For config read on every request, use `:persistent_term`. Application env goes through a GenServer.
- **Storing per-request data in :persistent_term**: Each write triggers global GC. Use ETS for data that changes per-request.
- **Forgetting `read_concurrency: true`**: Default ETS has no read optimization. Always set this for shared lookup tables.
- **Creating ETS in unsupervised processes**: Table dies with the process. Always create in a supervised process.
- **Using GenServer as a cache for concurrent reads**: GenServer serializes access. If 100 processes read concurrently, 99 wait in the mailbox. Use ETS.
- **Not setting `write_concurrency` for high-write tables**: Without it, concurrent writes serialize on a single lock.
- **Using `:ordered_set` when order doesn't matter**: `:set` is faster for pure key-value lookup. Only use `:ordered_set` if you need range queries or sorted iteration.

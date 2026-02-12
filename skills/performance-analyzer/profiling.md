# Profiling Tools and Techniques

## The Iron Law

```
NO OPTIMIZATION WITHOUT PROFILING DATA
```

**Before suggesting ANY optimization:**
1. Profile to identify bottlenecks
2. Create benchmarks for current state
3. Only then suggest changes
4. Benchmark again to verify improvement

**No exceptions:**
- Not for "obvious" improvements
- Not for "best practices"
- Not for code that "looks slow"
- Not when user is confident they know the problem

## Red Flags — STOP and Profile First

| Thought | Reality |
|---------|---------|
| "I can identify optimization opportunities" | Code review ≠ profiling. Measure first. |
| "This is obviously slow" | Obvious to you ≠ actual bottleneck. Profile. |
| "Multiple Enum passes are inefficient" | Maybe. Measure to confirm. |
| "Stream would be faster" | Maybe not. Benchmark both. |
| "The user knows it's an N+1 problem" | Users guess wrong. Verify with profiling. |
| "I would profile if I had access" | You do. Insist on profiling before proceeding. |
| "Let me explain how to profile" | Don't explain. Insist on actual profiling. |

**All of these mean: Refuse to suggest optimizations. Profile first.**

## Profiler Selection

| What You Need to Know | Tool | Command |
|-----------------------|------|---------|
| Which functions are called most? | cprof | `mix profile.cprof -e "Code.here()"` |
| Which functions take the most time? | eprof | `mix profile.eprof -e "Code.here()"` |
| Detailed call tree with time per call | fprof | `mix profile.fprof -e "Code.here()"` |
| Where is memory allocated? | tprof (OTP 27+) | `mix profile.tprof -e "Code.here()" --type memory` |
| Is the database the bottleneck? | Ecto telemetry / query logs | `config :my_app, MyApp.Repo, log: :debug` |

**Wrong tool = wrong conclusions:**
- fprof measures TIME, not memory
- cprof counts CALLS, not time
- eprof overhead is lower than fprof — start with eprof, use fprof only when you need call trees
- Use tprof `--type memory` for memory profiling

## In-Process Profiling

```elixir
# eprof — good default starting point
:eprof.start()
:eprof.start_profiling([self()])
MyModule.slow_function(input)
:eprof.stop_profiling()
:eprof.analyze()

# Quick wall-clock measurement
{microseconds, result} = :timer.tc(fn -> MyModule.slow_function(input) end)
IO.puts("#{microseconds / 1000}ms")
```

## Escalation Ladder

### Level 0: Measure Before Anything

Before touching code, establish what "slow" means.

| Question | How to Answer | Tool |
|----------|---------------|------|
| Is it actually slow? | Get a number, not a feeling | `Benchee.run` with current code |
| How slow? | Wall-clock time for the operation | `:timer.tc/1` or `Benchee` |
| Slow for whom? | User-facing latency vs background job throughput | Application metrics, Telemetry |
| How often? | Once per request? Once per deploy? | Logging, `:telemetry.attach` |

**Move to Level 1 when**: You have a number and it's too high.

### Level 1: Profile to Find the Bottleneck

Don't guess. Let the profiler tell you where time is spent. Use profiler selection table above.

**Move to Level 2 when**: Profiler shows where the time goes and it's CPU-bound application code.

### Level 2: Algorithmic and Data Structure Fixes

The highest-leverage fixes. A better algorithm beats any micro-optimization.

| Profiler Shows | Likely Cause | Fix |
|----------------|-------------|-----|
| O(n) function called in O(n) loop | O(n²) hidden complexity | Replace inner lookup with Map/MapSet (O(1)) |
| `Enum.member?/2` on large list | O(n) membership test | Switch to MapSet |
| List append (`++`) in loop | O(n) per append, O(n²) total | Prepend + `Enum.reverse/1`, or use `:queue` |
| Repeated Enum.filter/map chains | Multiple passes over same data | Single `Enum.reduce/3` or `for` comprehension |
| Sorting inside a loop | O(n log n) repeated unnecessarily | Sort once outside loop |

### Level 3: BEAM-Specific Optimizations

| Bottleneck Type | Solution | OTP/Library |
|-----------------|----------|-------------|
| CPU-bound, embarrassingly parallel | Parallel processing | `Task.async_stream/3` |
| I/O-bound (HTTP, DB) waiting | Concurrent requests | `Task.async_stream/3`, connection pooling |
| Large data, can't fit in memory | Streaming / chunking | `Stream`, `Repo.stream/1`, `Flow` |
| Hot GenServer bottleneck | Reduce process contention | ETS for reads, `:atomics` for counters |
| Frequent small allocations | Reduce garbage collection | ETS, `:persistent_term` for read-heavy data |
| JSON encoding/decoding | Faster library | `Jason` (already fast), or `:jiffy` NIF for extreme cases |

```elixir
# Task.async_stream — parallelize independent work
results =
  items
  |> Task.async_stream(&process_item/1, max_concurrency: System.schedulers_online())
  |> Enum.map(fn {:ok, result} -> result end)

# ETS — eliminate GenServer read bottleneck
:ets.new(:hot_cache, [:named_table, :public, read_concurrency: true])
:ets.insert(:hot_cache, {"key", value})
:ets.lookup(:hot_cache, "key")
```

### Level 4: Database and I/O Optimization

Most real-world slowness lives in I/O, not application code.

| Symptom | Solution | How to Verify |
|---------|----------|---------------|
| N+1 queries | `Repo.preload/2` or join | Check query count in logs before/after |
| Slow query | Add index | `EXPLAIN ANALYZE` in psql |
| Too many queries | Batch with `Ecto.Multi` or `insert_all` | Query count in logs |
| Large result sets | Pagination, `Repo.stream/1` | Memory usage before/after |
| Connection pool exhaustion | Increase pool size or reduce checkout time | `DBConnection` pool metrics |
| External API latency | Cache responses, circuit breaker | `Cachex` TTL, `Fuse` |

```elixir
# Preload to eliminate N+1
users = Repo.all(from u in User, preload: [:profile, :orders])

# Batch insert instead of N individual inserts
Repo.insert_all(Order, orders_params)
```

### Level 5: System-Level and Infrastructure Tuning

Last resort. Most applications never need this.

| Bottleneck | Solution | When Justified |
|-----------|----------|----------------|
| BEAM scheduler contention | `+S` flag to tune schedulers | Profiling shows scheduler saturation |
| GC pauses in critical path | Move hot data to ETS/`:persistent_term` | Measured GC impact |
| NIF for CPU-intensive math | Rustler NIF | Benchee shows >10x improvement justifies FFI complexity |
| Distributed processing | `Flow` or `GenStage` pipelines | Single node can't keep up with data volume |
| Kernel/network tuning | TCP buffer sizes, connection limits | Load testing shows OS-level bottleneck |

## Escalation Decision Flowchart

```
Do you have a number for "how slow"?
  NO  → Level 0 (measure first)
  YES → Do you know WHERE the time is spent?
          NO  → Level 1 (profile)
          YES → Is it an algorithmic problem (O(n²)+)?
                  YES → Level 2 (algorithm/data structure fix)
                  NO  → Is it CPU-bound application code?
                          YES → Level 3 (BEAM optimizations)
                          NO  → Is it database/I/O?
                                  YES → Level 4 (DB/I/O optimization)
                                  NO  → Level 5 (system tuning)
```

## Common Performance Patterns (After Profiling Shows These)

Only suggest these if profiling data confirms the problem:

### High Call Frequency
- **Symptom:** cprof shows function called 100,000+ times
- **Fix:** Reduce calls (caching, memoization) or optimize hot function

### Multiple Data Passes
- **Symptom:** eprof shows significant time in Enum.map chains
- **Fix:** Stream for large data, single-pass with reduce, or parallel processing

### Memory Pressure
- **Symptom:** tprof shows large allocations
- **Fix:** Stream processing, ETS tables, or chunking

### I/O Bound Operations
- **Symptom:** fprof shows time in database/network calls
- **Fix:** Parallel processing with Task.async_stream, connection pooling

### Database N+1 Queries
- **Symptom:** Database logs show 1 + N queries for associations
- **Fix:** Ecto.Repo.preload or custom joins

## Refusing Without Profiling Data

When user asks for optimization advice without profiling:

**DON'T say:**
- "I would profile..."
- "You might want to profile..."
- "To properly verify, I recommend profiling..."

**DO say:**
- "I cannot suggest optimizations without profiling data. Let's profile first."
- "Profile first to identify the actual bottleneck."
- "Create a benchmark showing current performance before changing anything."

**Make profiling MANDATORY, not optional.**

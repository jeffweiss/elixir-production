# BEAM Per-Process Garbage Collection

## How BEAM GC Works

BEAM garbage-collects each process independently. This is a strength (one process's GC doesn't pause another) but creates a trap: **a process with a large live heap will have long GC pauses**, causing latency spikes even when the rest of the system is fine (Juric, "Reducing the maximum latency of a bound buffer").

**Key insight**: The number of *GC runs* doesn't matter — what matters is the *duration* of each GC run, which is proportional to the live heap size.

## Diagnosis

If profiling shows p99.9+ latency spikes concentrated in a single GenServer, check its heap size:

```elixir
:erlang.process_info(pid, :heap_size)
```

A process holding 200k+ live references will trigger multi-millisecond GC pauses.

## Mitigation Techniques

In order of preference:

### 1. Offload Data to ETS

Store large collections in ETS tables instead of process state. ETS data lives outside the process heap and is freed immediately on deletion — no GC involvement.

This can reduce max latency from ~37ms to ~300us.

```elixir
:ets.new(:hot_data, [:named_table, :public, read_concurrency: true])
:ets.insert(:hot_data, {"key", large_value})
```

### 2. Split into Smaller Processes

A single process holding 200k items can be split into 20 processes holding 10k each. Each will GC faster, and GCs won't block each other.

### 3. Preallocate Heap for One-Off Jobs

For temporary processes that allocate heavily, preallocate to avoid repeated heap expansion and GC during the job:

```elixir
Process.spawn(fn -> heavy_work() end, [:link, {:min_heap_size, large_value}])
```

The memory is reclaimed instantly when the process terminates.

### 4. Use Refc Binaries

Binaries >64 bytes are stored on a shared heap with reference counting, not on the process heap. If your data is naturally binary (strings, serialized data), this reduces per-process heap pressure automatically.

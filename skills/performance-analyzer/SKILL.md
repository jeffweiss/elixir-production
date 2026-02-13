---
name: performance-analyzer
description: Use when code is reported slow, before suggesting any optimization, when choosing between cprof/eprof/fprof/tprof, or when creating Benchee benchmarks to compare approaches
---

# Performance Analysis for Elixir/Phoenix

## Overview

**NO OPTIMIZATION WITHOUT PROFILING DATA.** Code review cannot tell you where bottlenecks are — only measurement can. Refuse to suggest optimizations without profiling results.

## Profiler Selection

| What You Need | Tool | Command |
|---------------|------|---------|
| Function call frequency | cprof | `mix profile.cprof -e "Code.here()"` |
| Time per function | eprof | `mix profile.eprof -e "Code.here()"` |
| Detailed call tree | fprof | `mix profile.fprof -e "Code.here()"` |
| Memory allocations (OTP 27+) | tprof | `mix profile.tprof -e "Code.here()" --type memory` |

Start with eprof (lower overhead). Use fprof only when you need call trees.

## Escalation Ladder

```
Do you have a number for "how slow"?
  NO  → L0: Measure first (Benchee baseline)
  YES → Know WHERE time is spent?
          NO  → L1: Profile (eprof/fprof)
          YES → Algorithmic problem (O(n²)+)?
                  YES → L2: Algorithm/data structure fix
                  NO  → CPU-bound?
                          YES → L3: BEAM opts (Task.async_stream, ETS)
                          NO  → Database/I/O?
                                  YES → L4: DB optimization (preload, indexes)
                                  NO  → L5: System tuning (last resort)
```

## Common Mistakes

- **Optimizing without profiling** — code review ≠ profiling. Measure first.
- **No baseline benchmark** — measure current state before changing anything
- **Assuming optimization worked** — benchmark after changes to verify
- **Server-side metrics only** — client-observed latency can be 15x higher
- **Wrong profiler** — fprof measures time not memory; cprof counts calls not time

## Reference Files

**Read the file that matches your current problem:**

- `profiling.md` — **When**: About to profile code or choosing a profiler. Iron Law enforcement, profiler usage, escalation ladder L0-L5, common patterns
- `benchmarking.md` — **When**: Comparing implementation alternatives with Benchee. Benchee templates, complexity analysis, validation workflow
- `latency.md` — **When**: Investigating tail latency or fan-out amplification. Tail latency reduction (hedged requests), fan-out amplification, measurement pitfalls, pool sizing
- `beam-gc.md` — **When**: Suspecting garbage collection pressure or large heaps. Per-process GC, ETS for heap reduction, 4 mitigation techniques
- `beam-efficiency.md` — **When**: Hitting BEAM-specific performance pitfalls (binaries, maps, lists). BEAM performance pitfalls: Seven Myths, binary handling (IO lists, append vs prepend), map efficiency (32-key threshold, key sharing), list O(n) traps, process data copying, atom table, NIFs

## Commands

- **`/benchmark`** — Create and run Benchee benchmarks for comparison
- **`/review [file]`** — Review code including performance analysis

## Related Skills

- **algorithms**: Better data structures when profiling reveals O(n²)+
- **production-quality**: Observability and telemetry setup
- **elixir-patterns**: BEAM-specific patterns (ETS, Task, GenServer)

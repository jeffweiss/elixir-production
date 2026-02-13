---
name: algorithms
description: Use when choosing data structures, Map vs ETS vs gb_trees performance, evaluating hash functions, needing HyperLogLog or bloom/cuckoo filters, or comparing OTP built-ins against specialized alternatives for Elixir
---

# Modern Algorithms and Data Structures

## Overview

Use OTP built-ins first. Escalate to specialized structures only when profiling shows a bottleneck. For most Elixir applications, Map, MapSet, List, and the OTP modules cover 95% of needs.

## Quick Decision

```
What are you solving?
  Data storage/lookup       → See ets-and-persistent-term.md, otp-builtins.md
  Concurrent shared state   → See concurrent-data-structures.md, ets-and-persistent-term.md
  Graph/dependency problem  → See graph-algorithms.md
  Text search/matching      → See string-and-text.md
  Location/spatial          → See spatial.md
  Time ranges/scheduling    → See interval-and-range.md
  Streaming metrics         → See streaming-algorithms.md
  Large-scale counting/sets → See probabilistic.md
  Hashing                   → See hash-functions.md
  Compression               → See compression.md
  Sorting large datasets    → See sorting-and-search.md
  Optimization/constraints  → See optimization.md
  Statistics/analytics      → See statistics.md
```

## Common Mistakes

- **GenServer as concurrent cache**: Serializes reads; use ETS with `read_concurrency: true`
- **Application.get_env in hot paths**: Use `:persistent_term` for config read on every request
- **Lists as queues**: `queue ++ [item]` is O(n); use `:queue` for O(1)
- **GenServer as counter**: Use `:atomics` or `:counters` instead
- **MD5/SHA1 for non-crypto**: 60× slower than xxHash3
- **Exact counting at scale**: HyperLogLog uses 16 KB where MapSet uses 800 MB (100M items)

## Reference Files

- `ets-and-persistent-term.md` — ETS table types, concurrency options, cache/rate-limiter patterns, `:persistent_term` for config
- `otp-builtins.md` — `:queue`, `:gb_trees`, `:gb_sets`, `:atomics`, `:counters`, `:array`, Okasaki structures
- `graph-algorithms.md` — `:digraph`/`:digraph_utils` patterns: topological sort, shortest path, cycle detection, dependency resolution
- `string-and-text.md` — Fuzzy matching (Levenshtein, Jaro-Winkler), full-text search (tsvector, pg_trgm), autocomplete
- `concurrent-data-structures.md` — CAS with `:atomics`, lock-free patterns, ETS concurrency, `:counters` write_concurrency
- `spatial.md` — PostGIS (ST_DWithin, ST_Contains), geohashing, Haversine distance
- `interval-and-range.md` — Postgres range types, overlap detection, exclusion constraints, scheduling
- `streaming-algorithms.md` — Sliding windows, EMA, reservoir sampling, streaming percentiles
- `optimization.md` — Dynamic programming, greedy, constraint satisfaction, gradient descent (Nx), simulated annealing, linear programming, when to push to Postgres
- `statistics.md` — Descriptive stats (Postgres and Elixir), anomaly detection (Z-score, IQR), A/B testing, Explorer DataFrames, histograms, correlation
- `compression.md` — `:zlib`, Zstd, LZ4, `:erlang.term_to_binary` compressed option
- `probabilistic.md` — HyperLogLog, Cuckoo filters, Count-Min Sketch, Bloom filters
- `hash-functions.md` — xxHash3, BLAKE3, HighwayHash selection guide
- `sorting-and-search.md` — Cache-efficient sorting, BlockQuicksort, pdqsort, B+ trees

## Commands

- **`/algorithm-research`** — Deep research with academic paper citations
- **`/benchmark`** — Create Benchee benchmarks to compare data structure alternatives

## Related Skills

- **performance-analyzer**: Profiling, benchmarking, latency analysis
- **distributed-systems**: Consensus and replication algorithms
- **elixir-patterns**: OTP process patterns, ETS usage

Use the **algorithms-researcher** agent for deep research with paper citations.

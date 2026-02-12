---
name: algorithms
description: Use when choosing data structures, evaluating hash functions, needing probabilistic data structures, or comparing OTP built-ins against specialized alternatives for Elixir
---

# Modern Algorithms and Data Structures

## Overview

Use OTP built-ins first. Escalate to specialized structures only when profiling shows a bottleneck. For most Elixir applications, Map, MapSet, List, and the OTP modules cover 95% of needs.

## Data Structure Decision

| Problem | First Choice | Specialized Alternative | Switch When |
|---------|-------------|------------------------|-------------|
| Key-value store | Map | `:gb_trees` | Need ordered traversal or range queries |
| Unique collection | MapSet | `:gb_sets` | Need sorted set operations |
| FIFO buffer | `:queue` | — | Always use `:queue`, not list ++ |
| Concurrent counter | `:atomics` | — | Always, not GenServer |
| Unique count (large) | HyperLogLog | MapSet | >100K items, ±2% OK |
| Set membership (large) | Cuckoo Filter | MapSet | >1M items, need deletion |
| Frequency tracking | Count-Min Sketch | Map | Millions of items |
| Non-crypto hash | xxHash3 | `:erlang.phash2` | Performance critical |
| Crypto hash | BLAKE3 | SHA-256 | Performance critical |
| Graph algorithms | `:digraph` | — | Always use OTP built-in |
| Priority queue | `heap` library | Sorted list | >100 elements |

## Common Mistakes

- **Lists as queues**: `queue ++ [item]` is O(n); use `:queue` for O(1)
- **GenServer as counter**: Serializes all updates; use `:atomics` or `:counters`
- **MD5/SHA1 for non-crypto**: 60× slower than xxHash3 for checksums and hash tables
- **Exact counting for analytics**: HyperLogLog uses 16 KB where MapSet uses 800 MB (100M items)
- **Bloom filters when needing deletion**: Use Cuckoo filters instead

## Reference Files

- `otp-builtins.md` — `:queue`, `:gb_trees`, `:gb_sets`, `:atomics`, `:counters`, `:array`, Okasaki structures
- `probabilistic.md` — HyperLogLog, Cuckoo filters, Count-Min Sketch, Bloom filters
- `hash-functions.md` — xxHash3, BLAKE3, HighwayHash selection guide
- `sorting-and-search.md` — Cache-efficient sorting, BlockQuicksort, pdqsort, B+ trees

## Related Skills

- **performance-analyzer**: Profiling, benchmarking, latency analysis
- **distributed-systems**: Consensus and replication algorithms
- **elixir-patterns**: OTP process patterns, ETS usage

Use the **algorithms-researcher** agent for deep research with paper citations.

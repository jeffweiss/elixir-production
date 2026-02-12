---
name: distributed-systems
description: Use when building multi-node Elixir systems, choosing between Raft and CRDTs, configuring libcluster or Partisan, debugging split-brain or netsplit scenarios, or evaluating CP vs AP tradeoffs
---

# Distributed Systems Patterns

## Overview

Don't distribute unless you must. When you must, choose the lowest escalation level that meets requirements. Each level adds complexity, failure modes, and operational burden — only escalate when you've outgrown the current level.

## Escalation Decision

```
Single node handles the load?
  YES → Level 0 (don't distribute)
  NO  → Do you need shared state across nodes?
          NO  → Level 1 (stateless multi-node)
          YES → Is eventual consistency acceptable?
                  YES → Is it just presence/registry?
                          YES → Level 2 (lightweight)
                          NO  → Level 4 (CRDTs)
                  NO  → Level 3 (Raft consensus)
                         Cluster > 50 nodes? → Level 5
```

See `escalation-ladder.md` for full details on each level with code examples and migration triggers.

## Quick Reference

| Problem | Pattern | Tool/Library |
|---------|---------|--------------|
| Large clusters (>50 nodes) | Partisan overlay network | partisan |
| Strong consistency | Raft consensus | :ra, raft |
| Eventual consistency | CRDTs | delta_crdt, lasp |
| Leader election | Consensus or external coordinator | :ra, etcd |
| Service discovery | DNS, Consul, K8s | libcluster |
| Distributed state sync | PubSub | Phoenix.PubSub |
| Presence tracking | CRDT-based tracker | Phoenix.Tracker |
| Clock synchronization | Hybrid Logical Clocks | hlclock |
| Ephemeral distributed KV | LWW Registers + HLC | groot |
| Feature flags (distributed) | LWW Registers + HLC | rollout |
| Split-brain prevention | Quorum + fencing | :ra, external coordinator |
| Causal ordering | Vector clocks | hlclock (HLC) or manual (vector clocks) |
| Partition testing | Cookie-based node isolation | schism |

## Common Mistakes

- **Distributing too early**: Most Elixir apps never need distribution. A single BEAM node handles millions of processes. Start at Level 0.
- **Choosing Raft when CRDTs suffice**: If eventual consistency is acceptable (shopping carts, presence, likes), CRDTs avoid all consensus complexity.
- **Ignoring asymmetric partitions**: Most test tools simulate symmetric partitions. Real networks also produce one-way failures that violate Raft assumptions.
- **Single Global Process**: Using a GenServer as a global cache works on one node but becomes a bottleneck and single point of failure on a cluster.
- **Trusting CP/AP labels**: Many systems are neither strictly CP nor AP. Verify actual guarantees, don't trust vendor marketing.

## Reference Files

- `escalation-ladder.md` — Full Distribution Escalation Ladder (Levels 0-5) with code examples
- `consensus.md` — Raft via `:ra`, CRDTs via `delta_crdt`, Multi-Raft, Vector Clocks, Paxos
- `clustering.md` — Distributed Erlang, Partisan, libcluster configs, PubSub, debugging patterns
- `failure-modes.md` — Split-brain, fencing tokens, clock drift, gray failures, metastable failures, limplocks, concurrency bugs, race conditions, blast radius, redundancy conditions
- `cap-tradeoffs.md` — CAP theorem critique, fundamental limits, consistency models, when to use which approach
- `production-checklist.md` — 20-item deployment checklist
- `resilience-principles.md` — Architectural principles from Hebert, Brooker, Luu, Kleppmann, Cook et al.

## Related Skills

- **elixir-patterns**: GenServer, Supervisor, OTP patterns, overload management
- **production-quality**: Monitoring, observability, error handling
- **phoenix-liveview**: Phoenix.PubSub, Phoenix.Tracker

Use the **distributed-systems-expert** agent for deep analysis of distributed architectures, consensus algorithm selection, and distributed bug investigation.

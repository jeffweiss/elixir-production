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

## Quick Decision

```
Need exactly-one process across cluster?  → leader-election.md
Need multi-service transactions?          → distributed-transactions.md
Need to partition data across nodes?      → consistent-hashing.md
Need audit trail / event replay?          → event-sourcing.md
Need strong consistency?                  → consensus.md (Raft)
Need eventual consistency?                → consensus.md (CRDTs)
Need cluster membership / discovery?      → clustering.md, gossip-protocols.md
Need to understand failure modes?         → failure-modes.md
Preparing for production deployment?      → production-checklist.md
```

## Common Mistakes

- **Distributing too early**: A single BEAM node handles millions of processes. Start at Level 0.
- **Choosing Raft when CRDTs suffice**: If eventual consistency is acceptable, CRDTs avoid all consensus complexity.
- **Ignoring asymmetric partitions**: Real networks produce one-way failures that violate Raft assumptions.
- **Single Global Process**: GenServer-as-cache becomes a bottleneck and SPOF on a cluster.
- **Trusting CP/AP labels**: Verify actual guarantees, don't trust vendor marketing.

## Reference Files

- `leader-election.md` — `:global`, `:pg`, Horde, Oban cron, singleton patterns, netsplit behavior for each approach
- `distributed-transactions.md` — Saga (choreography + orchestration), Oban workflows, compensating transactions, why not 2PC
- `gossip-protocols.md` — SWIM failure detection, epidemic broadcast, delta-CRDTs, HyParView/Partisan
- `consistent-hashing.md` — Ring hashing, jump consistent hash, virtual nodes, sharded ETS, Broadway partitioning
- `event-sourcing.md` — Event sourcing, CQRS, Commanded patterns, projections, when to use vs CRUD
- `escalation-ladder.md` — Full Distribution Escalation Ladder (Levels 0-5) with code examples
- `consensus.md` — Raft via `:ra`, CRDTs via `delta_crdt`, Multi-Raft, Vector Clocks, Paxos
- `clustering.md` — Distributed Erlang, Partisan, libcluster configs, PubSub, debugging patterns
- `failure-modes.md` — Split-brain, fencing tokens, clock drift, gray failures, metastable failures, limplocks, concurrency bugs, blast radius
- `cap-tradeoffs.md` — CAP theorem critique, fundamental limits, consistency models
- `production-checklist.md` — 20-item deployment checklist
- `resilience-principles.md` — Architectural principles from Hebert, Brooker, Luu, Kleppmann, Cook et al.

## Commands

- **`/distributed-review`** — Deep analysis of distributed architecture and failure modes
- **`/feature <desc>`** — Guided implementation with distribution-aware design

## Related Skills

- **elixir-patterns**: GenServer, Supervisor, OTP patterns, overload management
- **production-quality**: Monitoring, observability, error handling
- **phoenix-liveview**: Phoenix.PubSub, Phoenix.Tracker

Use the **distributed-systems-expert** agent for deep analysis of distributed architectures, consensus algorithm selection, and distributed bug investigation.

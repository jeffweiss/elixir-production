---
name: distributed-systems
description: Use when working with distributed systems, clustering, consensus algorithms, network partitions, CAP tradeoffs, or distributed Erlang/Elixir patterns
---

# Distributed Systems Patterns

## Overview

This skill covers distributed systems design, consensus algorithms, clustering strategies, and common distributed bugs in Elixir/Erlang systems.

## When to Use

Use this skill when:
- Designing distributed systems architecture
- Evaluating consensus algorithms (Paxos, Raft, Multi-Raft)
- Planning clustering strategies
- Debugging distributed system issues
- Analyzing CAP tradeoffs
- Working with Distributed Erlang or Partisan

## Core Concepts

### Distributed Erlang Limitations

- **Full-mesh topology**: Breaks down at ~50-100 nodes
- **Network overhead**: O(n²) connections
- **Solution**: Partisan for large-scale clustering

### Consensus Algorithms

- **Paxos**: Classic but complex
- **Raft**: Understandable consensus
- **Multi-Raft with Leader Leases**: High-performance variant

### Common Distributed Bugs

- **Split-brain**: Network partition creates multiple leaders
- **Clock drift**: Time synchronization issues
- **Quorum errors**: Incorrect quorum calculations
- **Race conditions**: Distributed state updates

## Quick Reference

| Problem | Pattern | Tool/Library |
|---------|---------|--------------|
| Large clusters | Partisan overlay network | partisan |
| Consensus | Raft implementation | ra, raft |
| Conflict resolution | CRDTs | lasp, delta_crdt |
| Leader election | Distributed locks | libcluster |

## CAP Theorem

**Consistency + Availability + Partition Tolerance** - Pick 2:
- CA: Traditional RDBMS (no partition tolerance)
- CP: Prioritize consistency (Raft, Paxos)
- AP: Prioritize availability (CRDTs, eventual consistency)

Use the `distributed-systems-expert` agent for deep analysis of distributed architectures.

[Content will be expanded with full details - this stub enables plugin loading]

# Distribution Escalation Ladder

Start at the top. Only move down when you've outgrown the current level.

## Level 0: Don't Distribute

| Need | Single-Node Solution | Why Stay Here |
|------|---------------------|---------------|
| Shared state between processes | ETS, `:persistent_term`, GenServer | Zero network complexity; BEAM handles millions of processes on one node |
| Background jobs | Oban (with PostgreSQL) | Persistence + retries without distributed coordination |
| Pub/Sub within one node | `Registry` with `:duplicate` keys | No network, no partition risk |
| Caching | ETS, Cachex, ConCache | Local cache is always faster than distributed cache |

**Move to Level 1 when**: You need horizontal scaling for load, or fault tolerance across machines.

## Level 1: Stateless Multi-Node (Shared-Nothing)

| Need | Solution | OTP/Library |
|------|----------|-------------|
| Cluster formation | Auto-discovery | `libcluster` (DNS, K8s, Gossip) |
| Load distribution | Stateless request routing | Load balancer + multiple nodes |
| Shared database | PostgreSQL with connection pooling | Ecto + single writer |
| Broadcast events | PubSub across nodes | `Phoenix.PubSub` (uses `:pg` or Redis) |
| Session state | Database-backed or signed tokens | Ecto or Phoenix.Token |

```elixir
# libcluster — nodes find each other automatically
config :libcluster,
  topologies: [
    k8s: [
      strategy: Cluster.Strategy.Kubernetes,
      config: [mode: :dns, kubernetes_node_basename: "myapp"]
    ]
  ]

# Phoenix.PubSub — broadcast across all nodes, no coordination
Phoenix.PubSub.broadcast(MyApp.PubSub, "orders:new", {:new_order, order})
```

**Move to Level 2 when**: You need presence tracking, distributed process registry, or state that must live across nodes.

## Level 2: Lightweight Distributed State

| Need | Solution | OTP/Library |
|------|----------|-------------|
| User presence / "who's online" | CRDT-based presence | `Phoenix.Presence` (wraps `Phoenix.Tracker`) |
| Distributed process registry | Process groups | `:pg` (OTP 23+, replaces `:pg2`) |
| Cluster-wide process lookup | Registry across nodes | `Horde.Registry` or `Swarm` |
| Cluster-wide dynamic supervisors | Distributed supervisor | `Horde.DynamicSupervisor` |
| Cache invalidation across nodes | PubSub + local cache | `Phoenix.PubSub` broadcast → local ETS delete |

```elixir
# :pg — built-in OTP process groups (no deps)
:pg.join(:my_group, self())
members = :pg.get_members(:my_group)

# Horde — distribute processes across cluster
{:ok, _} = Horde.DynamicSupervisor.start_child(
  MyApp.DistributedSupervisor,
  {MyWorker, [id: "user:123"]}
)
```

**Move to Level 3 when**: You need strong consistency guarantees, distributed transactions, or leader election.

## Level 3: Consensus and Strong Consistency (CP)

| Need | Solution | OTP/Library |
|------|----------|-------------|
| Leader election | Raft consensus | `:ra` (RabbitMQ's Raft) |
| Replicated state machine | Log-based replication | `:ra` |
| Distributed locks | Consensus-based locking | `:ra`, or external (etcd, Consul) |
| Exactly-once processing | Idempotency + consensus | `:ra` + application-level dedup |
| Distributed transactions | Saga pattern or 2PC | Application-level orchestration |

**Tradeoff**: During network partitions, minority partition becomes **unavailable**. You accept downtime for correctness.

**Move to Level 4 when**: You need availability during partitions, or strong consistency is too costly for your use case.

## Level 4: Eventual Consistency (AP)

| Need | Solution | OTP/Library |
|------|----------|-------------|
| Counters that survive partitions | PN-Counters | `delta_crdt` |
| Distributed key-value | Add-wins LWW Map | `delta_crdt` (AWLWWMap) |
| Set membership across partitions | Observed-Remove Set | `delta_crdt` (ORSet) |
| Conflict resolution | CRDTs (automatic) or app-level merge | `delta_crdt`, `lasp` |
| Causal ordering of events | Vector clocks or HLCs | Manual implementation |

**Tradeoff**: All nodes stay **available** during partitions, but may temporarily serve stale data. Conflicts resolve automatically (CRDTs) or require application-level merge logic.

## Level 5: Large-Scale / Multi-Datacenter

| Need | Solution | OTP/Library |
|------|----------|-------------|
| >50 node clusters | Overlay network topology | `partisan` (HyParView) |
| Sharded consensus | Multi-Raft groups | Custom on `:ra` |
| Low-latency reads across regions | Leader leases | Custom (clock-bound wait) |
| Geo-distributed data | AP with per-region leaders | CRDTs + region-aware routing |
| Cross-datacenter replication | Async replication + conflict resolution | Application-specific |

**Tradeoff**: Significant operational complexity. Only justified at genuine scale (hundreds of nodes, multiple datacenters).

## Escalation Decision Flowchart

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

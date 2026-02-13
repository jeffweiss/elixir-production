# Gossip Protocols

Gossip (epidemic) protocols disseminate information through random peer-to-peer exchanges. They trade consistency for scalability — information eventually reaches all nodes without centralized coordination.

## Decision Table

| Need | Protocol | Tool | Use When |
|------|----------|------|----------|
| Cluster membership | SWIM | `libcluster` (gossip strategy) | Auto-discovery in dynamic clusters |
| Failure detection | SWIM (suspicion) | Distributed Erlang (built-in) | Detecting crashed/partitioned nodes |
| State dissemination | Gossip + CRDTs | Phoenix.Tracker, `delta_crdt` | Distributing state without consensus |
| Scalable membership | HyParView | Partisan | Large clusters (>50 nodes) |

## How Gossip Works

Every interval, each node:
1. **Selects** a random peer
2. **Exchanges** state with that peer (push, pull, or push-pull)
3. **Merges** received state with local state

Information spreads exponentially — like a rumor. With N nodes, gossip converges in O(log N) rounds.

```
Round 0: Node A has new info
Round 1: A tells B → 2 nodes know
Round 2: A tells C, B tells D → 4 nodes know
Round 3: → 8 nodes know
Round 4: → 16 nodes know
...
Round ~log2(N): All N nodes know
```

## SWIM: Scalable Failure Detection

SWIM (Scalable Weakly-consistent Infection-style Process Group Membership) is the standard for membership and failure detection in clusters.

### How SWIM Detects Failures

```
1. Node A pings Node B (direct probe)
2. If B responds → B is alive
3. If B doesn't respond within timeout:
   a. A asks k random nodes to ping B (indirect probe)
   b. If any indirect probe succeeds → B is alive
   c. If all indirect probes fail → B is suspected
4. After suspicion timeout with no defense → B is declared dead
```

**Why indirect probing matters**: Direct probe failure might be a network issue between A and B specifically, not B being down. Indirect probes through other nodes distinguish "B is down" from "A can't reach B."

### SWIM in Elixir Ecosystem

- **Distributed Erlang**: Uses its own heartbeat-based failure detection (not SWIM, but similar intent). Configurable via `net_kernel` settings.
- **libcluster Gossip strategy**: Uses gossip for node discovery (not SWIM directly, but gossip-based).
- **Partisan**: Implements HyParView — a gossip-based partial-view membership protocol designed for large clusters.

## Gossip-Based State Dissemination

### Phoenix.Tracker / Phoenix.Presence

Phoenix.Tracker uses a gossip-like protocol with CRDTs to track distributed state (user presence, online status):

```elixir
# Under the hood: each node maintains a CRDT of tracked presences
# Nodes periodically exchange deltas with random peers
# Conflicts resolved by CRDT merge rules (last-writer-wins with vector clocks)

# You use it through Phoenix.Presence:
defmodule MyAppWeb.Presence do
  use Phoenix.Presence,
    otp_app: :my_app,
    pubsub_server: MyApp.PubSub
end
```

### Delta-CRDTs for Efficient Gossip

Full state exchange is expensive. Delta-CRDTs only send changes since last sync:

```elixir
# {:delta_crdt, "~> 0.6"}
# Each node maintains a CRDT, syncs deltas with peers via gossip
{:ok, crdt} = DeltaCrdt.start_link(DeltaCrdt.AWLWWMap,
  sync_interval: 100  # ms between gossip rounds
)

# Local writes are instant
DeltaCrdt.put(crdt, "key", "value")

# Reads reflect local state (may lag behind other nodes briefly)
DeltaCrdt.get(crdt, "key")
```

## Gossip Protocol Properties

| Property | Guarantee |
|----------|-----------|
| Delivery | Probabilistic — converges with high probability, not certainty |
| Latency | O(log N) rounds for N nodes |
| Bandwidth | O(N) per round (each node contacts one peer) |
| Fault tolerance | Tolerates up to N/2 failures — gossip routes around dead nodes |
| Consistency | Eventual — nodes may see different state briefly |
| Scalability | Excellent — no central coordinator, constant per-node cost |

## HyParView (Partisan)

For clusters larger than ~50 nodes, Distributed Erlang's full-mesh becomes expensive (O(n²) connections). HyParView maintains a partial view:

- **Active view**: Small set of peers for direct communication (typically 5-7)
- **Passive view**: Larger set of known nodes for recovery (typically 30)
- **Shuffle protocol**: Periodically exchanges passive view entries with random peers

```elixir
# Partisan replaces Distributed Erlang with HyParView
# In config:
config :partisan,
  peer_service: :partisan_hyparview_peer_service,
  fanout: 5,
  active_max_size: 6,
  passive_max_size: 30
```

## Common Mistakes

- **Expecting immediate consistency from gossip**: Gossip is eventually consistent. If you need "all nodes see X before Y happens," use consensus (Raft), not gossip.
- **Not tuning gossip interval**: Too frequent → bandwidth waste. Too infrequent → slow convergence. Start with 100-200ms for state sync, 1-5s for failure detection.
- **Full state exchange at scale**: Sending full state every round is O(state_size × N) bandwidth. Use delta-CRDTs or Merkle trees for efficient reconciliation.
- **Using Distributed Erlang full-mesh beyond 50 nodes**: Connection overhead grows quadratically. Switch to Partisan for large clusters.
- **Relying on gossip for critical coordination**: Gossip is for dissemination, not coordination. For leader election or transactions, use consensus protocols.

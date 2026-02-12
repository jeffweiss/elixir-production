# Consensus Algorithms and Data Types

## Paxos

**Properties**:
- Classic consensus algorithm (Leslie Lamport, 1989)
- Provably correct
- Notoriously difficult to understand and implement
- Requires majority quorum (⌊n/2⌋ + 1)

**Phases**:
1. Prepare: Proposer sends proposal number
2. Promise: Acceptors promise not to accept lower proposals
3. Accept: Proposer sends value
4. Accepted: Acceptors record accepted value

**In Elixir**:
- Rarely implemented directly (complexity)
- Use Raft instead for most use cases

## Raft

**Properties**:
- Designed for understandability (Diego Ongaro, 2014)
- Leader-based consensus
- Log replication
- Strong consistency guarantees
- Requires majority quorum

**Key components**:
```elixir
# Using :ra (RabbitMQ's Raft implementation)
defmodule MyStateMachine do
  @behaviour :ra_machine

  def init(_config), do: %{}

  def apply(_meta, {:set, key, value}, state) do
    {state, Map.put(state, key, value), :ok}
  end

  def apply(_meta, {:get, key}, state) do
    {state, Map.get(state, key), {:ok, Map.get(state, key)}}
  end
end

# Start Raft cluster
:ra.start_cluster(
  :my_cluster,
  {:module, MyStateMachine, %{}},
  [
    {:"node1@host", :ra_node_id},
    {:"node2@host", :ra_node_id},
    {:"node3@host", :ra_node_id}
  ]
)

# Submit command
:ra.process_command({:my_cluster, node()}, {:set, :key, :value})
```

**When to use Raft**:
- Need strong consistency (CP)
- Leader election
- Replicated state machines
- Configuration management
- Distributed locks

**Libraries**:
- `:ra` - Production-grade (RabbitMQ)
- `raft` - Pure Elixir implementation

**`:ra` hardening configuration**:
```elixir
# Enable pre-vote to prevent spurious elections during asymmetric partitions.
# Without pre-vote, a node that can't receive heartbeats will start elections
# and force the healthy leader to step down.
config :ra,
  pre_vote: true

# Tune timeouts for your network characteristics
# election_timeout: too short → spurious elections; too long → slow failover
# heartbeat_interval: should be ~1/3 of election_timeout
```

**Leader step-down check** — a leader must confirm it can reach a majority, not just send heartbeats:
```elixir
defmodule LeaderHealthCheck do
  @doc """
  Verify the leader can both send AND receive from a majority.
  A leader that can send heartbeats but not receive acks
  should step down — it may be in an asymmetric partition.
  """
  def should_step_down?(follower_acks, cluster_size, heartbeat_timeout) do
    now = System.monotonic_time(:millisecond)
    quorum = div(cluster_size, 2) + 1

    recent_acks =
      Enum.count(follower_acks, fn {_node, last_ack} ->
        now - last_ack < heartbeat_timeout
      end)

    # +1 counts the leader itself
    recent_acks + 1 < quorum
  end
end
```

## Multi-Raft with Leader Leases

**Advanced pattern** used by CockroachDB, TiKV:

**Key optimizations**:
- Multiple Raft groups for sharding
- Leader leases reduce read latency
- Lease-based reads (no quorum check)
- Clock-bound wait (Google Spanner style)

**Concept**:
```elixir
# Multiple Raft groups (sharding)
# Group 1: Handles keys "a-m"
# Group 2: Handles keys "n-z"

# Leader lease optimization
defmodule RaftLeader do
  # Leader holds lease for 10 seconds
  @lease_duration 10_000

  def read_with_lease(state) do
    if lease_valid?(state.lease) do
      # Fast read: No quorum needed
      {:ok, state.data}
    else
      # Fallback: Quorum read
      quorum_read(state)
    end
  end

  defp lease_valid?(lease) do
    System.monotonic_time(:millisecond) < lease.expiry
  end
end
```

**Benefits**:
- 10x faster reads (no quorum)
- Better scalability (sharding)
- Maintains strong consistency

**Tradeoffs**:
- Clock drift sensitivity
- Increased complexity
- Lease management overhead

## Conflict-Free Replicated Data Types (CRDTs)

**For AP systems** - Automatic conflict resolution:

**Key CRDT types**:
```elixir
# G-Counter: Grow-only counter
{:ok, counter} = DeltaCrdt.start_link(DeltaCrdt.GCounter)
DeltaCrdt.mutate(counter, :increment)

# PN-Counter: Increment/decrement counter
{:ok, counter} = DeltaCrdt.start_link(DeltaCrdt.PNCounter)
DeltaCrdt.mutate(counter, :increment)
DeltaCrdt.mutate(counter, :decrement)

# AWLWWMap: Add-wins, Last-write-wins map
{:ok, map} = DeltaCrdt.start_link(DeltaCrdt.AWLWWMap)
DeltaCrdt.mutate(map, :add, ["key", "value"])
DeltaCrdt.mutate(map, :remove, ["key"])

# OR-Set: Observed-remove set
{:ok, set} = DeltaCrdt.start_link(DeltaCrdt.ORSet)
DeltaCrdt.mutate(set, :add, ["element"])
DeltaCrdt.mutate(set, :remove, ["element"])
```

**When to use CRDTs**:
- Eventually consistent systems (AP)
- Offline-first applications
- Collaborative editing
- Shopping carts
- Presence tracking
- Like/favorite counts

**Libraries**:
- `delta_crdt` - Production-ready
- `lasp` - Research-grade, advanced

## Vector Clocks

**For causal consistency** - Track causality between events:

```elixir
defmodule VectorClock do
  def new, do: %{}

  def increment(clock, node) do
    Map.update(clock, node, 1, &(&1 + 1))
  end

  def merge(clock1, clock2) do
    Map.merge(clock1, clock2, fn _k, v1, v2 -> max(v1, v2) end)
  end

  # Returns :concurrent, :before, or :after
  def compare(clock1, clock2) do
    cond do
      descends?(clock1, clock2) -> :after
      descends?(clock2, clock1) -> :before
      true -> :concurrent
    end
  end

  defp descends?(clock1, clock2) do
    Enum.all?(clock2, fn {node, count} ->
      Map.get(clock1, node, 0) >= count
    end) and clock1 != clock2
  end
end

# Usage in distributed system
defmodule DistributedCache do
  def put(key, value, clock) do
    new_clock = VectorClock.increment(clock, node())
    # Store {value, new_clock}
    {:ok, new_clock}
  end

  def resolve_conflict(values_with_clocks) do
    # Keep all concurrent values, discard causally dominated
    Enum.reject(values_with_clocks, fn {_v1, c1} ->
      Enum.any?(values_with_clocks, fn {_v2, c2} ->
        VectorClock.compare(c1, c2) == :before
      end)
    end)
  end
end
```

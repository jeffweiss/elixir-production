# Distributed Failure Modes

## Split-Brain Scenario

**Problem**: Network partition creates multiple leaders

**Example**:
```elixir
# Before partition: Single leader
# [Node1 (Leader)] <-> [Node2] <-> [Node3]

# After partition: TWO leaders!
# [Node1 (Leader)] <-> [Node2]  |  [Node3 (Leader)]
```

**Prevention strategies**:

**1. Quorum-based consensus (CP approach)**:
```elixir
# Raft: Requires majority
# 5 nodes: Need 3 for quorum
# After split: 3-node partition has leader, 2-node cannot elect

defmodule QuorumCheck do
  def has_quorum?(cluster_size, reachable_nodes) do
    reachable_nodes >= div(cluster_size, 2) + 1
  end
end
```

**2. Fencing tokens** (Kleppmann, "How to do distributed locking"):

Distributed locks have two fundamentally different uses:
- **Efficiency locks**: Prevent redundant work (duplicate emails, repeated computations). Occasional failure costs money, not correctness — a single-node Redis lock suffices.
- **Correctness locks**: Prevent data corruption. Failure means inconsistency or data loss. These *require* fencing tokens backed by consensus.

The danger: a client acquires a lock, pauses (GC, network delay), the lock expires, another client acquires it, then the first client resumes and writes — believing it still holds the lock. Fencing tokens prevent this because the storage layer rejects writes with stale tokens.

**Warning**: Any locking algorithm that depends on timing assumptions (bounded network delays, bounded clock drift, bounded GC pauses) is unsafe for correctness. Real networks violate these assumptions routinely — GitHub once experienced 90-second packet delays. Use consensus-backed locks (`:ra`, ZooKeeper, etcd) with fencing for correctness; use Redis for efficiency-only locks.

```elixir
defmodule LeaderFence do
  # Each leader gets monotonically increasing token
  def write_with_fence(resource, data, fence_token) do
    case Storage.conditional_write(resource, data, fence_token) do
      :ok -> :ok
      {:error, :stale_token} -> {:error, :not_leader}
    end
  end
end

# Storage layer rejects writes with old tokens
```

**3. External coordinator** (etcd, ZooKeeper, Consul):
```elixir
# Leader lease in etcd
defmodule LeaderElection do
  def acquire_leadership(node_id) do
    case Etcd.acquire_lease(node_id, ttl: 10) do
      {:ok, lease_id} ->
        # Periodically renew lease
        Process.send_after(self(), :renew_lease, 5_000)
        {:ok, lease_id}
      {:error, :already_held} ->
        {:error, :not_leader}
    end
  end
end
```

**Detection**:
```elixir
# Monitor for split-brain
defmodule SplitBrainDetector do
  def check_cluster_health do
    visible_nodes = [node() | Node.list()]
    expected_nodes = Application.get_env(:app, :cluster_nodes)

    if length(visible_nodes) < length(expected_nodes) / 2 do
      Logger.error("Possible split-brain: #{inspect(visible_nodes)}")
      trigger_alarm(:split_brain)
    end
  end
end
```

## Clock Drift Issues

**Problem**: Distributed clocks drift apart

**Impact**:
- Incorrect event ordering
- Lease expiry bugs
- Timestamp-based logic fails
- Data inconsistency

**Mitigation**:

**1. Use monotonic time for intervals**:
```elixir
# ❌ Wrong: System time changes (NTP adjustments)
start_time = System.system_time(:millisecond)
# ... work ...
elapsed = System.system_time(:millisecond) - start_time

# ✅ Correct: Monotonic time never goes backwards
start_time = System.monotonic_time(:millisecond)
# ... work ...
elapsed = System.monotonic_time(:millisecond) - start_time
```

**2. Hybrid Logical Clocks (HLC)**:
```elixir
defmodule HLC do
  # Combines physical time + logical counter
  defstruct [:physical_time, :logical_counter, :node_id]

  def new(node_id) do
    %HLC{
      physical_time: System.system_time(:millisecond),
      logical_counter: 0,
      node_id: node_id
    }
  end

  def send_event(clock) do
    physical = System.system_time(:millisecond)

    if physical > clock.physical_time do
      %{clock | physical_time: physical, logical_counter: 0}
    else
      %{clock | logical_counter: clock.logical_counter + 1}
    end
  end

  def receive_event(clock, remote_clock) do
    physical = System.system_time(:millisecond)
    max_physical = max(physical, max(clock.physical_time, remote_clock.physical_time))

    logical =
      if max_physical == clock.physical_time and max_physical == remote_clock.physical_time do
        max(clock.logical_counter, remote_clock.logical_counter) + 1
      else
        0
      end

    %{clock | physical_time: max_physical, logical_counter: logical}
  end
end
```

**3. NTP monitoring**:
```elixir
# Check clock skew
defmodule ClockMonitor do
  def check_ntp_offset do
    case System.cmd("ntpq", ["-c", "rv"]) do
      {output, 0} ->
        offset = parse_offset(output)
        if abs(offset) > 100 do # 100ms threshold
          Logger.error("Clock offset too high: #{offset}ms")
          trigger_alarm(:clock_skew)
        end
      _ ->
        Logger.error("Cannot check NTP")
    end
  end
end
```

## Quorum Calculation Errors

**Problem**: Incorrect quorum math

**Examples**:
```elixir
# ❌ Wrong: Even split isn't majority
quorum = div(cluster_size, 2)  # 5 nodes -> 2 (not majority!)

# ✅ Correct: Need more than half
quorum = div(cluster_size, 2) + 1  # 5 nodes -> 3

# Handle edge cases
defmodule Quorum do
  def required_nodes(cluster_size) when cluster_size > 0 do
    div(cluster_size, 2) + 1
  end

  def has_quorum?(cluster_size, available_nodes) do
    available_nodes >= required_nodes(cluster_size)
  end

  # Account for node failures
  def max_failures(cluster_size) do
    div(cluster_size - 1, 2)
  end
end

# Examples:
# 1 node: quorum=1, max_failures=0
# 3 nodes: quorum=2, max_failures=1
# 5 nodes: quorum=3, max_failures=2
# 7 nodes: quorum=4, max_failures=3
```

**Dynamic membership** adds complexity:
```elixir
# Reconfiguration must go through consensus
defmodule RaftReconfiguration do
  def add_node(cluster, new_node) do
    # Use joint consensus (C_old + C_new)
    :ra.add_member(cluster, new_node)
  end

  def remove_node(cluster, old_node) do
    :ra.remove_member(cluster, old_node)
  end
end
```

## Network Partition Handling

**Strategies**:

**1. Last-Write-Wins (LWW)**:
```elixir
# Simple but loses data
defmodule LWW do
  def resolve({value1, timestamp1}, {value2, timestamp2}) do
    if timestamp1 > timestamp2, do: value1, else: value2
  end
end
```

**2. Application-specific merge**:
```elixir
defmodule ShoppingCart do
  # Merge carts from both sides of partition
  def merge(cart1, cart2) do
    items1 = MapSet.new(cart1.items, fn item -> {item.product_id, item} end)
    items2 = MapSet.new(cart2.items, fn item -> {item.product_id, item} end)

    merged_items =
      MapSet.union(items1, items2)
      |> Enum.map(fn {_id, item} -> item end)

    %{cart1 | items: merged_items}
  end
end
```

**3. Read-repair**:
```elixir
defmodule ReadRepair do
  def get(key) do
    # Read from multiple nodes
    results = Enum.map(nodes(), fn node ->
      :rpc.call(node, Storage, :get, [key])
    end)

    # Find latest version
    {latest_value, latest_version} = find_latest(results)

    # Repair stale replicas
    Enum.each(results, fn {node, value, version} ->
      if version < latest_version do
        :rpc.cast(node, Storage, :put, [key, latest_value, latest_version])
      end
    end)

    latest_value
  end
end
```

## Asymmetric Network Partitions

**Problem**: Most partition testing assumes symmetric failure (A can't reach B, B can't reach A). Real networks also produce *asymmetric* partitions where A can send to B but B cannot respond — creating scenarios that violate Raft's typical assumptions.

**Why this is dangerous**: Erlang distribution has a binary view of connectivity (node is up or down) and assumes transitivity (if A↔B and B↔C then A↔C). Asymmetric partitions violate both assumptions.

**`:ra` specific scenario**:
```
Three-node :ra cluster [node1 (leader), node2, node3]

Asymmetric partition:
  node1 → node2: CAN send
  node2 → node1: CANNOT send
  node1 ↔ node3: bidirectional OK
  node2 ↔ node3: bidirectional OK

Result:
  - node1 sends heartbeats to node2 (delivered) and node3 (acked)
  - node2 never receives heartbeats (one-way loss), triggers election
  - node3 may vote for node2, creating a new leader in a higher term
  - node1 doesn't know it's been superseded until it tries to commit
  - Brief dual-leader window: committed entries are safe (Raft guarantees),
    but in-flight requests may timeout or be redirected
```

**Bidirectional connectivity probing** — don't rely on Erlang's `:nodeup`/`:nodedown`:
```elixir
defmodule BidirectionalProbe do
  @doc """
  Actively verify two-way connectivity. Erlang distribution may report
  a node as 'up' when only one direction works.
  """
  def check(remote_node, timeout \\ 2_000) do
    ref = make_ref()

    try do
      # Ask the remote node to call us back — confirms both directions
      case :rpc.call(remote_node, __MODULE__, :echo, [node(), ref], timeout) do
        {:echoed, ^ref} -> :bidirectional
        {:badrpc, _} -> :unreachable
      end
    catch
      :exit, _ -> :unreachable
    end
  end

  @doc "Called on remote node — proves it can reach us"
  def echo(caller_node, ref) do
    case :rpc.call(caller_node, Kernel, :node, [], 1_000) do
      ^caller_node -> {:echoed, ref}
      _ -> {:one_way_only, ref}
    end
  end
end
```

**Multi-level health checks** — check all three layers, not just Erlang distribution:
```elixir
defmodule ClusterHealth do
  def check(ra_server) do
    with :ok <- check_erlang_distribution(),
         :ok <- check_raft_consensus(ra_server),
         :ok <- check_application_liveness(ra_server) do
      :healthy
    end
  end

  defp check_erlang_distribution do
    expected = Application.get_env(:my_app, :cluster_nodes, [])
    missing = expected -- [node() | Node.list()]
    if missing == [], do: :ok, else: {:error, {:nodes_missing, missing}}
  end

  defp check_raft_consensus(ra_server) do
    # Submit a test command — confirms the cluster can make progress
    case :ra.process_command(ra_server, {:health_check, System.monotonic_time()}, 2_000) do
      {:ok, _, _} -> :ok
      {:timeout, _} -> {:error, :consensus_timeout}
      {:error, reason} -> {:error, {:consensus_error, reason}}
    end
  end

  defp check_application_liveness(ra_server) do
    # Verify the state machine is responsive, not just the Raft layer
    case :ra.leader_query(ra_server, fn state -> map_size(state) end, 2_000) do
      {:ok, {_, _}, _} -> :ok
      _ -> {:error, :state_machine_unresponsive}
    end
  end
end
```

**Monitoring for asymmetry** — frequent leader elections with all nodes "up" is the signature:
```elixir
# Attach to :ra telemetry events
:telemetry.attach_many(
  "ra-partition-detection",
  [
    [:ra, :server, :term_changed],
    [:ra, :server, :election_timeout],
    [:ra, :server, :command_timeout]
  ],
  fn event, measurements, metadata, _config ->
    Logger.warning("Raft event",
      event: event,
      term: metadata[:term],
      node: node(),
      visible_nodes: Node.list()
    )
  end,
  nil
)
# Alert pattern: frequent term changes + all nodes visible = asymmetric partition
```

**Testing asymmetric partitions**: Use `toxiproxy` or `iptables` rules that drop traffic in one direction only. Most network partition test tools (including Erlang's `:net_kernel.disconnect/1`) simulate symmetric partitions and will miss these bugs.

## Gray Failures

**Problem**: A component appears healthy to its own health checks but is failing from the perspective of its consumers. This *differential observability* makes gray failures the most dangerous class of distributed failure — they bypass all standard detection mechanisms (Huang et al., "Gray Failure: The Achilles Heel of Cloud-Scale Systems").

**Why this is dangerous in Elixir/OTP**: A GenServer may respond to `:ping` but silently drop or delay actual work requests. A database connection pool may report available connections while queries time out. A node may participate in `:pg` groups but not actually process messages.

**Common gray failure patterns**:
- **Partial network degradation**: 10% packet loss — health checks pass, real traffic fails
- **Resource exhaustion**: Process heap growing, GC pauses increasing — still "alive" but effectively stuck
- **Redundancy paradox**: With N dependencies, the probability of *at least one* being gray-failed approaches certainty at scale. More fan-out = more exposure to gray failures.

**Detection strategy — multi-perspective health**:
```elixir
defmodule GrayFailureDetector do
  @doc """
  Compare a service's self-reported health with its consumers' observed health.
  Divergence = gray failure.
  """
  def check(service) do
    self_health = service.health_check()
    consumer_signals = %{
      error_rate: Telemetry.rate([:service, :errors], :per_minute),
      p99_latency: Telemetry.percentile([:service, :latency], 99),
      timeout_rate: Telemetry.rate([:service, :timeouts], :per_minute)
    }

    case {self_health, consumer_signals} do
      {:healthy, %{error_rate: rate}} when rate > 0.01 ->
        {:gray_failure, :error_rate_divergence, consumer_signals}
      {:healthy, %{p99_latency: lat}} when lat > 5_000 ->
        {:gray_failure, :latency_divergence, consumer_signals}
      {:healthy, _} ->
        :healthy
      {:unhealthy, _} ->
        :unhealthy  # At least it's honest
    end
  end
end
```

**Mitigation**: Don't rely solely on self-reported health. Monitor the *relationship* between components, not just the components themselves.

## Metastable Failures

**Problem**: A trigger (traffic spike, deployment, brief failure) pushes the system into a bad state that **persists even after the trigger is removed**. The system is "up, but down" — high throughput but zero goodput because all responses arrive after clients have timed out (Bronson et al., "Metastable Failures in Distributed Systems"; Brooker, "Metastability and Distributed Systems").

**Why this is different from cascading failure**: Cascading failures spread to new components. Metastable failures are self-sustaining within the *same* components through feedback loops. Removing the trigger doesn't help — the system can't escape without manual intervention or load reduction below the recovery threshold.

**Sustaining feedback loops** (the real danger — not the trigger):
- **Retry amplification**: Requests time out → clients retry → server processes both original and retry → more timeouts → more retries
- **Cache stampede**: Cache eviction during overload → every request hits database → database slows → more cache misses
- **GC death spiral**: Large mailboxes → GC pauses → slower processing → larger mailboxes
- **Connection churn**: Timeouts → connection resets → TLS handshake storms → more timeouts

**In Elixir/OTP**: A GenServer with a growing mailbox is a classic metastable feedback loop. Messages arrive faster than they're processed → mailbox grows → GC pauses increase → processing slows further. The GenServer appears alive but delivers zero useful work. `Process.info(pid, :message_queue_len)` is your early warning signal.

**Mitigations**:
- **Fast error paths**: Rejecting a request must be cheaper than processing it. If error handling is slower than success handling (e.g., logging, retries, cleanup), overload will be self-reinforcing
- **Bound retry amplification**: Use token bucket retries (see elixir-patterns skill), not unbounded retries. Each successful response deposits 0.1 tokens; each retry costs 1 token
- **Monitor goodput, not throughput**: A system processing 10,000 req/s with 0% success rate is worse than one processing 1,000 req/s at 99% success. Alert on goodput decline, not just error rate increase
- **Load shedding at the edge**: Reject requests before they enter the processing pipeline. A 503 at the load balancer is better than a timeout deep in the call stack

## Limplocks — Degraded But Not Failed

**Problem**: A node or component slows dramatically but doesn't crash. Health checks pass (the node is "alive"), but it operates at 1/1000th of normal speed. Unlike total failures that trigger failover, limplocks poison the entire cluster through shared resources (Luu, "Slowlock").

**Why this is devastating**: One degraded Facebook node reduced cluster throughput from 172 jobs/hour to 1 job/hour — a 172x slowdown from a single node. Systems designed for binary fail/succeed have no mechanism to detect or eject degraded-but-alive nodes.

**In Elixir/OTP**: A GenServer with a growing mailbox (due to a slow dependency) is a limplock — it responds to health checks but processes work at a fraction of normal rate. Connection pools where one connection targets a slow database replica cause similar cascading slowdowns.

**Detection**: Monitor operation *throughput* and *latency percentiles*, not just availability. A node that passes pings but has p99 latency 100x normal is limplocked. Use the gray failure detection pattern (above) with latency thresholds, and eject nodes whose latency exceeds a multiple of the cluster median.

## Concurrency Bug Taxonomy

Research shows 97% of non-deadlock concurrency bugs fall into just two categories (Luu, "Notes on concurrency bugs"):

1. **Atomicity violations** (69%): A thread/process reads shared state, then acts on it, but another has modified it in between (check-then-act race)
2. **Ordering violations** (31%): Execution order assumptions are violated — operation B runs before operation A completes

In distributed systems specifically:
- 64% of bugs are triggered by a **single message** arriving at an unexpected time
- 96% of bugs are reproducible by controlling the ordering of just **2 concurrent operations**
- 47% of distributed bugs create **latent failures** — the system appears healthy but has silently corrupted state

**Implication for testing**: Focus distributed tests on two-event orderings and single-message-timing scenarios. You don't need to simulate complex multi-node chaos — most bugs hide in simple two-operation races.

## Race Conditions in Distributed State

**Problem**: Concurrent updates from different nodes

**Example**:
```elixir
# Two nodes decrement counter simultaneously
# Node1: read=10, write=9
# Node2: read=10, write=9
# Expected: 8, Actual: 9 (lost update!)
```

**Solution 1: Optimistic locking**:
```elixir
defmodule OptimisticLock do
  def update(key, update_fn) do
    case Storage.get_with_version(key) do
      {:ok, value, version} ->
        new_value = update_fn.(value)
        case Storage.put_if_version(key, new_value, version) do
          :ok -> {:ok, new_value}
          {:error, :version_mismatch} ->
            # Retry
            update(key, update_fn)
        end
      {:error, :not_found} ->
        {:error, :not_found}
    end
  end
end
```

**Solution 2: CRDTs**:
```elixir
# PN-Counter handles concurrent decrements correctly
{:ok, counter} = DeltaCrdt.start_link(DeltaCrdt.PNCounter)

# Node1 and Node2 can both decrement
DeltaCrdt.mutate(counter, :decrement)

# CRDTs merge automatically
```

**Solution 3: Serialization via consensus**:
```elixir
# All updates go through Raft leader
:ra.process_command({:my_cluster, node()}, {:decrement, :counter})
```

## Blast Radius Reduction (Cell-Based Architecture)

The most effective distributed architecture strategy is limiting the damage any single failure can cause. Instead of one monolithic service with shared state, partition into independent *cells* — each serving a subset of users or keys, failing independently (Brooker et al., "Millions of Tiny Databases" — AWS Physalia).

**Core principles**:
- **Smaller blast radius > better availability**: A cell serving 1% of traffic that goes down is a 1% outage, not a 100% outage
- **Independent failure domains**: Cells share no state, no connections, no coordinators. One cell's failure cannot cascade to another
- **Deployment segregation via "colors"**: Deploy updates to one color (cell group) at a time. Bad deploys affect one color, not the whole fleet

**Applying this in Elixir/OTP**:
```elixir
# Cell-per-tenant with supervision isolation
defmodule MyApp.CellSupervisor do
  use DynamicSupervisor

  def start_cell(tenant_id) do
    # Each tenant gets its own supervision tree — isolated failure domain
    DynamicSupervisor.start_child(__MODULE__, {
      MyApp.TenantCell, tenant_id: tenant_id
    })
  end
end

defmodule MyApp.TenantCell do
  use Supervisor

  def start_link(opts) do
    tenant_id = Keyword.fetch!(opts, :tenant_id)
    Supervisor.start_link(__MODULE__, tenant_id, name: via(tenant_id))
  end

  def init(tenant_id) do
    children = [
      {MyApp.TenantCache, tenant_id},
      {MyApp.TenantWorker, tenant_id}
    ]
    # max_restarts scoped to THIS tenant only
    Supervisor.init(children, strategy: :one_for_all)
  end
end
```

**When to apply**: Any system where a shared resource (pool, GenServer, ETS table, Raft cluster) serves all tenants. Partition it so one tenant's thundering herd doesn't take down another's service.

## Redundancy Conditions

Redundancy improves availability **only** when four conditions are met (Brooker, "When Redundancy Actually Helps", "Redundant against what?"):

1. **Complexity doesn't exceed benefit**: Added redundancy introduces operational and understanding risks. If operators can't reason about the redundant system, it's net-negative
2. **System works in degraded mode**: Cold caches, empty buffers, unwarmed connections — failover to a cold standby often fails in ways that weren't tested
3. **Health detection is reliable**: Different nodes in different parts of the network routinely disagree on health. Incorrect failure detection causes worse outcomes than no detection
4. **Return to full redundancy is automated**: Single-use redundancy (one failover, no recovery) provides negligible long-term availability improvement

**Data loss probability increases with cluster size** (Kleppmann, "The probability of data loss in large clusters"): Counter-intuitively, larger clusters have *higher* probability of losing at least one partition's data, even with 3x replication. In an 8,000-node cluster with 0.1% daily node failure probability and 256 partitions per node, the annual probability of permanent data loss (~all 3 replicas of some partition failing simultaneously) reaches ~60%. The math: more partitions means more "lottery tickets" for the unlucky combination. Increasing replication factor or reducing partitions per node helps, but the fundamental scaling behavior is inescapable. For critical data at scale, complement replication with independent backup mechanisms.

**The poison pill problem**: When a malformed event reaches a replicated state machine, all replicas fail identically — "running the same deterministic software on the same state produces the same bad outcome every time." This affects Raft clusters, primary/backup systems, and any architecture where replicas share logic and state. Defend against it with input validation at system boundaries and non-deterministic jitter in retry/recovery paths.

---
description: Analyze distributed system design and correctness
argument-hint: [module-or-feature]
allowed-tools: [Task, Read, Glob, Grep, Edit, TodoWrite]
model: opus
---

# Distributed Review Command

Comprehensive review of distributed system architecture, consensus algorithms, clustering strategy, and potential distributed bugs. Launches the **distributed-systems-expert** agent (Opus) for deep analysis.

## What It Does

Analyzes distributed system design and implementation:

1. **Architecture Review** - Clustering strategy, consistency model, scale assessment
2. **Consensus Analysis** - Algorithm choice evaluation (Raft, CRDTs, etc.)
3. **Bug Detection** - Split-brain risks, quorum errors, clock drift issues
4. **CAP Tradeoffs** - Consistency vs availability analysis
5. **Network Partition Handling** - Merge strategies, conflict resolution
6. **Recommendations** - Specific improvements with rationale

## Usage

```bash
# Review entire distributed system
/distributed-review

# Review specific module
/distributed-review lib/my_app/consensus.ex

# Review feature area
/distributed-review lib/my_app/cluster/

# Review configuration
/distributed-review config/config.exs
```

## Implementation

### Step 1: Launch Distributed Systems Expert

```markdown
Launching distributed-systems-expert agent (Opus) for distributed system analysis...

Scope: [target area]

The expert will:
1. Evaluate clustering strategy (Distributed Erlang vs Partisan)
2. Analyze consensus algorithm choice (Raft, CRDTs, etc.)
3. Check for distributed bugs (split-brain, clock drift, quorum errors)
4. Assess CAP tradeoffs and consistency model
5. Review network partition handling
6. Provide specific recommendations

This is a deep analysis using Opus model. May take 2-5 minutes...

Waiting for analysis...
```

### Step 2: Analysis Process

The distributed-systems-expert agent executes:

```bash
# Load context
Read [target files]
Read config/config.exs (libcluster, partisan configuration)
Grep "Node.list|:ra|DeltaCrdt|Phoenix.PubSub" (distributed patterns)
Read .claude/project-learnings.md (existing distributed patterns)

# Analyze architecture
- Clustering: Distributed Erlang or Partisan?
- Scale: Node count, projected growth
- Consensus: Raft, CRDTs, or ad-hoc?
- Consistency model: CP, AP, or CA?
- State synchronization: PubSub, Tracker, custom?

# Check for bugs
- Split-brain prevention: Quorum checks present?
- Quorum calculation: div(n, 2) + 1 verified?
- Clock usage: System.monotonic_time() for intervals?
- Race conditions: Optimistic locking or CRDTs?
- Network partition: Merge strategy defined?

# Evaluate decisions
- Consensus choice appropriate for use case?
- Clustering strategy suitable for scale?
- CAP tradeoffs align with requirements?
- Failure modes handled correctly?

# Generate recommendations
- Immediate fixes (critical bugs)
- Strategic improvements (architecture)
- Monitoring and alerting
- Testing approach (partition simulation)
```

### Step 3: Present Findings

**No issues found**:

```markdown
✅ Distributed System Review Complete - Well Designed

## Architecture Summary

**Clustering**: Distributed Erlang with libcluster (Kubernetes DNS)
- Cluster size: 8 nodes (within full-mesh limits)
- Service discovery: kubernetes_selector: "app=myapp"
- Status: Appropriate for scale ✓

**Consensus**: Raft via :ra for inventory management
- Algorithm: Leader-based consensus (CP system)
- Quorum: 5 of 9 nodes (tolerates 4 failures)
- Use case: Strong consistency for inventory
- Status: Correct choice ✓

**Partition Handling**: Quorum-based availability
- Strategy: Minority partition becomes unavailable
- Detection: Cluster health monitoring every 10s
- Status: Correctly implemented ✓

## Analysis

✅ **Scale**: 8 nodes, well under Distributed Erlang limit (~50)
✅ **Quorum**: Correctly calculated as div(9, 2) + 1 = 5
✅ **Clock usage**: System.monotonic_time() for intervals
✅ **Split-brain**: Quorum checks before leader election
✅ **CAP tradeoffs**: CP system appropriate for inventory
✅ **Monitoring**: Cluster health, quorum status tracked

## Recommendations

**Monitoring enhancements**:
1. Add NTP offset monitoring (clock drift detection)
2. Alert on cluster size drops below quorum
3. Track leader election frequency (detect instability)

**Testing**:
- Consider adding partition simulation tests (toxiproxy)
- Test minority partition behavior
- Verify quorum calculations under various failures

Distributed system is production-ready!
```

**Issues found**:

```markdown
🔍 Distributed System Review Findings

Reviewed: lib/my_app/cluster/ (4 files, distributed system implementation)

## Critical Issues

### [Critical] Split-Brain Risk: Missing Quorum Check
**Location**: `lib/my_app/cluster/leader_election.ex:34`
**Confidence**: 95%

**Problem**: Leader election doesn't verify quorum before electing new leader

**Current code**:
```elixir
def elect_leader do
  if leader_dead? do
    become_leader()  # Multiple partitions can elect!
  end
end
```

**Impact**: During network partition, both sides can elect leaders → split-brain

**Fix**:
```elixir
def elect_leader(cluster_size) do
  visible_nodes = [node() | Node.list()]
  reachable = length(visible_nodes)

  if leader_dead? and has_quorum?(cluster_size, reachable) do
    become_leader()
  end
end

defp has_quorum?(cluster_size, reachable_nodes) do
  reachable_nodes >= div(cluster_size, 2) + 1
end
```

### [Critical] Quorum Calculation Error
**Location**: `lib/my_app/cluster/consensus.ex:12`
**Confidence**: 100%

**Problem**: Off-by-one error in quorum calculation

**Current code**:
```elixir
@quorum div(@cluster_size, 2)  # 5 nodes → 2 (not majority!)
```

**Impact**: Even split (2-2 in 4-node cluster) incorrectly considered quorum

**Fix**:
```elixir
@quorum div(@cluster_size, 2) + 1  # 5 nodes → 3 (correct)
```

### [Critical] Clock Drift Bug
**Location**: `lib/my_app/cluster/lease.ex:23`
**Confidence**: 90%

**Problem**: Using System.system_time() for lease expiry check

**Current code**:
```elixir
def valid?(lease) do
  now = System.system_time(:millisecond)
  now < lease.expiry  # NTP adjustment breaks this!
end
```

**Impact**: NTP adjustments can cause lease to expire early or late

**Fix**:
```elixir
def valid?(lease) do
  now = System.monotonic_time(:millisecond)
  now < lease.expiry_monotonic  # Never goes backward
end

# Store lease with monotonic time
def create_lease(duration_ms) do
  %Lease{
    expiry_monotonic: System.monotonic_time(:millisecond) + duration_ms
  }
end
```

## Important Issues

### [Important] Scale Concern: Distributed Erlang at Limit
**Confidence**: 85%

**Problem**: Cluster approaching full-mesh topology limits

**Current state**:
- Cluster size: 45 nodes
- Topology: Full-mesh (O(n²) connections = 2,025 connections)
- Growth: Planning to scale to 80 nodes

**Impact**: Performance degradation, network overhead

**Recommendation**: Migrate to Partisan before hitting 50-node limit

**Implementation**:
```elixir
# 1. Add partisan dependency
{:partisan, "~> 5.0"}

# 2. Configure Partisan with HyParView
config :partisan,
  peer_service: Partisan.PeerService.HyParView,
  active_max_size: 6,
  passive_max_size: 30

# 3. Gradual migration
# - Start new nodes with Partisan
# - Maintain backward compatibility during migration
# - Complete migration before 50-node threshold
```

### [Important] Missing Network Partition Handling
**Location**: `lib/my_app/cluster/state_sync.ex`
**Confidence**: 80%

**Problem**: No defined strategy for merging state after partition heals

**Current behavior**: Undefined (likely last-write-wins by accident)

**Recommendation**: Define explicit merge strategy

**Options**:

**Option 1: CRDTs (if eventual consistency acceptable)**:
```elixir
# For eventually consistent data (user preferences, caches)
{:ok, crdt} = DeltaCrdt.start_link(DeltaCrdt.AWLWWMap)
DeltaCrdt.mutate(crdt, :add, [key, value])
# Automatic merge after partition
```

**Option 2: Application-specific merge**:
```elixir
defmodule StateMerge do
  def merge_after_partition(state1, state2) do
    # Define business logic for conflict resolution
    # Example: Union of sets, max of counters, etc.
  end
end
```

**Option 3: Read-repair**:
```elixir
def get(key) do
  # Read from multiple nodes
  results = Enum.map(nodes(), fn node ->
    :rpc.call(node, Storage, :get, [key])
  end)

  # Find latest, repair stale replicas
  latest = find_latest(results)
  repair_stale_replicas(key, latest, results)
  latest
end
```

### [Important] Race Condition in Distributed Counter
**Location**: `lib/my_app/cluster/counter.ex:18`
**Confidence**: 85%

**Problem**: Concurrent decrements from different nodes lose updates

**Current code**:
```elixir
def decrement(key) do
  value = Storage.get(key)
  Storage.put(key, value - 1)  # Lost update!
end
```

**Impact**: Two nodes can read same value, both write decremented value → lost update

**Fix Option 1: Optimistic locking**:
```elixir
def decrement(key) do
  case Storage.get_with_version(key) do
    {:ok, value, version} ->
      case Storage.put_if_version(key, value - 1, version) do
        :ok -> :ok
        {:error, :version_mismatch} -> decrement(key)  # Retry
      end
  end
end
```

**Fix Option 2: CRDT counter**:
```elixir
{:ok, counter} = DeltaCrdt.start_link(DeltaCrdt.PNCounter)
DeltaCrdt.mutate(counter, :decrement)  # Handles concurrency automatically
```

## Architecture Analysis

### Clustering Strategy

**Current**: Distributed Erlang with libcluster (Kubernetes DNS)

**Assessment**:
- Cluster size: 45 nodes (approaching limit)
- Service discovery: Working well ✓
- Network overhead: High (2,025 connections)
- **Status**: Needs migration to Partisan

### Consensus Algorithm

**Current**: Ad-hoc leader election (no formal consensus)

**Assessment**:
- Use case: Configuration management
- Consistency requirement: Strong (CP)
- Current implementation: Buggy (split-brain risk)
- **Status**: Should use Raft via :ra

**Recommendation**:
```elixir
# Replace ad-hoc election with Raft
defmodule ConfigStateMachine do
  @behaviour :ra_machine

  def init(_config), do: %{}

  def apply(_meta, {:set, key, value}, state) do
    {state, Map.put(state, key, value), :ok}
  end
end

# Start Raft cluster
:ra.start_cluster(
  :config_cluster,
  {:module, ConfigStateMachine, %{}},
  cluster_nodes()
)
```

### CAP Tradeoffs

**Current implementation**: Attempting CA (Consistency + Availability)

**Problem**: No partition tolerance → split-brain during network issues

**Recommended**: CP (Consistency + Partition Tolerance)
- Use Raft for strong consistency
- Accept reduced availability during partition (minority unavailable)
- Appropriate for configuration management use case

### Network Partition Behavior

**Current**: Undefined (dangerous)

**After partition**:
- Both sides continue operating → split-brain
- Different leaders elected → divergent state
- No merge strategy → data loss or corruption

**Recommended**: Quorum-based availability (CP)
- Majority partition: Remains operational
- Minority partition: Becomes unavailable (correct behavior)
- After heal: Minority adopts majority state

## Monitoring Gaps

Missing critical distributed system monitoring:

1. **Cluster health**:
   ```elixir
   # Add monitoring
   defmodule ClusterMonitor do
     def check_health do
       visible = [node() | Node.list()]
       expected = Application.get_env(:app, :cluster_size)

       metrics = %{
         visible_nodes: length(visible),
         has_quorum: length(visible) >= div(expected, 2) + 1,
         missing_nodes: expected - length(visible)
       }

       if not metrics.has_quorum do
         alert(:no_quorum)
       end

       metrics
     end
   end
   ```

2. **Clock skew** (NTP offset):
   ```bash
   ntpq -c rv | grep offset
   # Alert if abs(offset) > 100ms
   ```

3. **Leader election frequency**:
   - Track elections per hour
   - Alert if >3 per hour (indicates instability)

4. **Network partition events**:
   ```elixir
   :net_kernel.monitor_nodes(true, [:nodedown_reason])
   # Log nodedown events with reason
   ```

## Recommendations Priority

### High Priority (This Sprint)

**1. Fix split-brain risk** (2-3 hours)
- Add quorum checks to leader election
- Fix quorum calculation error
- Test with partition simulation

**2. Fix clock drift bug** (1 hour)
- Replace System.system_time() with System.monotonic_time()
- Update lease creation and validation

**3. Define partition handling strategy** (2-3 hours)
- Choose: CRDTs, application merge, or read-repair
- Implement and test

### Medium Priority (Next Sprint)

**4. Plan Partisan migration** (1 week)
- Evaluate current 45-node performance
- Design migration strategy
- Test in staging
- Execute before 50-node limit

**5. Replace ad-hoc consensus with Raft** (3-5 days)
- Design state machine
- Implement :ra cluster
- Migrate existing state
- Test thoroughly

**6. Add distributed monitoring** (2-3 days)
- Cluster health metrics
- NTP offset monitoring
- Leader election tracking
- Partition event logging

### Low Priority

**7. Partition simulation tests** (1-2 days)
- Add toxiproxy to staging
- Create partition scenarios
- Verify behavior matches expectations

## Testing Recommendations

**1. Partition simulation**:
```bash
# Use toxiproxy to simulate partition
toxic.add("network_partition", "timeout", attributes: {timeout: 10000})

# Or use iptables (staging only)
iptables -A INPUT -s <node_ip> -j DROP
```

**2. Test scenarios**:
- 3-2 split in 5-node cluster (majority/minority)
- Complete isolation of single node
- Partition heal after divergent state
- Clock skew (NTP adjustment simulation)
- Concurrent writes from different nodes

**3. Verification**:
- Majority partition elects leader ✓
- Minority partition does not elect ✓
- State converges after heal ✓
- No data loss or corruption ✓

## Documentation Needed

Add to `.claude/project-learnings.md`:

```markdown
## Distributed Systems Patterns

### Consensus Strategy
**Decision**: Using Raft via :ra for configuration management
**Rationale**: Strong consistency required, CP system appropriate
**Configuration**: 5-node cluster, quorum=3

### Cluster Configuration
**Setup**: Migrating to Partisan (cluster approaching 50-node limit)
**Scale**: Currently 45 nodes, projected 80 nodes
**Discovery**: Kubernetes DNS via libcluster

### Network Partition Handling
**Strategy**: CP system - quorum-based availability
**Merge**: N/A (minority adopts majority state)
**Detection**: Monitor cluster health every 10s

### Common Gotchas
1. **Quorum**: Always div(n, 2) + 1, not div(n, 2)
2. **Clock**: Use System.monotonic_time() for intervals
3. **Split-brain**: Verify quorum before leader election
4. **Scale**: Migrate to Partisan before 50 nodes
```

## Next Steps

1. **Review** findings with team
2. **Prioritize** fixes (split-brain is critical!)
3. **Fix** critical bugs immediately
4. **Plan** Partisan migration
5. **Test** with partition simulation
6. **Monitor** cluster health continuously

---

Run `/learn` to add distributed patterns to project knowledge base.
```

**Consensus algorithm evaluation**:

```markdown
🔍 Consensus Algorithm Analysis

Use case: Shopping cart state synchronization

## Requirements Analysis

**Consistency**: Eventual consistency acceptable
- Users rarely edit cart simultaneously
- Conflicts are rare (single user per cart)
- Temporary inconsistency okay

**Availability**: Critical
- Cart must work offline
- High availability improves UX
- Users can't wait for consensus

**Partition Tolerance**: Required
- Mobile apps go offline frequently
- Multi-region deployment planned

**Scale**: 100 nodes, projected 500 nodes

## Options Evaluated

### Option 1: Raft via :ra (CP)

**Pros**:
- Strong consistency guaranteed
- Well-tested library (RabbitMQ)
- Leader-based (simple model)

**Cons**:
- Reduced availability during partition ❌
- Leader bottleneck for reads ❌
- Overkill for shopping cart ❌
- Poor offline experience ❌

**Fit score**: 2/10

### Option 2: CRDTs via delta_crdt (AP)

**Pros**:
- Always available ✓
- Works offline ✓
- Automatic conflict resolution ✓
- Scales well ✓

**Cons**:
- Eventual consistency (acceptable for cart)
- Slightly larger memory footprint (negligible)

**Fit score**: 9/10

### Option 3: Last-Write-Wins (AP)

**Pros**:
- Simple implementation
- Always available

**Cons**:
- Loses data on conflict ❌
- No offline support ❌
- User frustration risk ❌

**Fit score**: 4/10

## Recommendation: CRDTs via delta_crdt

**Rationale**:
1. High availability critical for UX
2. Eventual consistency acceptable (rare conflicts)
3. Excellent offline support
4. Automatic merge (no data loss)
5. Scales to 500+ nodes

**Implementation**:

```elixir
defmodule MyApp.ShoppingCart do
  use GenServer
  alias DeltaCrdt.AWLWWMap

  def start_link(user_id) do
    GenServer.start_link(__MODULE__, user_id, name: via(user_id))
  end

  def init(user_id) do
    {:ok, crdt} = AWLWWMap.start_link()

    # Join cluster CRDTs
    neighbour_pids = get_neighbour_crdt_pids()
    Enum.each(neighbour_pids, fn pid ->
      DeltaCrdt.set_neighbours(crdt, [pid])
    end)

    {:ok, %{user_id: user_id, crdt: crdt, items: %{}}}
  end

  def add_item(user_id, item_id, quantity) do
    GenServer.call(via(user_id), {:add_item, item_id, quantity})
  end

  def remove_item(user_id, item_id) do
    GenServer.call(via(user_id), {:remove_item, item_id})
  end

  def get_items(user_id) do
    GenServer.call(via(user_id), :get_items)
  end

  def handle_call({:add_item, item_id, quantity}, _from, state) do
    DeltaCrdt.mutate(state.crdt, :add, [item_id, %{id: item_id, qty: quantity}])
    {:reply, :ok, state}
  end

  def handle_call({:remove_item, item_id}, _from, state) do
    DeltaCrdt.mutate(state.crdt, :remove, [item_id])
    {:reply, :ok, state}
  end

  def handle_call(:get_items, _from, state) do
    items = DeltaCrdt.read(state.crdt)
    {:reply, {:ok, items}, state}
  end

  defp via(user_id) do
    {:via, Registry, {MyApp.CartRegistry, user_id}}
  end

  defp get_neighbour_crdt_pids do
    # Get CRDTs from other nodes in cluster
    for node <- Node.list(),
        [{_cart_id, pid, _type, _modules}] <- :rpc.call(node, Registry, :lookup, [MyApp.CartRegistry, :carts]) do
      pid
    end
  end
end
```

**Configuration**:

```elixir
# config/config.exs
config :my_app, :shopping_cart,
  crdt_sync_interval: 5_000,  # Sync every 5 seconds
  conflict_resolution: :add_wins  # Items added win over removals
```

**Testing**:

```elixir
defmodule MyApp.ShoppingCartTest do
  use ExUnit.Case

  test "handles concurrent adds from different nodes" do
    # Node 1: Add item A
    ShoppingCart.add_item(user_id, "item_a", 1)

    # Node 2: Add item B (simulated offline)
    ShoppingCart.add_item(user_id, "item_b", 1)

    # After merge: Both items present
    {:ok, items} = ShoppingCart.get_items(user_id)
    assert Map.keys(items) |> Enum.sort() == ["item_a", "item_b"]
  end

  test "handles add/remove conflict (add wins)" do
    # Node 1: Add item
    ShoppingCart.add_item(user_id, "item_a", 1)

    # Node 2: Remove same item (offline)
    ShoppingCart.remove_item(user_id, "item_a")

    # After merge: Add wins (item present)
    {:ok, items} = ShoppingCart.get_items(user_id)
    assert "item_a" in Map.keys(items)
  end
end
```

**Monitoring**:

```elixir
defmodule MyApp.CRDTMonitor do
  def metrics do
    %{
      crdt_sync_lag: measure_sync_lag(),
      conflict_rate: measure_conflicts(),
      memory_usage: measure_memory()
    }
  end
end
```

## Migration Plan

**Phase 1: Pilot** (1 week)
1. Implement CRDT cart for 10% of users
2. Monitor conflicts, performance
3. Validate behavior

**Phase 2: Rollout** (2 weeks)
1. Gradual rollout to 100% users
2. Monitor closely
3. Keep fallback option

**Phase 3: Cleanup** (1 week)
1. Remove old implementation
2. Optimize CRDT settings
3. Document patterns

## Success Metrics

Track for 4 weeks:
- Cart availability: Target 99.99%
- Conflict rate: Expected <0.1%
- Sync latency: Target <100ms p95
- User satisfaction: Cart-related complaints

## Documentation

Add to `.claude/project-learnings.md`:

```markdown
## Shopping Cart: CRDT Implementation

**Decision**: Using CRDTs (delta_crdt) for shopping cart state

**Rationale**:
- High availability critical for UX
- Eventual consistency acceptable (rare conflicts)
- Excellent offline support
- Scales to 500+ nodes

**Conflict resolution**: Add-wins, Last-write-wins for quantities

**Common operations**:
```elixir
ShoppingCart.add_item(user_id, item_id, qty)
ShoppingCart.remove_item(user_id, item_id)
ShoppingCart.get_items(user_id)
```
```

## Configuration

Based on `.claude/elixir-production.local.md`:

**Analysis depth**:
- **Standard**: Architecture, consensus, top bugs
- **Deep**: Complete analysis, all patterns, monitoring plan
- **Quick**: High-level assessment only

## When to Run

**Recommended**:
- **New distributed system**: Before implementation
- **Scaling up**: Approaching Distributed Erlang limits
- **After incident**: Distributed bug investigation
- **Quarterly**: Regular distributed health check
- **Before production**: Validate distributed correctness

**Warning signs**:
- Split-brain incidents
- State inconsistencies after network issues
- Cluster performance degradation
- Nodes frequently disconnecting
- Unclear consensus strategy

## Related Commands

- `/review` - General code review (includes basic distributed checks)
- `/cognitive-audit` - Complexity analysis (can include consensus complexity)
- `/benchmark` - Performance testing (distributed operations)

## Success Criteria

Review succeeds when:
- ✅ Clustering strategy appropriate for scale
- ✅ Consensus algorithm justified or issues identified
- ✅ Split-brain prevention verified
- ✅ Quorum calculations correct
- ✅ Clock drift mitigation in place
- ✅ Network partition handling defined
- ✅ CAP tradeoffs explicit
- ✅ Monitoring recommendations provided
- ✅ Findings documented in project-learnings.md

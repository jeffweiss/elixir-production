# Leader Election

Many distributed patterns need "exactly one process does X" — cron scheduling, cache warming, migration running, singleton workers. Full Raft consensus is overkill for most of these.

## Decision Table

```
Need exactly one process to do something?
  Single node only?
    → Use a named GenServer (trivial)
  Multi-node cluster?
    → Need strong consistency (can't have two leaders)?
        YES → Is it simple leader election?
                YES → :global.register_name (built-in, good enough)
                NO  → :ra (Raft) for leader + replicated state
        NO  → Eventual consistency acceptable?
                YES → Horde (CRDT-based, survives netsplits with duplicates)
                NO  → External coordinator (etcd, Consul)
```

| Approach | Consistency | Netsplit Behavior | Complexity | Use When |
|----------|------------|-------------------|-----------|----------|
| Named GenServer | N/A (single node) | N/A | Trivial | Single node, process must be unique |
| `:global.register_name` | Strong (lock-based) | One side loses registration | Low | Simple singleton, small cluster |
| `:pg` + manual leader | Eventual | May have brief dual leaders | Low | Leader as optimization, not correctness |
| Horde.Registry | Eventual (CRDT) | Both sides may elect leaders | Medium | Dynamic processes, availability over consistency |
| `:ra` (Raft) | Strong (consensus) | Minority side has no leader | High | Leader + replicated state machine |
| External (etcd/Consul) | Strong (external) | Depends on external quorum | High | Multi-language, existing infrastructure |

## :global — Built-In Leader Election

The simplest multi-node leader election. Uses distributed locks — only one process with a given name exists across the cluster.

```elixir
defmodule MyApp.LeaderWorker do
  use GenServer

  def start_link(opts) do
    # :global.register_name ensures only one across the cluster
    GenServer.start_link(__MODULE__, opts, name: {:global, __MODULE__})
  end

  def init(opts) do
    # This process is the leader — start doing leader work
    schedule_work()
    {:ok, opts}
  end

  def handle_info(:do_work, state) do
    perform_leader_task()
    schedule_work()
    {:noreply, state}
  end

  defp schedule_work, do: Process.send_after(self(), :do_work, :timer.minutes(1))
end
```

**Supervision**: Start on every node. Only one succeeds. If the leader dies, another node's supervisor restarts it and wins the global registration.

```elixir
# In your application supervisor — on every node
children = [
  {MyApp.LeaderWorker, []}
]
```

### :global Gotchas

- **Registration is synchronous** — blocks until the global lock is acquired or times out
- **Netsplit behavior** — during a partition, the side that had the leader keeps it. On heal, conflicting registrations are resolved (one process is killed)
- **Not partition-tolerant** — if the minority partition needs a leader, it won't have one
- **Name conflicts on heal** — `:global` calls `resolve/3` which defaults to killing one process. You can provide a custom resolver.

## :pg — Process Groups for Soft Leader Election

When you need a leader as an optimization (not correctness), use `:pg` groups and elect from members:

```elixir
defmodule MyApp.SoftLeader do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    :pg.join(__MODULE__, self())
    schedule_election()
    {:ok, %{is_leader: false}}
  end

  def handle_info(:elect, state) do
    members = :pg.get_members(__MODULE__)
    # Deterministic election: smallest pid is leader
    leader = Enum.min(members)
    is_leader = leader == self()

    if is_leader, do: perform_leader_task()
    schedule_election()
    {:noreply, %{state | is_leader: is_leader}}
  end

  defp schedule_election, do: Process.send_after(self(), :elect, :timer.seconds(30))
end
```

**Tradeoffs**: Brief dual-leader during netsplit (both sides elect). Acceptable when leader work is idempotent (cache warming, stats aggregation). Not acceptable for work that must happen exactly once.

## Horde — CRDT-Based Distribution

Horde provides a distributed supervisor and registry using CRDTs. Processes are distributed across nodes with automatic rebalancing.

```elixir
# In application supervisor
children = [
  {Horde.Registry, [name: MyApp.Registry, keys: :unique]},
  {Horde.DynamicSupervisor, [name: MyApp.DSup, strategy: :one_for_one]},
  {MyApp.ClusterConnector, []}  # Joins Horde members on node connect
]
```

```elixir
# Start a singleton worker via Horde
Horde.DynamicSupervisor.start_child(MyApp.DSup, {MyApp.SingletonWorker, []})

# Register with Horde.Registry for cluster-wide uniqueness
{:ok, pid} = Horde.Registry.register(MyApp.Registry, :my_singleton, nil)
```

### Horde Netsplit Behavior

During a netsplit, both sides may run the "singleton" — Horde favors **availability over consistency**. On heal, Horde reconciles via CRDT merge and kills duplicates.

**Use when**: You need dynamic process distribution with automatic failover, and brief duplicates during netsplit are acceptable.

**Don't use when**: Exactly-once semantics are required (e.g., payment processing). Use `:ra` or an external coordinator instead.

## Singleton Pattern with Oban

For periodic/cron work that must run on exactly one node, Oban's built-in leader election handles this:

```elixir
# Oban already elects a leader for cron scheduling
# You get singleton behavior for free with cron jobs:
config :my_app, Oban,
  queues: [default: 10],
  plugins: [
    {Oban.Plugins.Cron, crontab: [
      {"*/5 * * * *", MyApp.Workers.CacheWarmer},
      {"0 * * * *", MyApp.Workers.StatsAggregator}
    ]}
  ]
```

Oban's peer election ensures only one node inserts cron jobs. This is often the simplest solution for "run this periodically on one node."

## Testing Leader Election

```elixir
test "only one leader exists" do
  # Start two instances
  {:ok, pid1} = MyApp.LeaderWorker.start_link([])
  # Second start should fail (global name taken)
  assert {:error, {:already_started, ^pid1}} =
    MyApp.LeaderWorker.start_link([])
end

test "new leader elected on failure" do
  {:ok, pid1} = MyApp.LeaderWorker.start_link([])
  GenServer.stop(pid1)

  # Allow time for re-election
  Process.sleep(100)

  # New leader should be running
  assert Process.alive?(GenServer.whereis({:global, MyApp.LeaderWorker}))
end
```

## Common Mistakes

- **Using `:global` for high-frequency registration**: `:global` uses distributed locks — expensive for processes that start/stop frequently. Use Horde for dynamic process pools.
- **Assuming singleton during netsplit**: With `:global`, the minority side has no leader. With Horde, both sides have one. Design for your netsplit requirements.
- **Building custom leader election**: `:global`, `:pg`, Horde, and Oban cover 95% of cases. Custom election protocols are hard to get right.
- **Not making leader work idempotent**: If using soft leader election (`:pg`), brief dual-leader periods mean the work may run twice. Make it idempotent.
- **Forgetting Oban has leader election**: If your "singleton" need is periodic work, Oban cron already solves this without any additional infrastructure.

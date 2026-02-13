# Consistent Hashing and Partitioning

How to distribute data across nodes so that adding or removing a node only moves a minimal amount of data.

## Decision Table

| Need | Approach | Use When |
|------|----------|----------|
| Route requests to specific nodes | Consistent hashing | Sticky sessions, sharded caches, partitioned state |
| Distribute Oban jobs by tenant | Queue per tenant or `partition_by` | Isolation between tenants |
| Shard database reads | Read replicas with routing | Read-heavy workloads exceeding single node |
| Partition Broadway pipeline | `partition_by` option | Ordered processing per key |
| Distribute GenServers across cluster | Horde + consistent hash | Dynamic process placement |

## How Consistent Hashing Works

Nodes and keys are placed on a virtual ring (0 to 2^32-1). Each key is assigned to the next node clockwise on the ring.

```
Ring:  0 ----[Node A]---- 1/4 ----[Node B]---- 1/2 ----[Node C]---- 3/4 ---- 0

Key "user:42" hashes to position 0.3 → assigned to Node B (next clockwise)
Key "user:99" hashes to position 0.6 → assigned to Node C
```

**When Node B is removed**: Only keys between Node A and Node B move to Node C. Other keys are unaffected. This is the key property — only K/N keys move on average when a node is added/removed (vs all keys with modular hashing).

### Virtual Nodes

Real consistent hashing uses virtual nodes (vnodes) for even distribution. Each physical node gets many positions on the ring:

```elixir
defmodule MyApp.ConsistentHash do
  @vnodes_per_node 150

  def new(nodes) do
    ring =
      nodes
      |> Enum.flat_map(fn node ->
        for i <- 1..@vnodes_per_node do
          hash = :erlang.phash2({node, i}, trunc(:math.pow(2, 32)))
          {hash, node}
        end
      end)
      |> Enum.sort_by(&elem(&1, 0))

    %{ring: ring, nodes: MapSet.new(nodes)}
  end

  def get_node(%{ring: ring}, key) do
    hash = :erlang.phash2(key, trunc(:math.pow(2, 32)))

    # Find first vnode with position >= hash (clockwise)
    case Enum.find(ring, fn {pos, _} -> pos >= hash end) do
      {_, node} -> node
      nil -> elem(List.first(ring), 1)  # Wrap around
    end
  end
end

ring = MyApp.ConsistentHash.new([:node_a, :node_b, :node_c])
MyApp.ConsistentHash.get_node(ring, "user:42")  # => :node_b
```

## Jump Consistent Hash

Simpler and faster than ring-based hashing when nodes are numbered 0..N-1. No ring to maintain — a single function maps key → bucket:

```elixir
defmodule MyApp.JumpHash do
  @doc """
  Maps key to a bucket in 0..num_buckets-1.
  Only moves ~1/N keys when a bucket is added.
  """
  def compute(key, num_buckets) when num_buckets > 0 do
    seed = :erlang.phash2(key)
    jump(seed, num_buckets, -1, 0)
  end

  defp jump(_seed, num_buckets, b, _j) when b >= num_buckets - 1, do: min(b, num_buckets - 1)
  defp jump(seed, num_buckets, _b, j) do
    b = j
    seed = seed * 2862933555777941757 + 1
    j = trunc((b + 1) * (1 / ((seed >>> 33) + 1)))
    jump(seed, num_buckets, b, j)
  end
end

# Distribute across 3 shards
MyApp.JumpHash.compute("user:42", 3)  # => 1
MyApp.JumpHash.compute("user:42", 4)  # => 1 (same! minimal disruption)
```

**Limitation**: Only supports adding/removing from the end of the node list (node N). Can't remove a node from the middle without remapping.

## Practical Patterns

### Sharded ETS Cache

```elixir
defmodule MyApp.ShardedCache do
  @shards 16

  def init do
    for i <- 0..(@shards - 1) do
      :ets.new(:"cache_shard_#{i}", [:set, :named_table, :public, read_concurrency: true])
    end
  end

  def get(key) do
    shard = :erlang.phash2(key, @shards)
    case :ets.lookup(:"cache_shard_#{shard}", key) do
      [{^key, value}] -> {:ok, value}
      [] -> :miss
    end
  end

  def put(key, value) do
    shard = :erlang.phash2(key, @shards)
    :ets.insert(:"cache_shard_#{shard}", {key, value})
  end
end
```

### Broadway Partitioning

Broadway's built-in partitioning uses consistent assignment to ensure same-key messages go to the same processor:

```elixir
Broadway.start_link(__MODULE__,
  processors: [default: [concurrency: 10]],
  partition_by: fn message -> :erlang.phash2(message.data.user_id) end
)
```

## Consistent Hashing vs Alternatives

| Approach | Key Movement on Scale | Ordering | Complexity |
|----------|----------------------|----------|-----------|
| Modular hash (`rem(hash, N)`) | All keys move when N changes | None | Trivial |
| Consistent hash (ring) | ~K/N keys move | None | Medium |
| Jump consistent hash | ~K/N keys move | Append-only nodes | Low |
| Range partitioning | Depends on rebalancing | Ordered within partition | Medium |

## Common Mistakes

- **Using `rem(hash, N)` for sharding**: Adding a node remaps almost every key. Use consistent hashing for stable assignment.
- **Too few virtual nodes**: With real consistent hashing, 150+ vnodes per physical node ensures even distribution. Too few creates hot spots.
- **Not considering rebalancing**: When a node is added, existing data on other nodes doesn't automatically move. You need a migration strategy.
- **Sharding prematurely**: A single BEAM node handles millions of processes. Shard only when you have actual evidence of single-node bottleneck.

# Cache-Efficient Algorithms and Sorting

## Cache-Oblivious Algorithms

Algorithms designed to work efficiently across all cache levels without knowing cache parameters. Key principle: divide-and-conquer with base cases small enough to fit in cache.

```elixir
defmodule CacheOblivious.Matrix do
  @base_case 64  # Tune to L1 cache size

  def multiply(a, b) do
    n = length(a)

    if n <= @base_case do
      naive_multiply(a, b)
    else
      {a11, a12, a21, a22} = subdivide(a)
      {b11, b12, b21, b22} = subdivide(b)

      c11 = add(multiply(a11, b11), multiply(a12, b21))
      c12 = add(multiply(a11, b12), multiply(a12, b22))
      c21 = add(multiply(a21, b11), multiply(a22, b21))
      c22 = add(multiply(a21, b12), multiply(a22, b22))

      combine(c11, c12, c21, c22)
    end
  end
end
```

**Performance**: 2-3× faster than naive approach for large matrices.

**Paper**: Frigo et al., 1999

## B+ Trees

Self-balancing tree optimized for systems with cache/disk hierarchy. Used in databases.

- All data in leaf nodes, internal nodes for navigation only
- Leaf nodes linked for range queries
- High fan-out reduces height

```elixir
# {:b_tree, "~> 0.1"}
tree = BTree.new(order: 100)
tree = Enum.reduce(1..1_000_000, tree, fn i, acc ->
  BTree.insert(acc, i, "value_#{i}")
end)

BTree.get(tree, 42)
BTree.range(tree, 100, 200)
```

**Use cases**: Database indexes, file systems, on-disk data, large sorted collections.

## BlockQuicksort (2016)

Variant of quicksort with better cache behavior through block-wise partitioning.

```elixir
defmodule BlockQuicksort do
  @block_size 128

  def sort(list) when length(list) <= @block_size, do: Enum.sort(list)

  def sort(list) do
    pivot = select_pivot(list)
    {left, equal, right} = partition_blockwise(list, pivot)

    Task.async_stream([left, right], &sort/1, ordered: false)
    |> Enum.flat_map(fn {:ok, sorted} -> sorted end)
    |> Kernel.++(equal)
  end

  defp partition_blockwise(list, pivot) do
    list
    |> Enum.chunk_every(@block_size)
    |> Enum.reduce({[], [], []}, fn block, {l, e, r} ->
      {bl, be, br} = partition_block(block, pivot)
      {l ++ bl, e ++ be, r ++ br}
    end)
  end
end
```

**Performance**: 1.5-2× faster than standard quicksort on modern hardware.

**Paper**: Edelkamp & Weiß, 2016

## Pattern-Defeating Quicksort (pdqsort, 2021)

Hybrid sorting that detects patterns (sorted, reverse-sorted, equal elements) and adapts strategy.

- Switches to heapsort when recursion depth excessive
- Uses insertion sort for small partitions
- O(n log n) worst-case (vs O(n²) for standard quicksort)
- Used in Rust's standard library

**Paper**: Orson Peters, 2021

## When to Use Modern vs Classic

| Use Case | Modern | Classic | Switch When |
|----------|--------|---------|-------------|
| FIFO Queue | `:queue` (OTP) | List as queue | Always — O(1) vs O(n) |
| Ordered key-value | `:gb_trees` (OTP) | Sorted list | >50 elements |
| Priority Queue | Pairing heap | Sorted list | >100 elements |
| Sorting Large Data | BlockQuicksort | Standard quicksort | >10K items |
| Sorting with Patterns | pdqsort | Quicksort | Data has patterns |
| Matrix Multiplication | Cache-oblivious | Naive O(n³) | >1000×1000 |
| Database Indexes | B+ Tree | Binary tree | Persistent storage |

## Common Mistakes

**Using lists as queues**:
```elixir
# ❌ O(n) — appending to list tail
queue = queue ++ [new_item]

# ✅ O(1) amortized — :queue handles both ends
q = :queue.in(new_item, q)
{{:value, item}, q} = :queue.out(q)
```

**Using GenServer for shared counters**:
```elixir
# ❌ BOTTLENECK — all updates serialized
GenServer.call(CounterServer, {:increment, key})

# ✅ LOCK-FREE — concurrent updates
ref = :atomics.new(1, signed: false)
:atomics.add(ref, 1, 1)
```

## Custom Implementations

Consider custom when:
- Need specific tuning for your use case
- No stable library available
- Integrating with C/Rust code (use Rustler for NIFs)
- Performance critical and library overhead matters

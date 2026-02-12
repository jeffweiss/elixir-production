# OTP Built-In Data Structures

Before reaching for external libraries, use what Erlang/OTP provides. Battle-tested, zero-dependency, optimized for the BEAM.

## Quick Reference

| Module | Structure | Use When |
|--------|-----------|----------|
| `:queue` | Double-ended FIFO queue | O(1) enqueue/dequeue from both ends; BFS; producer-consumer buffers |
| `:gb_trees` | General balanced trees | Ordered key-value with O(log n) operations; range queries |
| `:gb_sets` | General balanced sets | Ordered unique collection; union, intersection |
| `:ordsets` | Ordered list sets | Small sets (<100) needing sorted iteration |
| `:orddict` | Ordered list dicts | Small key-value maps (<50 keys) needing sorted keys |
| `:sets` | Hash sets (OTP 24+) | Unordered unique collection; faster than `:gb_sets` for large sets |
| `:digraph` | Mutable directed graph | Graph algorithms (shortest path, topological sort, cycles); uses ETS |
| `:array` | Functional sparse array | Integer-indexed data with gaps; default values for missing indices |
| `:atomics` | Lock-free integer array | Concurrent counters, flags; shared mutable state without process bottleneck |
| `:counters` | Concurrent counters | High-throughput counting; write-optimized |
| `circular_buffer` | Fixed-size ring buffer | Sliding window; recent metrics, rate limiting |

## Usage Examples

```elixir
# :queue — O(1) operations from both ends
q = :queue.new()
q = :queue.in(:first, q)
q = :queue.in(:second, q)
{{:value, :first}, q} = :queue.out(q)

# :gb_trees — ordered key-value with range operations
tree = :gb_trees.empty()
tree = :gb_trees.insert("alice", 1, tree)
tree = :gb_trees.insert("bob", 2, tree)
{_key, _val, _iter} = :gb_trees.next(:gb_trees.iterator(tree))

# :array — sparse functional array with defaults
arr = :array.new(default: 0)
arr = :array.set(5, :hello, arr)
:hello = :array.get(5, arr)
0 = :array.get(99, arr)  # returns default
```

## When to Use OTP Structures Over Elixir's Built-Ins

- `:queue` when you need FIFO semantics (lists are O(n) for dequeue from tail)
- `:gb_trees` when you need ordered traversal or range queries (maps are unordered)
- `:gb_sets` when you need sorted set operations (MapSet is unordered)
- `:digraph` when solving graph problems (adjacency lists are verbose)
- `:atomics`/`:counters` when concurrent processes update shared counters (GenServer bottleneck)

## Okasaki-Style Functional Structures

Chris Okasaki's "Purely Functional Data Structures" (1998) established foundational techniques for efficient immutable data structures. Elixir's immutable model means these are directly applicable.

**What Elixir already gives you from Okasaki's world:**
- **Maps** use HAMTs (Hash Array Mapped Tries) — persistent with structural sharing
- **Lists** are classic cons-cells with O(1) prepend
- **MapSet** wraps Map — same HAMT benefits
- `:queue` uses Okasaki's paired-list technique

**When to think about Okasaki-style structures:**

| Situation | Consider |
|-----------|----------|
| O(1) queue operations | `:queue` (already Okasaki-derived) |
| Fixed-size sliding window | `circular_buffer` — Okasaki paired-list (like `:queue`) with Enumerable/Collectable |
| Priority queue/heap | Pairing heap — `heap` library |
| Snapshotting state for undo/audit | Persistent structures give this for free |
| Large indexed collections | Erlang's `:array` covers most cases |

```elixir
# Persistent structures: old versions survive updates
tree1 = :gb_trees.insert("a", 1, :gb_trees.empty())
tree2 = :gb_trees.insert("b", 2, tree1)
# tree1 still contains only "a" — useful for snapshots, undo, audit trails

# Priority queue via pairing heap (add {:heap, "~> 3.0"} to deps)
heap = Heap.new(&<=/2)  # min-heap
heap = heap |> Heap.push(5) |> Heap.push(1) |> Heap.push(3)
{1, heap} = Heap.split(heap)  # O(1) find-min, O(log n) amortized delete-min
```

**When NOT to reach for Okasaki structures:**
- If Map, MapSet, or a plain list solves the problem
- If you need mutable shared state — use ETS or `:atomics`
- If the collection is small (<1000 elements) — constant factors dominate

**Reference**: Okasaki, Chris. "Purely Functional Data Structures." Cambridge University Press, 1998.

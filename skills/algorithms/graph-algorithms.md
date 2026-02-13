# Graph Algorithms

## OTP Built-Ins: :digraph and :digraph_utils

Erlang ships a full mutable directed graph implementation backed by ETS. Use it before reaching for external libraries.

## Quick Reference

| Operation | Function | Complexity |
|-----------|----------|-----------|
| Create graph | `:digraph.new/0` or `:digraph.new/1` | O(1) |
| Add vertex | `:digraph.add_vertex/3` | O(1) |
| Add edge | `:digraph.add_edge/5` | O(1) |
| Shortest path | `:digraph.get_short_path/3` | O(V + E) BFS |
| All paths | `:digraph.get_path/3` | Exponential worst case |
| Topological sort | `:digraph_utils.topsort/1` | O(V + E) |
| Connected components | `:digraph_utils.components/1` | O(V + E) |
| Strongly connected | `:digraph_utils.strong_components/1` | O(V + E) |
| Cycle detection | `:digraph_utils.is_acyclic/1` | O(V + E) |
| Reachable from vertex | `:digraph_utils.reachable/2` | O(V + E) |
| Condensation | `:digraph_utils.condensation/1` | O(V + E) |

## Usage Patterns

### Dependency Resolution

```elixir
# Build dependency graph
g = :digraph.new([:acyclic])  # Reject cycles on insertion

:digraph.add_vertex(g, :web, "Web layer")
:digraph.add_vertex(g, :accounts, "Accounts context")
:digraph.add_vertex(g, :repo, "Database")

:digraph.add_edge(g, :web, :accounts)
:digraph.add_edge(g, :accounts, :repo)

# Topological sort — gives valid build/migration order
:digraph_utils.topsort(g)
# => [:web, :accounts, :repo]

# Detect circular dependencies
case :digraph.add_edge(g, :repo, :web) do
  {:error, {:bad_edge, path}} -> {:error, :circular_dependency, path}
  edge -> {:ok, edge}
end
```

### Task Scheduling with Prerequisites

```elixir
defmodule MyApp.TaskScheduler do
  def execution_order(tasks) do
    g = :digraph.new()

    # Add tasks as vertices
    Enum.each(tasks, fn task ->
      :digraph.add_vertex(g, task.id, task)
    end)

    # Add prerequisite edges
    Enum.each(tasks, fn task ->
      Enum.each(task.prerequisites, fn prereq ->
        :digraph.add_edge(g, prereq, task.id)
      end)
    end)

    case :digraph_utils.topsort(g) do
      false -> {:error, :circular_dependency}
      order -> {:ok, order}
    end
  after
    :digraph.delete(g)
  end
end
```

### Finding Affected Modules (Impact Analysis)

```elixir
# What modules are affected if :accounts changes?
affected = :digraph_utils.reaching([:accounts], g)
# => [:web, :accounts] — everything that depends on accounts

# What does :web depend on (transitively)?
dependencies = :digraph_utils.reachable([:web], g)
# => [:web, :accounts, :repo]
```

### Cycle Detection in Workflows

```elixir
if :digraph_utils.is_acyclic(g) do
  :digraph_utils.topsort(g)
else
  # Find the cycles
  cycles = :digraph_utils.cyclic_strong_components(g)
  {:error, :cycles_detected, cycles}
end
```

## Graph Options

```elixir
# Default: cyclic, no self-loops protection
:digraph.new()

# DAG (directed acyclic graph) — rejects edges that would create cycles
:digraph.new([:acyclic])

# Protected access (default: only owning process can modify)
:digraph.new([:protected])

# Private — only owning process can read or write
:digraph.new([:private])
```

## Important: Memory Management

`:digraph` uses ETS tables internally. **You must delete the graph when done**, or it leaks memory:

```elixir
g = :digraph.new()
try do
  # ... use graph ...
  result = :digraph_utils.topsort(g)
  result
after
  :digraph.delete(g)
end
```

## When to Use :digraph vs Alternatives

| Scenario | Use | Why |
|----------|-----|-----|
| Dependency resolution | `:digraph` + `:digraph_utils.topsort/1` | Built-in, correct, O(V+E) |
| Shortest path (unweighted) | `:digraph.get_short_path/3` | BFS, built-in |
| Shortest path (weighted) | `libgraph` library | `:digraph` doesn't support weights natively |
| Large graphs (>100K nodes) | `libgraph` or custom | `:digraph` ETS overhead may matter |
| Persistent/immutable graph | `libgraph` | `:digraph` is mutable (ETS-backed) |
| Simple adjacency list | Plain Map | `%{node => [neighbors]}` is simpler for small graphs |

## Common Mistakes

- **Forgetting to delete graphs**: `:digraph` uses ETS — always delete in an `after` block or supervised process
- **Assuming immutability**: `:digraph` is mutable. If you add an edge in one function, callers see it
- **Using `:acyclic` without handling errors**: Edge insertion returns `{:error, {:bad_edge, path}}` when it would create a cycle — handle it
- **Building adjacency maps instead**: If you need topological sort, shortest path, or cycle detection, `:digraph` already implements them correctly

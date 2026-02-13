# Optimization Algorithms

## Decision Table

```
Need to find the best solution given constraints?
  Is the search space small (< 1000 options)?
    → Enumerate all options (brute force is fine)
  Is there optimal substructure (optimal solution built from optimal sub-solutions)?
    → Dynamic programming
  Can you make locally optimal choices that lead to global optimum?
    → Greedy algorithm
  Is it a constraint satisfaction problem (variables, domains, constraints)?
    → Constraint propagation / backtracking
  Is it a continuous optimization (minimize a function)?
    → Gradient descent (Nx)
  Is it NP-hard and you need "good enough"?
    → Heuristic: simulated annealing, genetic algorithm, or local search
```

| Problem Class | Algorithm | Complexity | Use When |
|--------------|-----------|-----------|----------|
| Shortest path | Dijkstra / BFS | O(E + V log V) | Route planning, dependency ordering |
| Optimal substructure | Dynamic programming | Varies | Knapsack, edit distance, sequence alignment |
| Local optimality = global | Greedy | O(n log n) typical | Scheduling, coin change, Huffman coding |
| Constraint satisfaction | Backtracking + pruning | Exponential worst | Sudoku, scheduling with constraints, configuration |
| Continuous function min/max | Gradient descent | Iterative | ML training, curve fitting, parameter tuning |
| Combinatorial (NP-hard) | Simulated annealing | Heuristic | TSP, bin packing, VLSI layout |
| Population-based search | Genetic algorithms | Heuristic | Multi-objective optimization, evolving strategies |
| Linear constraints | Linear programming | Polynomial | Resource allocation, blending, transportation |

## Dynamic Programming

When a problem has **overlapping subproblems** and **optimal substructure**, solve each subproblem once and cache results.

```elixir
# Classic: Knapsack problem
# Given items with weights and values, maximize value within weight limit
defmodule Knapsack do
  def solve(items, capacity) do
    items
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {{weight, value}, i}, memo ->
      for cap <- 0..capacity, reduce: memo do
        memo ->
          without = Map.get(memo, {i - 1, cap}, 0)
          with_item =
            if weight <= cap do
              value + Map.get(memo, {i - 1, cap - weight}, 0)
            else
              0
            end
          Map.put(memo, {i, cap}, max(without, with_item))
      end
    end)
    |> Map.get({length(items) - 1, capacity}, 0)
  end
end
```

**Common DP problems in production**:
- Text diff / edit distance (code review, content comparison)
- Optimal line breaking (text formatting)
- Resource allocation with constraints
- Sequence matching (search relevance)

### Memoization Pattern

```elixir
# Generic memoization using process dictionary (simple, fast)
defp memoize(key, fun) do
  case Process.get(key) do
    nil ->
      result = fun.()
      Process.put(key, result)
      result
    result ->
      result
  end
end

# Or with ETS for cross-process memoization
defmodule MyApp.Memo do
  def get_or_compute(table, key, fun) do
    case :ets.lookup(table, key) do
      [{^key, value}] -> value
      [] ->
        value = fun.()
        :ets.insert(table, {key, value})
        value
    end
  end
end
```

## Greedy Algorithms

Make the locally optimal choice at each step. Works when local optimality guarantees global optimality.

```elixir
# Job scheduling: maximize number of non-overlapping jobs
# Sort by end time, greedily pick earliest-ending non-conflicting job
def schedule_jobs(jobs) do
  jobs
  |> Enum.sort_by(& &1.end_time)
  |> Enum.reduce({[], nil}, fn job, {selected, last_end} ->
    if last_end == nil or job.start_time >= last_end do
      {[job | selected], job.end_time}
    else
      {selected, last_end}
    end
  end)
  |> elem(0)
  |> Enum.reverse()
end
```

**When greedy works**: Activity selection, fractional knapsack, Huffman coding, minimum spanning tree.
**When greedy fails**: 0/1 knapsack, traveling salesman, graph coloring — use DP or heuristics instead.

## Constraint Satisfaction

For problems with variables, domains, and constraints (scheduling, configuration, puzzle solving):

```elixir
# Simple backtracking with constraint propagation
defmodule Scheduler do
  def assign(tasks, resources, constraints) do
    backtrack(tasks, resources, constraints, %{})
  end

  defp backtrack([], _resources, _constraints, assignment), do: {:ok, assignment}

  defp backtrack([task | rest], resources, constraints, assignment) do
    Enum.find_value(resources, :no_solution, fn resource ->
      candidate = Map.put(assignment, task, resource)
      if satisfies_constraints?(candidate, constraints) do
        case backtrack(rest, resources, constraints, candidate) do
          {:ok, _} = result -> result
          :no_solution -> nil
        end
      end
    end) || :no_solution
  end

  defp satisfies_constraints?(assignment, constraints) do
    Enum.all?(constraints, fn constraint -> constraint.(assignment) end)
  end
end
```

## Numerical Optimization with Nx

For continuous optimization (minimizing cost functions, parameter tuning), use Nx:

```elixir
# {:nx, "~> 0.7"}
# Gradient descent to find minimum of a function
defmodule MyApp.Optimizer do
  import Nx.Defn

  defn loss(params, data) do
    predictions = Nx.dot(data, params)
    errors = predictions - targets
    Nx.mean(errors ** 2)
  end

  defn step(params, data, learning_rate) do
    {loss, grad} = value_and_grad(params, &loss(&1, data))
    new_params = params - learning_rate * grad
    {new_params, loss}
  end
end
```

**Use Nx when**: Parameter tuning, regression, curve fitting, any continuous optimization. Nx compiles to optimized native code via EXLA/Torchx backends.

## Linear Programming

For optimization with linear constraints (resource allocation, scheduling, blending):

```elixir
# No mature pure-Elixir LP solver — call external tools
# Option 1: Shell out to GLPK or CBC
# Option 2: Use Python via Pythonx for scipy.optimize.linprog
# Option 3: Express as Nx optimization for simple cases

# Example: formulate as Nx when constraints are simple
# Maximize: 3x + 5y
# Subject to: x + y <= 10, x >= 0, y >= 0
# This is simple enough for enumeration or gradient methods
```

For production LP needs, consider calling Python's `scipy.optimize.linprog` or Google's OR-Tools via a Port or Pythonx.

## Heuristic Optimization

When exact solutions are intractable (NP-hard problems), use heuristics for "good enough" solutions:

### Simulated Annealing

Randomly explores solution space, accepting worse solutions with decreasing probability (escapes local minima):

```elixir
defmodule SimulatedAnnealing do
  def optimize(initial, energy_fn, neighbor_fn, opts \\ []) do
    temp = Keyword.get(opts, :initial_temp, 1000.0)
    cooling = Keyword.get(opts, :cooling_rate, 0.995)
    iterations = Keyword.get(opts, :iterations, 10_000)

    Enum.reduce(1..iterations, {initial, energy_fn.(initial), temp}, fn _, {current, current_e, t} ->
      neighbor = neighbor_fn.(current)
      neighbor_e = energy_fn.(neighbor)
      delta = neighbor_e - current_e

      {next, next_e} =
        if delta < 0 or :rand.uniform() < :math.exp(-delta / t) do
          {neighbor, neighbor_e}
        else
          {current, current_e}
        end

      {next, next_e, t * cooling}
    end)
    |> then(fn {solution, energy, _} -> {solution, energy} end)
  end
end
```

**Use for**: Traveling salesman, job shop scheduling, bin packing, network routing — any problem where you can define a neighbor function and an energy/cost function.

## When to Push Optimization to the Database

Many "optimization" problems in web apps are better solved by Postgres:

| Problem | SQL Approach |
|---------|-------------|
| Top-K items by score | `ORDER BY score DESC LIMIT k` |
| Nearest neighbors | PostGIS `ST_DWithin` with GiST index |
| Optimal assignment | Window functions + CTEs |
| Resource scheduling | Range types + exclusion constraints |
| Ranking with constraints | `ROW_NUMBER() OVER (PARTITION BY ...)` |

Don't implement in Elixir what Postgres can do with an index and a query.

## Common Mistakes

- **Implementing in Elixir what SQL can do**: Top-K, sorting, filtering, and ranking are almost always faster in the database with proper indexes.
- **Using brute force beyond small inputs**: Enumerate all options for <1000 items. Beyond that, the algorithm choice matters.
- **Greedy when DP is needed**: Greedy only works when local optimality guarantees global optimality. For knapsack, sequence alignment, or edit distance, use DP.
- **Not memoizing recursive DP**: Recursive DP without memoization recomputes subproblems exponentially. Always memoize or use bottom-up tabulation.
- **Over-engineering optimization**: If the business problem is "sort by score, take top 10," you don't need an optimization algorithm — you need `ORDER BY ... LIMIT 10`.

# Benchmarking with Benchee

## Setup

```elixir
# Add to mix.exs
{:benchee, "~> 1.0", only: :dev}
```

## Standard Benchmark Template

```elixir
Benchee.run(%{
  "current implementation" => fn ->
    CurrentModule.function(input)
  end,
  "proposed optimization" => fn ->
    OptimizedModule.function(input)
  end
},
  warmup: 2,
  time: 5,
  memory_time: 2
)
```

**CRITICAL:** Benchmark BEFORE changing code to establish baseline.

## Complexity Analysis for O(n²)+ Code

When profiling reveals slow code AND analysis shows O(n²) or worse complexity, confirm with increasing input sizes:

```elixir
Benchee.run(%{
  "current O(n²)" => fn n ->
    CurrentImplementation.function(1..n)
  end
},
  inputs: %{
    "100 items" => 100,
    "1,000 items" => 1000,
    "10,000 items" => 10_000
  }
)
# If 10K is 100x slower than 1K (not 10x), you have O(n²)
```

## Validating "Improvements"

User claims code is faster after changes:

**REFUSE to confirm without benchmarks:**
1. "Show me the before and after benchmarks"
2. If no baseline exists, cannot verify improvement
3. "Should be faster" is not the same as "measured to be faster"

## Anti-Patterns

| Mistake | Fix |
|---------|-----|
| No baseline benchmark | Measure current state before changing anything |
| Assuming optimization worked | Benchmark after changes to verify |
| Profiling in dev instead of prod-like data | Use realistic data volumes and conditions |
| Benchmarking with trivial inputs | Use representative production-scale data |
| Ignoring memory_time | Memory allocation matters — always include `memory_time` |
| Comparing different machines | Run before/after on same hardware, same conditions |

## The Correct Workflow

```
User reports slowness
  → Has profiling data?
      NO  → REFUSE advice. Profile first.
      YES → Has baseline benchmark?
              NO  → Create baseline benchmark
              YES → Suggest optimization based on data
                    → Benchmark optimization
                    → Compare results
```

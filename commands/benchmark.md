---
description: Create or run Benchee benchmarks
argument-hint: <function-or-module>
allowed-tools:
  - "Task"
  - "Bash(mix *)"
  - "Read"
  - "Write"
  - "Edit"
  - "Glob"
  - "Grep"
model: sonnet
---

# Benchmark Command

Create and run Benchee benchmarks with representative data for performance analysis.

## What It Does

Automates benchmarking with data-driven performance testing:

1. **Identify Benchmark Target** - Function, module, or algorithm
2. **Analyze Complexity** - Estimate O(n) characteristics
3. **Generate Representative Data** - Create realistic test data
4. **Create Benchee Benchmark** - Write benchmark file with multiple inputs
5. **Run Benchmark** - Execute and analyze results
6. **Report Findings** - Performance metrics with recommendations

## Usage

```bash
/benchmark MyApp.OrderProcessor.process_batch/1
/benchmark lib/my_app/search.ex
/benchmark "compare Enum vs Stream for filtering"
```

## When to Use

**Benchmark when**:
- Implementing O(n²)+ algorithms (auto-triggered by architect)
- Performance regression suspected
- Comparing algorithm alternatives
- Optimizing hot paths
- Before and after optimization
- Validating performance assumptions

**Skip benchmarking if**:
- Simple O(1) or O(n) operations on small data
- Performance not critical for feature
- Premature optimization
- No performance requirements

## Implementation

### Step 1: Identify Benchmark Target

Parse the target from user input:

```markdown
Analyzing benchmark target: MyApp.OrderProcessor.process_batch/1

Finding target:
- Module: MyApp.OrderProcessor
- Function: process_batch/1
- Location: lib/my_app/order_processor.ex:42
```

If comparing alternatives:

```markdown
Benchmark request: "compare Enum vs Stream for filtering"

Identifying comparison:
- Approach 1: Enum-based filtering
- Approach 2: Stream-based filtering
- Context: Large dataset processing
- Creating benchmark to compare both approaches
```

### Step 2: Analyze Complexity

Launch **performance-analyzer** agent to analyze complexity:

```markdown
Launching performance-analyzer agent (Sonnet) for complexity analysis...

Analyzing: MyApp.OrderProcessor.process_batch/1

Agent will:
1. Read implementation
2. Identify nested iterations
3. Calculate algorithmic complexity
4. Estimate real-world impact with project data sizes
5. Recommend benchmark data sizes
6. Create appropriate benchmark

Waiting for analysis...
```

### Step 3: Performance Analyzer Process

Agent analyzes the code:

```elixir
# Current implementation
def process_batch(orders) do
  Enum.map(orders, fn order ->
    # ⚠️ O(n²) - nested Enum.filter for each order
    line_items = Enum.filter(order.line_items, fn item ->
      Enum.any?(inventory, &match_item?(&1, item))
    end)

    %{order | processed_items: line_items}
  end)
end
```

**Complexity analysis**:

```markdown
## Complexity Analysis

**Algorithm**: Nested iterations with Enum.map + Enum.filter + Enum.any
**Complexity**: O(n × m × k) where:
- n = number of orders
- m = line items per order
- k = inventory size

**Real-world impact** (based on project data):
- Typical: 100 orders, 5 items each, 1000 inventory = 500,000 operations
- Peak: 1000 orders, 10 items each, 5000 inventory = 50,000,000 operations (~5s)

**Recommendation**: Optimize to O(n × m) by preprocessing inventory into lookup map
```

### Step 4: Generate Benchmark File

Create benchmark in `bench/` directory:

```elixir
# bench/order_processor_benchmark.exs
#
# Benchmark for MyApp.OrderProcessor.process_batch/1
# Created: 2025-01-16
# Complexity: O(n × m × k) → O(n × m) optimization

# Setup test data factories
Code.require_file("../test/support/factory.ex", __DIR__)

alias MyApp.{OrderProcessor, Factory}

# Original O(n × m × k) implementation
defmodule Original do
  def process_batch(orders, inventory) do
    Enum.map(orders, fn order ->
      line_items = Enum.filter(order.line_items, fn item ->
        Enum.any?(inventory, &match_item?(&1, item))
      end)

      %{order | processed_items: line_items}
    end)
  end

  defp match_item?(inv_item, order_item) do
    inv_item.sku == order_item.sku
  end
end

# Optimized O(n × m) implementation
defmodule Optimized do
  def process_batch(orders, inventory) do
    # Build lookup map once: O(k)
    inventory_map =
      inventory
      |> Enum.map(&{&1.sku, &1})
      |> Map.new()

    # Process with map lookup: O(n × m)
    Enum.map(orders, fn order ->
      line_items = Enum.filter(order.line_items, fn item ->
        Map.has_key?(inventory_map, item.sku)
      end)

      %{order | processed_items: line_items}
    end)
  end
end

# Generate representative test data
inventory_100 = Factory.build_list(100, :inventory_item)
inventory_1000 = Factory.build_list(1000, :inventory_item)
inventory_5000 = Factory.build_list(5000, :inventory_item)

orders_10 = Factory.build_list(10, :order_with_items, items_count: 5)
orders_100 = Factory.build_list(100, :order_with_items, items_count: 5)
orders_1000 = Factory.build_list(1000, :order_with_items, items_count: 10)

# Run benchmarks with different data sizes
Benchee.run(
  %{
    "original O(n×m×k)" => fn {orders, inventory} ->
      Original.process_batch(orders, inventory)
    end,
    "optimized O(n×m)" => fn {orders, inventory} ->
      Optimized.process_batch(orders, inventory)
    end
  },
  inputs: %{
    "small (10 orders, 100 inventory)" =>
      {orders_10, inventory_100},

    "typical (100 orders, 1K inventory)" =>
      {orders_100, inventory_1000},

    "peak (1K orders, 5K inventory)" =>
      {orders_1000, inventory_5000}
  },
  time: 10,
  memory_time: 5,
  formatters: [
    Benchee.Formatters.Console,
    {Benchee.Formatters.HTML, file: "bench/results/order_processor.html"}
  ]
)
```

### Step 5: Run Benchmark

Execute the benchmark:

```bash
# Create bench directory if needed
mkdir -p bench/results

# Run benchmark
mix run bench/order_processor_benchmark.exs
```

### Step 6: Analyze Results

Parse and present benchmark output:

```markdown
## Benchmark Results: order_processor.process_batch/1

### Performance Summary

**Small dataset** (10 orders, 100 inventory):
| Implementation | IPS | Average | vs Original |
|----------------|-----|---------|-------------|
| Optimized O(n×m) | 15.2 K | 65.8 μs | Baseline |
| Original O(n×m×k) | 12.4 K | 80.6 μs | 1.22x slower |

**Typical dataset** (100 orders, 1K inventory):
| Implementation | IPS | Average | vs Original |
|----------------|-----|---------|-------------|
| Optimized O(n×m) | 1.85 K | 540 μs | Baseline |
| Original O(n×m×k) | 245 | 4.08 ms | **7.55x slower** |

**Peak dataset** (1K orders, 5K inventory):
| Implementation | IPS | Average | vs Original |
|----------------|-----|---------|-------------|
| Optimized O(n×m) | 185 | 5.4 ms | Baseline |
| Original O(n×m×k) | 2.8 | 357 ms | **66x slower** |

### Memory Impact

**Typical dataset**:
- Original: 45.2 MB allocated
- Optimized: 12.8 MB allocated
- **Reduction**: 71% less memory

### Key Findings

1. **Complexity validated**: Performance degrades exponentially with data size
2. **Critical at scale**: 66x slower at peak load (unacceptable)
3. **Memory efficient**: 71% reduction in allocations
4. **Clear winner**: Optimized O(n×m) approach recommended

### Recommendation

**Action**: Implement optimized O(n×m) version immediately

**Impact**:
- Peak load: 357ms → 5.4ms (66x faster)
- Memory: 45MB → 13MB (71% reduction)
- Scalability: Linear vs exponential growth

**Risk**: Low - optimization maintains same logic, just preprocessing

**Effort**: 2-3 hours including tests
```

### Step 7: Integration with Architecture

When benchmark auto-triggered by architect:

```markdown
## Auto-Benchmark Triggered

Context: elixir-architect detected O(n²) complexity during feature design

Feature: Product search with filtering
Function: MyApp.Products.search_with_filters/2
Detected complexity: O(n × f) where f = number of filters

Creating benchmark to validate performance assumptions...

[Benchmark creation and execution...]

Results show acceptable performance up to 10K products with 5 filters.
Architecture approved for implementation.
```

## Benchmark File Organization

Organize benchmarks by module:

```
bench/
├── results/              # HTML and JSON results
│   ├── order_processor.html
│   ├── product_search.html
│   └── user_query.html
├── order_processor_benchmark.exs
├── product_search_benchmark.exs
├── user_query_benchmark.exs
└── README.md            # Index of all benchmarks
```

### Benchmark README Template

Create `bench/README.md`:

```markdown
# Performance Benchmarks

Track all performance benchmarks for the project.

## Active Benchmarks

### Order Processor
- **File**: order_processor_benchmark.exs
- **Created**: 2025-01-16
- **Complexity**: O(n²) → O(n) optimization
- **Status**: ✅ Optimized (66x improvement)
- **Results**: bench/results/order_processor.html

### Product Search
- **File**: product_search_benchmark.exs
- **Created**: 2025-01-18
- **Complexity**: O(n × f) linear with filters
- **Status**: ✅ Acceptable (<100ms at peak)
- **Results**: bench/results/product_search.html

## Running Benchmarks

```bash
# Run specific benchmark
mix run bench/order_processor_benchmark.exs

# Run all benchmarks
for file in bench/*_benchmark.exs; do
  echo "Running $file..."
  mix run "$file"
done
```

## Interpreting Results

- **IPS** (iterations per second): Higher is better
- **Average**: Time per operation
- **Deviation**: Consistency of results (<20% is good)
- **Memory**: Allocations per operation

## When to Re-run

- After optimization changes
- Before deploying performance-sensitive features
- When data sizes change significantly
- Quarterly performance review
```

## Configuration

### Benchmark Defaults

Based on project context:

**Data sizes** (from project-learnings.md or defaults):
- Small: 10-100 items (unit test scale)
- Typical: 1K-10K items (average production load)
- Peak: 100K+ items (maximum expected load)

**Timing**:
- time: 10 seconds per scenario (accurate measurements)
- memory_time: 5 seconds (memory profiling)
- warmup: 2 seconds (JIT compilation)

**Output formats**:
- Console (always)
- HTML report (for detailed analysis)
- JSON (optional, for CI/CD integration)

## Error Handling

### Benchmark Target Not Found

```
❌ Benchmark Target Not Found

Target: MyApp.MissingModule.function/1
Error: Module or function does not exist

Check:
- Module name spelling
- Function exists and is exported
- File has been compiled

Try: mix compile
```

### Benchmark Failed to Run

```
❌ Benchmark Execution Failed

Error: ** (UndefinedFunctionError) function Factory.build_list/2 is undefined

Issue: Test factories not available in benchmark context

Fix: Add to benchmark file:
Code.require_file("../test/support/factory.ex", __DIR__)

Ensure test support files are accessible.
```

### Insufficient Data Range

```
⚠️  Benchmark Warning

Issue: Only testing small data size (10 items)

Recommendation: Add larger data sizes to reveal complexity:
- Small: 10-100 items
- Typical: 1K-10K items
- Peak: 100K items

Large data sizes reveal O(n²) and O(n log n) differences.
```

## Best Practices

1. **Representative data**: Use realistic data sizes from production
2. **Multiple sizes**: Test small, typical, and peak loads
3. **Compare alternatives**: Always benchmark before/after or option A vs B
4. **Memory matters**: Track memory usage, not just speed
5. **Warmup**: Allow JIT compilation before measurements
6. **Document context**: Explain why benchmark was created
7. **Version control**: Commit benchmark files
8. **Re-run after changes**: Validate optimizations work

## Integration with Other Commands

**Triggered by**:
- `/feature` (architect detects O(n²)+)
- User request (`/benchmark`)
- `/review` (performance concerns)

**Triggers**:
- Performance-analyzer agent
- Results inform optimization decisions
- Updates to project-learnings.md

**Related commands**:
- `/cognitive-audit` - If optimization makes code complex
- `/algorithm-research` - For advanced optimization techniques
- `/review` - Validate benchmark-driven changes

## Example: Comparing Enum vs Stream

```elixir
# bench/enum_vs_stream_benchmark.exs

data_1k = Enum.to_list(1..1_000)
data_10k = Enum.to_list(1..10_000)
data_100k = Enum.to_list(1..100_000)

Benchee.run(
  %{
    "Enum pipeline" => fn data ->
      data
      |> Enum.filter(&rem(&1, 2) == 0)
      |> Enum.map(&(&1 * 2))
      |> Enum.take(10)
    end,
    "Stream pipeline" => fn data ->
      data
      |> Stream.filter(&rem(&1, 2) == 0)
      |> Stream.map(&(&1 * 2))
      |> Enum.take(10)
    end
  },
  inputs: %{
    "1K items" => data_1k,
    "10K items" => data_10k,
    "100K items" => data_100k
  },
  time: 10,
  memory_time: 5
)
```

**Results interpretation**:

```markdown
## Enum vs Stream Comparison

**Finding**: Stream wins for large datasets when only partial results needed

**1K items**:
- Enum: 125 μs (baseline)
- Stream: 142 μs (1.14x slower) - overhead not worth it

**10K items**:
- Enum: 1.25 ms (baseline)
- Stream: 890 μs (1.4x faster) - Stream starts winning

**100K items**:
- Enum: 12.5 ms (baseline)
- Stream: 950 μs (13x faster!) - Stream clearly better

**Recommendation**: Use Stream when:
- Dataset >10K items
- Taking/limiting results (not consuming all)
- Memory pressure concerns

Use Enum when:
- Dataset <1K items
- Consuming all results anyway
- Simplicity preferred
```

## Success Criteria

Benchmark succeeds when:
- ✅ Representative data sizes tested
- ✅ Multiple scenarios covered (small/typical/peak)
- ✅ Clear performance comparison
- ✅ Memory usage measured
- ✅ Actionable recommendations provided
- ✅ Results saved for future reference
- ✅ Complexity assumptions validated

## Related Commands

- `/feature` - Architecture phase may auto-trigger benchmarks
- `/spike-migrate` - Benchmark during migration for validation
- `/review` - May recommend benchmarking
- `/cognitive-audit` - Balance performance vs complexity
- `/algorithm-research` - Advanced optimization techniques

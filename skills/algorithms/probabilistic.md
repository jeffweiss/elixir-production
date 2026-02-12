# Probabilistic Data Structures

Trade perfect accuracy for dramatic space savings and speed. Essential for large-scale systems.

## HyperLogLog (2007)

Estimates cardinality (unique count) with configurable accuracy using minimal memory.

- **Space**: 1.5 KB for billions of elements (vs 8 GB exact for 1 billion)
- **Accuracy**: ±2% typical with 1.5 KB

```elixir
# {:hyperloglog, "~> 1.0"}
hll = HyperLogLog.new(14)  # 14-bit precision

hll =
  Enum.reduce(1..1_000_000, hll, fn i, acc ->
    HyperLogLog.add(acc, "user_#{i}")
  end)

estimated_count = HyperLogLog.count(hll)  # ~1,000,000 ±2%
```

**Use cases**: Unique visitor counting, distinct value estimation, real-time analytics.

**Production pattern**:
```elixir
defmodule MyApp.Analytics.UniqueVisitors do
  use GenServer

  def init(_opts) do
    {:ok, %{hll: HyperLogLog.new(16)}}  # 16-bit = ~0.8% error, 64 KB
  end

  def track_visitor(user_id), do: GenServer.cast(__MODULE__, {:track, user_id})
  def get_count, do: GenServer.call(__MODULE__, :count)

  def handle_cast({:track, user_id}, state) do
    {:noreply, %{state | hll: HyperLogLog.add(state.hll, to_string(user_id))}}
  end

  def handle_call(:count, _from, state) do
    {:reply, HyperLogLog.count(state.hll), state}
  end
end
```

**Paper**: Flajolet et al., 2007

## Cuckoo Filters (2014)

Space-efficient set membership testing with deletion support. Improves on Bloom filters.

- **Space**: ~1.5 bytes per item for 3% false positive rate
- **Advantages over Bloom**: Supports deletion, better space efficiency, better cache locality

```elixir
# {:cuckoo_filter, "~> 0.1"}
filter = CuckooFilter.new(capacity: 1_000_000)
filter = CuckooFilter.add(filter, "item1")
CuckooFilter.contains?(filter, "item1")  # true

# Unlike Bloom filters, can delete
filter = CuckooFilter.delete(filter, "item1")
```

**Use cases**: Cache invalidation, spam filtering, distributed deduplication, rate limiting with expiration.

**Paper**: Fan et al., 2014

## Count-Min Sketch (2005)

Frequency estimation in streams. Answers "how many times has X appeared?" with bounded error.

- **Space**: Few KB for millions of items
- **Accuracy**: Overestimates by at most ε×N with probability 1-δ

```elixir
# {:count_min_sketch, "~> 0.1"} or write custom
cms = CountMinSketch.new(epsilon: 0.001, delta: 0.01)

cms = Enum.reduce(events, cms, fn event, acc ->
  CountMinSketch.add(acc, event.type)
end)

CountMinSketch.count(cms, "page_view")  # Estimated count
```

**Use cases**: Real-time analytics (top K), network monitoring, heavy hitter detection, frequency-based rate limiting.

**Paper**: Cormode & Muthukrishnan, 2005

## Selection Guide

| Need | Structure | Space | Accuracy |
|------|-----------|-------|----------|
| Unique count | HyperLogLog | 16 KB | ±2% |
| Set membership (no delete) | Bloom Filter | 1.8 MB/1M items | 2% FP |
| Set membership (with delete) | Cuckoo Filter | 1.5 MB/1M items | 2% FP |
| Frequency estimation | Count-Min Sketch | 40 KB/100M events | 1% error |

## Elixir Libraries

| Type | Library | Maturity |
|------|---------|----------|
| HyperLogLog | `hyperloglog` | Stable |
| Bloom Filters | `bloomex` | Stable |
| Cuckoo Filters | `cuckoo_filter` | Beta |
| Count-Min Sketch | Write custom | No stable library |

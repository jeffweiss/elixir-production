# Streaming Algorithms

Algorithms that process data in a single pass with bounded memory — essential for real-time metrics, time-series analysis, and high-throughput data pipelines.

## Decision Table

| Problem | Algorithm | Memory | Use When |
|---------|-----------|--------|----------|
| Recent N items | Circular buffer / `:queue` | O(N) | Sliding window, recent events |
| Running average/sum | Exponential moving average | O(1) | Smoothed metrics, trend detection |
| Sample from stream | Reservoir sampling | O(k) | Fair sample without knowing stream size |
| Approximate percentiles | t-digest | O(compression) | P50/P95/P99 from streaming data |
| Top-K frequent items | Count-Min Sketch + heap | O(k + sketch) | Most popular pages, heavy hitters |
| Unique count (streaming) | HyperLogLog | O(1) | See `probabilistic.md` |

## Sliding Window

### Fixed-Size Window with :queue

```elixir
defmodule MyApp.SlidingWindow do
  defstruct [:max_size, :queue, :count]

  def new(max_size) do
    %__MODULE__{max_size: max_size, queue: :queue.new(), count: 0}
  end

  def add(%{count: count, max_size: max} = window, item) when count >= max do
    {_, queue} = :queue.out(window.queue)
    %{window | queue: :queue.in(item, queue)}
  end

  def add(window, item) do
    %{window | queue: :queue.in(item, window.queue), count: window.count + 1}
  end

  def to_list(window), do: :queue.to_list(window.queue)

  def average(window) do
    list = to_list(window)
    if list == [], do: 0, else: Enum.sum(list) / length(list)
  end
end

# Track last 100 response times
window = SlidingWindow.new(100)
window = SlidingWindow.add(window, 42)
window = SlidingWindow.add(window, 38)
SlidingWindow.average(window)
```

### Time-Based Window

```elixir
defmodule MyApp.TimeWindow do
  def new(duration_ms) do
    %{events: :queue.new(), duration_ms: duration_ms}
  end

  def add(window, event) do
    now = System.monotonic_time(:millisecond)
    window
    |> expire_old(now)
    |> Map.update!(:events, &:queue.in({now, event}, &1))
  end

  def count(window) do
    now = System.monotonic_time(:millisecond)
    window = expire_old(window, now)
    :queue.len(window.events)
  end

  defp expire_old(window, now) do
    cutoff = now - window.duration_ms
    events = drop_before(window.events, cutoff)
    %{window | events: events}
  end

  defp drop_before(queue, cutoff) do
    case :queue.peek(queue) do
      {:value, {timestamp, _}} when timestamp < cutoff ->
        {_, queue} = :queue.out(queue)
        drop_before(queue, cutoff)
      _ ->
        queue
    end
  end
end

# Rate counter: events in last 60 seconds
counter = TimeWindow.new(60_000)
counter = TimeWindow.add(counter, :request)
TimeWindow.count(counter)  # => 1
```

## Exponential Moving Average (EMA)

Smoothed metric that gives more weight to recent values. O(1) memory — no buffer needed.

```elixir
defmodule MyApp.EMA do
  defstruct [:alpha, :value]

  @doc """
  Alpha controls smoothing: 0.1 = slow (smooth), 0.9 = fast (responsive).
  For N-period equivalent: alpha = 2 / (N + 1)
  """
  def new(alpha \\ 0.1), do: %__MODULE__{alpha: alpha, value: nil}

  def update(%{value: nil} = ema, value), do: %{ema | value: value}

  def update(ema, value) do
    %{ema | value: ema.alpha * value + (1 - ema.alpha) * ema.value}
  end

  def get(%{value: value}), do: value
end

# Track smoothed response time
ema = EMA.new(0.1)  # ~20-period smoothing
ema = ema |> EMA.update(42) |> EMA.update(38) |> EMA.update(55)
EMA.get(ema)  # => smoothed value
```

## Reservoir Sampling

Select k random items from a stream of unknown size, where each item has equal probability of being selected.

```elixir
defmodule MyApp.ReservoirSample do
  def new(k), do: %{k: k, reservoir: [], count: 0}

  def add(%{count: count, k: k} = state, item) when count < k do
    %{state | reservoir: [item | state.reservoir], count: count + 1}
  end

  def add(%{count: count, k: k} = state, item) do
    count = count + 1
    j = :rand.uniform(count)

    reservoir =
      if j <= k do
        List.replace_at(state.reservoir, j - 1, item)
      else
        state.reservoir
      end

    %{state | reservoir: reservoir, count: count}
  end

  def sample(%{reservoir: reservoir}), do: reservoir
end

# Sample 100 items from a stream of millions
sampler = ReservoirSample.new(100)
sampler = Enum.reduce(huge_stream, sampler, &ReservoirSample.add(&2, &1))
ReservoirSample.sample(sampler)  # => 100 uniformly random items
```

**Use cases**: Log sampling, A/B test assignment from streaming data, representative subset from large datasets.

## Production Pattern: Telemetry-Based Metrics

Combine streaming algorithms with Telemetry for real-time application metrics:

```elixir
defmodule MyApp.Metrics.ResponseTime do
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    :telemetry.attach(
      "response-time-tracker",
      [:phoenix, :endpoint, :stop],
      &__MODULE__.handle_event/4,
      nil
    )

    {:ok, %{
      ema: MyApp.EMA.new(0.1),
      window: MyApp.SlidingWindow.new(1000),
      count: 0
    }}
  end

  def handle_event(_event, %{duration: duration}, _metadata, _config) do
    duration_ms = System.convert_time_unit(duration, :native, :millisecond)
    GenServer.cast(__MODULE__, {:record, duration_ms})
  end

  def handle_cast({:record, duration_ms}, state) do
    {:noreply, %{state |
      ema: MyApp.EMA.update(state.ema, duration_ms),
      window: MyApp.SlidingWindow.add(state.window, duration_ms),
      count: state.count + 1
    }}
  end

  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  def handle_call(:stats, _from, state) do
    recent = MyApp.SlidingWindow.to_list(state.window)
    sorted = Enum.sort(recent)
    len = length(sorted)

    stats = %{
      ema: MyApp.EMA.get(state.ema),
      p50: percentile(sorted, len, 0.5),
      p95: percentile(sorted, len, 0.95),
      p99: percentile(sorted, len, 0.99),
      total_requests: state.count
    }

    {:reply, stats, state}
  end

  defp percentile(_, 0, _), do: 0
  defp percentile(sorted, len, p) do
    index = round(p * (len - 1))
    Enum.at(sorted, index)
  end
end
```

## Common Mistakes

- **Storing all events for metrics**: If you need "average over last hour," use a time-based window or EMA — not a growing list.
- **Using Enum.sort on every query for percentiles**: Sort once when reading, not on every insert. Or use a t-digest for streaming approximate percentiles.
- **Fixed-size window when time-based is needed**: A window of "last 100 requests" has very different behavior at 10 req/s vs 10,000 req/s. Usually you want time-based.
- **Not using monotonic time**: `System.monotonic_time/1` for durations, never `DateTime.utc_now()`. Wall clock jumps break time-window calculations.
- **Forgetting EMA initialization**: First value should seed the EMA, not be averaged with nil/0.

**See also**: `statistics.md` for batch statistical analysis, anomaly detection, and A/B testing.

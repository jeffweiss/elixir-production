# Observability

You can't fix what you can't see. Observability is structured insight layered at the right abstraction levels — not "visibility into everything."

## Telemetry Layers

| Layer | What to Measure | Elixir Tools |
|-------|----------------|--------------|
| OS/VM | Memory, CPU, scheduler utilization, GC | `:erlang.system_info/1`, `:erlang.statistics/1`, `recon` |
| Framework | Request latency, queue depths, pool utilization | `Telemetry`, `:telemetry.attach/4` |
| Application | Business metrics, context operation counts, error rates | Custom `Telemetry` events, StatsD/Prometheus |
| User | Satisfaction, error pages served, timeout rates | Application-level tracking |

```elixir
# Telemetry that tells a story for the person paged at 3am
:telemetry.execute(
  [:my_app, :orders, :create],
  %{duration: duration, queue_time: sojourn},
  %{status: status, payment_method: method}
)
```

## Span Convention

**Use the span convention for telemetry events** (Keathley, "Telemetry Conventions"): Emit three events per operation — `[:lib, :function, :start]`, `[:lib, :function, :stop]`, and `[:lib, :function, :exception]`. This trio covers ~90% of APM, tracing, and time-series use cases. Never let users customize event names — consistency enables monitoring tools to reliably capture data. Emit telemetry from core code, not middleware. Treat telemetry as a public API: test it, because breaking changes damage production monitoring silently.

## Tracing as Analytics

**Treat tracing as queryable analytics, not just debugging** (Luu, "A simple way to get more value from tracing"): Most organizations use traces only for debugging individual requests. The real ROI comes from making trace data queryable — export to SQL tables for aggregate analysis. This reveals load amplification patterns, unusual service dependencies, and call-path-specific latency that per-service metrics can't show. Tracing and metrics are complementary, not substitutes: metrics show *what* is happening system-wide; traces show *why* through specific call paths.

## Logging

**Log facts, not interpretations**: Logs should record what happened, not what you think it means. Interpretations become wrong as the system evolves; facts remain useful forever.

```elixir
# ❌ Interpretation — misleading when the real cause is something else
Logger.warning("Database seems slow, possible network issue")

# ✅ Facts — lets the reader (or future you) draw correct conclusions
Logger.info("Database query completed",
  query_time_ms: 1547,
  rows_returned: 0,
  connection_pool_wait_ms: 1200
)
```

## Process Labels (OTP 27+)

Label dynamic processes for debugging and observability. Labels appear in Observer, crash dumps, and `Process.info/2`. Essential when running hundreds of similar workers.

```elixir
# Label a process for identification in Observer and crash dumps
defmodule MyApp.OrderWorker do
  use GenServer

  def start_link(order_id) do
    GenServer.start_link(__MODULE__, order_id)
  end

  def init(order_id) do
    :proc_lib.set_label({:order_worker, order_id})
    {:ok, %{order_id: order_id}}
  end
end

# Read a process's label
:proc_lib.get_label(pid)
# => {:order_worker, "order-123"}
```

Use labels whenever you create dynamic processes — Task workers, Broadway consumers, Oban workers, or any process started via DynamicSupervisor. Without labels, crash dumps show hundreds of identical `erlang:apply/2` entries with no way to tell them apart.

## Operator Experience (OX)

Design telemetry for the person who gets paged at 3am. Every metric should answer: What changed? What's the impact? Where's the bottleneck?

**Avoid zombie metrics**: Metrics collected but never looked at, or that can't drive a decision, are waste. MTBF and MTTR are often zombie metrics — they measure averages that obscure actual failure modes. A metric's value is the behavior it drives. If nobody acts on it, delete it.

**Use monotonic time**: `System.monotonic_time/1` for measuring durations, never `DateTime.utc_now()`. Wall clock can jump (NTP adjustments, VM migration).

**A 100% healthy system is suspicious**: If monitoring shows zero errors, zero latency spikes, and zero warnings, the most likely explanation is broken monitoring — not a perfect system.

## Alerting

**Alerts should direct attention, not just report conditions**: The most common alerting failure is flooding operators with context-free notifications during cascading failures — exactly when cognitive load is highest (Woods, "The Alarm Problem"). Design alerts that answer: What changed? What's the impact? Where should I look first? Emphasize *departures from baseline* rather than absolute thresholds, and use spatial/temporal patterns that support preattentive processing (color changes, trend lines) rather than requiring operators to read and interpret each alert individually.

**Make automated interventions visible**: OTP supervision trees restart crashed processes automatically — which is correct. But invisible automation creates a dangerous gap: operators lose awareness of what the system is doing on their behalf (Bainbridge, "Ironies of Automation"). Log every supervisor restart with context (which child, how many times, how recently). Emit telemetry for restart frequency. If a process restarts 50 times in an hour but "works," that's a walking-dead system — the bug is being hidden, not fixed.

```elixir
# ❌ Invisible automation — restarts hide the problem
children = [
  {MyWorker, []}
]
Supervisor.init(children, strategy: :one_for_one)

# ✅ Visible automation — restarts are tracked and alertable
:telemetry.execute(
  [:my_app, :supervisor, :restart],
  %{count: 1},
  %{child: child_id, reason: reason, supervisor: __MODULE__}
)
```

## Degraded Mode and Gray Failures

**Systems always run in degraded mode**: Complex systems are never fully healthy — components are always partially broken, recently repaired, or operating outside design parameters (Cook, "How Complex Systems Fail"). Health checks that require every component to be perfect will fire constantly. Design health checks around *acceptable degradation*: the system is healthy when it can serve its core purpose, even if some subsystems are impaired.

**Monitor capacity headroom, not just utilization**: The transition from resilient to brittle is sudden and nonlinear — a system at 85% capacity can absorb a traffic spike, while one at 95% cannot (Cook & Rasmussen, "Going Solid"). Alert on *remaining capacity* rather than current utilization: pool checkout wait times trending upward, queue depths growing faster than drain rates, scheduler utilization exceeding 70%. By the time utilization hits 100%, the system has already gone solid.

**Detect gray failures through differential observability**: A component can appear healthy to its own health checks while being unhealthy from the perspective of its consumers — this is a *gray failure* (Huang et al., "Gray Failure"). Detection requires observing health from *multiple vantage points*: not just "is the service up?" but "is the service working for its actual consumers?"

```elixir
# ❌ Single-perspective health check — misses gray failures
def health_check do
  case MyApp.Repo.query("SELECT 1") do
    {:ok, _} -> :healthy
    _ -> :unhealthy
  end
end

# ✅ Multi-perspective health check — detects differential observability
def health_check do
  %{
    self_check: MyApp.Repo.query("SELECT 1"),
    consumer_error_rate: Telemetry.get_counter([:my_app, :repo, :errors]) |> rate_per_minute(),
    consumer_p99_latency: Telemetry.get_summary([:my_app, :repo, :query_time]) |> p99()
  }
  |> evaluate_health()
end
```

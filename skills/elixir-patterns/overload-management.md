# Overload Management

When a system receives more work than it can handle, there are only two sustainable responses: **back-pressure** (slow the caller down) and **load-shedding** (drop work). Queues without bounds don't fix overload — they hide it until the system runs out of memory.

## Strategy Overview

| Strategy | When | Mechanism |
|----------|------|-----------|
| Back-pressure | Caller can wait | Bounded mailboxes, `GenServer.call` timeouts, pool checkout limits |
| Load-shedding | Freshness matters more than completeness | Drop oldest messages, reject requests, sample |
| Circuit breaker | Remote dependency is *completely* failing | Trip open after N failures, half-open to test recovery |
| Bounded queue | Buffer small bursts | Fixed-size queue; reject or drop when full |
| Token bucket retries | Retry with self-regulation | Deposit 0.1 tokens/success, spend 1/retry; auto-limits under load |

```elixir
# Back-pressure with GenServer.call timeout — caller slows down naturally
def submit_work(item) do
  GenServer.call(__MODULE__, {:submit, item}, 5_000)
end

# Load-shedding with ETS atomic counter
def allow_request?(client_id) do
  count = :ets.update_counter(:rate_limits, client_id, {2, 1}, {client_id, 0})
  count <= @max_requests_per_window
end

# Circuit breaker with :fuse library
:fuse.install(:external_api, {{:standard, 5, 10_000}, {:reset, 60_000}})

case :fuse.ask(:external_api, :sync) do
  :ok -> call_external_api(params)
  :blown -> {:error, :circuit_open}
end
```

## Circuit Breaker Critique

**Circuit breakers may harm resilience** (Brooker, "Will circuit breakers solve my problems?"): Circuit breakers convert *partial* failures into *complete* failures. In a sharded database where one partition (A-H) is overloaded, a circuit breaker either trips and blocks requests to healthy shards too, or stays open and provides no protection. The fundamental problem: circuit breakers lack information about which *specific* calls will succeed. Prefer token bucket retries for most cases — they self-regulate without binary trip/reset decisions.

## Token Bucket Retries

Self-regulating retry pattern without threshold tuning:

```elixir
defmodule RetryBucket do
  use GenServer

  @max_tokens 10.0

  def allow_retry?(bucket) do
    GenServer.call(bucket, :allow_retry?)
  end

  def record_success(bucket) do
    GenServer.cast(bucket, :success)
  end

  def handle_call(:allow_retry?, _from, tokens) when tokens >= 1.0 do
    {:reply, true, tokens - 1.0}
  end
  def handle_call(:allow_retry?, _from, tokens) do
    {:reply, false, tokens}
  end

  def handle_cast(:success, tokens) do
    {:noreply, min(tokens + 0.1, @max_tokens)}
  end
end
```

## Backoff Limitations

**Backoff only helps if it reduces total work** (Brooker, "What is Backoff For?"): Backoff is valuable short-term for traffic spikes and for serial clients with bounded count. But with unbounded parallel clients (web users), backoff merely postpones requests — every deferred request still arrives eventually. Backoff does not solve persistent overload; load-shedding does.

## Key Principles

**Every queue must be bounded**: Unbounded queues are a latent memory leak triggered by any traffic spike. Measure **sojourn time** (how long items wait in queue) — if it grows, you're overloaded regardless of queue depth.

**Design for cold restart under load**: Systems must handle starting up when traffic is already flowing. If your application starts with empty caches and all connections initializing simultaneously, the thundering herd will overwhelm dependencies. Stagger connection establishment, use circuit breakers from the start, and serve degraded responses until warm.

**Make operations idempotent**: In production, messages get retried, requests get duplicated, and jobs get re-enqueued. Design operations so that executing them twice produces the same result as once.

```elixir
# Idempotent insert — safe to retry
def create_payment(attrs) do
  %Payment{}
  |> Payment.changeset(attrs)
  |> Repo.insert(
    on_conflict: :nothing,
    conflict_target: [:idempotency_key]
  )
end
```

## Adaptive Concurrency

**Static concurrency limits guess wrong** (Keathley, "Using Regulator"): Too low wastes capacity, too high causes overload. Adaptive concurrency observes latency and error rates, then adjusts limits dynamically using Little's Law (L = λ × W). Use AIMD (Additive Increase, Multiplicative Decrease) for outbound calls. **Autoscaling does not solve overload** — it often makes it worse by increasing downstream pressure, especially on databases.

## Libraries

- `fuse` — Circuit breakers
- `poolboy` — Bounded worker pools
- `sbroker` — Sojourn-time-based broker
- `regulator` — Adaptive concurrency limits

# Tail Latency Reduction and Measurement

## Latency Measurement Pitfalls

Even with profiling data, common measurement errors produce misleading results (Luu, "Some latency measurement pitfalls"):

**Server-side latency ≠ client-observed latency**: Requests pass through client networking -> network -> server networking -> server code. Server metrics capture only user code execution. In one case, server p99 was 16ms while client p99 was 240ms — a **15x gap** from queuing in network stacks, kernel throttling, and thread pool congestion. Always measure from the client's perspective.

**Averaging per-shard tail latencies is meaningless**: Taking the average of per-shard p99 values defeats the purpose of monitoring tail latency. On a 100-node cluster where one node's tail latency increases 10x, the average shows only a 9% increase — masking the real impact on affected users. Export histogram data and reconstruct cluster-wide percentiles from raw distributions.

**Minutely resolution hides sub-minute bursts**: A large latency spike followed by 30 seconds of low request rate can be invisible in standard minute-granularity metrics. For critical paths, collect at secondly or sub-secondly granularity.

**Coordinated omission**: If your load generator waits for a response before sending the next request, slow responses reduce the *measured* request rate, hiding the true latency that queued requests would experience. Use open-loop load generators (constant arrival rate) for realistic latency measurement.

## Tail Latency Reduction Techniques

When profiling shows that p99/p999 latency is significantly worse than median, and the system fans out to multiple backends or partitions (Dean & Barroso, "The Tail at Scale"):

| Technique | How It Works | Overhead | When to Use |
|-----------|-------------|----------|-------------|
| **Hedged requests** | Send to backup after p95 timeout of primary | ~5% extra load | Fan-out queries to sharded data |
| **Tied requests** | Enqueue on multiple servers, cancel duplicates when one completes | Minimal with cancellation | Load-balanced worker pools |
| **Micro-partitioning** | 20x more partitions than servers for fine-grained rebalancing | Management complexity | Sharded stateful services |
| **Latency probation** | Temporarily exclude slow nodes, send shadow requests to monitor recovery | Shadow request load | Heterogeneous node fleet |
| **Canary requests** | Test on small subset before full fan-out | One extra round-trip | High fan-out queries (100+ nodes) |

### Hedged Request Implementation

```elixir
defmodule HedgedRequest do
  def query(nodes, request, opts \\ []) do
    p95_timeout = Keyword.get(opts, :hedge_after_ms, 50)

    primary = Enum.random(nodes)
    backup = Enum.random(nodes -- [primary])

    task1 = Task.async(fn -> rpc_call(primary, request) end)

    # Wait for primary up to p95 timeout
    case Task.yield(task1, p95_timeout) do
      {:ok, result} ->
        result
      nil ->
        # Primary is slow — hedge with backup
        task2 = Task.async(fn -> rpc_call(backup, request) end)
        case Task.yield_many([task1, task2], 5_000) do
          [{^task1, {:ok, r}}, _] -> Task.shutdown(task2, :brutal_kill); r
          [_, {^task2, {:ok, r}}] -> Task.shutdown(task1, :brutal_kill); r
          _ -> {:error, :timeout}
        end
    end
  end
end
```

**Key insight**: At scale, the slowest component in any fan-out determines overall latency. A single slow node turns a 10ms operation into a 10-second operation.

## Fan-Out Amplification

**Tail latency amplifies with fan-out** (Brooker, "Tail Latency Might Matter More Than You Think"): With N parallel backend calls, the probability of hitting at least one slow outlier is `1 - (1 - p)^N`. At p99 with 10 parallel calls, ~10% of requests hit a tail-latency response. With 50 parallel calls, it's ~40%.

Serial call chains are worse: variance compounds by up to 25x compared to single-hop systems. Monitor end-to-end latency across realistic workflows, not just per-service metrics.

## Pool Sizing Economics

**Larger pools need less headroom** (Brooker, "Surprising Economics of Load-Balanced Systems"): Erlang's C formula shows that at the same per-server utilization, larger pools dramatically reduce queuing probability. A 5-server pool at 50% utilization queues only 3.6% of requests; a 2-server pool at the same utilization queues 13%.

Most of the benefit comes at modest scale — going from 2 to 10 servers captures most of the improvement.

**Implication for Elixir connection pools**: Don't size `pool_size` purely from "peak concurrent queries." A slightly larger pool at lower per-connection utilization yields disproportionately better tail latency. Benchmark with realistic load patterns — the non-linear queuing improvement means the "right" pool size is often larger than back-of-envelope calculations suggest.

## Simulation Before Sizing

**Simulate before committing** (Brooker, "Simple Simulations for System Builders"): Formal methods prove correctness but can't answer "what latency should we expect?" or "how much headroom do we need?"

Simple Monte Carlo simulations (often < 50 lines of code) reveal non-linear performance "knees" — the utilization threshold where latency suddenly spikes. Run simulations before committing to pool sizes, partition counts, or worker limits.

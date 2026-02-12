# Distributed Systems Production Checklist

Before deploying distributed system:

- [ ] **Consensus**: Choose CP (Raft) or AP (CRDT) based on requirements
- [ ] **Quorum**: Verify correct quorum calculation (`div(n, 2) + 1`)
- [ ] **Split-brain**: Implement detection and prevention
- [ ] **Clock drift**: Use monotonic time for intervals, NTP monitoring
- [ ] **Network partitions**: Define merge/resolution strategy
- [ ] **Cluster size**: Use Partisan if >50 nodes
- [ ] **Service discovery**: Configure libcluster for environment
- [ ] **Monitoring**: Set up distributed tracing (telemetry, OpenTelemetry)
- [ ] **Failure modes**: Test with Chaos Monkey, network partition simulation (`schism` for ExUnit-based partition testing via cookie-based node isolation)
- [ ] **Observability**: Distributed metrics, logging with trace_id
- [ ] **Strategy diversity**: Avoid identical retry/timeout/health-check logic across all services — correlated strategies create correlated failures (algorithmic monoculture)
- [ ] **Blast radius**: Shared resources (pools, GenServers, Raft clusters) partitioned so one tenant/group failure doesn't cascade to all
- [ ] **Gray failure detection**: Health checks include consumer-perspective signals, not just self-checks
- [ ] **Dependency SLAs**: Every external dependency has a degraded-mode path or its SLA is accepted as your SLA ceiling
- [ ] **Limplock detection**: Monitor operation latency percentiles, not just availability — eject nodes whose latency exceeds cluster median by >10x
- [ ] **Cache death spiral prevention**: Latency increase → queue buildup → GC pressure → more latency is the most common cascading failure pattern. Bound all queues, implement back-pressure, and limit client retries (Luu, "A decade of major cache incidents at Twitter")
- [ ] **Configuration change safety**: Treat config changes (feature flags, pool sizes, timeouts) with same rigor as code deploys — 50% of global outages stem from config changes
- [ ] **Metastable failure resistance**: Fast error paths (reject cheaper than process), bounded retries (token bucket), goodput monitoring, and load shedding at the edge
- [ ] **Redundancy audit**: Each redundant component meets all 4 conditions — complexity justified, degraded mode tested, health detection reliable, recovery to full redundancy automated
- [ ] **Poison pill defense**: Replicated state machines validate inputs at boundaries; identical replicas running identical logic on identical state will fail identically

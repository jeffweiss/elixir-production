# Resilience Architecture Principles

Apply these when designing module boundaries, supervision trees, and failure handling.

## Core Principles

- **Failures come from relationships, not parts**: The most dangerous failures emerge from component interactions, not individual modules. Design supervision trees and context boundaries around failure propagation paths, not just data flow. Ask: "When X fails, what else breaks?"

- **Preserve operational slack**: Don't optimize away buffers. Pool headroom, queue capacity margins, and timeout padding absorb traffic spikes and prevent systems from "going solid" — the sudden transition from loosely-coupled (resilient) to tightly-coupled (brittle) at saturation.

- **Safety margins erode incrementally**: Each "reasonable optimization" (smaller pool, tighter timeout, removed retry) is invisible individually but compounds. Document explicit margin targets — they're the first thing future developers will shave.

- **Design for graceful extensibility, not just robustness**: Robustness handles anticipated failures with hard walls. Extensibility handles surprises by degrading service quality instead of failing entirely. Design explicit degraded-operation modes: what does the feature do when dependencies are unavailable?

- **Preserve human intervention paths**: Automated healing, retries, and failovers must remain inspectable and overridable. If operators can't understand or stop what automation is doing, they can't fix what automation gets wrong.

- **Alert on aggregate signals, not individual events**: A single process crash is supervision working correctly. Supervision tree restart exhaustion, error rate acceleration, or queue depth growth are architectural problems. Design telemetry around these aggregate signals.

- **Best practices are a floor, not a ceiling**: OTP patterns, the escalation ladders, and testing strategies are starting points. When context demands deviation, document the reasoning — don't force-fit patterns that don't serve the problem.

## Anti-Fragility Patterns

- **Avoid algorithmic monoculture**: When every service uses identical retry logic, the same circuit breaker thresholds, and the same health check strategy, failures become correlated — all services fail the same way at the same time (Kleinberg & Raghavan, "Algorithmic Monoculture"). Deliberately vary retry intervals, stagger timeouts, and use different health check strategies across services.

- **More automation means less-prepared operators**: The more reliably OTP supervision handles failures, the less practice operators get handling them — and the less they understand the system's failure modes (Bainbridge, "Ironies of Automation"). Design runbooks that include "how to manually do what the automation does." Periodically review what supervision trees are restarting — frequent restarts mean the automation is masking bugs, not fixing them.

- **Complex failures have multiple contributing factors**: Post-incident analysis that seeks a single "root cause" will always find one — and it will always be incomplete (Cook, "How Complex Systems Fail"). Design post-mortems around contributing factors, not root causes. In the architecture: design telemetry that captures the full state of the system at failure time, not just the final error.

## Operational Principles

- **Minimize blast radius through isolation**: The most effective reliability strategy is limiting the damage any single failure can cause (Brooker et al., "Millions of Tiny Databases"). Design independent failure domains: per-tenant supervision trees, partitioned pools, isolated caches. A GenServer that serves all tenants is a single point of failure for all tenants. A DynamicSupervisor that spawns per-tenant cells limits each failure to one tenant.

- **Dependencies inherit your SLA**: A 99.99% service that hard-depends on a 99.9% service is a 99.9% service (Hamilton, "On Designing and Deploying Internet-Scale Services"). For every external dependency, design a degraded-mode path that doesn't require it, or accept the dependency's SLA as your ceiling.

- **Simple architectures first / innovation tokens**: A Python monolith on Postgres scaled to a $1.7B valuation with 70 engineers (Luu, "In defense of simple architectures"). Every organization has a limited budget of "innovation tokens" to spend on novel technology — most overestimate their supply (McKinley, "Choose Boring Technology"). Complexity burden should concentrate on unavoidable domain challenges — not infrastructure you don't yet need.

- **Metastable failures outlast their triggers**: A trigger (traffic spike, deployment, brief failure) can push a system into a bad state that persists even after the trigger is removed (Bronson et al., "Metastable Failures in Distributed Systems"). The *sustaining feedback loop* — not the trigger — is what matters. Retry amplification, cache stampedes, and GC death spirals are all self-sustaining. Design fast error paths (rejecting must be cheaper than processing), bound retry amplification with token buckets, and monitor goodput — not just throughput.

- **Watch for normalization of deviance**: Teams gradually accept increasingly risky practices as normal (Luu, "Normalization of deviance"). Five mechanisms drive it: rules seem inefficient, newcomers learn deviant processes as standard, people break rules with noble intent, individuals claim trust exemptions, and employees fear speaking up. When someone says "we always skip load testing for small changes" — that's deviance being normalized.

- **Configuration changes cause 50% of global outages**: Configuration bugs produce more severe outages than code bugs, yet most organizations lack staging and testing for config changes (Luu, "Reading postmortems"). Treat configuration changes — feature flags, pool sizes, timeout values, routing rules — with the same rigor as code deployments: review, stage, monitor, and have rollback plans.

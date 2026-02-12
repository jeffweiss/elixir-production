# Skill/Command/Agent Restructure Design

## Problem

After research mining from 8+ sources (Hebert, acolyer.org, keathley.io, theerlangelist.com, danluu.com, brooker.co.za, mcfunley.com, kleppmann.com), every skill is 6-12x the recommended size from writing-skills guidelines. Commands duplicate ~70% of skill content as inline reference material. One agent (elixir-architect) is bloated with inline resilience principles.

## Principle

Each SKILL.md becomes a concise entry point (~300-500 words) with:
1. Overview (core principle, 1-2 sentences)
2. When to Use (symptoms, triggers — CSO-optimized)
3. Quick Reference (scannable table)
4. Common Mistakes (top 3-5)
5. Pointers to reference files for deep dives

Heavy content (code examples, escalation ladders, checklists, tables) moves to supporting files. No content is deleted — it moves to where Claude can load it on demand instead of consuming 3,000-6,000 words on every skill discovery.

Commands become lean workflow orchestrators that reference skills for domain knowledge instead of duplicating it.

## Skills

### distributed-systems (6,191 words -> ~400 word SKILL.md)

```
distributed-systems/
  SKILL.md                  ~400w — overview, decision flowchart, quick ref
  escalation-ladder.md      Distribution Escalation Ladder (Levels 0-4)
  consensus.md              Raft via :ra, CRDTs via delta_crdt, quorum, fencing tokens
  clustering.md             libcluster, Partisan, distributed Erlang architecture
  failure-modes.md          Gray failures, limplocks, metastable failures, netsplits,
                              race conditions, concurrency bug taxonomy, redundancy conditions
  cap-tradeoffs.md          CAP critique, consistency models, CP vs AP decision guide
  production-checklist.md   Full deployment checklist (~20 items)
  resilience-principles.md  Architectural principles from Hebert, Brooker, Luu, Kleppmann,
                              Cook, et al. (moved from elixir-architect agent)
```

SKILL.md contents:
- Overview: "Don't distribute unless you must. When you must, choose the lowest escalation level that meets requirements."
- Decision flowchart: existing Level 0-4 ASCII diagram
- Quick reference table: maps use cases to approaches (one-liner each)
- Common mistakes: SGP anti-pattern, choosing Raft when CRDTs suffice, ignoring netsplits
- Pointers: "See consensus.md for Raft/CRDT patterns, failure-modes.md for production failure detection"

Description (keep as-is):
```
Use when building multi-node Elixir systems, choosing between Raft and CRDTs,
configuring libcluster or Partisan, debugging split-brain or netsplit scenarios,
or evaluating CP vs AP tradeoffs
```

### production-quality (4,856 words -> ~400 word SKILL.md)

```
production-quality/
  SKILL.md                  ~400w — escalation ladder summary, quick ref
  escalation-ladder.md      Full Production Readiness Ladder (L0-L5 with details)
  testing.md                Testing strategy, property-based/StreamData, TDD, integration
  security.md               SQL injection, XSS, CSRF, input validation, secrets
  observability.md          Telemetry, tracing-as-analytics, span conventions, logging
  database.md               Safe Ecto migrations, isolation level warnings, SLA dependency
  error-handling.md         Crash early patterns, 92% catastrophic failures, 3 anti-patterns
```

SKILL.md contents:
- Overview: "Production readiness is an escalation ladder — L0 (compiles) through L5 (production-hardened). Most features should reach at least L3 before merge."
- Quick reference table: each level in one row with gate criteria
- Common mistakes: skipping L2 (testing), treating L4 (observability) as optional, unsafe migrations
- Pointers: topic-specific files for deep dives

Description rewrite:
```
Use when preparing code for production, conducting reviews, running precommit
checks, adding typespecs or tests, evaluating security posture, or checking
migration safety
```

### elixir-patterns (4,783 words -> ~400 word SKILL.md)

```
elixir-patterns/
  SKILL.md                  ~400w — escalation ladder summary, quick ref
  escalation-ladder.md      Full Pattern Escalation Ladder (Levels 0-5)
  otp-patterns.md           GenServer, Supervisor, Registry, Task, Protocol,
                              process boundary rules, SGP anti-pattern
  overload-management.md    Back-pressure, load-shedding, circuit breaker critique,
                              token bucket retries, backoff, adaptive concurrency,
                              cold restart, idempotency
  domain-patterns.md        Phoenix contexts, DDD, code quality patterns
  references/
    railway.md              (already exists)
    ddd-example.md          (already exists)
```

SKILL.md contents:
- Overview: "Start with pure functions. Escalate to processes only when you need runtime concerns. Separate domain logic from temporal logic."
- Decision flowchart: Level 0-5 ASCII diagram
- Quick reference: one row per level
- Common mistakes: reaching for GenServer too early, unbounded queues, SGP on multi-node
- Pointers: otp-patterns.md, overload-management.md

Description rewrite:
```
Use when structuring Elixir code, deciding whether to use processes or
functions, designing supervision trees, handling overload, or needing
idiomatic OTP and Phoenix context patterns
```

### cognitive-complexity (4,270 words -> ~400 word SKILL.md)

```
cognitive-complexity/
  SKILL.md                  ~400w — core principles, quick ref
  escalation-ladder.md      Full Complexity Reduction Ladder (L0-L4)
  ousterhout-principles.md  Deep vs shallow modules, information hiding, tactical
                              vs strategic programming, pull complexity downward
  references/
    examples.md             (already exists)
    metrics.md              (already exists)
    patterns.md             (already exists)
```

SKILL.md contents:
- Overview: "Complexity comes from dependencies and obscurity. Reduce it by making modules deeper — simple interfaces hiding significant implementation."
- Quick reference: depth ratio metric, working memory limits, nesting thresholds
- Common mistakes: shallow decomposition, pass-through variables, temporal coupling
- Pointers: ousterhout-principles.md, escalation-ladder.md

Description (keep as-is — already symptom-focused):
```
Use when code is hard to understand, a module has too many parameters or deep
nesting, abstractions feel leaky, or you need to evaluate whether code is
deep-module or shallow-module design
```

### algorithms (3,910 words -> ~400 word SKILL.md)

```
algorithms/
  SKILL.md                  ~400w — decision guide, quick ref
  otp-builtins.md           :queue, :gb_trees, :gb_sets, :atomics, :counters, :ets
  probabilistic.md          HyperLogLog, Bloom filters, Count-Min Sketch, Cuckoo filters
  hash-functions.md         xxHash3, BLAKE3, HighwayHash selection guide
  sorting-and-search.md     Cache-efficient sorting, Okasaki structures, B-tree variants
```

SKILL.md contents:
- Overview: "Use OTP built-ins first. Escalate to specialized structures only when profiling shows a bottleneck."
- Quick reference table: maps problem types to recommended structures
- Common mistakes: reimplementing :ets, MD5/SHA for non-crypto hashing, Enum on large collections
- Pointers: otp-builtins.md, probabilistic.md

Description rewrite:
```
Use when choosing data structures, evaluating hash functions, needing
probabilistic data structures, or comparing OTP built-ins against
specialized alternatives for Elixir
```

### performance-analyzer (3,187 words -> ~400 word SKILL.md)

```
performance-analyzer/
  SKILL.md                  ~400w — Iron Law, profiler selection, quick ref
  profiling.md              cprof, eprof, fprof, tprof selection and usage,
                              database profiling, N+1 detection
  benchmarking.md           Benchee patterns, representative data, anti-patterns
  latency.md                Tail latency reduction (hedged requests + code),
                              fan-out amplification, measurement pitfalls, pool sizing
  beam-gc.md                Per-process GC, ETS for heap reduction, 4 mitigations,
                              simulation-before-sizing
```

SKILL.md contents:
- Overview: "NO OPTIMIZATION WITHOUT PROFILING DATA."
- Profiler selection table: 4 rows mapping question to tool
- Common mistakes: optimizing without data, unrealistic benchmarks, server-side-only measurement
- Pointers: profiling.md, latency.md

Description (keep as-is).

### phoenix-liveview (2,820 words -> ~400 word SKILL.md)

```
phoenix-liveview/
  SKILL.md                  ~400w — escalation ladder summary, gotchas, quick ref
  escalation-ladder.md      Full Interactivity Escalation Ladder (L0-L5)
  references/
    streams.md              (already exists)
    forms.md                (already exists)
    hooks.md                (already exists)
    auth.md                 (already exists)
```

SKILL.md contents:
- Overview: "Start with server-rendered HTML. Escalate through streams, assign_async, PubSub, hooks."
- Quick reference: one row per level
- Common gotchas: no else-if, stream ID mismatches, mount runs twice, to_form required
- Pointers: references/streams.md, references/forms.md

Description (keep as-is).

## Commands (5 large commands trimmed)

### Approach

Commands become workflow orchestrators that reference skills for domain knowledge. Keep:
- Step sequencing and agent dispatch instructions
- User-facing progress messages
- Response format templates (compact)
- Decision points and handoff logic

Remove:
- Inline code examples that exist in skills
- Duplicated checklists and domain explanations
- Full reference material

### Targets

| Command | Current | Target | Reference Instead |
|---------|---------|--------|-------------------|
| distributed-review (863 lines) | 2,729w | ~700w | distributed-systems skill files |
| spike-migrate (743 lines) | 2,608w | ~800w | production-quality skill files |
| pr-review (681 lines) | 2,268w | ~800w | production-quality + cognitive-complexity |
| learn (710 lines) | 2,066w | ~1,000w | Keep unique templates, trim examples |
| algorithm-research (571 lines) | 1,995w | ~700w | algorithms skill files |

### Remaining 6 commands (lighter trimming)

| Command | Current | Assessment |
|---------|---------|------------|
| precommit (313 lines) | 922w | Fine — mostly workflow |
| review (386 lines) | 1,231w | Light trim — some checklist duplication |
| feature (456 lines) | 1,546w | Light trim — some pattern duplication |
| cognitive-audit (418 lines) | 1,660w | Light trim — references cognitive-complexity |
| benchmark (563 lines) | 1,804w | Moderate trim — references performance-analyzer |
| spike (507 lines) | 1,802w | Moderate trim — some production-quality overlap |

## Agents (1 agent trimmed)

### elixir-architect (1,294 words -> ~400 words)

Move the ~15 resilience principles (from Hebert, Brooker, Luu, Kleppmann, Cook, Bainbridge, et al.) to `distributed-systems/resilience-principles.md`. Replace with:

```
**REQUIRED BACKGROUND:** Consult distributed-systems skill
resilience-principles.md for architectural decision principles.
```

### All other agents (300-500 words each)

No changes needed — already well-sized.

## Implementation Order

1. **Skills first** — restructure all 7 skills (creates the reference files that commands will point to)
2. **Agents second** — trim elixir-architect (moves principles to skill reference file)
3. **Commands third** — deduplicate by referencing new skill files

## Success Criteria

- Every SKILL.md is under 500 words
- Every command is under 1,000 words
- Every agent is under 500 words
- No reference material is deleted — only moved to supporting files
- All descriptions follow CSO guidelines (start with "Use when...", symptoms only)
- Existing workflows still function (commands reference skills correctly)

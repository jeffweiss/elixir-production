# Plugin Modernization Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Modernize the elixir-production plugin to reflect state-of-the-art Claude Code plugin best practices (v2.1.x era), focusing on agent triggering accuracy, security, and new platform features.

**Architecture:** Update agent descriptions with `<example>` blocks and `tools` restrictions for least-privilege security. Update skill descriptions to canonical third-person format. Add `skills` frontmatter to agents for auto-loading. Add plugin `settings.json` for default configuration.

**Tech Stack:** Claude Code plugin system (markdown frontmatter, JSON config)

---

## Chunk 1: Agent Description Modernization

### Task 1: Add `<example>` blocks and `tools` to elixir-architect

**Files:**
- Modify: `agents/elixir-architect.md:1-6` (frontmatter)

- [ ] **Step 1: Update frontmatter**

Replace the current frontmatter:

```yaml
---
name: elixir-architect
description: Use when a feature needs architectural design before implementation, including complexity analysis, test specification, and phased implementation strategy
model: opus
color: blue
---
```

With:

```yaml
---
name: elixir-architect
description: Use when a feature needs architectural design before implementation, including complexity analysis, test specification, and phased implementation strategy

  <example>
  Context: User wants to add a new feature to an Elixir project.
  user: "I need to add real-time notifications to our Phoenix app"
  assistant: "I'll use the elixir-architect agent to design the notification system architecture before implementation."
  <commentary>
  Feature requires architectural decisions about PubSub, persistence, delivery guarantees — architect designs before developer implements.
  </commentary>
  </example>

  <example>
  Context: User describes a complex feature that spans multiple contexts.
  user: "We need a billing system with Stripe integration, usage tracking, and invoice generation"
  assistant: "This spans multiple Phoenix contexts. I'll use the elixir-architect agent to design the module structure and data flow."
  <commentary>
  Multi-context feature needs upfront architecture planning with clear boundaries.
  </commentary>
  </example>

  <example>
  Context: User wants to understand the design implications before coding.
  user: "Before we build this, can you design the architecture?"
  assistant: "I'll use the elixir-architect agent to produce a comprehensive architecture document."
  <commentary>
  Explicit architecture request maps directly to the architect agent.
  </commentary>
  </example>
model: opus
color: blue
tools:
  - Read
  - Grep
  - Glob
  - Bash
  - Agent
  - TodoWrite
  - WebSearch
  - WebFetch
skills:
  - elixir-production:elixir-patterns
  - elixir-production:production-quality
  - elixir-production:performance-analyzer
---
```

- [ ] **Step 2: Verify file parses correctly**

Run: `head -48 agents/elixir-architect.md`
Expected: Clean YAML frontmatter with examples visible

- [ ] **Step 3: Commit**

```bash
git add agents/elixir-architect.md
git commit -m "feat(agents): add example blocks, tools, and skills to elixir-architect"
```

### Task 2: Add `<example>` blocks and `tools` to elixir-developer

**Files:**
- Modify: `agents/elixir-developer.md:1-6` (frontmatter)

- [ ] **Step 1: Update frontmatter**

Replace the current frontmatter:

```yaml
---
name: elixir-developer
description: Use when implementing Elixir code after a plan exists, or when writing new functions, modules, or features that need tests written first
model: sonnet
color: green
---
```

With:

```yaml
---
name: elixir-developer
description: Use when implementing Elixir code after a plan exists, or when writing new functions, modules, or features that need tests written first

  <example>
  Context: An architecture plan exists and implementation is ready to begin.
  user: "The architecture looks good, go ahead and implement it"
  assistant: "I'll use the elixir-developer agent to implement this with TDD — tests first, then implementation."
  <commentary>
  Post-architecture implementation with TDD is the developer agent's primary role.
  </commentary>
  </example>

  <example>
  Context: User wants to add a specific function or module.
  user: "Add a GenServer that manages rate limiting with a token bucket"
  assistant: "I'll use the elixir-developer agent to implement this with tests first."
  <commentary>
  Concrete implementation task that needs TDD workflow.
  </commentary>
  </example>
model: sonnet
color: green
tools:
  - Read
  - Write
  - Edit
  - Bash
  - Grep
  - Glob
  - TodoWrite
skills:
  - elixir-production:elixir-patterns
  - elixir-production:production-quality
  - elixir-production:enforcing-precommit
---
```

- [ ] **Step 2: Verify file parses correctly**

Run: `head -36 agents/elixir-developer.md`

- [ ] **Step 3: Commit**

```bash
git add agents/elixir-developer.md
git commit -m "feat(agents): add example blocks, tools, and skills to elixir-developer"
```

### Task 3: Add `<example>` blocks and `tools` to elixir-reviewer

**Files:**
- Modify: `agents/elixir-reviewer.md:1-6` (frontmatter)

- [ ] **Step 1: Update frontmatter**

Replace current frontmatter with:

```yaml
---
name: elixir-reviewer
description: Use when code changes need review against production standards, before committing, or when checking if implementation is production-ready

  <example>
  Context: A major project step has been completed and needs review.
  user: "I've finished implementing the user authentication system"
  assistant: "I'll use the elixir-reviewer agent to review the implementation against production standards."
  <commentary>
  Completed implementation needs production standards review before commit.
  </commentary>
  </example>

  <example>
  Context: User wants a code quality check.
  user: "Can you review this module before I commit?"
  assistant: "I'll use the elixir-reviewer agent to check against production standards."
  <commentary>
  Explicit review request with pre-commit context.
  </commentary>
  </example>
model: sonnet
color: yellow
tools:
  - Read
  - Grep
  - Glob
  - Bash
skills:
  - elixir-production:production-quality
  - elixir-production:phoenix-liveview
  - elixir-production:elixir-patterns
  - elixir-production:enforcing-precommit
---
```

Note: elixir-reviewer already had Bash in the plan — it needs it for `validate-dependencies.sh` and `mix precommit`.

- [ ] **Step 2: Verify and commit**

```bash
head -35 agents/elixir-reviewer.md
git add agents/elixir-reviewer.md
git commit -m "feat(agents): add example blocks, tools, and skills to elixir-reviewer"
```

### Task 4: Add `<example>` blocks and `tools` to cognitive-scientist

**Files:**
- Modify: `agents/cognitive-scientist.md:1-6` (frontmatter)

- [ ] **Step 1: Update frontmatter**

```yaml
---
name: cognitive-scientist
description: Use when actively analyzing a specific module or codebase for cognitive load, onboarding difficulty, or refactoring opportunities

  <example>
  Context: User notices code is hard to understand or maintain.
  user: "This module has gotten really complex, can you analyze the cognitive load?"
  assistant: "I'll use the cognitive-scientist agent to perform an Ousterhout-based complexity analysis."
  <commentary>
  Explicit cognitive complexity concern maps to this specialist agent.
  </commentary>
  </example>

  <example>
  Context: Onboarding a new developer to a codebase area.
  user: "How hard would it be for a new developer to understand the billing context?"
  assistant: "I'll use the cognitive-scientist agent to assess onboarding difficulty and produce a guide."
  <commentary>
  Onboarding difficulty assessment is a core cognitive-scientist capability.
  </commentary>
  </example>
model: opus
color: magenta
tools:
  - Read
  - Grep
  - Glob
  - Bash
  - TodoWrite
skills:
  - elixir-production:cognitive-complexity
---
```

- [ ] **Step 2: Verify and commit**

```bash
head -31 agents/cognitive-scientist.md
git add agents/cognitive-scientist.md
git commit -m "feat(agents): add example blocks, tools, and skills to cognitive-scientist"
```

### Task 5: Add `<example>` blocks and `tools` to performance-analyzer

**Files:**
- Modify: `agents/performance-analyzer.md:1-6` (frontmatter)

- [ ] **Step 1: Update frontmatter**

```yaml
---
name: performance-analyzer
description: Use when actively profiling slow code, running benchmarks to compare implementations, or investigating a specific performance bottleneck with measurement tools

  <example>
  Context: User reports slow performance in their application.
  user: "The API endpoint is taking 2 seconds, can you profile it?"
  assistant: "I'll use the performance-analyzer agent to profile the bottleneck and recommend data-driven optimizations."
  <commentary>
  Specific performance issue needs measurement-first profiling workflow.
  </commentary>
  </example>

  <example>
  Context: User wants to compare two implementation approaches.
  user: "Which is faster for our use case — ETS lookup or GenServer call?"
  assistant: "I'll use the performance-analyzer agent to create Benchee benchmarks comparing both approaches."
  <commentary>
  Implementation comparison needs benchmarks, not speculation.
  </commentary>
  </example>
model: sonnet
color: red
tools:
  - Read
  - Write
  - Edit
  - Bash
  - Grep
  - Glob
skills:
  - elixir-production:performance-analyzer
---
```

- [ ] **Step 2: Verify and commit**

```bash
head -30 agents/performance-analyzer.md
git add agents/performance-analyzer.md
git commit -m "feat(agents): add example blocks, tools, and skills to performance-analyzer"
```

### Task 6: Add `<example>` blocks and `tools` to remaining 5 agents

**Files:**
- Modify: `agents/algorithms-researcher.md:1-6`
- Modify: `agents/distributed-systems-expert.md:1-6`
- Modify: `agents/test-designer.md:1-6`
- Modify: `agents/phoenix-expert.md:1-6`
- Modify: `agents/pr-reviewer.md:1-6`

- [ ] **Step 1: Update algorithms-researcher frontmatter**

```yaml
---
name: algorithms-researcher
description: Use when a problem needs novel algorithmic approaches, academic paper citations, or evaluation of cutting-edge data structures not covered in the algorithms skill

  <example>
  Context: User needs to choose an algorithm for a specific problem.
  user: "What's the best approximate counting algorithm for our analytics pipeline?"
  assistant: "I'll use the algorithms-researcher agent to survey recent papers and recommend with citations."
  <commentary>
  Novel algorithm selection with academic rigor requires the researcher agent.
  </commentary>
  </example>

  <example>
  Context: User wants to evaluate data structure alternatives.
  user: "Is there something better than a bloom filter for our membership test with deletions?"
  assistant: "I'll use the algorithms-researcher agent to research alternatives like cuckoo filters."
  <commentary>
  Cutting-edge data structure evaluation with tradeoff analysis.
  </commentary>
  </example>
model: opus
color: cyan
tools:
  - Read
  - Write
  - Grep
  - Glob
  - Bash
  - WebSearch
  - WebFetch
skills:
  - elixir-production:algorithms
---
```

- [ ] **Step 2: Update distributed-systems-expert frontmatter**

```yaml
---
name: distributed-systems-expert
description: Use when designing a distributed architecture, investigating a distributed bug (split-brain, state disagreement, partition recovery, data loss), evaluating consensus algorithm tradeoffs, or working with message brokers (Kafka, RabbitMQ), PubSub systems, event streaming, or message delivery guarantees (at-least-once, exactly-once)

  <example>
  Context: User is designing a multi-node system.
  user: "We need to add leader election for our job scheduler across 3 nodes"
  assistant: "I'll use the distributed-systems-expert agent to evaluate leader election strategies and recommend an approach."
  <commentary>
  Distributed consensus decision requires specialist with CAP tradeoff expertise.
  </commentary>
  </example>

  <example>
  Context: User is debugging a distributed system issue.
  user: "We're seeing state disagreements between nodes after a network partition"
  assistant: "I'll use the distributed-systems-expert agent to investigate the split-brain scenario."
  <commentary>
  Distributed bug investigation needs deep expertise in partition recovery.
  </commentary>
  </example>

  <example>
  Context: User is concerned about data loss in a messaging pipeline.
  user: "We're losing messages between our Kafka consumer and the processing pipeline"
  assistant: "I'll use the distributed-systems-expert agent to analyze message delivery guarantees and identify where data loss is occurring."
  <commentary>
  Data loss in message brokers requires understanding of delivery semantics, offset management, and failure modes.
  </commentary>
  </example>

  <example>
  Context: User is designing a PubSub or event streaming system.
  user: "Should we use Phoenix.PubSub, Broadway with Kafka, or Oban for distributing events across nodes?"
  assistant: "I'll use the distributed-systems-expert agent to evaluate the tradeoffs for your event distribution needs."
  <commentary>
  PubSub/event streaming architecture choices involve delivery guarantees, ordering, and backpressure — distributed systems concerns.
  </commentary>
  </example>
model: opus
color: blue
tools:
  - Read
  - Grep
  - Glob
  - Bash
  - TodoWrite
  - WebSearch
  - WebFetch
skills:
  - elixir-production:distributed-systems
---
```

- [ ] **Step 3: Update test-designer frontmatter**

```yaml
---
name: test-designer
description: Use when designing a test strategy for a feature, analyzing behavioral coverage gaps, or specifying which test cases to write with criticality ratings

  <example>
  Context: A new feature needs comprehensive test coverage.
  user: "Design the test strategy for the payment processing module"
  assistant: "I'll use the test-designer agent to design tests with criticality ratings covering all success/error/edge paths."
  <commentary>
  Test strategy design with criticality prioritization is the test-designer's specialty.
  </commentary>
  </example>

  <example>
  Context: User suspects test coverage gaps.
  user: "Are there any behavioral coverage gaps in our auth tests?"
  assistant: "I'll use the test-designer agent to analyze the test space and identify missing coverage."
  <commentary>
  Coverage gap analysis requires systematic behavioral enumeration.
  </commentary>
  </example>
model: sonnet
color: cyan
tools:
  - Read
  - Write
  - Grep
  - Glob
  - Bash
skills:
  - elixir-production:production-quality
---
```

- [ ] **Step 4: Update phoenix-expert frontmatter**

```yaml
---
name: phoenix-expert
description: Use when building or debugging Phoenix LiveView features that need guided implementation, not just pattern lookup

  <example>
  Context: User is building a LiveView feature.
  user: "I need to add a live search with debounce to the users page"
  assistant: "I'll use the phoenix-expert agent for guided LiveView implementation with proper stream patterns."
  <commentary>
  LiveView implementation guidance beyond simple pattern lookup.
  </commentary>
  </example>

  <example>
  Context: User is debugging a LiveView issue.
  user: "My LiveView form keeps resetting on every keystroke"
  assistant: "I'll use the phoenix-expert agent to debug this — likely a form/changeset lifecycle issue."
  <commentary>
  LiveView gotcha debugging requires specialist knowledge.
  </commentary>
  </example>
model: sonnet
color: magenta
tools:
  - Read
  - Write
  - Edit
  - Bash
  - Grep
  - Glob
skills:
  - elixir-production:phoenix-liveview
  - elixir-production:elixir-patterns
---
```

- [ ] **Step 5: Update pr-reviewer frontmatter**

```yaml
---
name: pr-reviewer
description: Use when reviewing a GitHub pull request by number, or when validating a PR is ready to merge

  <example>
  Context: User wants a PR reviewed.
  user: "Review PR #42"
  assistant: "I'll use the pr-reviewer agent to perform a comprehensive review of PR #42."
  <commentary>
  PR review by number is the primary trigger for this agent.
  </commentary>
  </example>

  <example>
  Context: User wants to validate before merging.
  user: "Is PR #15 ready to merge?"
  assistant: "I'll use the pr-reviewer agent to validate the PR against production standards."
  <commentary>
  Merge readiness validation maps to the PR reviewer.
  </commentary>
  </example>
model: sonnet
color: yellow
tools:
  - Read
  - Grep
  - Glob
  - Bash
  - Agent
skills:
  - elixir-production:production-quality
  - elixir-production:enforcing-precommit
---
```

- [ ] **Step 6: Verify all 5 files parse correctly**

Run: `for f in agents/{algorithms-researcher,distributed-systems-expert,test-designer,phoenix-expert,pr-reviewer}.md; do echo "=== $f ==="; head -5 "$f"; echo; done`

- [ ] **Step 7: Commit all 5**

```bash
git add agents/algorithms-researcher.md agents/distributed-systems-expert.md agents/test-designer.md agents/phoenix-expert.md agents/pr-reviewer.md
git commit -m "feat(agents): add example blocks, tools, and skills to remaining 5 agents"
```

---

## Chunk 2: Skill Description Modernization

### Task 7: Update skill descriptions to third-person format

**Files:**
- Modify: `skills/enforcing-precommit/SKILL.md:1-4`
- Modify: `skills/elixir-patterns/SKILL.md:1-4`
- Modify: `skills/production-quality/SKILL.md:1-4`
- Modify: `skills/cognitive-complexity/SKILL.md:1-4`
- Modify: `skills/distributed-systems/SKILL.md:1-4`
- Modify: `skills/algorithms/SKILL.md:1-4`
- Modify: `skills/performance-analyzer/SKILL.md:1-4`
- Modify: `skills/phoenix-liveview/SKILL.md:1-4`

The canonical format is "This skill should be used when..." instead of "Use when...".

- [ ] **Step 1: Update each skill description (frontmatter only)**

**enforcing-precommit:**
```yaml
description: This skill should be used when about to run "git commit", "git push", or claim implementation is complete in an Elixir project — requires running mix precommit and confirming output before any commit or completion claim
```

**elixir-patterns:**
```yaml
description: This skill should be used when structuring Elixir code, deciding whether to use "GenServer or plain functions", "designing supervision trees", "handling overload or unbounded message queues", "organizing Phoenix contexts", or needing idiomatic OTP patterns
```

**production-quality:**
```yaml
description: This skill should be used when preparing code for production, running "mix precommit", "mix compile --warnings-as-errors", "mix credo --strict", "mix format", "mix test", adding typespecs, evaluating security posture, checking migration safety, or reviewing code before committing
```

**cognitive-complexity:**
```yaml
description: This skill should be used when code is hard to understand, a module has "too many parameters or deep nesting", "functions exceed 40 lines", "abstractions feel leaky", or evaluating "deep-module vs shallow-module" design per Ousterhout principles
```

**distributed-systems:**
```yaml
description: This skill should be used when building "multi-node Elixir systems", choosing between "Raft and CRDTs", configuring "libcluster or Partisan", debugging "split-brain or netsplit scenarios", evaluating "CP vs AP tradeoffs", investigating "data loss" in distributed pipelines, working with "Kafka", "RabbitMQ", "Broadway", or "PubSub" message delivery guarantees, or designing "event streaming" architectures
```

**algorithms:**
```yaml
description: This skill should be used when choosing "data structures", "Map vs ETS vs gb_trees performance", evaluating "hash functions", needing "HyperLogLog or bloom/cuckoo filters", or comparing OTP built-ins against specialized alternatives for Elixir
```

**performance-analyzer:**
```yaml
description: This skill should be used when code is reported slow, before suggesting any optimization, when choosing between "cprof/eprof/fprof/tprof", or when creating "Benchee benchmarks" to compare approaches
```

**phoenix-liveview:**
```yaml
description: This skill should be used when working with "Phoenix LiveView", "Plug pipelines", "controllers", "JSON APIs", "channels", "streams", "forms", "phx-hook", "authentication", or debugging "Phoenix/LiveView gotchas"
```

- [ ] **Step 2: Verify each file's frontmatter parses correctly**

Run: `for f in skills/*/SKILL.md; do echo "=== $f ==="; head -4 "$f"; echo; done`

- [ ] **Step 3: Commit**

```bash
git add skills/*/SKILL.md
git commit -m "feat(skills): update descriptions to canonical third-person format with trigger phrases"
```

---

## Chunk 3: Plugin Configuration Modernization

### Task 8: Add plugin settings.json for default configuration

**Files:**
- Create: `settings.json` (at plugin root)

- [ ] **Step 1: Create settings.json**

Plugin-shipped `settings.json` provides default configuration that users inherit when enabling the plugin:

```json
{
  "permissions": {
    "allow": [
      "Bash(mix precommit:*)",
      "Bash(mix compile:*)",
      "Bash(mix format:*)",
      "Bash(mix credo:*)",
      "Bash(mix test:*)",
      "Bash(mix deps.get:*)",
      "Bash(mix hex.info:*)",
      "Read",
      "Grep",
      "Glob"
    ]
  }
}
```

- [ ] **Step 2: Verify settings.json is valid JSON**

Run: `cat settings.json | python3 -m json.tool`

- [ ] **Step 3: Commit**

```bash
git add settings.json
git commit -m "feat: add plugin settings.json with default mix command permissions"
```

### Task 9: Bump plugin version

**Files:**
- Modify: `.claude-plugin/plugin.json:3`

- [ ] **Step 1: Update version**

Change version from `"2.5.0"` to `"2.6.0"` to reflect the modernization changes.

- [ ] **Step 2: Commit**

```bash
git add .claude-plugin/plugin.json
git commit -m "chore: bump version to 2.6.0 for plugin modernization"
```

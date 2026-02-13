# Elixir Production Plugin for Claude Code

A Claude Code plugin for production-quality Elixir development. Enforces precommit quality gates, TDD workflows, and escalation-based patterns for OTP, Phoenix LiveView, and distributed systems.

## What This Plugin Does

When installed, this plugin **mechanically prevents broken commits**. Three independent enforcement layers ensure `mix precommit` passes before any code enters version control:

1. **Hook gate** — A blocking `PreToolUse` hook intercepts `git commit` and `git push`, running the full `mix precommit` suite. The commit does not proceed until all four checks pass (compile, format, credo, test).
2. **Discipline skill** — The `enforcing-precommit` skill provides iron laws, gate functions, and rationalization prevention that agents internalize during sessions.
3. **Workflow gate** — The `/feature` command requires the developer agent to pass precommit before handing off to review.

A `SessionStart` hook bootstraps every session with non-negotiable rules and environment checks.

Beyond enforcement, the plugin provides 10 specialized agents, 8 progressive skills with escalation ladders, and 11 commands for guided Elixir development.

## Features

### 🤖 10 Specialized Agents

**Core Agents**:
- **elixir-architect** (Opus) - Feature design with complexity analysis and comprehensive TDD test suite design
- **elixir-developer** (Sonnet) - Primary TDD-focused implementation worker
- **elixir-reviewer** (Sonnet) - Code review with confidence-based reporting (≥80%)
- **test-designer** (Sonnet) - Comprehensive test strategy with criticality ratings (1-10 scale)

**Phoenix & Performance Specialists**:
- **phoenix-expert** (Sonnet) - LiveView/Phoenix specialist with deep patterns
- **performance-analyzer** (Sonnet) - Profiling and Benchee benchmarks
- **pr-reviewer** (Sonnet) - GitHub PR automation with cognitive integration

**Expert Consultants** (Opus):
- **cognitive-scientist** - Cognitive load analysis (Ousterhout philosophy)
- **distributed-systems-expert** - Consensus algorithms and distributed bugs
- **algorithms-researcher** - Cutting-edge algorithms from recent research

### 📚 8 Progressive Skills

- **enforcing-precommit** - Non-negotiable precommit gate with iron law and rationalization prevention
- **elixir-patterns** - Core Elixir patterns (railway, DDD, OTP)
- **phoenix-liveview** - LiveView streams, forms, hooks, authentication
- **production-quality** - Quality standards and workflows
- **cognitive-complexity** - Cognitive load analysis (Ousterhout philosophy)
- **distributed-systems** - Consensus, clustering, CAP tradeoffs
- **algorithms** - Modern algorithms and data structures
- **performance-analyzer** - Profiling, benchmarking, latency analysis

### ⚡ 11 Commands

**Core Workflow**:
- `/precommit` - Run full quality check suite (compile, format, credo, test)
- `/feature` - Guided feature implementation with parallel exploration and TDD
- `/review` - Comprehensive code review against production standards
- `/cognitive-audit` - Analyze cognitive complexity (Ousterhout philosophy)

**SPIKE Workflow**:
- `/spike` - Rapid prototyping mode with debt tracking
- `/spike-migrate` - Upgrade SPIKE code to production quality

**Performance & Analysis**:
- `/benchmark` - Create/run Benchee benchmarks with representative data
- `/pr-review` - Review GitHub PRs with automated standards checking

**Knowledge & Expert Domains**:
- `/learn` - Update project-learnings.md with structured patterns
- `/distributed-review` - Analyze distributed systems design and correctness
- `/algorithm-research` - Research cutting-edge algorithms with citations

### 🔄 Three Workflow Modes

1. **Enterprise Maintenance** - Strict quality gates, comprehensive reviews, team knowledge sharing
2. **Production Prototypes** - Balanced quality and speed, clear migration paths
3. **Rapid Experimentation** - SPIKE mode for fast iteration, easy upgrade when ready

## Installation

### Prerequisites

- Claude Code CLI (`claude-code`) installed
- Elixir project with mix

### Install Plugin

```bash
# Clone or copy plugin to Claude plugins directory
cp -r elixir-production ~/.claude/plugins/

# Verify installation
claude-code --list-plugins
```

### Project Setup

Add required dependencies to your `mix.exs`:

```elixir
defp deps do
  [
    # Required for production quality
    {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
    {:styler, "~> 1.0", only: [:dev, :test], runtime: false},

    # Recommended for testing
    {:mox, "~> 1.0", only: :test},
    {:stream_data, "~> 0.6", only: [:dev, :test]},

    # Recommended for HTTP (prefer over HTTPoison/Tesla)
    {:req, "~> 0.4"},

    # Optional but valuable
    {:ex_doc, "~> 0.30", only: :dev, runtime: false},
    {:dialyxir, "~> 1.3", only: [:dev, :test], runtime: false},
    {:benchee, "~> 1.1", only: :dev}
  ]
end
```

Configure `.formatter.exs`:

```elixir
[
  plugins: [Styler],
  inputs: ["*.{ex,exs}", "{config,lib,test}/**/*.{ex,exs}"],
  line_length: 98
]
```

Install dependencies:

```bash
mix deps.get
```

## Quick Start

### 1. Run Precommit Check

Validate your code meets production standards:

```bash
claude-code /precommit

# With auto-fix for formatting
claude-code /precommit --fix
```

### 2. Implement a Feature

Use the guided feature workflow:

```bash
claude-code /feature "Add user email verification"
```

This will:
1. **Explore** codebase in parallel for similar patterns
2. **Design** architecture with complexity analysis (Opus)
3. **Wait** for your approval
4. **Implement** using strict TDD (Sonnet)
5. **Precommit gate** — all four checks must pass before review
6. **Review** with parallel quality analysis
7. **Summarize** with next steps

### 3. Review Code

Get comprehensive code review:

```bash
# Review entire project
claude-code /review

# Review specific file
claude-code /review lib/my_app/accounts.ex

# Review directory
claude-code /review lib/my_app/accounts/
```

### 4. Project Templates (Optional)

Copy templates to your project for enhanced standards:

```bash
# Project-specific configuration
cp ~/.claude/plugins/elixir-production/templates/AGENTS.md ./
cp ~/.claude/plugins/elixir-production/templates/CLAUDE.md ./

# Create .claude directory for project knowledge
mkdir -p .claude
cp ~/.claude/plugins/elixir-production/templates/project-learnings.md .claude/
```

## Getting the Most Out of the Plugin

### Mental Model

Three layers work together — you only interact with the first:

```
Commands (you run these)
  └── Agents (dispatched automatically, matched to task complexity)
        └── Skills (loaded on demand, provide domain knowledge)
```

**Commands** are your interface: `/feature`, `/review`, `/precommit`, etc. **Agents** are specialists that commands dispatch — Opus for design and deep analysis, Sonnet for implementation. **Skills** are reference knowledge that agents pull from automatically when they need domain expertise.

### Everyday Workflows

**Building a feature end-to-end:**

```bash
/feature "Add user email verification"
```

This orchestrates the full pipeline: architecture design (Opus) → your approval → TDD implementation (Sonnet) → precommit gate → parallel code review → summary with next steps. You approve the design, then the plugin handles the rest.

**Checking code before you commit:**

```bash
/precommit
```

Runs compile (warnings-as-errors), format (with Styler), credo (strict), and tests. The plugin also enforces this automatically — a blocking hook prevents `git commit` and `git push` until all four checks pass.

**Exploring an idea quickly:**

```bash
/spike "try GenStage for backpressure"
```

Skips production requirements (typespecs, full test coverage). Code gets marked with `# SPIKE: reason` and debt is tracked in `.claude/spike-debt.md`. When the approach pans out, `/spike-migrate` brings it to production quality with TDD.

**Reviewing code:**

```bash
/review lib/my_app/accounts/     # review a directory
/pr-review 123                   # review a GitHub PR
/cognitive-audit                  # analyze cognitive complexity
```

Reviews only report issues at ≥80% confidence — no speculative noise.

### Picking the Right Command

| What you're doing | Command |
|---|---|
| Building something new | `/feature` |
| Checking code quality | `/review` |
| Before committing | `/precommit` |
| Exploring an idea fast | `/spike` |
| SPIKE code is stable | `/spike-migrate` |
| Performance questions | `/benchmark` |
| PR ready for review | `/pr-review 123` |
| Distributed system concerns | `/distributed-review` |
| Need a better algorithm | `/algorithm-research` |
| Code feels complex | `/cognitive-audit` |
| Learned something useful | `/learn "pattern"` |

### Behaviors to Know About

**Precommit is a hard gate.** Three independent layers enforce it: a blocking hook on `git commit`/`git push`, a discipline skill internalized by agents, and a workflow gate in `/feature`. There is no override except SPIKE mode (`ELIXIR_SPIKE_MODE=1`).

**TDD is the default.** Agents write tests before implementation. Tests are rated by business criticality (1-10) — critical paths (9-10) get tested first. Use `/spike` to skip this when experimenting.

**Skills scale to the problem.** Each skill uses an escalation ladder (L0 through L5+). A quick question gets a concise reference answer. A complex architectural decision gets deep analysis with citations and tradeoff evaluation.

**Knowledge accumulates across sessions.** Use `/learn` to capture patterns in `.claude/project-learnings.md`. All agents read this file, keeping them consistent with your project's conventions over time.

**Per-edit feedback is automatic.** A non-blocking hook runs compile and format checks after every `.ex`/`.exs` edit, catching issues early without interrupting your flow.

## Workflows

### Enterprise Maintenance (Large Teams)

**Configuration**: `.claude/elixir-production.local.md`
```yaml
---
strict_mode: true
require_review: true
auto_precommit: false
complexity_analysis_required: true
pr_automation_enabled: true
team_learning_enabled: true
---
```

**Workflow**:
1. Feature request → `/feature` command
2. elixir-architect (Opus) designs with complexity analysis
3. User approval required
4. elixir-developer (Sonnet) implements with TDD
5. Precommit gate — developer must pass all four checks before handoff
6. `/review` before proposing changes
7. Hooks enforce standards at every edit and block commits without precommit
8. PR → `/pr-review` auto-comments
9. Team reviews → project-learnings.md updated

**Benefits**:
- Consistent patterns in project-learnings.md
- Quality gates prevent regressions
- Knowledge sharing across team
- New contributors learn from documented patterns

### Production Prototypes

**Configuration**:
```yaml
---
strict_mode: true
require_review: false
auto_precommit: true
complexity_analysis_required: true
spike_migration_tracking: true
---
```

**Workflow**:
1. `/feature` for architecture planning
2. Rapid implementation with TDD
3. Tests for critical paths only (9-10 criticality)
4. Auto-run precommit after changes
5. Mark experimental code with `# SPIKE:`
6. Track debt in `.claude/spike-debt.md`
7. Regular `/spike-migrate` when patterns stabilize

**Benefits**:
- Fast iteration with clear upgrade path
- Performance validated early
- Proven patterns documented
- Technical debt visible

### Rapid Experimentation

**Configuration**:
```yaml
---
strict_mode: false
spike_migration_tracking: true
spike_migration_suggestions: true
---
```

**Workflow**:
1. `/spike <goal>` command
2. Skip typespecs, focus on working code
3. Minimal tests (smoke tests only)
4. Mark all with `# SPIKE: reason`
5. System monitors spike maturity
6. Suggests `/spike-migrate` when ready

**Benefits**:
- Maximum iteration speed
- Clear migration path
- Automatic maturity detection
- Easy knowledge capture

## Configuration

### Plugin-Level Settings

File: `~/.claude/plugins/elixir-production/.claude-plugin/plugin.json`

Controls plugin metadata and component registration.

### Project-Level Settings

File: `.claude/elixir-production.local.md` (in project root)

```yaml
---
enabled: true
strict_mode: true
require_review: true
auto_precommit: false
complexity_analysis_required: true
pr_automation_enabled: false
team_learning_enabled: true
spike_migration_tracking: true
spike_migration_suggestions: true
---
```

### Environment Variables

```bash
# Validation
export ELIXIR_VALIDATE_ON_EDIT=1  # Validate code on every edit (default: 1)
export ELIXIR_SPIKE_MODE=1        # Skip precommit enforcement for SPIKE mode (default: 0)
```

## Project Files

The plugin creates and uses these files in your project:

```
project-root/
├── .claude/
│   ├── project-learnings.md         # Auto-updated project knowledge
│   ├── spike-debt.md                # Tracked SPIKE technical debt
│   ├── elixir-production.local.md   # Project-specific plugin config
│   └── settings.local.json          # Permissions
├── AGENTS.md (optional)             # Project-specific technical standards
├── CLAUDE.md (optional)             # Project-specific high-level principles
├── .formatter.exs                   # Must include Styler plugin
└── mix.exs                          # Must include credo and styler deps
```

## Precommit Workflow

Every commit must pass all four checks:

1. **Compile**: `mix compile --warnings-as-errors`
2. **Format**: `mix format` (includes Styler)
3. **Credo**: `mix credo --strict`
4. **Tests**: `mix test`

This is enforced at three levels:

- **Hook**: `enforce-precommit.sh` runs as a blocking `PreToolUse` hook on `git commit`/`git push`. Commits are blocked until all checks pass.
- **Skill**: The `enforcing-precommit` skill is loaded by all code-producing agents, providing iron laws and rationalization prevention.
- **Workflow**: The `/feature` command gates the developer agent on precommit before the review phase.

Set up the `mix precommit` alias in your project for the simplest experience:

```elixir
# In mix.exs
defp aliases do
  [
    precommit: ["compile --warnings-as-errors", "deps.unlock --unused", "format", "credo --strict", "test"]
  ]
end
```

## Architecture

### Plugin Structure

```
~/.claude/plugins/elixir-production/
├── .claude-plugin/
│   └── plugin.json                # Plugin manifest
├── agents/                        # 10 specialized agents
│   ├── elixir-architect.md        # Feature design (Opus)
│   ├── elixir-developer.md        # TDD implementation (Sonnet)
│   ├── elixir-reviewer.md         # Code review (Sonnet)
│   ├── test-designer.md           # Test strategy (Sonnet)
│   ├── phoenix-expert.md          # LiveView specialist (Sonnet)
│   ├── performance-analyzer.md    # Profiling/benchmarks (Sonnet)
│   ├── pr-reviewer.md             # GitHub PR automation (Sonnet)
│   ├── cognitive-scientist.md     # Cognitive load (Opus)
│   ├── distributed-systems-expert.md  # Consensus/clustering (Opus)
│   └── algorithms-researcher.md   # Algorithm research (Opus)
├── skills/                        # 8 progressive skills, 70 reference files
│   ├── algorithms/                # SKILL.md + 14 reference files (data structures, ETS, graphs, spatial, streaming, optimization, statistics)
│   ├── cognitive-complexity/      # SKILL.md + escalation + references/
│   ├── distributed-systems/       # SKILL.md + 12 reference files (consensus, clustering, leader election, sagas, gossip, consistent hashing, event sourcing, failure modes)
│   ├── elixir-patterns/           # SKILL.md + 12 reference files (OTP, async processing, macros, state machines, web API design, REST, GraphQL, overload management)
│   ├── enforcing-precommit/       # SKILL.md — iron law, gate function, rationalization table
│   ├── performance-analyzer/      # SKILL.md + 5 reference files (profiling, benchmarking, latency, GC, BEAM efficiency)
│   ├── phoenix-liveview/          # SKILL.md + 8 reference files (streams, forms, hooks, auth, advanced patterns, Plug/controllers, channels)
│   └── production-quality/        # SKILL.md + 10 reference files (testing, property-based, security, observability, database, deployment, configuration, Ecto preloading)
├── commands/                      # 11 slash commands
│   ├── precommit.md               # Quality gate
│   ├── feature.md                 # Feature workflow
│   ├── review.md                  # Code review
│   ├── cognitive-audit.md         # Complexity analysis
│   ├── spike.md                   # Rapid prototyping
│   ├── spike-migrate.md           # SPIKE to production
│   ├── benchmark.md               # Benchee benchmarks
│   ├── pr-review.md               # GitHub PR review
│   ├── learn.md                   # Knowledge capture
│   ├── distributed-review.md      # Distributed systems
│   └── algorithm-research.md      # Algorithm research
├── hooks/
│   ├── hooks.json                 # Hook configuration (SessionStart, PreToolUse, PostToolUse)
│   └── scripts/
│       ├── session-start.sh       # Session bootstrap: rules, environment checks
│       ├── enforce-precommit.sh   # BLOCKING gate: full mix precommit before commit/push
│       ├── quick-validate.sh      # Fast per-edit feedback (compile + format, non-blocking)
│       ├── validate-precommit.sh  # Legacy validation script
│       ├── check-complexity.sh    # Heuristic complexity checks
│       └── validate-dependencies.sh # Checks credo/styler in mix.exs
└── templates/
    ├── AGENTS.md                  # For new projects
    ├── CLAUDE.md                  # For new projects
    ├── .formatter.exs             # Formatter config
    ├── mix-deps-snippet.exs       # Required dependencies
    ├── project-learnings.md       # Knowledge template
    └── spike-debt.md              # Debt tracking template
```

### State-of-the-Art Patterns

This plugin incorporates patterns from official Claude Code plugins:

1. **Parallel agent coordination** (feature-dev plugin)
   - Fork-join for independent exploration
   - Fork-join for specialized review
   - User approval gates between phases

2. **Confidence-based filtering** (code-reviewer agent)
   - 80% threshold for reporting
   - Severity categories (Critical 90-100%, Important 80-89%)
   - Signal-to-noise optimization

3. **Test criticality scoring** (pr-test-analyzer)
   - 1-10 scale based on business impact
   - Focus on critical paths (9-10)
   - Behavioral coverage over line coverage

4. **Tool allowlisting** (commit.md command)
   - Pre-approved operations reduce permission prompts
   - Self-documenting capabilities

5. **Progressive disclosure** (plugin-dev skills)
   - Lean SKILL.md core (<500 words)
   - Deep references in subdirectories
   - "Use when..." descriptions for discovery

6. **Path portability** (universal pattern)
   - ${CLAUDE_PLUGIN_ROOT} for all internal paths
   - Cross-installation compatibility

## Status & Roadmap

### ✅ Fully Implemented (v2.3.0)

All 10 agents, 8 skills, and 11 commands are complete and production-ready. Skills follow progressive disclosure: lean SKILL.md (<500 words) with deep reference files for domain knowledge. Precommit enforcement is active at three layers (hook, skill, workflow).

## Contributing

To complete remaining components, follow the established patterns:

### Adding an Agent

```markdown
# Agent Name

## Identity
You are the **agent-name agent**, [description].

## Core Responsibilities
[List 3-5 key responsibilities]

## Available Tools
[Tools this agent can use]

## Model
Use **sonnet/opus/haiku** model for [reasoning].

## [Agent-specific sections]
```

### Adding a Skill

```markdown
---
name: skill-name
description: Use when [specific triggering conditions]
---

# Skill Name

## Overview
[Core principle in 1-2 sentences]

## Quick Reference
[Table or bullets for scanning]

## Common Mistakes
[What goes wrong + fixes]
```

SKILL.md should be <500 words. Put deep reference material in separate files within the skill directory.

### Adding a Command

```markdown
---
description: [Short description]
argument-hint: [usage hint]
allowed-tools: [list of allowed tools]
model: [sonnet/opus/haiku]
---

# Command Name

[Full command documentation]
```

## Troubleshooting

### Plugin Not Loaded

```bash
# Verify plugin location
ls ~/.claude/plugins/elixir-production/

# Check plugin.json syntax
cat ~/.claude/plugins/elixir-production/.claude-plugin/plugin.json | jq

# List loaded plugins
claude-code --list-plugins
```

### Hooks Not Firing

```bash
# Check hooks.json syntax
cat ~/.claude/plugins/elixir-production/hooks/hooks.json | jq

# Verify script permissions
ls -la ~/.claude/plugins/elixir-production/hooks/scripts/
# All .sh files should be executable (chmod +x)
```

### Dependencies Missing

```bash
# Verify mix.exs has required deps
grep credo mix.exs
grep styler mix.exs

# Install dependencies
mix deps.get

# Verify .formatter.exs includes Styler
grep "Styler" .formatter.exs
```

## References

### Elixir Resources
- [Elixir Official Guide](https://elixir-lang.org/getting-started/introduction.html)
- [Phoenix Framework](https://hexdocs.pm/phoenix/overview.html)
- [Ecto Documentation](https://hexdocs.pm/ecto/Ecto.html)
- [LiveView Guide](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html)

### Plugin Patterns
- [Claude Code Plugin Guide](https://github.com/anthropics/claude-code-plugins)
- [Official Feature-Dev Plugin](https://github.com/anthropics/claude-code/plugins/feature-dev)
- [Official PR Review Toolkit](https://github.com/anthropics/claude-code/plugins/pr-review-toolkit)

## License

MIT License - See LICENSE file for details

## Author

Jeff Weiss

## Acknowledgments

The skills in this plugin draw heavily from the work of many researchers and practitioners.

**Elixir & OTP Community**:
- Fred Hebert — distributed systems architectural principles, Erlang in Anger
- Saša Jurić — "To spawn, or not to spawn?", "Beyond Task.Async", OTP process patterns
- Chris Keathley — "Good and Bad Elixir", telemetry conventions, adaptive concurrency with Regulator
- Mitch Bernheisel — Safe Ecto Migrations

**Software Design & Philosophy**:
- Dave Thomas (PragDave) — DDD, functional core/imperative shell, YAGNI
- Quinn Wilton — correctness over convenience, production-grade engineering
- John Ousterhout — "A Philosophy of Software Design": deep modules, information hiding, pull complexity downward

**Distributed Systems**:
- Marc Brooker — metastability, circuit breakers, backoff, redundancy analysis, Physalia, tail latency economics, simulation for system builders
- Martin Kleppmann — CAP theorem critique, fencing tokens, isolation level testing, data loss probability in large clusters
- Leslie Lamport — Paxos consensus algorithm
- Diego Ongaro — Raft consensus algorithm
- Nathan Bronson — metastable failures in distributed systems
- James Hamilton — "On Designing and Deploying Internet-Scale Services", dependency SLAs
- Peng Huang — gray failure in cloud-scale systems
- Dan McKinley — "Choose Boring Technology", innovation tokens

**Systems Engineering & Reliability**:
- Richard Cook — "How Complex Systems Fail"
- Lisanne Bainbridge — "Ironies of Automation"
- David Woods — the alarm problem, cognitive load during cascading failures
- Jens Rasmussen — "Going Solid", capacity headroom and system brittleness
- Dan Luu — concurrency bugs, limplocks, latency measurement pitfalls, normalization of deviance, postmortem analysis
- Ding Yuan — "Simple Testing Can Prevent Most Critical Failures" (92% of catastrophic failures from incorrect error handling)
- Jon Kleinberg & Manish Raghavan — algorithmic monoculture and correlated failures

**Performance & Latency**:
- Jeffrey Dean & Luiz André Barroso — "The Tail at Scale"

**Algorithms & Data Structures**:
- Chris Okasaki — "Purely Functional Data Structures"
- Philippe Flajolet — HyperLogLog cardinality estimation
- Graham Cormode & S. Muthukrishnan — Count-Min Sketch
- Bin Fan — Cuckoo Filters
- Yann Collet — xxHash3
- Jack O'Connor — BLAKE3
- Geoff Pike & Jyrki Alakuijala — HighwayHash
- Orson Peters — Pattern-Defeating Quicksort (pdqsort)
- Stefan Edelkamp & Armin Weiß — BlockQuicksort
- Matteo Frigo — cache-oblivious algorithms

**Tools & Infrastructure**:
- Claude Code team for plugin architecture
- Anthropic for Claude and tooling

---

**Version**: 2.3.0 - All 10 agents, 8 skills, and 11 commands are fully implemented and production-ready. Three-layer precommit enforcement prevents broken commits.

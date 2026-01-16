# Elixir Production Plugin for Claude Code

A comprehensive Claude Code plugin system for production-quality Elixir development, combining specialized agents, progressive skills, commands, and safety automation.

## Features

### 🤖 10 Specialized Agents

**Core Agents**:
- **elixir-architect** (Opus) - Feature design with complexity analysis and comprehensive TDD test suite design
- **elixir-developer** (Sonnet) - Primary TDD-focused implementation worker
- **elixir-reviewer** - Code review with confidence-based reporting (≥80%)
- **test-designer** - Comprehensive test strategy with criticality ratings (1-10 scale)

**Expert Agents** (Planned):
- **phoenix-expert** - LiveView/Phoenix specialist
- **performance-analyzer** - Profiling and Benchee benchmarks
- **pr-reviewer** - GitHub PR automation
- **distributed-systems-expert** (Opus) - Consensus algorithms and distributed bugs
- **algorithms-researcher** (Opus) - Cutting-edge algorithms from recent research
- **cognitive-scientist** (Opus) - Cognitive load analysis (Ousterhout philosophy)

### 📚 6 Progressive Skills

- **elixir-patterns** - Core Elixir patterns (railway, DDD, OTP)
- **phoenix-liveview** (Planned) - LiveView streams, forms, hooks, authentication
- **production-quality** - Quality standards and workflows
- **distributed-systems** (Planned) - Consensus, clustering, CAP tradeoffs
- **algorithms** (Planned) - Modern algorithms and data structures
- **cognitive-complexity** (Planned) - Cognitive load analysis

### ⚡ 11 Commands

**Implemented**:
- `/precommit` - Run full quality check suite (compile, format, credo, test)
- `/feature` - Guided feature implementation with parallel exploration and TDD
- `/review` - Comprehensive code review against production standards

**Planned**:
- `/spike` - Rapid prototyping mode
- `/spike-migrate` - Upgrade SPIKE code to production quality
- `/benchmark` - Create/run Benchee benchmarks
- `/pr-review` - Review GitHub PRs
- `/learn` - Update project-learnings.md
- `/distributed-review` - Analyze distributed systems design
- `/algorithm-research` - Research cutting-edge algorithms
- `/cognitive-audit` - Analyze cognitive complexity

### 🛡️ Safety-Net Protection

Blocks destructive operations before execution:
- `git reset --hard`, `git push --force`, `git clean -f`
- `rm -rf` outside project directory
- Destructive database operations
- Semantic command analysis (not just pattern matching)

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
5. **Review** with parallel quality analysis
6. **Summarize** with next steps

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

## Core Concepts

### Test-Driven Development (TDD)

This plugin enforces strict TDD:

1. **Tests before implementation** - Always
2. **Explore entire result space** - All `{:ok, ...}` and `{:error, ...}` variants
3. **Red-Green-Refactor** - Failing test → implementation → passing test → improve
4. **100% coverage** - New code fully tested

Example workflow:

```elixir
# 1. Write comprehensive tests FIRST
describe "create_user/1 - Success Cases" do
  test "creates user with valid attributes"
  test "creates user with optional fields"
end

describe "create_user/1 - Error Cases" do
  test "returns error with missing required fields"
  test "returns error with invalid email"
  test "returns error with duplicate email"
end

# 2. Implement to make tests pass
# 3. Refactor while tests stay green
```

### Confidence-Based Reporting

Reviews only report high-confidence issues (≥80%):

```
[Critical] Missing typespec (Confidence: 95%)
[Important] Missing error handling (Confidence: 85%)

# Issues below 80% confidence are NOT reported
```

This reduces noise and focuses on actionable feedback.

### Criticality Ratings

Tests are rated 1-10 based on business risk:

```
10: Financial data, security, data loss
9:  Core business logic
8:  Error handling, data integrity
7:  Edge cases, boundaries
6:  UX improvements
5:  Convenience features
...
```

Focus on critical tests first (9-10).

### SPIKE Mode

Fast prototyping without production requirements:

- Skip typespecs
- Minimal tests (smoke tests only)
- Mark code with `# SPIKE: reason`
- Track in `.claude/spike-debt.md`
- Easy migration when patterns stabilize

### project-learnings.md

Auto-updated knowledge base:

```markdown
## Architecture Decisions
- [Date] Feature X uses GenServer pool because Y

## Domain Conventions
- Always pass current_scope as first argument

## Performance Patterns
- Product queries: Always preload [:category, :vendor]

## Common Gotchas
- LiveView stream IDs: Use "prefix-#{id}" format
```

Agents read this file to ensure consistency with project patterns.

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
5. `/review` before proposing changes
6. Manual `/precommit` before commit
7. Hooks enforce standards at every edit
8. PR → `/pr-review` auto-comments (when implemented)
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
# Safety-net modes
export SAFETY_NET_STRICT=1      # Fail-closed on unparseable commands
export SAFETY_NET_PARANOID=1    # Enhanced checks including rm -rf in cwd

# Validation
export ELIXIR_VALIDATE_ON_EDIT=1  # Validate code on every edit (default: 1)
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

Every commit must pass:

1. **Compile**: `mix compile --warnings-as-errors`
2. **Format**: `mix format` (includes Styler)
3. **Credo**: `mix credo --strict`
4. **Tests**: `mix test`

Hooks enforce this automatically. No broken code enters version control.

## Safety-Net Protection

The safety-net blocks destructive operations:

**Git operations**:
- `git reset --hard/--merge` (destroys work)
- `git push --force/-f` (rewrites history) - allows `--force-with-lease`
- `git clean -f` (removes files permanently)
- `git stash drop/clear` (permanent deletion)
- `git branch -D` (force delete without merge check)
- `git checkout --` (discards changes)

**Filesystem operations**:
- `rm -rf` outside project directory or `/tmp`
- `find ... -delete`
- `xargs rm -rf` and `parallel rm -rf`

**Features**:
- Semantic command analysis (understands intent)
- Handles nested shell wrappers up to 5 levels
- Allows safe variants (`--dry-run`, `--force-with-lease`)
- Blocks before permission system engages

## Architecture

### Plugin Structure

```
~/.claude/plugins/elixir-production/
├── .claude-plugin/
│   └── plugin.json              # Plugin manifest
├── agents/
│   ├── elixir-architect.md      # Feature design (Opus)
│   ├── elixir-developer.md      # TDD implementation (Sonnet)
│   ├── elixir-reviewer.md       # Code review
│   └── test-designer.md         # Test strategy
├── skills/
│   ├── elixir-patterns/         # Core patterns
│   │   ├── SKILL.md
│   │   └── references/
│   └── production-quality/      # Quality standards
│       └── SKILL.md
├── commands/
│   ├── precommit.md             # Quality gate
│   ├── feature.md               # Feature workflow
│   └── review.md                # Code review
├── hooks/
│   ├── hooks.json               # Hook configuration
│   └── scripts/
│       ├── safety-net.sh        # Blocks destructive ops
│       ├── validate-precommit.sh
│       ├── check-complexity.sh
│       └── validate-dependencies.sh
└── templates/
    ├── AGENTS.md                # For new projects
    ├── CLAUDE.md                # For new projects
    ├── project-learnings.md     # Knowledge template
    └── spike-debt.md            # Debt tracking template
```

### State-of-the-Art Patterns

This plugin incorporates patterns from official Claude Code plugins:

1. **Parallel agent coordination** (feature-dev plugin)
   - Fork-join for independent exploration
   - Fork-join for specialized review
   - User approval gates between phases

2. **Safety-net integration** (claude-code-safety-net)
   - PreToolUse hooks block destructive operations
   - Semantic command analysis
   - Nested wrapper detection

3. **Confidence-based filtering** (code-reviewer agent)
   - 80% threshold for reporting
   - Severity categories (Critical 90-100%, Important 80-89%)
   - Signal-to-noise optimization

4. **Test criticality scoring** (pr-test-analyzer)
   - 1-10 scale based on business impact
   - Focus on critical paths (9-10)
   - Behavioral coverage over line coverage

5. **Tool allowlisting** (commit.md command)
   - Pre-approved operations reduce permission prompts
   - Self-documenting capabilities

6. **Progressive disclosure** (plugin-dev skills)
   - Lean core (~1500-2000 words)
   - Deep references in subdirectories
   - Explicit triggering phrases

7. **Path portability** (universal pattern)
   - ${CLAUDE_PLUGIN_ROOT} for all internal paths
   - Cross-installation compatibility

## Status & Roadmap

### ✅ Implemented (Minimal Working System)

**Phase 1: Core Setup**
- ✅ Plugin directory structure
- ✅ plugin.json manifest
- ✅ Base templates (AGENTS.md, CLAUDE.md, project-learnings.md, spike-debt.md)
- ✅ Safety-net.sh script
- ✅ Validation scripts (precommit, complexity, dependencies)

**Phase 2: Essential Agents & Skills**
- ✅ elixir-reviewer agent
- ✅ elixir-patterns skill
- ✅ production-quality skill

**Phase 3: Core Feature Workflow**
- ✅ elixir-architect agent (Opus)
- ✅ elixir-developer agent (Sonnet)
- ✅ test-designer agent

**Phase 5: Essential Commands**
- ✅ /precommit command
- ✅ /feature command
- ✅ /review command

**Phase 6: Automation**
- ✅ hooks.json configuration
- ✅ PreToolUse safety-net
- ✅ SessionStart context loading
- ✅ SessionEnd learning suggestions

### 🚧 Remaining Work

**Phase 4: Remaining Core Agents**
- ⏳ phoenix-expert agent
- ⏳ performance-analyzer agent
- ⏳ pr-reviewer agent

**Phase 4.5: Expert Consultant Agents (Opus)**
- ⏳ distributed-systems-expert agent
- ⏳ algorithms-researcher agent
- ⏳ cognitive-scientist agent

**Phase 5: Remaining Commands**
- ⏳ /spike command
- ⏳ /spike-migrate command
- ⏳ /benchmark command
- ⏳ /pr-review command
- ⏳ /learn command
- ⏳ /distributed-review command
- ⏳ /algorithm-research command
- ⏳ /cognitive-audit command

**Skills**
- ⏳ phoenix-liveview skill
- ⏳ distributed-systems skill
- ⏳ algorithms skill
- ⏳ cognitive-complexity skill

**Phase 7: Documentation**
- ⏳ Video/GIF demos
- ⏳ Example workflows
- ⏳ Team onboarding guide
- ⏳ Migration guide for existing projects

### Current Capabilities

You can currently use the plugin for:

✅ **Precommit quality gate**: `/precommit` runs all checks
✅ **Feature implementation**: `/feature` provides guided TDD workflow
✅ **Code review**: `/review` performs comprehensive analysis
✅ **Safety protection**: Blocks destructive git/filesystem operations
✅ **Pattern guidance**: elixir-patterns skill provides best practices
✅ **Quality standards**: production-quality skill enforces standards

The system is **functional** for core workflows but lacks some advanced features (phoenix-expert, performance-analyzer, SPIKE mode, etc.).

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
# Skill Name

## Skill Identity
[Description and purpose]

## Triggers
- <example>"trigger phrase"</example>
- <example>"another phrase"</example>

## Core Content
[~1500-2000 words of knowledge]

## Additional References
[Links to reference files]
```

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

### Safety-Net Too Strict

```bash
# Disable safety-net temporarily (not recommended)
export SAFETY_NET_STRICT=0

# Or allow specific operations
# Edit safety-net.sh to customize blocked operations
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
- [Safety-Net Implementation](https://github.com/anthropics/claude-code-safety-net)

### Philosophies
- Dave Thomas (PragDave): DDD, functional core/imperative shell, YAGNI
- Quinn Wilton: Correctness over convenience, production-grade engineering
- John Ousterhout: "A Philosophy of Software Design" - deep modules, reducing complexity

## License

MIT License - See LICENSE file for details

## Author

Jeff Weiss

## Acknowledgments

- Dave Thomas for DDD and functional programming principles
- Quinn Wilton for correctness-first approach
- Jeff Weiss's technical patterns gist
- Claude Code team for plugin architecture
- Anthropic for Claude and tooling

---

**Note**: This is v1.0.0 with minimal working system. Some features are planned for future releases. See Status & Roadmap section for details.

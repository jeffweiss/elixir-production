---
description: Review a GitHub PR with personality-driven debate
argument-hint: <pr-number>
allowed-tools: [Agent, Bash, Read, Grep, Glob]
model: sonnet
---

# PR Review Command

Multi-agent debate review of GitHub Pull Requests. Dispatches personality agents in parallel, runs a rebuttal round, and synthesizes consensus.

## What It Does

1. **Fetch PR** — Using `gh` CLI to get PR data, diff, changed files
2. **Classify** — Determine change type (feature, bug fix, performance, distributed, Phoenix, large refactor)
3. **Dispatch** — Launch relevant personality agents in parallel for independent review (Round 1)
4. **Rebuttal** — Share all findings with all agents, each responds/challenges/concedes (Round 2)
5. **Synthesize** — Produce consensus, resolved debates, unresolved disagreements, and Deming's process changes
6. **Post** — Comment on PR with structured debate review

## Personality Agents

Agents are dispatched based on change type. **torvalds** and **deming** always participate.

| Change Type | Agents |
|-------------|--------|
| New feature | dijkstra, valim, beck, ousterhout + torvalds, deming |
| Bug fix | beck + torvalds, deming |
| Performance | gregg, knuth + torvalds, deming |
| Distributed | lamport, dijkstra, gregg + torvalds, deming |
| Phoenix/LiveView | mccord, ousterhout + torvalds, deming |
| Large refactor | ousterhout, dijkstra + torvalds, deming |

## Prerequisites

**Required**:
- `gh` CLI installed and authenticated
- GitHub repository with pull requests

**Setup**:
```bash
brew install gh     # macOS
gh auth login       # Authenticate
gh pr list          # Verify access
```

## Usage

```bash
# Review specific PR
/pr-review 123

# Review current branch's PR
/pr-review

# Review with PR URL
/pr-review https://github.com/owner/repo/pull/456
```

## Implementation

Launch the **pr-reviewer** agent (debate orchestrator) with the PR number. The orchestrator handles the full two-round debate process:

1. Fetches PR data via `gh`
2. Classifies change type using file-path heuristics
3. Dispatches personality agents in parallel (Round 1)
4. Collects findings and sends to all agents for rebuttal (Round 2)
5. Synthesizes into four-section output
6. Posts review as PR comment

## Review Output

```markdown
## PR Debate Review: [PR Title]

### Consensus (All Agents Agree)
[Definite action items]

### Resolved Debates
[Where one agent conceded — both sides shown]

### Unresolved Disagreements
[Human decides — both arguments presented]

### Deming's Process Changes
[Systemic improvements — Credo rules, CI gates, hooks]
```

## Confidence Ratings

**90-100% (Critical)**: Missing tests/typespecs, security issues, invariant violations
**80-89% (Important)**: Logic bugs, performance issues, pattern violations
**< 80%**: Not reported

## Related Commands

- `/review` — Local code review (before PR)
- `/precommit` — Run quality checks
- `/cognitive-audit` — Deep complexity analysis
- `/spike-migrate` — Upgrade SPIKE code found in PR

## gh CLI Commands Reference

```bash
gh pr view <N> --json title,body,author,files,additions,deletions
gh pr diff <N>
gh pr comment <N> --body "review text"
gh pr review <N> --comment --body "review text"
gh pr review <N> --approve --body "LGTM!"
gh pr review <N> --request-changes --body "Please address..."
gh pr checks <N>
gh pr list --state merged --limit 20  # For Deming's history analysis
```

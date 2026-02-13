# Enforcement Improvements Design

## Problem

Agents using the elixir-production plugin frequently forget to run `mix precommit` before committing. The plugin is strong on reference material but weak on enforcement — no mechanical gates, no discipline skills, no anti-rationalization patterns.

## Decisions

### In scope (this iteration)

| # | Item | Type | Notes |
|---|------|------|-------|
| 1 | Pre-commit hook on `git commit` | Hook | Full `mix precommit` suite, blocking |
| 2 | Precommit enforcement skill | Skill (discipline) | Needs TDD per writing-skills |
| 3 | Session-start hook | Hook | No project-learnings.md loading |
| 7 | Anti-rationalization in agents | Agent edits | Reference shared skill from item 2 |
| 8 | Feature command: precommit gates developer | Command edit | Gate developer agent, not whole workflow |
| 9 | Cross-references: skills → commands | Skill edits | One-line additions |
| 10 | Split precommit scripts (quick + full) | Scripts | Enables fast per-edit + hard commit gate |
| 11 | CSO improvements on SKILL.md descriptions | Skill edits | Frontmatter fixes |
| 12 | Plugin.json improvements | Metadata | Keywords, richer description |

### Deferred

| # | Item | Reason |
|---|------|--------|
| 4 | Blocking PostToolUse hook | Risk of trapping agents mid-implementation |
| 5 | Trim command files | Separate effort, no enforcement impact |
| 6 | Trim templates | Breaking change, separate effort |
| 13 | Skill triggering tests | High effort, do after structural changes stabilize |

## Implementation Phases

### Phase 1: Quick Wins (mechanical, no TDD needed)

- **3** — Session-start hook
- **9** — Cross-references between skills and commands
- **11** — CSO improvements on SKILL.md descriptions
- **12** — Plugin.json improvements

### Phase 2: Infrastructure (scripts and hooks)

- **10** — Split `validate-precommit.sh` into `quick-validate.sh` + `enforce-precommit.sh`
- **1** — Add PreToolUse hook on `Bash:git commit*|Bash:git push*` using `enforce-precommit.sh`

### Phase 3: Enforcement Skill (requires TDD)

- **2** — Create `skills/enforcing-precommit/SKILL.md` with iron law, gate function, rationalization table
- **7** — Add enforcement references to `elixir-developer`, `elixir-reviewer`, `pr-reviewer` agents

### Phase 4: Workflow Gate

- **8** — Edit `/feature` command to gate developer agent on precommit before handoff to review

## Key Design Decisions

### Pre-commit hook runs full suite
Full `mix precommit` — not a "recently run" check. The user was explicit: recency isn't enough.

### Enforcement skill is shared, agents reference it
Rather than duplicating iron laws across 10 agent files, create one skill (`enforcing-precommit`) and have agents cross-reference it. Keeps token cost low per agent.

### Session-start hook does NOT load project-learnings.md
Project-learnings is project-specific context. Agents should pull it when needed, not have it forced into every session.

### Feature command gates the developer, not the workflow
The developer agent must pass precommit before handing off. The review phase doesn't wait for the whole workflow — it starts after the developer verifies their own work.

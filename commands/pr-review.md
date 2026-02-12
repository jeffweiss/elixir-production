---
description: Review a GitHub PR against standards
argument-hint: <pr-number>
allowed-tools: [Task, Bash, Read, Grep, Glob]
model: sonnet
---

# PR Review Command

Automated GitHub Pull Request review using `gh` CLI and pr-reviewer agent. Checks code against project standards, identifies issues, and triggers cognitive complexity analysis for large changes.

## What It Does

Reviews GitHub PRs comprehensively:

1. **Fetch PR** - Using `gh` CLI to get PR data, diff, changed files
2. **Analyze Scale** - Detect large changes (>500 lines or >5 files)
3. **Code Review** - Check against standards (typespecs, tests, patterns)
4. **Cognitive Analysis** - Launch cognitive-scientist for large PRs
5. **Post Feedback** - Comment on PR with findings
6. **SPIKE Detection** - Identify SPIKE code ready for migration

## Prerequisites

**Required**:
- `gh` CLI installed and authenticated
- GitHub repository with pull requests

**Setup**:
```bash
# Install gh CLI
brew install gh  # macOS
# or apt install gh  # Linux

# Authenticate
gh auth login

# Verify access
gh pr list
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

### Step 1: Fetch PR Data

Fetch PR metadata, diff, and changed files using `gh` CLI:

```bash
gh pr view 123 --json number,title,body,author,files,additions,deletions
gh pr diff 123
gh pr view 123 --json files --jq '.files[].path'
```

### Step 2: Detect Large Changes

Check if PR crosses thresholds for cognitive review:
- More than 500 lines changed, OR
- More than 5 files modified, OR
- Complex architectural changes

### Step 3: Launch Reviewers

**For all PRs** - Launch pr-reviewer agent to check against project standards (AGENTS.md, CLAUDE.md, project-learnings.md).

**For large PRs** - Also launch cognitive-scientist agent to analyze complexity, working memory load, and onboarding difficulty.

### Step 4: Generate Review

Pr-reviewer agent analyzes changed files, rates confidence for each issue, and reports only issues with ≥80% confidence. See production-quality skill for code quality standards and cognitive-complexity skill for complexity analysis.

### Step 5: Post Review

Post review as PR comment:

```bash
gh pr comment 123 --body "$(cat review.md)"
```

### Step 6: Handle Edge Cases

**PR not found**: Verify PR number and repository access.

**Not in git repository**: Navigate to project root.

**gh CLI not authenticated**: Run `gh auth login`.

## Review Format Template

```markdown
## Code Review Summary

### 📊 Change Statistics
- Files changed: N
- Lines added: +N
- Lines deleted: -N
- Complexity: Low/Medium/High

### ✅ Strengths
- [Positive observations about the code]

### ⚠️ Issues Found

#### [Critical/Important] Issue description (Confidence: N%)
**File**: `path/to/file.ex:line`
**Issue**: Clear description of the problem

**Recommendation**:
```elixir
# Code fix
```

### 🧠 Cognitive Complexity Analysis

**Large change**: N lines across N files

**Findings**:
- Deep vs shallow modules assessment
- Working memory load concerns
- Temporal coupling detection
- Overall maintainability assessment

### 🚀 SPIKE Code
Detection status and migration readiness if applicable.

### 📝 Next Steps
- [ ] Action items based on findings
- [ ] Run `/precommit` before merging

---
🤖 Generated with Claude Code - Elixir Production Plugin
```

## Configuration

**Review strictness**:
- **Standard** (default): Confidence ≥80%
- **Strict**: Confidence ≥70%
- **Lenient**: Confidence ≥90%

**Cognitive threshold**: 500+ lines OR 5+ files triggers cognitive analysis.

## Confidence Ratings

**90-100% (Critical)**:
- Missing tests (objective)
- Missing typespecs (objective)
- Security vulnerabilities (clear evidence)
- Project convention violations (documented)

**80-89% (Important)**:
- Logic bugs (clear evidence)
- Performance issues (measurable)
- Missing error handling (likely needed)
- Pattern violations (established pattern)

**< 80% (Not reported)**:
- Subjective style preferences
- Speculative improvements
- Uncertain issues

## gh CLI Commands Reference

```bash
# View PR
gh pr view <number>
gh pr view <number> --json title,body,author,files,additions,deletions

# Get diff
gh pr diff <number>

# List changed files
gh pr view <number> --json files --jq '.files[].path'

# Post comment
gh pr comment <number> --body "review text"

# Post review (approve/request changes)
gh pr review <number> --comment --body "review text"
gh pr review <number> --approve --body "LGTM!"
gh pr review <number> --request-changes --body "Please address..."

# Check CI status
gh pr checks <number>

# List PRs
gh pr list --state open --limit 10
```

## Best Practices

1. **Review early**: Run on draft PRs for quick feedback
2. **Address critical first**: Security and correctness before style
3. **Re-review after changes**: Verify fixes with another review

## Related Commands

- `/review` - Local code review (before PR)
- `/precommit` - Run quality checks
- `/cognitive-audit` - Deep complexity analysis
- `/spike-migrate` - Upgrade SPIKE code found in PR

## Domain Knowledge References

For code quality standards, see production-quality skill.
For cognitive complexity analysis, see cognitive-complexity skill.

## Success Criteria

Review succeeds when:
- ✅ PR data fetched successfully
- ✅ All changed files analyzed
- ✅ Issues reported with ≥80% confidence
- ✅ Cognitive analysis included for large PRs
- ✅ SPIKE code identified
- ✅ Review posted as PR comment
- ✅ Actionable recommendations provided

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

```markdown
Fetching PR #123 using gh CLI...

PR: Add user profile feature
Author: @developer
Files changed: 8
Lines: +452 / -23
```

**Using gh CLI**:
```bash
# Get PR metadata
gh pr view 123 --json number,title,body,author,files,additions,deletions

# Get PR diff
gh pr diff 123

# List changed files
gh pr view 123 --json files --jq '.files[].path'
```

### Step 2: Detect Large Changes

**Thresholds for cognitive review**:
- More than 500 lines changed, OR
- More than 5 files modified, OR
- Complex architectural changes

```markdown
Analyzing PR scale...

Files changed: 8
Lines changed: +452 / -23
Complexity: Medium

This is a moderately large change. Will launch cognitive-scientist agent for complexity analysis.
```

### Step 3: Launch Reviewers

**For all PRs** - Launch pr-reviewer agent:
```markdown
Launching pr-reviewer agent for code review...

The reviewer will:
1. Load project standards (AGENTS.md, CLAUDE.md, project-learnings.md)
2. Review changed files against standards
3. Check for missing typespecs, tests, error handling
4. Identify SPIKE code
5. Verify project convention compliance
```

**For large PRs** - Also launch cognitive-scientist:
```markdown
Launching cognitive-scientist agent for cognitive complexity analysis...

This PR modifies 8 files with 452 lines. Analyzing:
- Deep vs shallow modules
- Working memory load
- Onboarding difficulty
- Complexity indicators
```

### Step 4: Review Process

The pr-reviewer agent executes:

```bash
# Fetch changed files
gh pr diff 123 > /tmp/pr_123.diff

# Read changed files
for file in $(gh pr view 123 --json files --jq '.files[].path'); do
  Read $file
done

# Load project standards
Read AGENTS.md
Read CLAUDE.md
Read .claude/project-learnings.md

# Analyze each file
- Check typespecs on public functions
- Verify test coverage
- Check error handling (tagged tuples)
- Identify SPIKE markers
- Verify project patterns

# Rate confidence for each issue
# Report only issues with ≥80% confidence
```

### Step 5: Post Review

**Generate review comment**:
```bash
gh pr comment 123 --body "$(cat review.md)"
```

**Review format**:
```markdown
## Code Review Summary

### 📊 Change Statistics
- Files changed: 8
- Lines added: +452
- Lines deleted: -23
- Complexity: Medium

### ✅ Strengths
- Excellent test coverage (95%)
- Clear separation of concerns
- Follows project authentication patterns
- Good error handling with tagged tuples

### ⚠️ Issues Found

#### [Critical] Missing typespec on public API (Confidence: 95%)
**File**: `lib/my_app/accounts.ex:45`
**Function**: `update_profile/2` needs typespec

**Recommendation**:
```elixir
@spec update_profile(User.t(), map()) ::
        {:ok, User.t()} | {:error, Ecto.Changeset.t()}
def update_profile(user, params) do
  # ...
end
```

#### [Important] Potential N+1 query (Confidence: 85%)
**File**: `lib/my_app_web/profile_live.ex:23`
**Issue**: Loading user posts in loop

**Recommendation**: Add preload in query:
```elixir
user = Accounts.get_user!(id) |> Repo.preload(:posts)
```

### 🧠 Cognitive Complexity Analysis

**PR adds** 452 lines across 8 files. Cognitive assessment:

**Strengths**:
- Deep module design in `Accounts.Profile`
- Clear separation between boundary and core logic

**Concerns**:
- `ProfileLive.handle_event/3` has mixed abstraction levels
- Consider extracting validation to `Accounts.ProfileValidator`
- Onboarding difficulty: Medium (requires understanding auth flow)

**Overall**: Well-structured with opportunities for improved clarity.

### 🚀 SPIKE Code
None detected. All code appears production-ready.

### 📝 Next Steps
- [ ] Add typespec to `update_profile/2`
- [ ] Fix N+1 query with preload
- [ ] Consider cognitive complexity suggestions
- [ ] Run `/precommit` before merging

---
🤖 Generated with Claude Code - Elixir Production Plugin
```

### Step 6: Handle Edge Cases

**PR not found**:
```markdown
❌ PR Not Found

Error: PR #999 does not exist in this repository

Check:
- PR number is correct
- You have access to the repository
- PR hasn't been closed/deleted
```

**Not in git repository**:
```markdown
❌ Not in Git Repository

Current directory is not a git repository.

Navigate to your project root and try again.
```

**gh CLI not authenticated**:
```markdown
❌ GitHub CLI Not Authenticated

Run: gh auth login

Then try the pr-review command again.
```

## Review Checklist

The pr-reviewer agent checks:

### Code Quality

**Elixir Standards**:
- [ ] Public functions have typespecs
- [ ] Error handling uses tagged tuples
- [ ] Pattern matching in function heads
- [ ] Proper use of `with` for railway programming
- [ ] No N+1 queries

**Testing**:
- [ ] New public functions have tests
- [ ] Edge cases covered
- [ ] Error paths tested
- [ ] Integration tests if needed

**Phoenix/LiveView** (if applicable):
- [ ] Stream IDs match project pattern
- [ ] Forms use `to_form/2`
- [ ] Proper `on_mount` hooks for auth
- [ ] `assign_async` for async operations

**Security**:
- [ ] Input validation present
- [ ] SQL injection risks mitigated
- [ ] XSS vulnerabilities checked
- [ ] Authorization checks in place

### Project Compliance

**Against project-learnings.md**:
- [ ] Follows documented conventions
- [ ] Uses established patterns
- [ ] Avoids documented anti-patterns
- [ ] Consistent with domain model

**Against AGENTS.md/CLAUDE.md**:
- [ ] Meets production quality standards
- [ ] DDD principles applied
- [ ] Error handling strategy followed

### SPIKE Code

**Detection markers**:
```elixir
# SPIKE: <reason>
# TODO: Add typespecs
# TODO: Add tests
# Needs refactoring
```

**Migration readiness**:
- Has code been stable for 2+ weeks?
- Are patterns clear?
- Is it ready for production migration?

## Examples

### Example 1: Small PR (No Issues)

**Input**:
```bash
/pr-review 123
```

**Output**:
```markdown
## Code Review: Fix email validation bug

### 📊 Change Statistics
- Files changed: 2
- Lines added: +15
- Lines deleted: -8
- Complexity: Low

### ✅ Strengths
- Focused change (single bug fix)
- Test added for regression
- Follows existing validation patterns
- Clear commit message

### ⚠️ Issues Found
No issues found! Code meets all production standards.

### 📝 Recommendation
✅ Approved - Ready to merge after `/precommit` passes

---
🤖 Generated with Claude Code - Elixir Production Plugin
```

### Example 2: Large PR with Issues

**Input**:
```bash
/pr-review 456
```

**Output**:
```markdown
## Code Review: Add payment processing feature

### 📊 Change Statistics
- Files changed: 12
- Lines added: +847
- Lines deleted: -45
- Complexity: High

### ✅ Strengths
- Comprehensive test coverage (92%)
- Good separation of concerns
- Clear error handling throughout
- Follows project payment patterns

### ⚠️ Issues Found

#### [Critical] Security: Missing input validation (Confidence: 100%)
**File**: `lib/my_app/payments/stripe_client.ex:34`
**Issue**: Amount parameter not validated before Stripe API call

**Risk**: Could pass invalid amounts to Stripe (negative, zero, non-integer)

**Fix**:
```elixir
def charge(amount, currency, metadata) when is_integer(amount) and amount > 0 do
  # Validate amount before API call
  with :ok <- validate_amount(amount),
       {:ok, charge} <- Stripe.Charge.create(%{
         amount: amount,
         currency: currency,
         metadata: metadata
       }) do
    {:ok, charge}
  end
end

defp validate_amount(amount) when is_integer(amount) and amount > 0, do: :ok
defp validate_amount(_), do: {:error, :invalid_amount}
```

#### [Critical] Missing typespec (Confidence: 95%)
**File**: `lib/my_app/payments.ex:56`
**Function**: `process_payment/3` lacks typespec

**Add**:
```elixir
@spec process_payment(User.t(), integer(), map()) ::
        {:ok, Payment.t()} | {:error, :insufficient_funds | Ecto.Changeset.t()}
```

#### [Important] Potential race condition (Confidence: 85%)
**File**: `lib/my_app/payments/balance.ex:23`
**Issue**: Balance check and debit not atomic

**Current**:
```elixir
def debit(user_id, amount) do
  balance = get_balance(user_id)
  if balance >= amount do
    update_balance(user_id, balance - amount)
  end
end
```

**Problem**: Another process could debit between check and update

**Fix**: Use database transaction with pessimistic locking:
```elixir
def debit(user_id, amount) do
  Repo.transaction(fn ->
    user = Repo.get!(User, user_id, lock: "FOR UPDATE")
    if user.balance >= amount do
      Ecto.Changeset.change(user, balance: user.balance - amount)
      |> Repo.update!()
    else
      Repo.rollback(:insufficient_funds)
    end
  end)
end
```

### 🧠 Cognitive Complexity Analysis

**Large change**: 847 lines across 12 files

**Findings**:

**Shallow modules detected**:
- `PaymentProcessor` (depth ratio: 0.9)
  - Complex interface, minimal power
  - 20+ call sites need to handle errors
  - Recommendation: Pull error handling into module

**High working memory load**:
- `process_complex_payment/7`: 7 parameters, 4-level nesting
  - Score: 8/10 (high)
  - Recommendation: Use context struct

**Temporal coupling**:
- Payment initialization has 5-step sequence (no enforcement)
  - Risk: Easy to call in wrong order
  - Recommendation: Single `initialize_payment/1` function

**Overall assessment**: Good architecture with some complexity hot spots. Addressing recommendations would improve maintainability.

### 🚀 SPIKE Code
None detected.

### 📝 Recommendations

**Critical (Must fix before merge)**:
1. Add input validation to Stripe client
2. Add typespec to `process_payment/3`
3. Fix race condition with transaction

**Important (Should address)**:
4. Refactor PaymentProcessor to deep module pattern
5. Add context struct to reduce parameter count
6. Consolidate payment initialization

**Optional (Nice to have)**:
7. Add property-based tests for amount validation
8. Consider extracting PaymentValidator module

### ✨ Next Steps

1. **Fix critical issues** (estimated: 2-3 hours)
2. **Address race condition** (estimated: 1 hour)
3. **Consider refactoring recommendations** (estimated: 4-6 hours)
4. **Run `/precommit`** to verify all checks pass
5. **Request re-review** after changes

---
🤖 Generated with Claude Code - Elixir Production Plugin
```

### Example 3: SPIKE Code Detected

**Output**:
```markdown
## Code Review: Add dashboard feature

### 🚀 SPIKE Code Detected

**File**: `lib/my_app_web/live/dashboard_live.ex`
**Status**: Ready for migration

**SPIKE markers found**:
- `# SPIKE: Rapid prototyping for user validation`
- Missing typespecs (12 functions)
- Minimal error handling
- 2 smoke tests only

**Assessment**:
- Stable for 3 weeks
- Patterns clear and validated with users
- Performance acceptable for 100 users

**Migration readiness**: 🟡 Medium

**Estimated migration effort**: ~4 hours
- Add typespecs: 1 hour
- Add error handling: 1.5 hours
- Comprehensive tests: 1.5 hours

**Next step**: `/spike-migrate lib/my_app_web/live/dashboard_live.ex`

### ⚠️ Other Issues
[Continue with other findings...]
```

## Integration with Cognitive Scientist

**Automatic trigger for large PRs**:

```markdown
Detected large PR: 8 files, 452 lines changed

Launching cognitive-scientist agent in parallel with code review...

Both analyses will be integrated into the final review.
```

**Cognitive analysis includes**:
- Deep vs shallow modules (Ousterhout principles)
- Working memory load of new code
- Temporal coupling detection
- Onboarding difficulty assessment

## Configuration

Based on `.claude/elixir-production.local.md`:

**Review strictness**:
- **Standard** (default): Confidence ≥80%
- **Strict**: Confidence ≥70%
- **Lenient**: Confidence ≥90%

**Cognitive threshold**:
- **Lines**: 500+ lines triggers cognitive analysis
- **Files**: 5+ files triggers cognitive analysis
- **Override**: Can specify `--skip-cognitive` flag

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

## Workflow

**Standard workflow**:
1. Developer creates PR
2. Run `/pr-review <number>`
3. Review posted as PR comment
4. Developer addresses feedback
5. Re-run `/pr-review <number>` if needed
6. Merge when approved

**Team integration**:
```bash
# In CI/CD pipeline
- name: Claude Code Review
  run: claude pr-review ${{ github.event.pull_request.number }}

# Or as GitHub Action
- uses: anthropic/claude-code-review@v1
  with:
    pr-number: ${{ github.event.pull_request.number }}
```

## Best Practices

1. **Review early**: Run on draft PRs for quick feedback
2. **Address critical first**: Security and correctness before style
3. **Use cognitive insights**: Large PRs benefit from complexity analysis
4. **Re-review after changes**: Verify fixes with another review
5. **Document patterns**: Add recurring issues to project-learnings.md

## Related Commands

- `/review` - Local code review (before PR)
- `/precommit` - Run quality checks
- `/cognitive-audit` - Deep complexity analysis
- `/spike-migrate` - Upgrade SPIKE code found in PR

## Success Criteria

Review succeeds when:
- ✅ PR data fetched successfully
- ✅ All changed files analyzed
- ✅ Issues reported with ≥80% confidence
- ✅ Cognitive analysis included for large PRs
- ✅ SPIKE code identified
- ✅ Review posted as PR comment
- ✅ Actionable recommendations provided

## Troubleshooting

**Error: gh command not found**:
```bash
# Install gh CLI
brew install gh  # macOS
apt install gh   # Linux
```

**Error: gh authentication required**:
```bash
gh auth login
```

**Error: PR not found**:
- Verify PR number
- Check repository access
- Ensure PR isn't closed

**Error: Cannot post comment**:
- Verify write permissions
- Check GitHub token scopes
- Ensure not rate-limited

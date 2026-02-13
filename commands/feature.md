---
description: Implement a new feature with architecture planning and parallel exploration
argument-hint: <feature-description>
allowed-tools:
  - Task
  - Read
  - Glob
  - Grep
  - TodoWrite
model: sonnet
---

# Feature Command

Guided feature implementation with comprehensive architecture planning, parallel codebase exploration, TDD implementation, and multi-lens review.

## What It Does

Implements a complete feature workflow:

1. **Parallel Codebase Exploration** - Fork-join pattern with multiple explore agents
2. **Architecture Design** - High-quality planning with complexity analysis (Opus)
3. **User Gate** - Approval before implementation
4. **TDD Implementation** - Test-first development (Sonnet)
5. **Precommit Gate** - Developer runs `mix precommit`, ALL checks must pass before handoff
6. **Parallel Quality Review** - Multi-lens review with confidence filtering
7. **Summary** - Consolidated findings and next steps

## Usage

```bash
/feature Add user email verification
/feature Implement product search with filters
/feature Create admin dashboard with analytics
```

## Implementation

### Phase 1: Parallel Codebase Exploration

Launch 2-3 explore agents **in parallel** to gather context:

```
Agent 1: Find similar features/patterns
Agent 2: Identify relevant contexts and modules
Agent 3: Analyze test patterns for similar features
```

**Launch in single message** (parallel execution):

```markdown
I'm launching 3 agents in parallel to explore the codebase for relevant patterns:

1. Explore agent: Find similar features to "email verification"
2. Explore agent: Identify authentication and user management contexts
3. Explore agent: Analyze existing test patterns for user features

Waiting for all agents to complete...
```

**After all complete**, consolidate findings:

```markdown
## Exploration Results

**Similar Features Found**:
- Password reset flow (lib/my_app/accounts/password_reset.ex)
- Phone verification (lib/my_app/accounts/phone_verification.ex)

**Relevant Contexts**:
- Accounts context (lib/my_app/accounts.ex)
- Email context (lib/my_app/email.ex)
- User schema (lib/my_app/accounts/user.ex)

**Test Patterns**:
- Integration tests with Mox for email sending
- Property-based tests for tokens
- Criticality 9-10 for authentication flows

**Project Conventions** (from project-learnings.md):
- Tokens expire in 24 hours
- Background jobs use Oban
- Email templates in templates/email/
```

### Phase 2: Architecture Design

Launch **elixir-architect** agent (Opus) with consolidated exploration:

```markdown
Launching elixir-architect (Opus) to design architecture...

Providing context:
- Feature requirement: Add email verification
- Similar features: password reset, phone verification
- Relevant contexts: Accounts, Email
- Project patterns: Oban for background jobs, Mox for testing

Agent will:
1. Analyze existing patterns
2. Design architecture with complexity analysis
3. Create comprehensive TDD test suite
4. Provide phased implementation plan
5. Auto-create benchmarks if O(n²)+ detected

Waiting for architect...
```

**Architect Output** (example):

```markdown
# Feature Architecture: Email Verification

## Overview

Implement email verification with token-based confirmation link sent via email.

## Module Structure

lib/my_app/
  accounts/
    email_verification.ex      # Token generation/validation
    user.ex                     # Add verified_at field
  accounts.ex                   # Public API

lib/my_app/workers/
  email_verification_worker.ex  # Oban worker for email sending

lib/my_app_web/
  controllers/
    email_verification_controller.ex  # Handle verification link

## Public API

```elixir
@spec send_verification_email(User.t()) ::
  {:ok, :email_sent} | {:error, :already_verified} | {:error, :email_failed}

@spec verify_email(String.t()) ::
  {:ok, User.t()} | {:error, :invalid_token} | {:error, :expired}
```

## Complexity Analysis

### Operation: generate_verification_token()
- Algorithm: Random secure token with HMAC
- Complexity: O(1)
- Expected: <1ms
- Security: 32-byte random, signed with Phoenix.Token

### Operation: verify_token(token)
- Algorithm: HMAC verification
- Complexity: O(1)
- Expected: <1ms
- Timing-safe comparison used

## Comprehensive Test Suite

### Success Cases (Criticality: 9-10)
1. Sends verification email with token
2. Verifies email with valid token
3. Marks user as verified

### Error Cases (Criticality: 9-10)
4. Returns error if already verified
5. Returns error for invalid token
6. Returns error for expired token (>24h)
7. Returns error if email sending fails

### Edge Cases (Criticality: 7-8)
8. Handles multiple verification attempts
9. Handles token reuse attempt

[Full test specifications provided]

## Implementation Phases

### Phase 1: Core Functionality (4-5 hours)
- Create email_verification module
- Add verified_at to users table
- Implement token generation/validation
- Comprehensive tests

### Phase 2: Email Integration (2-3 hours)
- Create Oban worker
- Email templates
- Controller for verification link
- Integration tests

### Phase 3: UI (2 hours)
- Verification sent page
- Verification success page
- Resend verification link

## Success Criteria
- All critical tests pass (9-10)
- Tokens cryptographically secure
- Email verification works end-to-end
- Precommit checks pass
```

### Phase 3: User Gate

**Present architecture for approval**:

```markdown
## Architecture Ready for Review

I've designed a comprehensive architecture for email verification.

### Key Decisions:
1. **Token approach**: Phoenix.Token (signed, 24h expiry)
2. **Email delivery**: Oban background worker (async, retry logic)
3. **Phases**: 3 phases, ~8-10 hours total

### Test Strategy:
- 18 comprehensive tests
- Criticality 9-10 for security/authentication
- Property-based tests for token security

### Review:
- See full architecture above
- Check tradeoffs section
- Verify alignment with requirements

**Proceed with implementation?**
- Type "yes" to start TDD implementation
- Ask questions if anything unclear
- Request changes if needed
```

**Wait for user response** before proceeding.

### Phase 4: TDD Implementation

Launch **elixir-developer** agent (Sonnet) with architecture:

```markdown
User approved architecture. Launching elixir-developer (Sonnet) for TDD implementation...

Providing to developer:
- Complete architecture plan
- Test specifications
- Module structure
- Success criteria

Developer will:
1. Create comprehensive tests FIRST
2. Implement following TDD: Red → Green → Refactor
3. Run tests continuously
4. Track progress with TodoWrite
5. Update project-learnings.md

Waiting for implementation...
```

**Developer works through TDD cycles**:

```
TodoWrite tracking:

Phase 1: Core Functionality
- [in_progress] Create tests for send_verification_email/1 (8 tests)
  Status: Red phase - 8 tests failing (expected)

- [in_progress] Implement send_verification_email/1
  Status: Green phase - 8/8 tests passing

- [pending] Create tests for verify_email/1 (10 tests)
- [pending] Implement verify_email/1

[Developer continues through all phases]
```

### Phase 5: Precommit Gate

<EXTREMELY-IMPORTANT>
The developer agent MUST run `mix precommit` and verify ALL FOUR checks pass before handing off to review.
Do NOT proceed to Phase 6 if precommit fails. Fix all failures first.
</EXTREMELY-IMPORTANT>

After TDD implementation completes, the developer agent runs the full precommit suite:

```bash
mix precommit
# Or if no alias: mix compile --warnings-as-errors && mix format && mix credo --strict && mix test
```

**Gate criteria:**
- All code compiles with zero warnings
- All files formatted (Styler applied)
- Credo strict mode passes
- All tests pass (including newly written tests)

If any check fails, the developer fixes the issues and re-runs until all pass. Only then does the workflow proceed to review.

### Phase 6: Parallel Quality Review

Launch 3 reviewer agents **in parallel**:

```markdown
Implementation complete! Launching 3 reviewers in parallel for multi-lens review:

1. Simplicity Reviewer: Code clarity and elegance
2. Correctness Reviewer: Bugs and edge cases (confidence ≥80%)
3. Conventions Reviewer: Project patterns compliance

Waiting for all reviewers...
```

**Consolidate findings** from all reviewers:

```markdown
## Quality Review Findings

### Simplicity Review
✅ Code is clear and well-structured
✅ Functions are focused and single-purpose
💡 Suggestion: Extract email template building into separate function

### Correctness Review (Confidence-based)

[Important] Missing error handling (Confidence: 85%): email_verification_controller.ex:23
Function doesn't handle Oban job failure scenario.
Add: Handle {:error, :job_failed} case in controller

[Critical] Security issue (Confidence: 95%): email_verification.ex:42
Token comparison not timing-safe. Use Phoenix.Token.verify instead of string comparison.

### Conventions Review
✅ Follows project patterns (Oban, Phoenix.Token)
✅ Consistent with project-learnings.md conventions
⚠️  Test criticality tags missing on 3 tests

### Summary
- 2 issues found (1 critical, 1 important)
- All high-confidence (85%+), actionable
- 3 minor improvements suggested
```

### Phase 7: Summary

Provide comprehensive summary:

```markdown
# Feature Implementation Complete: Email Verification

## What Was Built

✅ **Core functionality**: Token generation/validation
✅ **Email integration**: Oban worker with templates
✅ **User interface**: Verification pages and flows
✅ **Comprehensive tests**: 18 tests, criticality 9-10

## Quality Metrics

- Tests: 18 total, all passing
- Test coverage: 100% of new code
- Criticality: 15 tests rated 9-10 (critical paths)
- Precommit: All checks pass

## Review Findings

**Critical Issues** (Must fix):
1. Token comparison timing-safe issue - SECURITY

**Important Issues**:
1. Missing Oban failure handling

**Improvements**:
- 3 code clarity suggestions

## Next Steps

1. Address critical security issue (5 mins)
2. Fix Oban error handling (10 mins)
3. Optional: Apply code clarity suggestions
4. Run /precommit to verify
5. Ready for PR!

## Files Changed

- lib/my_app/accounts/email_verification.ex (new)
- lib/my_app/accounts.ex (updated)
- lib/my_app/accounts/user.ex (updated)
- lib/my_app/workers/email_verification_worker.ex (new)
- lib/my_app_web/controllers/email_verification_controller.ex (new)
- test/my_app/accounts/email_verification_test.exs (new)
- test/my_app/workers/email_verification_worker_test.exs (new)

## Project Knowledge Updated

Updated .claude/project-learnings.md with:
- Email verification patterns
- Phoenix.Token usage
- Oban background job pattern
```

## Configuration

### Scenario-Specific Behavior

Based on `.claude/elixir-production.local.md`:

**Enterprise mode** (strict_mode: true):
- Require architecture approval
- All 3 review lenses
- Extensive documentation

**Prototype mode** (strict_mode: false):
- Optional architecture approval
- Focus on functionality
- Minimal documentation

**Spike mode**:
- Skip architecture phase
- Fast implementation
- Mark as SPIKE code

## Error Handling

### Exploration Phase Failures

```
⚠️  Exploration incomplete

Agent 1: ✅ Found 3 similar features
Agent 2: ✅ Identified 2 relevant contexts
Agent 3: ❌ Timeout finding test patterns

Proceeding with available context. May need manual review of test patterns.
```

### Architecture Phase Issues

```
❌ Architecture design failed

Error: Unable to analyze complexity - similar features too different

Action: Provide more specific requirements or manual complexity estimates.
```

### Implementation Phase Failures

```
❌ Implementation failed: Tests not passing

Last status: 2/18 tests still failing
Issue: Token expiration logic incorrect

Action: Developer needs to fix failing tests before proceeding.
```

## Best Practices

1. **Clear requirements**: Specific feature descriptions get better results
2. **Review architecture**: Always review before approving implementation
3. **Trust the process**: TDD ensures quality, but takes time
4. **Address critical issues**: Fix security/correctness before shipping
5. **Update knowledge**: Capture patterns in project-learnings.md

## Success Metrics

Feature workflow succeeds when:
- ✅ Clear architecture with tradeoffs documented
- ✅ TDD approach with tests before implementation
- ✅ All critical tests passing (9-10 criticality)
- ✅ Only high-confidence issues reported (≥80%)
- ✅ Multi-lens review catches different issue types
- ✅ Ready for PR with minimal back-and-forth

## Related Commands

- `/precommit` - Validate before commit
- `/review` - Deep review of existing code
- `/spike` - Fast prototyping without full quality
- `/benchmark` - Performance analysis
- `/cognitive-audit` - Complexity analysis

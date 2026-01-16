---
description: Fast iteration mode for experiments without production requirements
argument-hint: <spike-goal>
allowed-tools:
  - "Task"
  - "Read"
  - "Write"
  - "Edit"
  - "Bash(mix *)"
  - "Glob"
  - "Grep"
model: haiku
---

# Spike Mode

Rapid prototyping for exploring ideas and proving concepts without production quality requirements.

## What It Does

Enables fast iteration with deliberately reduced quality gates:

1. **Skip Production Standards** - No typespecs, minimal tests, basic error handling
2. **Mark All SPIKE Code** - Clear `# SPIKE:` comments on every file/function
3. **Track Technical Debt** - Maintain `.claude/spike-debt.md`
4. **Focus on Learning** - Validate approach, not build production code
5. **Plan Migration** - Document what works for later upgrade

## Usage

```bash
/spike Add user email preferences
/spike Try GraphQL subscriptions for live updates
/spike Experiment with Nx for ML predictions
```

## When to Use SPIKE Mode

**Perfect for**:
- Exploring new libraries or approaches
- Prototyping UI/UX concepts
- Validating technical feasibility
- Learning new patterns
- Quick demos for stakeholders
- Answering "can we do X?" questions

**NOT for**:
- Production features
- Security-critical code
- Data integrity operations
- Public APIs
- Payment processing
- Authentication/authorization

## Implementation

### Step 1: Validate SPIKE Appropriateness

Check if SPIKE mode is safe for this goal:

```markdown
Analyzing SPIKE request: [goal]

Checking appropriateness:
- Security impact: [Low/Medium/High]
- Data integrity risk: [Low/Medium/High]
- Production user exposure: [None/Limited/Direct]

Decision: [✅ Safe for SPIKE | ⚠️ Proceed with caution | ❌ Requires production quality]
```

**If HIGH risk**:

```
❌ SPIKE Mode Not Appropriate

This feature involves:
- [Security/Data/User risk]

Recommendation: Use /feature for full TDD implementation

SPIKE is for learning and exploration, not production-critical code.
```

### Step 2: Create/Update SPIKE Debt Tracker

Initialize or read existing `.claude/spike-debt.md`:

```markdown
# SPIKE Technical Debt

Track all SPIKE code for future migration to production quality.

## Active SPIKEs

### [Goal] - [Date Started]
**Purpose**: Quick exploration of [what you're testing]
**Status**: 🔬 Experimenting | 🟡 Validated (works) | 🔴 Abandoned (didn't work)
**Migration Priority**: Low | Medium | High
**Estimated Migration Effort**: [X hours/days]

**Files**:
- lib/my_app/[module].ex
- lib/my_app_web/live/[live].ex
- test/[basic_test].exs (smoke tests only)

**What We Learned**:
- [Key insights from exploration]
- [What worked well]
- [What needs improvement]

**Migration Notes**:
- Need comprehensive tests (currently 2 smoke tests)
- Add typespecs (0 functions have specs)
- Implement proper error handling (only happy path)
- Add complexity analysis

---

## Migrated SPIKEs

[Archive of completed migrations]

---

## Abandoned SPIKEs

[Archive of experiments that didn't pan out]
```

### Step 3: Rapid Implementation

Launch **elixir-developer** agent (Haiku) with SPIKE constraints:

```markdown
Launching elixir-developer (Haiku) in SPIKE mode...

SPIKE Goal: [user's goal]

SPIKE Constraints:
- ✅ Focus on working code FAST
- ✅ Skip typespecs initially
- ✅ Minimal tests (1-2 smoke tests only)
- ✅ Basic error handling (happy path focus)
- ✅ Mark everything with # SPIKE: comments
- ✅ Use simplest approach, not best approach
- ❌ No comprehensive test suite
- ❌ No production error handling
- ❌ No performance optimization
- ❌ No complexity analysis

Agent will:
1. Create minimal working implementation
2. Add # SPIKE: marker to every file/function
3. Write 1-2 smoke tests (basic functionality only)
4. Document what works in spike-debt.md
5. Note migration requirements

Target: Working prototype in <1 hour

Waiting for implementation...
```

### Step 4: SPIKE Code Markers

All SPIKE code MUST include clear markers:

**File-level marker**:

```elixir
# SPIKE: Email preferences experiment - 2025-01-16
# This is prototype code for exploring user preference storage.
# Migration required before production. See .claude/spike-debt.md

defmodule MyApp.UserPreferences do
  # SPIKE: Minimal implementation for testing concept
  def get_preferences(user_id) do
    # Implementation...
  end
end
```

**Function-level markers**:

```elixir
defmodule MyApp.Accounts do
  # SPIKE: Quick prototype - needs proper error handling
  def update_email_preferences(user, preferences) do
    # Only handles happy path
    Repo.update!(changeset)
  end
end
```

**Test markers**:

```elixir
# SPIKE: Smoke tests only - need comprehensive test suite for production
defmodule MyApp.UserPreferencesTest do
  use MyApp.DataCase

  # SPIKE: Basic happy path test
  test "get_preferences/1 returns preferences" do
    user = insert(:user)
    assert {:ok, _prefs} = UserPreferences.get_preferences(user.id)
  end
end
```

### Step 5: Document Learnings

Update `.claude/spike-debt.md` with findings:

```markdown
## Active SPIKEs

### Email Preferences - 2025-01-16
**Purpose**: Test storing user email preferences in JSONB column vs separate table
**Status**: 🟡 Validated (JSONB approach works well)
**Migration Priority**: Medium
**Estimated Migration Effort**: 4-6 hours

**Files**:
- lib/my_app/user_preferences.ex (85 lines)
- lib/my_app/accounts.ex (updated, 3 new functions)
- lib/my_app_web/live/preferences_live.ex (120 lines)
- test/my_app/user_preferences_test.exs (2 smoke tests)

**What We Learned**:
✅ JSONB approach is flexible and performant for <100 fields
✅ Phoenix LiveView handles preference updates cleanly
✅ No N+1 queries with current approach
⚠️  Need validation on JSONB structure
⚠️  Need indexes on JSONB fields for search

**Migration Notes**:
- Add comprehensive tests (need ~15 tests for all cases)
- Add typespecs (@spec for 6 public functions)
- Implement input validation and error handling
- Add JSONB field indexes
- Document JSONB schema structure
- Add complexity analysis (current O(n) should be fine)

**Performance Note**:
- Tested with 1,000 users - no issues
- Need benchmarks if scaling to 100K+ users
```

### Step 6: Present Results

Provide clear summary of SPIKE:

```markdown
# SPIKE Complete: Email Preferences

## What We Built

✅ **Working prototype** in 45 minutes
- User preference storage (JSONB approach)
- LiveView UI for managing preferences
- Basic CRUD operations
- 2 smoke tests

## What We Learned

**Technical Validation**:
✅ JSONB approach works - flexible and fast
✅ LiveView integration is straightforward
✅ Current design handles 1,000 users without issues

**Unknowns**:
⚠️  Scale to 100K+ users (needs benchmarking)
⚠️  Complex queries on JSONB (may need separate table)

## Code Quality

**Current State** (SPIKE):
- No typespecs (0/6 functions)
- Minimal tests (2 smoke tests)
- Basic error handling (happy path only)
- No performance analysis
- All marked with # SPIKE: comments

**Migration Required**:
- Comprehensive tests: ~15 tests (4-6 hours)
- Typespecs: 6 functions (1 hour)
- Error handling: all edge cases (2 hours)
- Documentation: (1 hour)
- Total: ~8 hours to production quality

## Files Created

- lib/my_app/user_preferences.ex (85 lines) [SPIKE]
- lib/my_app_web/live/preferences_live.ex (120 lines) [SPIKE]
- test/my_app/user_preferences_test.exs (2 tests) [SPIKE]

## Next Steps

**Option 1: Migrate to Production** (recommended if approach validated)
Run: `/spike-migrate lib/my_app/user_preferences.ex`
- Upgrade to production quality
- Full test suite
- All quality gates

**Option 2: Continue Experimenting**
- Keep as SPIKE
- Test with real users (non-production)
- Gather more feedback
- Migrate later

**Option 3: Abandon**
- Approach didn't work as expected
- Archive in spike-debt.md
- Try different approach

## Technical Debt Tracked

Updated `.claude/spike-debt.md` with:
- Migration requirements
- Effort estimates
- Learnings captured
```

## SPIKE Rules

### What SPIKE Code Includes

**Minimum viable**:
- ✅ Working implementation (no compilation errors)
- ✅ # SPIKE: markers on all files/functions
- ✅ 1-2 smoke tests (basic functionality)
- ✅ Basic error handling (prevent crashes)
- ✅ Simple, readable code

**Explicitly skip**:
- ❌ Comprehensive test suites
- ❌ Typespecs (can add after if helpful)
- ❌ Edge case handling
- ❌ Performance optimization
- ❌ Complexity analysis
- ❌ Production-grade error handling
- ❌ Documentation (beyond # SPIKE: comments)
- ❌ Code review

### When to Stop Spiking

**Stop and migrate** when:
- Approach is validated and working
- Users need this in production
- Other features depend on it
- Code has been stable for 1+ week

**Stop and abandon** when:
- Approach doesn't work
- Better alternative found
- Requirements changed
- Complexity too high

**Keep spiking** when:
- Still exploring and learning
- Multiple approaches to try
- Unclear if needed in production
- Gathering stakeholder feedback

## Precommit Behavior

SPIKE code **skips some precommit checks**:

```bash
# Run precommit on SPIKE code
/precommit

# Modified behavior:
✅ Compilation (still required - no broken code)
✅ Formatting (still required - readable code)
⚠️  Credo warnings allowed (not errors)
⚠️  Minimal test coverage acceptable

# Note in output:
⚠️  SPIKE Code Detected
Files with # SPIKE: markers found.
This is prototype code - migration required before production.
See .claude/spike-debt.md for migration plan.
```

## Configuration

### SPIKE Time Limits

Track how long SPIKE code lives:

```markdown
## Active SPIKEs

### [Feature] - Created: 2025-01-16
**Age**: 3 days
**Status**: 🟡 Validated

⚠️  SPIKE is >7 days old
Consider migrating to production or abandoning.
SPIKEs should be short-lived experiments.
```

**Recommended limits**:
- 0-7 days: 🟢 Active exploration
- 7-14 days: 🟡 Should decide: migrate or abandon
- 14+ days: 🔴 Becoming technical debt - migrate now

## Error Handling

### SPIKE for Security-Critical Code

```
❌ SPIKE Mode Not Appropriate

Goal: "Add user authentication"

This involves security, which requires production quality:
- Comprehensive testing (authentication must be bulletproof)
- Proper error handling (security failures must be safe)
- Typespecs (clear contracts for security functions)

Use: /feature for full TDD implementation

SPIKE is for exploration, not security.
```

### SPIKE Debt Tracker Missing

```
Creating .claude/spike-debt.md...

# SPIKE Technical Debt

Track all SPIKE code for future migration.

[Initial template created]

✅ SPIKE tracker initialized
```

## Best Practices

1. **Clear markers**: Every SPIKE file/function marked
2. **Track debt**: Always update spike-debt.md
3. **Time-box**: Keep SPIKEs short (days, not weeks)
4. **Document learnings**: Capture what worked/didn't
5. **Migrate or abandon**: Don't let SPIKEs linger
6. **Avoid production**: Keep SPIKE code away from users
7. **Smoke tests**: Ensure basic functionality works

## Migration Path

Every SPIKE needs clear migration path:

```markdown
## Migration Checklist for [Feature]

**Current State** (SPIKE):
- [ ] 0/6 functions have typespecs
- [ ] 2/15 tests implemented (smoke only)
- [ ] 3/8 error cases handled
- [ ] 0 complexity analysis done
- [ ] 0 performance benchmarks

**Migration Tasks** (8 hours estimated):
1. Add typespecs (1 hour)
   - 6 public functions
   - Follow project patterns

2. Comprehensive tests (4 hours)
   - Success cases (3 tests)
   - Error cases (8 tests)
   - Edge cases (4 tests)
   - Criticality: 9-10

3. Error handling (2 hours)
   - Network failures
   - Invalid input
   - Database errors
   - Timeout handling

4. Documentation (1 hour)
   - Module docs
   - Function docs
   - Usage examples

**Ready for migration**: Run /spike-migrate lib/my_app/[module].ex
```

## Success Criteria

SPIKE succeeds when:
- ✅ Working prototype in <2 hours
- ✅ Validates technical approach
- ✅ All code marked with # SPIKE:
- ✅ Learnings documented in spike-debt.md
- ✅ Clear migration path defined
- ✅ Appropriate use case (not security/data critical)

## Related Commands

- `/spike-migrate` - Upgrade SPIKE to production quality
- `/feature` - Full production implementation (use instead of SPIKE for critical code)
- `/precommit` - Modified checks for SPIKE code
- `/learn` - Document patterns discovered during SPIKE
- `/review` - Will detect SPIKE code and suggest migration

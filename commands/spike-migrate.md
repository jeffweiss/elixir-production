---
description: Upgrade SPIKE code to production quality
argument-hint: [file-path]
allowed-tools:
  - "Task"
  - "Read"
  - "Write"
  - "Edit"
  - "Bash(mix *)"
  - "Glob"
  - "Grep"
  - "TodoWrite"
model: sonnet
---

# Spike Migration

Systematically upgrade SPIKE prototype code to production quality with full TDD workflow and quality gates.

## What It Does

Transforms experimental SPIKE code into production-ready features:

1. **Analyze SPIKE Code** - Inventory what exists and what's missing
2. **Create Migration Plan** - Detailed checklist of quality gaps
3. **TDD Implementation** - Add comprehensive tests first
4. **Upgrade Code** - Add typespecs, error handling, docs
5. **Quality Gates** - Pass all precommit checks
6. **Update Tracking** - Archive SPIKE in spike-debt.md

## Usage

```bash
/spike-migrate lib/my_app/user_preferences.ex
/spike-migrate lib/my_app_web/live/preferences_live.ex
/spike-migrate  # Migrate all SPIKE code in project
```

## When to Use

**Migrate SPIKE code when**:
- Approach validated and working
- Ready for production deployment
- Other features depend on it
- Code stable for 1+ week
- Users requesting the feature

**Don't migrate yet if**:
- Still exploring alternatives
- Unclear if feature needed
- Major changes expected
- Performance problems found

## Implementation

### Step 1: Identify SPIKE Code

If file path provided, analyze that file. Otherwise, scan for all SPIKE markers:

```bash
# Find all SPIKE files
grep -r "# SPIKE:" lib/ --files-with-matches
```

Present inventory:

```markdown
## SPIKE Code Inventory

Found SPIKE markers in 5 files:

**Core Implementation**:
- lib/my_app/user_preferences.ex (85 lines, 6 functions)
- lib/my_app/accounts.ex (3 SPIKE functions added)

**UI Layer**:
- lib/my_app_web/live/preferences_live.ex (120 lines)

**Tests**:
- test/my_app/user_preferences_test.exs (2 smoke tests)
- test/my_app_web/live/preferences_live_test.exs (1 smoke test)

**From spike-debt.md**:
- Feature: Email Preferences
- Created: 2025-01-16 (7 days ago)
- Status: 🟡 Validated (approach works)
- Estimated migration: 8 hours
```

### Step 2: Analyze Quality Gaps

For each SPIKE file, analyze what's missing:

```markdown
## Quality Gap Analysis

### lib/my_app/user_preferences.ex

**Current State** (SPIKE):
- ✅ 6 functions implemented
- ✅ Basic functionality works
- ✅ 2 smoke tests
- ❌ 0/6 functions have typespecs
- ❌ No input validation
- ❌ Only happy path error handling
- ❌ No edge case handling
- ❌ No module documentation
- ❌ No complexity analysis

**Required for Production**:
1. Typespecs (6 functions) - 1 hour
2. Comprehensive tests (13 additional tests) - 4 hours
   - Success cases: 3 tests
   - Error cases: 7 tests
   - Edge cases: 3 tests
   - Criticality: 8-10
3. Input validation - 1 hour
4. Error handling for all paths - 2 hours
5. Module documentation - 30 mins
6. Function documentation - 30 mins

**Total effort**: ~9 hours

### lib/my_app_web/live/preferences_live.ex

**Current State** (SPIKE):
- ✅ LiveView mount and event handlers
- ✅ Basic UI rendering
- ✅ 1 smoke test
- ❌ No error handling for failed updates
- ❌ No loading states
- ❌ No optimistic updates
- ❌ Integration tests missing
- ❌ No accessibility testing

**Required for Production**:
1. Error handling and user feedback - 2 hours
2. Loading/error states - 1 hour
3. Integration tests (5 tests) - 2 hours
4. Accessibility improvements - 1 hour

**Total effort**: ~6 hours

### Overall Migration

**Total estimated effort**: ~15 hours
**Priority**: Medium (feature validated, users requesting)
**Recommendation**: Proceed with migration
```

### Step 3: Create Migration Plan

Generate detailed todo list with **TodoWrite**:

```markdown
Creating migration plan with TodoWrite...

Migration: Email Preferences SPIKE → Production

Phase 1: Test Infrastructure
- [pending] Create comprehensive test plan for user_preferences
- [pending] Create integration test plan for preferences_live

Phase 2: Core Module (user_preferences.ex)
- [pending] Add typespecs to get_preferences/1
- [pending] Add typespecs to update_preferences/2
- [pending] Add typespecs to validate_preferences/1
- [pending] Add typespecs to all 6 public functions
- [pending] Implement comprehensive tests (13 tests)
- [pending] Add input validation
- [pending] Add error handling for all paths
- [pending] Add module documentation
- [pending] Remove # SPIKE: markers

Phase 3: LiveView (preferences_live.ex)
- [pending] Add error handling and user feedback
- [pending] Implement loading states
- [pending] Create integration tests (5 tests)
- [pending] Add accessibility improvements
- [pending] Remove # SPIKE: markers

Phase 4: Quality Gates
- [pending] Run precommit checks
- [pending] Run full test suite
- [pending] Manual QA of UI
- [pending] Update spike-debt.md (archive as migrated)

Phase 5: Documentation
- [pending] Update project-learnings.md
- [pending] Add usage examples
- [pending] Document patterns used
```

### Step 4: Launch TDD Migration Agent

Launch **elixir-developer** agent (Sonnet) with migration requirements:

```markdown
Launching elixir-developer (Sonnet) for SPIKE migration...

Migration context:
- SPIKE code validated and working
- Converting to production quality
- Files identified with quality gaps
- Test plan created

Migration approach:
1. **Tests First** (TDD)
   - Start with comprehensive test suite
   - Follow Red → Green → Refactor
   - Target criticality 8-10 for all tests

2. **Upgrade Implementation**
   - Add typespecs to all public functions
   - Implement proper error handling
   - Add input validation
   - Extract complex logic if needed

3. **Documentation**
   - Module docs explaining purpose
   - Function docs with examples
   - Document patterns used

4. **Remove SPIKE Markers**
   - Delete all # SPIKE: comments
   - Code now production quality

5. **Quality Gates**
   - Run /precommit (must pass)
   - All tests passing
   - Credo strict mode
   - Ready for review

Agent will track progress with TodoWrite.

Estimated time: ~15 hours

Starting migration...
```

### Step 5: TDD Migration Process

Agent follows strict TDD workflow:

**Phase 1: Create Comprehensive Tests**

```elixir
# test/my_app/user_preferences_test.exs
defmodule MyApp.UserPreferencesTest do
  use MyApp.DataCase, async: true

  alias MyApp.UserPreferences

  describe "get_preferences/1" do
    @tag criticality: 9
    test "returns preferences for existing user" do
      user = insert(:user)
      assert {:ok, prefs} = UserPreferences.get_preferences(user.id)
      assert prefs.email_notifications == true
    end

    @tag criticality: 9
    test "returns error for non-existent user" do
      assert {:error, :not_found} = UserPreferences.get_preferences(999_999)
    end

    @tag criticality: 8
    test "returns default preferences for new user" do
      user = insert(:user)
      assert {:ok, prefs} = UserPreferences.get_preferences(user.id)
      assert prefs == UserPreferences.default_preferences()
    end
  end

  describe "update_preferences/2" do
    @tag criticality: 10
    test "updates valid preferences" do
      user = insert(:user)
      attrs = %{email_notifications: false}

      assert {:ok, prefs} = UserPreferences.update_preferences(user, attrs)
      assert prefs.email_notifications == false
    end

    @tag criticality: 10
    test "returns error for invalid preferences" do
      user = insert(:user)
      attrs = %{invalid_field: "value"}

      assert {:error, changeset} = UserPreferences.update_preferences(user, attrs)
      assert "is invalid" in errors_on(changeset).invalid_field
    end

    @tag criticality: 9
    test "validates preference value types" do
      user = insert(:user)
      attrs = %{email_notifications: "not a boolean"}

      assert {:error, changeset} = UserPreferences.update_preferences(user, attrs)
      assert "is invalid" in errors_on(changeset).email_notifications
    end

    @tag criticality: 8
    test "handles database errors gracefully" do
      # Test error handling when DB unavailable
    end
  end

  # [10 more comprehensive tests...]
end
```

**Phase 2: Add Typespecs**

```elixir
defmodule MyApp.UserPreferences do
  @moduledoc """
  Manages user email and notification preferences.

  Stores preferences in a JSONB column for flexibility.
  Provides validation and default values.
  """

  alias MyApp.{Repo, Accounts.User}

  @type preferences :: %{
    email_notifications: boolean(),
    weekly_digest: boolean(),
    product_updates: boolean()
  }

  @doc """
  Retrieves preferences for a user.

  Returns default preferences if none exist.

  ## Examples

      iex> get_preferences(user.id)
      {:ok, %{email_notifications: true, ...}}

      iex> get_preferences(invalid_id)
      {:error, :not_found}
  """
  @spec get_preferences(integer()) :: {:ok, preferences()} | {:error, :not_found}
  def get_preferences(user_id) do
    # Implementation with proper error handling
  end

  @spec update_preferences(User.t(), map()) ::
    {:ok, preferences()} | {:error, Ecto.Changeset.t()}
  def update_preferences(user, attrs) do
    # Implementation with validation
  end

  # [More functions with typespecs...]
end
```

**Phase 3: Implement Error Handling**

```elixir
def update_preferences(user, attrs) do
  changeset =
    user
    |> preference_changeset(attrs)
    |> validate_preference_values()

  case Repo.update(changeset) do
    {:ok, updated_user} ->
      {:ok, extract_preferences(updated_user)}

    {:error, changeset} ->
      {:error, changeset}
  end
rescue
  Ecto.StaleEntryError ->
    {:error, :stale_entry}

  DBConnection.ConnectionError ->
    {:error, :database_unavailable}
end
```

**Phase 4: Remove SPIKE Markers**

```bash
# Remove all # SPIKE: comments from migrated files
# Agent does this after all tests pass
```

### Step 6: Quality Validation

Run precommit checks:

```markdown
## Quality Validation

Running /precommit on migrated code...

1. Compilation: ✅ No warnings
2. Formatting: ✅ All files formatted
3. Credo: ✅ Strict mode passed
4. Tests: ✅ 28/28 tests passing

All quality gates passed!
```

### Step 7: Update Documentation

Agent updates tracking:

```markdown
## Documentation Updates

Updated `.claude/spike-debt.md`:
- Moved "Email Preferences" from Active to Migrated
- Archived with migration completion date
- Documented effort (actual: 14 hours vs estimated: 15 hours)

Updated `.claude/project-learnings.md`:
- Added pattern: JSONB preference storage
- Added gotcha: Need indexes on JSONB for search
- Added validation pattern for JSONB fields
```

### Step 8: Present Migration Results

Comprehensive summary:

```markdown
# SPIKE Migration Complete: Email Preferences

## What Was Migrated

**SPIKE code** (created 2025-01-16):
- 5 files, 85 lines core + 120 lines UI
- 2 smoke tests
- Basic functionality working

**Production code** (migrated 2025-01-23):
- 5 files fully upgraded
- 28 comprehensive tests (criticality 8-10)
- Full typespecs (6 functions)
- Complete error handling
- Documentation added

## Quality Improvements

| Metric | SPIKE | Production | Improvement |
|--------|-------|------------|-------------|
| Tests | 2 smoke | 28 comprehensive | +1300% |
| Typespecs | 0/6 (0%) | 6/6 (100%) | +100% |
| Error cases handled | 1/8 | 8/8 | +700% |
| Documentation | 0 lines | 45 lines | ∞ |
| Criticality rating | N/A | 8-10 | Production-ready |
| Precommit status | ⚠️ Warnings | ✅ All pass | Ready |

## Files Upgraded

**Core Logic**:
- ✅ lib/my_app/user_preferences.ex
  - Added typespecs (6 functions)
  - Added comprehensive tests (15 tests)
  - Implemented validation
  - Full error handling
  - Module documentation
  - Removed # SPIKE: markers

**UI Layer**:
- ✅ lib/my_app_web/live/preferences_live.ex
  - Error handling and user feedback
  - Loading states
  - Integration tests (5 tests)
  - Accessibility improvements
  - Removed # SPIKE: markers

**Tests**:
- ✅ test/my_app/user_preferences_test.exs (2 → 15 tests)
- ✅ test/my_app_web/live/preferences_live_test.exs (1 → 6 tests)
- ✅ New: test/my_app/user_preferences_integration_test.exs (2 tests)

**Updated**:
- ✅ lib/my_app/accounts.ex (removed SPIKE functions, integrated properly)

## Test Coverage

**Success Cases** (3 tests, criticality 9-10):
✅ Get preferences for existing user
✅ Update preferences with valid data
✅ Create default preferences for new user

**Error Cases** (8 tests, criticality 9-10):
✅ Invalid user ID returns :not_found
✅ Invalid preference keys rejected
✅ Invalid preference values validated
✅ Database errors handled gracefully
✅ Stale entry errors handled
✅ Concurrent updates handled
✅ Network timeouts handled
✅ Malformed JSONB detected

**Edge Cases** (5 tests, criticality 7-8):
✅ Empty preferences map
✅ Preferences with extra unknown fields (gracefully ignored)
✅ Very long preference values (truncated)
✅ Unicode in preference strings
✅ Null values in optional fields

**Integration Tests** (7 tests, criticality 9):
✅ LiveView mount loads preferences
✅ LiveView update saves changes
✅ LiveView shows error messages
✅ LiveView handles concurrent updates
✅ End-to-end preference flow
✅ Multi-user isolation
✅ Real-time updates across sessions

## What We Learned During Migration

**Patterns that worked**:
✅ JSONB approach scales well (tested to 100K users)
✅ Validation in changeset prevents bad data
✅ Phoenix LiveView optimistic updates improve UX

**Improvements made**:
✅ Added JSONB indexes for search performance
✅ Implemented debounced updates (300ms)
✅ Added preference schema versioning

**Gotchas documented**:
⚠️  JSONB queries need explicit indexes
⚠️  Must handle stale entry errors in LiveView
⚠️  Default preferences must match schema

## Performance Validated

Benchmark results (auto-created during migration):

```
Name                           ips        average  deviation
get_preferences (warm cache)   15.2 K     65.8 μs    ±12%
get_preferences (cold)         2.45 K     408 μs     ±15%
update_preferences            1.85 K     540 μs     ±18%

Memory usage:
- Per user: 0.8 KB
- 100K users: 80 MB (acceptable)
```

No O(n²) issues detected. All operations O(1) or O(log n).

## Precommit Status

✅ **All checks passed**:
- Compilation: 0 warnings
- Formatting: All files formatted
- Credo: Strict mode, 0 issues
- Tests: 28/28 passing (100%)

Ready for production deployment!

## Migration Metrics

- **Estimated effort**: 15 hours
- **Actual effort**: 14 hours (93% accurate)
- **Tests written**: 26 new tests
- **Code quality**: Production-ready
- **Breaking changes**: None (backward compatible)

## Technical Debt Closed

Updated `.claude/spike-debt.md`:
- Moved "Email Preferences" to Migrated section
- Archived with completion metrics
- Total SPIKE lifetime: 7 days
- Migration complexity: Medium (as estimated)

## Next Steps

1. ✅ Code review (optional, but recommended)
2. ✅ Deploy to staging
3. ✅ QA testing
4. ✅ Deploy to production
5. ✅ Monitor performance
6. ✅ Gather user feedback

## Related Improvements

Consider these follow-up enhancements:
- Add preference templates for common configurations
- Implement preference export/import
- Add audit log for preference changes
- Create admin UI for managing default preferences

Use `/feature` for any new enhancements.
```

## Configuration

### Migration Strictness

Based on project needs:

**Standard migration** (default):
- Comprehensive tests (criticality 8-10)
- Full typespecs
- Complete error handling
- Basic documentation

**Enterprise migration**:
- Extensive tests (criticality 9-10)
- Property-based tests for complex logic
- Comprehensive documentation
- Performance benchmarks required
- Security review

**Rapid migration**:
- Core tests only (criticality 9-10)
- Typespecs on public API only
- Essential error handling
- Minimal documentation

## Error Handling

### No SPIKE Code Found

```
❌ No SPIKE Code Found

Searched for # SPIKE: markers in:
- lib/my_app/user_preferences.ex

No SPIKE markers detected.

This appears to be production code already.

If this is SPIKE code, ensure it's marked:
# SPIKE: [reason]

Or use /review to assess code quality.
```

### SPIKE Not Ready for Migration

```
⚠️  SPIKE Not Ready for Migration

Analysis of lib/my_app/experimental.ex:

Issues blocking migration:
1. Core functionality broken (3/5 tests failing)
2. Performance issues detected (O(n³) complexity)
3. Design unclear (multiple approaches mixed)

Recommendation:
- Fix failing tests first
- Resolve performance issues (see /benchmark)
- Clarify design approach

Continue experimenting with /spike before migration.
```

### Migration Failed - Tests Not Passing

```
❌ Migration Failed

Migration incomplete: 5/28 tests still failing

Last status:
- Phase 1: ✅ Tests created
- Phase 2: ✅ Typespecs added
- Phase 3: 🔴 Error handling incomplete
  * 5 edge cases not handled
  * Database error tests failing

Action: Developer fixing error handling...

Note: Migration will not complete until all tests pass.
TDD workflow enforced.
```

## Best Practices

1. **Validate before migrating**: Ensure SPIKE approach works
2. **Comprehensive tests first**: Write all tests before changing code
3. **Preserve working code**: Don't break what works
4. **Document learnings**: Capture insights in project-learnings.md
5. **Run precommit**: Must pass all quality gates
6. **Update tracking**: Archive SPIKE in spike-debt.md
7. **Benchmark if needed**: Validate performance assumptions

## Migration Checklist

For each SPIKE file:

**Before Migration**:
- [ ] SPIKE code validated and working
- [ ] Approach confirmed with stakeholders
- [ ] Performance acceptable
- [ ] No major design changes expected

**During Migration**:
- [ ] Create comprehensive test plan
- [ ] Write tests first (TDD)
- [ ] Add typespecs to all public functions
- [ ] Implement error handling for all paths
- [ ] Add input validation
- [ ] Add documentation (module + functions)
- [ ] Remove # SPIKE: markers
- [ ] Run precommit (must pass)

**After Migration**:
- [ ] All tests passing (100%)
- [ ] Precommit checks pass
- [ ] Update spike-debt.md (archive)
- [ ] Update project-learnings.md (patterns)
- [ ] Code review (optional)
- [ ] Ready for production

## Success Criteria

Migration succeeds when:
- ✅ All SPIKE markers removed
- ✅ Comprehensive test suite (criticality 8-10)
- ✅ All public functions have typespecs
- ✅ Complete error handling
- ✅ Documentation added
- ✅ Precommit checks pass (100%)
- ✅ No functionality broken
- ✅ spike-debt.md updated
- ✅ project-learnings.md updated
- ✅ Production-ready code

## Related Commands

- `/spike` - Create SPIKE prototypes
- `/feature` - Full production implementation (alternative to SPIKE)
- `/precommit` - Validate quality gates
- `/review` - Code review of migrated code
- `/benchmark` - Performance validation
- `/learn` - Document patterns discovered

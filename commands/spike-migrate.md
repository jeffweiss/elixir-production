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

Transforms experimental SPIKE code into production-ready features through a 6-step workflow:

1. **Analyze SPIKE Code** - Inventory existing code and identify quality gaps
2. **Create Migration Plan** - Generate detailed checklist with TodoWrite
3. **TDD Implementation** - Launch elixir-developer agent to add comprehensive tests first
4. **Upgrade Code** - Agent adds typespecs, error handling, documentation
5. **Quality Gates** - Validate all precommit checks pass
6. **Update Tracking** - Archive SPIKE in spike-debt.md, document learnings

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

**Don't migrate yet if**:
- Still exploring alternatives
- Unclear if feature needed
- Major changes expected
- Performance problems found

## Implementation

### Step 1: Identify SPIKE Code

If file path provided, analyze that file. Otherwise, scan for all SPIKE markers with `grep -r "# SPIKE:" lib/ --files-with-matches`.

Present inventory showing:
- Core implementation files (line counts, function counts)
- UI layer files
- Test files
- Entries from spike-debt.md with creation dates and status

### Step 2: Analyze Quality Gaps

For each SPIKE file, analyze current state vs. production requirements. Count functions needing typespecs, identify missing tests (success/error/edge cases), check error handling coverage, document validation needs, estimate effort.

Generate gap analysis showing what exists (✅) vs. missing (❌) with effort estimates.

### Step 3: Create Migration Plan

Generate detailed todo list with **TodoWrite** in phases:
Phase 1: Test Infrastructure | Phase 2: Core upgrades (typespecs, tests, validation, error handling, docs) | Phase 3: UI/LiveView upgrades | Phase 4: Quality Gates (precommit, tests, QA) | Phase 5: Documentation

### Step 4: Launch TDD Migration Agent

Launch **elixir-developer** agent (Sonnet) with migration context. Agent workflow:

1. **Tests First (TDD)** - Comprehensive test suite (success, error, edge cases). Criticality 8-10. Red → Green → Refactor.
2. **Upgrade Implementation** - Typespecs on all public functions. Full error handling. Input validation.
3. **Documentation** - Module docs, function docs with examples, patterns.
4. **Remove SPIKE Markers** - Delete all # SPIKE: comments after tests pass.
5. **Quality Gates** - Run /precommit (must pass). All tests passing. Credo strict mode.

Agent tracks progress with TodoWrite.

For production quality standards, see production-quality skill: escalation-ladder.md
For testing patterns, see production-quality skill: testing.md

### Step 5: Quality Validation

Run precommit checks: compilation (no warnings), formatting (all files), Credo (strict mode), tests (all passing). All gates must pass.

### Step 6: Update Documentation

Update `.claude/spike-debt.md` (move to Migrated with date) and `.claude/project-learnings.md` (patterns, gotchas, validation approaches).

### Step 7: Present Migration Results

Present compact summary:

```markdown
# SPIKE Migration Complete: [Feature Name]

## Summary
- **Files Migrated**: X files upgraded from SPIKE to production
- **Tests Added**: Y new tests (criticality 8-10)
- **Typespecs**: Z functions now fully typed
- **Time**: Actual vs. estimated effort

## Files Upgraded
[List files with brief status: typespecs added, tests added, error handling, docs]

## Quality Improvements
- Tests: X smoke → Y comprehensive (+N%)
- Typespecs: 0% → 100%
- Error coverage: X/Y → Y/Y paths
- Precommit: ⚠️ Warnings → ✅ All pass

## Key Learnings
[3-5 patterns that worked, improvements made, gotchas documented]

## Precommit Status
✅ All checks passed - Ready for production

## Next Steps
1. Code review (optional)
2. Deploy to staging
3. QA testing
4. Production deployment
```

## Configuration

**Standard** (default): Comprehensive tests (8-10), full typespecs, complete error handling, basic docs
**Enterprise**: Extensive tests (9-10), property tests, comprehensive docs, benchmarks, security review
**Rapid**: Core tests only (9-10), public API typespecs, essential error handling, minimal docs

## Error Handling

**No SPIKE Code Found**: Present message indicating no markers detected. Suggest /review or marking code with `# SPIKE: [reason]`.

**SPIKE Not Ready**: Show blocking issues (broken tests, performance problems, unclear design). Recommend fixing first.

**Migration Failed**: Show phase status, failing tests, and blocker. Migration won't complete until all tests pass (TDD enforced).

## Best Practices

1. **Tests first** - Write all tests before changing implementation
2. **Preserve working code** - Don't break what works during migration
3. **Run precommit** - Must pass all quality gates before completion

## Migration Checklist

**Before**: SPIKE validated, approach confirmed, performance acceptable, no major changes expected

**During**: Test plan, TDD workflow, typespecs, error handling, validation, docs, remove markers, precommit

**After**: 100% tests pass, precommit pass, update spike-debt.md and project-learnings.md, ready for production

## Success Criteria

Migration succeeds when:
- ✅ All SPIKE markers removed
- ✅ Comprehensive test suite (criticality 8-10)
- ✅ All public functions have typespecs
- ✅ Complete error handling
- ✅ Documentation added
- ✅ Precommit checks pass (100%)
- ✅ No functionality broken
- ✅ Tracking files updated
- ✅ Production-ready code

## Related Commands

- `/spike` - Create SPIKE prototypes
- `/feature` - Full production implementation (alternative to SPIKE)
- `/precommit` - Validate quality gates
- `/review` - Code review of migrated code
- `/benchmark` - Performance validation

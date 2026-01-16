# SPIKE Technical Debt Tracker

**Purpose**: Track code marked as SPIKE (rapid prototypes) and migration status.

SPIKE mode allows fast iteration without production quality requirements. This file tracks:
- What code is in SPIKE mode
- Why it's marked as SPIKE
- Migration readiness and effort estimates
- Completion status

---

## Active SPIKE Code

### [Date] Feature: User Dashboard LiveView

**Location**: `lib/my_app_web/live/dashboard_live.ex`

**SPIKE Markers**: 3 functions marked with `# SPIKE:`

**Reason**: Rapid UI exploration to validate design with stakeholders

**Quality Gaps**:
- [ ] Missing typespecs (8 functions)
- [ ] Minimal error handling (only happy path)
- [ ] Tests: 2 smoke tests (need 15+ comprehensive tests)
- [ ] No complexity analysis

**Migration Readiness**: 🟡 Medium
- Design validated with users ✓
- Patterns clear and consistent ✓
- Performance acceptable for 100 users ✓
- Needs: typespecs, error handling, full test suite

**Effort Estimate**: ~4 hours

**Priority**: Medium (used by 50 users, but stable for 2 weeks)

**Migration Command**: `/spike-migrate lib/my_app_web/live/dashboard_live.ex`

---

### [Date] Feature: Product Search Algorithm

**Location**: `lib/my_app/products/search.ex`

**SPIKE Markers**: 1 module marked with `# SPIKE: experimental search algorithm`

**Reason**: Testing different search approaches for performance

**Quality Gaps**:
- [ ] No typespecs
- [ ] Nested loop implementation (O(n²) - not benchmarked)
- [ ] Tests: 3 basic tests (need property-based tests)
- [ ] No error handling for edge cases

**Migration Readiness**: 🔴 Low
- Algorithm works but slow with >1000 products
- Not sure if best approach
- Performance unvalidated

**Next Steps**:
1. Run `/benchmark` to measure actual performance
2. Research better algorithms with `/algorithm-research`
3. Consider trigram indexes or Elasticsearch

**Effort Estimate**: ~8 hours (includes research and benchmarking)

**Priority**: High (blocks scaling to 10k products)

---

### [Date] Feature: Email Template System

**Location**: `lib/my_app/email_templates/`

**SPIKE Markers**: Entire directory is SPIKE

**Reason**: Exploring templating approaches (Liquid vs embedded)

**Quality Gaps**:
- [ ] No typespecs
- [ ] Error handling incomplete (silently fails on bad templates)
- [ ] Tests: 5 example tests (need error cases)
- [ ] Security: no XSS validation
- [ ] Performance: not measured

**Migration Readiness**: 🔴 Low
- Still evaluating Liquid vs embedded templates
- Security concerns not addressed
- No decision on template storage (DB vs files)

**Blockers**:
- Decision needed on template engine
- Security review required
- Need product feedback on template editing UX

**Effort Estimate**: ~12 hours (includes security review)

**Priority**: Low (feature used by 2 admins, low risk)

---

## Recently Migrated (Success Stories)

### [Date] ✅ Feature: User Authentication Flow

**Location**: `lib/my_app/accounts/auth.ex`

**Migration Completed**: PR #789

**Original SPIKE Duration**: 2 hours (UI and basic flow)

**Migration Effort**: 5 hours (typespecs, tests, error handling, security review)

**Tests Added**: 18 tests (criticality 9-10)

**Learnings**:
- SPIKE great for exploring OAuth flow with Google
- Migration straightforward - patterns were clear
- Tests caught 3 edge cases not in original SPIKE:
  * OAuth token expiration handling
  * Network timeout scenarios
  * Duplicate email edge case

**Outcome**: Production-ready, deployed to 500 users without issues

---

### [Date] ✅ Feature: Real-Time Notifications

**Location**: `lib/my_app_web/live/notifications_live.ex`

**Migration Completed**: PR #845

**Original SPIKE Duration**: 1 hour (basic PubSub setup)

**Migration Effort**: 6 hours (performance analysis, comprehensive tests)

**Changes**:
- Refactored from O(n²) to O(n) with hash map lookup
- Added benchmarks: 5ms for 1000 users (was 350ms)
- Added 14 tests (criticality 7-9)
- Implemented connection pool for PubSub

**Learnings**:
- Initial O(n²) implementation worked for 50 users
- Scaling to 1000 users required optimization
- Benchmarking revealed the bottleneck early

**Outcome**: Scales to 10k users with sub-10ms latency

---

## SPIKE Mode Guidelines

### When to Use SPIKE Mode

✅ **Good for SPIKE**:
- UI/UX exploration with stakeholders
- Algorithm experimentation
- Integration testing with external APIs
- Proof-of-concept for new features
- Rapid prototyping for demos

❌ **Not for SPIKE**:
- Core business logic with financial impact
- Security-critical features (authentication, authorization)
- Data migration scripts
- Production critical paths

### SPIKE Quality Requirements

**Minimal but Essential**:
- Basic smoke tests (does it work in happy path?)
- Mark all SPIKE code with `# SPIKE: <reason>`
- Track in this file with estimated migration effort
- Run `/spike-migrate` when patterns stabilize

**Explicitly Skip**:
- Comprehensive typespecs
- Full error handling
- Property-based tests
- Performance benchmarks

### Migration Triggers

**Automatic suggestions when**:
- Code stable for 3+ sessions
- Clear patterns emerged
- Used by >10 users
- Performance acceptable
- No major refactoring planned

**Manual migration when**:
- Feature going to production
- Adding to critical path
- Scaling requirements change
- Security review needed

### Migration Checklist

Use `/spike-migrate <file>` which will:
- [ ] Add missing typespecs to all public functions
- [ ] Implement comprehensive error handling
- [ ] Create full test suite (unit, integration, property-based)
- [ ] Add criticality scores to tests
- [ ] Run complexity analysis
- [ ] Create benchmarks for O(n²)+ algorithms
- [ ] Update documentation
- [ ] Remove `# SPIKE:` markers
- [ ] Update this file to "Recently Migrated"

---

## Monitoring and Review

### Weekly Review
- Review all active SPIKE code for migration readiness
- Update priority based on usage and risk
- Identify blockers and next steps

### Quarterly Audit
- Assess technical debt from SPIKE code
- Plan migration sprints for high-priority items
- Archive old SPIKE entries that were replaced

### Metrics
- Active SPIKE modules: (count from markers)
- Average SPIKE age: (time from creation to migration)
- Migration success rate: (completed vs abandoned)

---

## Commands Reference

- **Create SPIKE**: `/spike <feature>` - enables fast iteration mode
- **Check migration readiness**: Agents auto-detect and suggest
- **Migrate to production**: `/spike-migrate <file>` - full upgrade
- **Benchmark performance**: `/benchmark <module>` - before migration

---

## Notes

- Keep this file updated as SPIKE code is created or migrated
- Use emojis for quick visual scanning: 🔴 Low, 🟡 Medium, 🟢 High readiness
- Link to PRs, benchmarks, and related documents
- Don't delete migrated entries - keep as success stories
- Celebrate migrations - they're investments in quality!

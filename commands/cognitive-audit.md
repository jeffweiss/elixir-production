---
description: Analyze code cognitive load and onboarding difficulty
argument-hint: [module-or-directory]
allowed-tools:
  - Task
  - Glob
  - Grep
  - Read
  - Edit
  - TodoWrite
model: opus
---

# Cognitive Audit Command

Analyzes code cognitive load, onboarding difficulty, and provides strategic refactoring recommendations based on John Ousterhout's "A Philosophy of Software Design" principles.

## What It Does

Launches the **cognitive-scientist agent** (Opus) to perform deep analysis:

1. **Ousterhout Principle Analysis** - Deep vs shallow modules, information leakage, complexity push-up vs pull-down
2. **Cognitive Load Metrics** - Working memory, semantic ambiguity, temporal coupling, pass-through complexity
3. **Onboarding Difficulty Assessment** - Context requirements, state complexity, estimated time to productivity
4. **Strategic Refactoring Recommendations** - High-priority improvements with ROI
5. **Report Generation** - Comprehensive audit report and onboarding guides

## Usage

```bash
# Analyze entire codebase
/cognitive-audit

# Analyze specific module
/cognitive-audit lib/my_app/order_processor.ex

# Analyze directory
/cognitive-audit lib/my_app/payments/

# Analyze multiple modules
/cognitive-audit lib/my_app/{orders,payments,inventory}
```

## Implementation

### Step 1: Launch Cognitive Scientist

```markdown
Launching cognitive-scientist agent (Opus) for cognitive complexity analysis...

Scope: [target files/directories]

The agent will:
1. Apply Ousterhout's principles (deep modules, pull complexity down, strategic programming)
2. Measure cognitive complexity metrics (beyond cyclomatic)
3. Assess onboarding difficulty (1-10 scale)
4. Identify high-burden areas
5. Suggest strategic refactoring
6. Generate comprehensive report

This is a deep analysis using Opus model. May take 2-5 minutes...

Waiting for analysis...
```

### Step 2: Analysis Process

The cognitive-scientist agent executes:

```bash
# Load context
Read [target files]
Read .claude/project-learnings.md (if exists)
Read .claude/cognitive-audit-report.md (previous audit, if exists)

# Analyze Ousterhout principles
- Module depth ratio (power / complexity)
- Information leakage (temporal coupling, pass-through, exposed internals)
- Complexity direction (push-up vs pull-down)
- Strategic vs tactical code
- Errors that could be defined out

# Measure cognitive load
- Working memory load (parameters, lifespans, concerns, nesting)
- Semantic ambiguity (generic names, inconsistent naming)
- Temporal coupling (hidden dependencies)
- Pass-through complexity (arguments through layers)

# Assess onboarding
- Context requirements (modules to understand)
- Domain knowledge needed
- Historical decisions documented
- State machine complexity
- Overall difficulty score (1-10)

# Generate reports
- Create .claude/cognitive-audit-report.md
- Create .claude/onboarding-guide-[module].md (for complex areas)
- Update .claude/project-learnings.md (cognitive patterns section)
```

### Step 3: Present Findings

**Summary output**:

```markdown
# Cognitive Complexity Analysis Complete

## Executive Summary

**Scope**: lib/my_app/orders/ (8 files, 2,450 lines)
**Overall complexity**: High (7.2/10)
**Onboarding difficulty**: 7/10 (Hard - 4-8 weeks to productivity)
**Estimated comprehension time**: 18 hours for new developer

## Primary Issues

### 1. Shallow Modules (Critical)
- **OrderProcessor**: Depth ratio 0.8 (shallow - refactor needed)
  * Complex interface (6 parameters, 4 special cases)
  * Minimal power (just delegates)
  * Impact: 20+ call sites duplicating error handling

### 2. High Working Memory Load
- **process_complex_order/8**: 8 parameters, 95-line variable lifespan
  * Score: 9/10 (very high)
  * Nesting depth: 6 levels
  * Recommendation: Chunk into steps, use context object

### 3. Temporal Coupling (Production Bugs)
- **OrderInitializer**: 7 functions must be called in specific order
  * No enforcement, easy to get wrong
  * Caused 3 production bugs (from git history)
  * Recommendation: Single initialize/1 with explicit dependencies

## Ousterhout Analysis

### Deep vs Shallow Modules

**Shallow (Need refactoring)**:
1. OrderProcessor (depth: 0.8) - 20+ call sites affected
2. PaymentValidator (depth: 0.9) - Complex interface, minimal power
3. ShippingCalculator (depth: 1.1) - Marginal

**Deep (Good examples)**:
1. Accounts context (depth: 4.5) - Simple interface, powerful implementation
2. EmailDelivery (depth: 3.2) - Hides complexity well

### Information Leakage

**Critical leakage points**:
1. Temporal coupling in OrderInitializer (3 production bugs)
2. Pass-through arguments: current_user through 8 layers
3. Exposed ETS table in CacheManager (callers must know ETS API)

### Strategic vs Tactical Code

**Tactical code accumulating complexity**:
1. PaymentProcessor: 5 copy-pasted blocks, 6-month-old TODOs
2. NotificationSystem: Special cases for user types proliferating

**Strategic code to emulate**:
1. EmailDelivery: Clean abstraction, easy to extend
2. Accounts: Deep module with great interface

## Refactoring Recommendations

### High Priority (This Sprint)

**1. Refactor OrderProcessor → Deep Module**
- **Impact**: High (20+ call sites affected)
- **Effort**: 2-3 days
- **Benefit**: Eliminates 200+ lines of duplicated logic
- **ROI**: Very high
- **Approach**:
  * Pull error handling into module
  * Provide high-level operations
  * Hide state machine complexity
- **Files**: lib/my_app/orders/order_processor.ex + 20 call sites

**2. Fix OrderInitializer Temporal Coupling**
- **Impact**: Critical (prevents bugs)
- **Effort**: 1 day
- **Benefit**: Eliminates entire class of initialization bugs
- **ROI**: High (prevents production incidents)
- **Approach**:
  * Single initialize/1 function
  * Make dependencies explicit with `with`
  * Return clear errors
- **Files**: lib/my_app/orders/order_initializer.ex

**3. Create RequestContext**
- **Impact**: Medium (30+ files)
- **Effort**: 2 days
- **Benefit**: Reduces working memory load across system
- **ROI**: Medium-high
- **Approach**:
  * Define RequestContext struct
  * Update pipeline to build context
  * Refactor functions to accept context
- **Files**: lib/my_app_web/* (30+ files)

### Medium Priority (Next Sprint)

4. Strategic refactor PaymentProcessor (3-4 days)
5. Add comprehensive state machine documentation (1 day)

### Low Priority

6. Naming consistency pass (2-3 days)
7. Extract configuration (1-2 days)

## Cognitive Load Metrics

| Metric | Current | Target | Status |
|--------|---------|--------|--------|
| Shallow modules | 8 | 0 | 🔴 Critical |
| High working memory functions | 12 | <5 | 🔴 High |
| Temporal coupling instances | 6 | 0 | 🔴 High |
| Pass-through layers (max) | 8 | 3 | 🔴 High |
| Onboarding difficulty | 7/10 | 4/10 | 🔴 Hard |
| Code clarity | 5/10 | 8/10 | 🟡 Moderate |

## Reports Generated

Full analysis and recommendations:
- **Audit report**: `.claude/cognitive-audit-report.md` (detailed findings)
- **Onboarding guide**: `.claude/onboarding-guide-orders.md` (for OrderProcessor module)
- **Project patterns**: `.claude/project-learnings.md` (updated with cognitive patterns)

## Estimated Impact

**If high-priority refactoring completed**:
- Onboarding time: 4-8 weeks → 2-3 weeks (50% reduction)
- Code comprehension: 18 hours → 8 hours (55% improvement)
- Change difficulty: 7/10 → 4/10 (easier to modify)
- Bug risk: High → Medium (fewer temporal coupling bugs)

## Next Steps

1. **Review** full audit report: `.claude/cognitive-audit-report.md`
2. **Prioritize** refactoring recommendations with team
3. **Schedule** strategic refactoring work (5-6 days estimated)
4. **Measure** improvement after refactoring (run audit again)
5. **Establish** cognitive complexity thresholds for new code

**Ready to proceed with refactoring?**
```

## Configuration

### Analysis Depth

Based on `.claude/elixir-production.local.md`:

**Standard depth** (default):
- Ousterhout principles
- Core cognitive metrics
- Onboarding assessment
- Top 3-5 recommendations

**Deep analysis** (comprehensive):
- All metrics detailed
- Every module analyzed
- Complete refactoring catalog
- Onboarding guides for all complex areas

**Quick scan** (surface level):
- Module depth only
- Top issues
- Quick recommendations

### Scope Control

```bash
# Entire codebase (can be slow for large projects)
/cognitive-audit

# Specific focus areas (recommended)
/cognitive-audit lib/my_app/orders/
/cognitive-audit lib/my_app_web/live/

# Critical modules only
/cognitive-audit lib/my_app/{orders,payments,inventory}.ex
```

## Integration with Other Commands

**Triggered by**:
- pr-reviewer agent (for large PRs >500 lines or >5 files)
- User request
- Periodic audits (recommended: quarterly)

**Triggers**:
- Updates to `.claude/project-learnings.md`
- Creation of onboarding guides
- Refactoring recommendations added to backlog

**Related commands**:
- `/review` - Code review (includes some cognitive checks)
- `/feature` - Can use audit insights for design
- `/learn` - Update project patterns based on audit

## When to Run

**Recommended**:
- **New project**: Establish baseline
- **Before onboarding**: Create guides for new developers
- **After major feature**: Check complexity growth
- **Quarterly**: Track complexity trends
- **Before refactoring**: Identify high-value targets
- **Large PR**: Understand cognitive impact

**Warning signs** requiring audit:
- New developers struggling (>4 weeks to productivity)
- Frequent bugs in same areas
- Fear of changing code
- "Don't touch that module" comments
- Long PR review times
- Difficulty understanding changes

## Understanding the Report

### Module Depth Ratio

```
Depth = Implementation Power / Interface Complexity

> 2.0  = Deep module (good!)
1.0-2.0 = Balanced (acceptable)
< 1.0  = Shallow module (refactor needed)
```

**Example**:
```
OrderProcessor: 0.8 (shallow)
- Interface complexity: 8/10 (6 params, 4 special cases)
- Implementation power: 6/10 (200 lines, delegates to others)
- Ratio: 6/8 = 0.75
```

### Working Memory Load

```
Score = Parameters + Lifespan + Concerns + Nesting

0-5   = Low load (easy to understand)
6-10  = Moderate load (requires focus)
11-15 = High load (difficult)
16+   = Very high load (refactor!)
```

### Onboarding Difficulty

```
1-3  = Easy (new dev productive in days)
4-6  = Moderate (new dev productive in 1-2 weeks)
7-8  = Hard (new dev productive in 3-4 weeks)
9-10 = Very hard (new dev productive in 1-2 months)
```

## Acting on Findings

### High-Priority Issues (Address Immediately)

- Critical shallow modules (depth < 0.8)
- Production bugs from temporal coupling
- Working memory load > 15
- Security or data integrity risks

### Medium-Priority Issues (Address This Quarter)

- Moderate shallow modules (depth 0.8-1.0)
- High working memory load (11-15)
- Strategic refactoring opportunities
- Onboarding difficulty > 7

### Low-Priority Issues (Address When Convenient)

- Minor naming inconsistencies
- Configuration extraction
- Documentation improvements
- Style consistency

### Strategic Investments (Long-term)

- Comprehensive refactoring
- Architecture improvements
- Pattern standardization
- Team education

## Success Metrics

Audit succeeds when:
- ✅ Ousterhout principles applied systematically
- ✅ Metrics beyond cyclomatic complexity measured
- ✅ Onboarding difficulty quantified (1-10 score)
- ✅ Strategic refactoring recommendations with ROI
- ✅ Comprehensive reports generated
- ✅ Actionable next steps provided
- ✅ Explicitly avoids Clean Code dogma

## Tips

1. **Run before major changes**: Understand complexity before adding to it
2. **Share report with team**: Discuss priorities together
3. **Track metrics over time**: Is complexity growing or shrinking?
4. **Use for onboarding**: Give report to new developers
5. **Pair with refactoring**: Use recommendations as guide
6. **Celebrate improvements**: Re-run audit after refactoring to show progress

## Related Commands

- `/review` - General code review
- `/feature` - Feature implementation (can use audit insights)
- `/distributed-review` - Distributed systems analysis
- `/algorithm-research` - Algorithm optimization
- `/learn` - Document cognitive patterns discovered

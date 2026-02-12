---
description: Analyze distributed system design and correctness
argument-hint: [module-or-feature]
allowed-tools: [Task, Read, Glob, Grep, Edit, TodoWrite]
model: opus
---

# Distributed Review Command

Comprehensive review of distributed system architecture, consensus algorithms, clustering strategy, and potential distributed bugs. Launches the **distributed-systems-expert** agent (Opus) for deep analysis.

## What It Does

Analyzes distributed system design with focus on correctness and scale. Reviews clustering strategy, consensus algorithms, split-brain risks, quorum calculations, clock drift issues, CAP tradeoffs, and network partition handling. Provides specific recommendations for improvement.

## Usage

```bash
# Review entire distributed system
/distributed-review

# Review specific module
/distributed-review lib/my_app/consensus.ex

# Review feature area
/distributed-review lib/my_app/cluster/

# Review configuration
/distributed-review config/config.exs
```

## Implementation

### Step 1: Launch Distributed Systems Expert

```markdown
Launching distributed-systems-expert agent (Opus) for distributed system analysis...

Scope: [target area]

The expert will evaluate clustering strategy, consensus algorithms, distributed bugs, CAP tradeoffs, and network partition handling using domain knowledge from the distributed-systems skill reference files.

Deep analysis using Opus model. May take 2-5 minutes...

Waiting for analysis...
```

### Step 2: Present Findings

**No issues found**:

```markdown
✅ Distributed System Review Complete - Well Designed

## Architecture Summary

**Clustering**: Distributed Erlang with libcluster (Kubernetes DNS)
- Cluster size: 8 nodes (within limits)
- Service discovery: kubernetes_selector: "app=myapp"
- Status: Appropriate for scale ✓

**Consensus**: Raft via :ra for inventory management
- Algorithm: Leader-based consensus (CP system)
- Quorum: 5 of 9 nodes (tolerates 4 failures)
- Use case: Strong consistency for inventory
- Status: Correct choice ✓

**Partition Handling**: Quorum-based availability
- Strategy: Minority partition becomes unavailable
- Detection: Cluster health monitoring every 10s
- Status: Correctly implemented ✓

## Analysis

✅ **Scale**: 8 nodes, well under Distributed Erlang limit
✅ **Quorum**: Correctly calculated as div(9, 2) + 1 = 5
✅ **Clock usage**: System.monotonic_time() for intervals
✅ **Split-brain**: Quorum checks before leader election
✅ **CAP tradeoffs**: CP system appropriate for use case
✅ **Monitoring**: Cluster health, quorum status tracked

## Recommendations

**Monitoring enhancements**:
1. Add NTP offset monitoring (clock drift detection)
2. Alert on cluster size drops below quorum
3. Track leader election frequency (detect instability)

**Testing**:
- Consider partition simulation tests (toxiproxy)
- Test minority partition behavior
- Verify quorum calculations under failures

Distributed system is production-ready!
```

**Issues found**:

```markdown
🔍 Distributed System Review Findings

Reviewed: [scope] ([N] files, distributed system implementation)

## Critical Issues

### [Critical] Issue Title
**Location**: `path/to/file.ex:line`
**Confidence**: XX%

**Problem**: Brief description of the issue

**Current behavior**: What's happening now

**Impact**: Specific consequences (split-brain, data loss, etc.)

**Fix**: High-level fix approach
- Reference distributed-systems skill for patterns
- For consensus: See distributed-systems/consensus.md
- For split-brain prevention: See distributed-systems/failure-modes.md
- For clock drift: See distributed-systems/timing.md
- For CRDTs: See distributed-systems/crdts.md

## Important Issues

### [Important] Issue Title
**Confidence**: XX%

**Problem**: Description

**Impact**: Consequences

**Recommendation**: Suggested approach with skill references

## Architecture Analysis

### Clustering Strategy
**Current**: [Description]
**Assessment**: Evaluation with recommendations
**Scale**: Current and projected node count
**Status**: Assessment (needs migration, appropriate, etc.)

For clustering patterns: See distributed-systems/clustering.md

### Consensus Algorithm
**Current**: [Description]
**Assessment**: Evaluation of algorithm choice
**Use case**: What it's being used for
**Consistency requirement**: CP, AP, or CA
**Status**: Assessment

For consensus patterns: See distributed-systems/consensus.md

### CAP Tradeoffs
**Current implementation**: CP, AP, or CA
**Assessment**: Evaluation of tradeoffs
**Recommended**: If different from current

For CAP analysis: See distributed-systems/cap-theorem.md

### Network Partition Behavior
**Current**: Description of current handling
**Assessment**: Evaluation
**Recommended**: If improvement needed

For partition handling: See distributed-systems/failure-modes.md

## Recommendations Priority

### High Priority (This Sprint)
1. [Fix description] (time estimate)
2. [Fix description] (time estimate)

### Medium Priority (Next Sprint)
3. [Fix description] (time estimate)
4. [Fix description] (time estimate)

### Low Priority
5. [Fix description] (time estimate)

## Next Steps

1. Review findings with team
2. Prioritize fixes (critical bugs first)
3. Implement high-priority fixes
4. Test with partition simulation
5. Monitor cluster health continuously

---

Run `/learn` to add distributed patterns to project knowledge base.
```

## Configuration

Based on `.claude/elixir-production.local.md`:

**Analysis depth**:
- **Standard**: Architecture, consensus, top bugs
- **Deep**: Complete analysis, all patterns, monitoring plan
- **Quick**: High-level assessment only

## When to Run

**Recommended**:
- **New distributed system**: Before implementation
- **Scaling up**: Approaching Distributed Erlang limits
- **After incident**: Distributed bug investigation
- **Quarterly**: Regular distributed health check
- **Before production**: Validate distributed correctness

**Warning signs**:
- Split-brain incidents
- State inconsistencies after network issues
- Cluster performance degradation
- Nodes frequently disconnecting
- Unclear consensus strategy

## Skill References

The distributed-systems-expert agent uses these skill reference files for domain knowledge:

- **distributed-systems/consensus.md** - Raft, Paxos, consensus algorithms
- **distributed-systems/clustering.md** - Distributed Erlang, Partisan, libcluster
- **distributed-systems/failure-modes.md** - Split-brain, network partitions, quorum
- **distributed-systems/crdts.md** - CRDTs for eventual consistency
- **distributed-systems/timing.md** - Clock drift, monotonic time, NTP
- **distributed-systems/cap-theorem.md** - CAP tradeoffs, consistency models
- **distributed-systems/monitoring.md** - Cluster health, observability

## Related Commands

- `/review` - General code review (includes basic distributed checks)
- `/cognitive-audit` - Complexity analysis (can include consensus complexity)
- `/benchmark` - Performance testing (distributed operations)

---
description: Research state-of-the-art algorithms for a problem
argument-hint: <problem-description>
allowed-tools: [Task, WebFetch, Read, Write, Glob, Grep, Bash]
model: opus
---

# Algorithm Research Command

Launches the algorithms-researcher agent to conduct comprehensive research on algorithms and data structures, with paper citations and implementation guidance.

## Purpose

This command helps you:
- Find modern algorithms that outperform classic approaches
- Research solutions for novel problems
- Get paper citations and implementation complexity analysis
- Assess tradeoffs between accuracy, performance, and complexity
- Receive Elixir-specific implementation recommendations

## Usage

```bash
/algorithm-research <problem-description>
```

**Examples**:
```bash
/algorithm-research unique visitor counting for 100M users
/algorithm-research faster alternative to MD5 for checksums
/algorithm-research top-k tracking in event stream
/algorithm-research approximate nearest neighbor search
```

## Research Workflow

### 1. Problem Clarification

The agent will first clarify your requirements:
- **Data scale**: How many items? What throughput?
- **Accuracy**: Exact or approximate? Acceptable error rate?
- **Latency**: Real-time or batch processing?
- **Memory/compute budget**: Any constraints?
- **Current approach**: What are you using now? Why insufficient?

### 2. Literature Search

The agent searches academic sources:
- **arXiv preprints** (cs.DS, cs.DB, cs.DC)
- **ACM conferences** (SIGMOD, STOC, FOCS)
- **IEEE publications** (ICDE, Big Data)
- **Industry research** (Google, Facebook, Microsoft)

Search focuses on:
- Recent papers (last 5 years preferred)
- Practical implementations with benchmarks
- Production deployments

### 3. Algorithm Comparison

The agent compares candidate algorithms:
- **Complexity analysis**: Time and space bounds
- **Performance benchmarks**: From papers or estimated
- **Accuracy guarantees**: For approximate algorithms
- **Implementation difficulty**: Effort required
- **Production maturity**: Who's using it in practice

Presented in comparison table format.

### 4. Recommendation

The agent provides:
- **Primary recommendation** with rationale
- **Alternative approaches** for different constraints
- **Implementation guidance** (library or custom)
- **Tradeoff analysis** (accuracy, performance, complexity)
- **Next steps** for prototyping and validation

### 5. Documentation

For substantial research, the agent creates:
- **Annotated bibliography** in `.claude/research-refs.md`
- **Full paper citations** with links
- **Implementation notes** and code sketches
- **Further reading** for deep dives

## Output Format

### Quick Research (Simple Problems)

For well-known algorithm spaces:

```markdown
## Algorithm Recommendation: [Algorithm Name]

**Paper**: "[Title]" ([Authors], [Year])

**Your Problem**: [Problem statement]
**Your Scale**: [Data volume/throughput]

### Why This Algorithm
[2-3 sentences explaining fit]

### Performance
- Time: O(...)
- Space: O(...)
- At your scale: [concrete metrics]
- Improvement over current: [X]× faster/smaller

### Implementation
**Elixir Library**: [package name]
**Complexity**: Low/Medium/High
**Time Estimate**: [hours/days]

### Tradeoffs
**Pros**: [2-3 advantages]
**Cons**: [2-3 limitations]

### Alternatives
- **[Algorithm 2]**: [When to use instead]

## References
1. [Paper citation with link]

## Next Steps
1. [Action 1]
2. [Action 2]
```

### Deep Research (Novel/Complex Problems)

For substantial research:

```markdown
# [Research Topic] - Algorithms Bibliography

**Date**: [Date]
**Researcher**: algorithms-researcher agent
**Context**: [Why research needed]

## Executive Summary
[3-5 sentence overview of findings]

**Recommended**: [Algorithm]
**Key Paper**: [Most important paper]
**Implementation**: [Elixir approach]

## Problem Space

### Requirements
- Scale: [Data volume/throughput]
- Accuracy: [Requirements]
- Latency: [Performance needs]
- Memory: [Constraints]

### Current Approach
[What you're doing now and limitations]

## Literature Review

### Survey Papers
[Overview papers to understand space]

### Foundational Papers
[Classic work that established the field]

### Modern Improvements
[Recent advances (last 5 years)]

### Implementation Papers
[Systems papers with production experience]

## Algorithm Comparison

| Algorithm | Year | Time | Space | Accuracy | Complexity | Production |
|-----------|------|------|-------|----------|------------|------------|
| Current | - | O(n) | O(n) | 100% | Low | Your system |
| Option A | 2018 | O(1) | O(k) | 98% | Medium | Company X |
| **Recommended** | **2020** | **O(1)** | **O(k)** | **99%** | **Medium** | **Company Y** |

## Detailed Analysis: [Recommended Algorithm]

### Algorithm Description
[Plain language explanation]

### Theoretical Guarantees
[Complexity bounds, accuracy]

### Practical Performance
[Real-world benchmarks]

### Implementation Considerations
[Challenges, parameters, gotchas]

### Elixir-Specific Notes
[How to implement effectively in Elixir]

## Implementation Recommendations

### For Your Scale

**Best Choice**: [Algorithm]

**Rationale**:
1. [Reason 1]
2. [Reason 2]

**Implementation Path**:

1. **Quick Prototype** (1-2 hours):
   - [Approach]
   - [Validation]

2. **Production Version** (1-2 days):
   - [Steps]
   - [Testing]

3. **Optimization** (if needed):
   - [Tuning]

### Alternative Approaches
[If requirements change]

## Elixir Ecosystem

### Available Libraries
- [Library assessments]

### Custom Implementation
[Guidance if needed]

### NIFs/Ports
[When to use native code]

## Further Reading

### Essential Papers
1. [Paper] - [Why essential]

### Advanced Topics
1. [Paper] - [Deep dive]

### Implementation Resources
- [Tutorials]
- [Reference implementations]

## Appendix

### Search Terms Used
[For reproducibility]

### Related Problems
[Pointers to related topics]
```

## Common Research Scenarios

### Scenario 1: Need Modern Alternative

**Problem**: "I'm using MD5 for checksums, is there something faster?"

**Research Flow**:
1. Clarify: Non-cryptographic use case, performance critical
2. Search: Modern hash functions (xxHash, BLAKE3, HighwayHash)
3. Compare: Speed benchmarks, quality, collision resistance
4. Recommend: xxHash3 (60× faster, excellent quality)
5. Implementation: `exhash` library (production-ready)

**Output**: Quick research format with clear recommendation

### Scenario 2: Novel Problem

**Problem**: "How do I track top 1000 items in a stream of billions?"

**Research Flow**:
1. Clarify: Scale (billions/day), accuracy (approximate okay), memory budget
2. Decompose: Stream processing + frequency counting + top-k tracking
3. Survey: Space-Saving, Count-Min Sketch, HeavyKeeper
4. Compare: Memory footprint, accuracy guarantees, update speed
5. Recommend: Space-Saving algorithm (O(k) memory, bounded error)
6. Document: Full bibliography in `.claude/research-refs.md`

**Output**: Deep research format with annotated bibliography

### Scenario 3: Implementation Complexity Assessment

**Problem**: "Should I switch from exact counting to HyperLogLog?"

**Research Flow**:
1. Clarify: Current scale (50M unique items), growth trajectory
2. Calculate: Current memory (400 MB) vs HyperLogLog (12 KB)
3. Assess: Implementation effort (6 hours) vs savings (immediate)
4. Tradeoff: 100% accuracy → 98% accuracy (acceptable for analytics)
5. Recommend: Yes, switch (33,000× memory reduction)

**Output**: Cost-benefit analysis with clear go/no-go decision

### Scenario 4: Performance Optimization

**Problem**: "This sorting is too slow on large lists"

**Research Flow**:
1. Clarify: Data size (>100K items), data characteristics (random, patterns?)
2. Search: Modern sorting (BlockQuicksort, pdqsort, TimSort)
3. Compare: Cache efficiency, pattern detection, worst-case behavior
4. Recommend: pdqsort for mixed data with patterns
5. Coordinate: Hand off to performance-analyzer for benchmarking

**Output**: Recommendation with handoff to performance-analyzer

## Research Quality Standards

The agent ensures:

✅ **Citations Include**:
- Full paper title
- Authors
- Publication venue and year
- Link to paper (arXiv, DOI, conference site)
- Key contribution in one sentence

✅ **Comparisons Include**:
- Multiple candidate algorithms (3-5)
- Quantitative metrics (time, space, accuracy)
- Real-world benchmarks or estimates
- Production deployments (who uses it)

✅ **Recommendations Include**:
- Clear choice based on requirements
- Rationale (why this algorithm fits)
- Tradeoff acknowledgment
- Implementation complexity
- Alternatives for different constraints

✅ **Implementation Guidance Includes**:
- Elixir library recommendations with maturity assessment
- Custom implementation approach if no library
- Code sketches or examples
- Testing strategy
- Monitoring considerations

## Integration with Other Agents

### Handoff to Performance Analyzer

When algorithm recommendation needs validation:

```
algorithms-researcher: Recommends BlockQuicksort over standard sort
↓
performance-analyzer: Creates benchmark comparing both
↓
algorithms-researcher: May suggest tuning based on benchmark results
```

### Handoff from Architect

When code review identifies algorithmic issues:

```
architect: Identifies O(n²) complexity in code
↓
algorithms-researcher: Finds O(n log n) or O(n) alternative
↓
architect: Reviews implementation approach
```

### Handoff to Cognitive Scientist

When algorithm adds complexity:

```
algorithms-researcher: Recommends complex algorithm for big performance gain
↓
cognitive-scientist: Assesses readability impact
↓
algorithms-researcher: May suggest simpler alternative if cognitive load too high
```

## Tips for Effective Research

### Be Specific About Scale

Instead of: "I need fast counting"
Better: "I need to count 100M unique visitors per day"

Specific scale enables:
- Concrete performance estimates
- Appropriate algorithm selection
- Cost-benefit analysis

### Clarify Accuracy Requirements

Instead of: "Approximate is okay"
Better: "Can tolerate ±2% error for analytics dashboard"

Accuracy bounds enable:
- Probabilistic structure selection
- Parameter tuning
- Tradeoff evaluation

### Describe Current Approach

Instead of: "Need better algorithm"
Better: "Currently using MapSet for unique counting, using 2GB memory"

Context enables:
- Baseline comparison
- Quantified improvements
- Migration path

### State Constraints

Instead of: "Memory-efficient algorithm"
Better: "Must use <100MB memory, CPU not constrained"

Explicit constraints enable:
- Focused search
- Appropriate tradeoffs
- Feasible recommendations

## When to Use This Command

**Use algorithm-research when**:
- ✅ Need to find better algorithm than current approach
- ✅ Novel problem without obvious solution
- ✅ Performance issues seem algorithmic in nature
- ✅ Considering approximate algorithms (probabilistic structures)
- ✅ Need academic paper citations for decision justification
- ✅ Want to understand tradeoffs before implementing

**Don't use algorithm-research when**:
- ❌ Just need to optimize existing code (use performance-analyzer)
- ❌ Problem is code quality, not algorithms (use architect)
- ❌ Need testing strategy (use elixir-tester)
- ❌ Well-known algorithm, just need implementation (use general assistant)

## Example Sessions

### Example 1: Quick Research

```
User: /algorithm-research faster checksum than MD5

Agent: Let me clarify your requirements:
- Use case: Non-cryptographic checksums?
- Scale: How many checksums per second?
- Data size: Typical size being hashed?

User: Yes non-crypto, about 10K checksums/sec, files ~1MB each

Agent: [Researches modern hash functions]

## Algorithm Recommendation: xxHash3

**Paper**: "xxHash: Fast Hash Algorithm" (Yann Collet, 2020)
**Link**: https://github.com/Cyan4973/xxHash

**Your Problem**: Non-cryptographic checksums for 1MB files at 10K/sec
**Your Scale**: 10GB/sec throughput needed

### Why This Algorithm
xxHash3 is optimized for modern CPUs with SIMD instructions, achieving
31.5 GB/s vs MD5's 0.5 GB/s. Excellent hash quality with low collision
rates. Widely used in production (Zstd, Redis, RocksDB).

### Performance
- Speed: 31.5 GB/s (60× faster than MD5)
- Quality: Excellent distribution, low collisions
- At your scale: 10GB/sec easily handled
- Improvement: 60× faster, unblock your pipeline

### Implementation
**Elixir Library**: `exhash` package
**Maturity**: Stable, production-ready
**Complexity**: Low (drop-in replacement)
**Time Estimate**: 1-2 hours (add dep, update calls, test)

**Usage**:
```elixir
# Old
:crypto.hash(:md5, data)

# New
:exhash.xxh3_128(data)  # 128-bit hash
```

### Tradeoffs
**Pros**:
- 60× faster than MD5
- Better hash quality
- Consistent across platforms

**Cons**:
- Not cryptographic (but you don't need that)
- Different hash values (not MD5 compatible)

### Alternatives
- **BLAKE3**: If need cryptographic properties (still 5× faster than MD5)

## References
1. Collet, Y. (2020). "xxHash: Fast Hash Algorithm"
   https://github.com/Cyan4973/xxHash

## Next Steps
1. Add `{:exhash, "~> 0.2"}` to mix.exs
2. Replace MD5 calls with xxh3_128
3. Benchmark on your data to confirm improvement
```

### Example 2: Deep Research

```
User: /algorithm-research tracking top 100 events in stream with 100K event types

Agent: Let me clarify scale and requirements:
- Event rate: How many events per second?
- Update latency: How fast do top-100 need to update?
- Query frequency: How often querying top-100?
- Accuracy: Exact or approximate? If approximate, acceptable error?

User: About 3K events/sec, updates can be seconds, queries every minute, approximate within 5% okay

Agent: [Conducts comprehensive research, searches papers, compares algorithms]

[Creates full annotated bibliography in .claude/research-refs.md]

## Research Summary

I've created a comprehensive bibliography in `.claude/research-refs.md` with full paper citations.

**Recommendation**: Space-Saving Algorithm + Min-Heap

This provides:
- Fixed O(k) memory (k=100 counters)
- Real-time updates in O(log k) time
- Guaranteed to find true top-100
- Frequency error bounded by N/k

See full analysis in `.claude/research-refs.md` for:
- Literature review (5 papers analyzed)
- Algorithm comparison table
- Implementation guide
- Production examples
- Alternative approaches

Next steps:
1. Review bibliography
2. Prototype Space-Saving (4-6 hours estimated)
3. Validate accuracy on your data
```

## Success Criteria

Successful research provides:
- ✅ Clear algorithm recommendation with rationale
- ✅ Academic paper citations with links
- ✅ Performance metrics (quantitative)
- ✅ Implementation complexity assessment
- ✅ Elixir library recommendations
- ✅ Tradeoff analysis
- ✅ Alternative approaches
- ✅ Next steps for implementation

---

**See also**:
- `algorithms` skill for comprehensive algorithm patterns
- `algorithms-researcher` agent for detailed methodology
- `performance-analyzer` agent for benchmarking algorithms
- `.claude/research-refs.md` for accumulated research notes

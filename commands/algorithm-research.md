---
description: Research state-of-the-art algorithms for a problem
argument-hint: <problem-description>
allowed-tools: [Task, WebFetch, Read, Write, Glob, Grep, Bash]
model: opus
---

# Algorithm Research Command

Launches the algorithms-researcher agent to conduct comprehensive research on algorithms and data structures, with paper citations and implementation guidance.

## Purpose

- Find modern algorithms that outperform classic approaches and get paper citations
- Research solutions for novel problems with complexity analysis and tradeoff assessment
- Receive Elixir-specific implementation recommendations with library guidance

## Usage

```bash
/algorithm-research <problem-description>
```

**Examples**:
```bash
/algorithm-research unique visitor counting for 100M users
/algorithm-research faster alternative to MD5 for checksums
/algorithm-research top-k tracking in event stream
```

## Research Workflow

### 1. Problem Clarification
Clarify data scale, accuracy requirements (exact/approximate), latency needs, memory/compute budget, and current approach limitations.

### 2. Literature Search
Search arXiv (cs.DS, cs.DB), ACM conferences (SIGMOD, STOC), IEEE publications, and industry research for recent papers (last 5 years) with practical implementations.

### 3. Algorithm Comparison
Compare candidates by complexity analysis, performance benchmarks, accuracy guarantees, implementation difficulty, and production maturity in table format.

### 4. Recommendation
Provide primary recommendation with rationale, alternatives for different constraints, implementation guidance (library or custom), tradeoff analysis, and next steps.

### 5. Documentation
For substantial research, create annotated bibliography in `.claude/research-refs.md` with full citations, links, implementation notes, and further reading.

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

### Current Approach
[What you're doing now and limitations]

## Literature Review
### Survey Papers / Foundational Papers / Modern Improvements / Implementation Papers
[Organized citations by category]

## Algorithm Comparison
| Algorithm | Year | Time | Space | Accuracy | Complexity | Production |
|-----------|------|------|-------|----------|------------|------------|
| **Recommended** | **2020** | **O(1)** | **O(k)** | **99%** | **Medium** | **Company** |

## Detailed Analysis: [Recommended Algorithm]
### Algorithm Description / Theoretical Guarantees / Practical Performance / Implementation Considerations / Elixir-Specific Notes

## Implementation Recommendations
### For Your Scale / Alternative Approaches / Elixir Ecosystem

## Further Reading
### Essential Papers / Advanced Topics / Implementation Resources

## Appendix
### Search Terms Used / Related Problems
```

## Common Research Scenarios

**Modern Alternative**: "Is there something faster than MD5?" → Research modern hash functions (xxHash, BLAKE3)
**Novel Problem**: "Track top 1000 items in stream of billions" → Research Space-Saving, Count-Min Sketch, HeavyKeeper with full bibliography
**Implementation Complexity**: "Should I switch to HyperLogLog?" → Cost-benefit analysis with go/no-go decision
**Performance Optimization**: "Sorting too slow on large lists" → Research modern sorting (pdqsort, TimSort) and handoff to performance-analyzer

## Research Quality Standards

The agent ensures:

✅ **Citations Include**: Full paper title, authors, venue/year, link (arXiv/DOI), and key contribution

✅ **Comparisons Include**: Multiple candidates (3-5), quantitative metrics, real-world benchmarks, and production deployments

✅ **Recommendations Include**: Clear choice based on requirements, rationale, tradeoff acknowledgment, implementation complexity, and alternatives

✅ **Implementation Guidance Includes**: Elixir library recommendations with maturity assessment, custom implementation approach, code sketches, testing strategy, and monitoring considerations

## When to Use This Command

**Use algorithm-research when**:
- ✅ Need to find better algorithm than current approach
- ✅ Novel problem without obvious solution
- ✅ Performance issues seem algorithmic in nature
- ✅ Considering approximate algorithms (probabilistic structures)
- ✅ Need academic paper citations for decision justification

**Don't use algorithm-research when**:
- ❌ Just need to optimize existing code (use performance-analyzer)
- ❌ Problem is code quality, not algorithms (use architect)
- ❌ Well-known algorithm, just need implementation (use general assistant)

---

**Algorithm reference data**: See algorithms skill files: `otp-builtins.md`, `probabilistic.md`, `hash-functions.md`, `sorting-and-search.md`

**See also**:
- `algorithms` skill for comprehensive algorithm patterns
- `algorithms-researcher` agent for detailed methodology
- `performance-analyzer` agent for benchmarking algorithms

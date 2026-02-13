---
name: cognitive-complexity
description: Use when code is hard to understand, a module has too many parameters or deep nesting, functions exceed 40 lines, abstractions feel leaky, or you need to evaluate deep-module vs shallow-module design per Ousterhout principles
---

# Cognitive Complexity

## Overview

Complexity comes from dependencies and obscurity. Reduce it by making modules deeper — simple interfaces hiding significant implementation. Measure depth as implementation power divided by interface complexity.

## Complexity Reduction Ladder

| Level | Smell | Fix |
|-------|-------|-----|
| L0 | Generic names | Rename to describe domain concepts |
| L1 | >4 params, >3 nesting levels, >40 line functions | Group into structs, extract named functions |
| L2 | Callers duplicate checks, must call in order | Pull complexity downward, deepen the interface |
| L3 | Branching grows with each new type | Protocols to eliminate special cases |
| L4 | Can't find things, features touch 8 files | Organize by domain (Phoenix contexts) |
| L5 | Accumulated tactical debt | Strategic refactoring — one protocol/module per PR |

```
Code is confusing. Why?
  Names are unclear          → Level 0 (rename)
  Too much to track at once  → Level 1 (reduce working memory)
  Module is hard to use      → Level 2 (deepen the interface)
  Branching keeps growing    → Level 3 (eliminate special cases)
  Can't find things          → Level 4 (architectural clarity)
  Accumulated debt           → Level 5 (strategic refactoring)
```

## Core Principles (Ousterhout)

- **Deep modules**: Simple interface, powerful implementation — `DeepCache.put(key, val)` beats `ShallowCache.put(key, val, ttl, serializer, compression)`
- **Information hiding**: Don't leak internal representation, temporal coupling, or pass-through variables
- **Pull complexity downward**: Add complexity to implementation to simplify all callers
- **Define errors out of existence**: Types that make invalid states unrepresentable
- **Strategic over tactical**: Invest in abstractions; technical debt compounds immediately

## Common Mistakes

- **Shallow decomposition**: Extracting tiny functions that just delegate — increases indirection without reducing complexity
- **Pass-through variables**: Same config threaded through 5 layers — access it where needed instead
- **Temporal coupling**: Functions that must be called in specific order — chain with `with` internally
- **Clean Code dogma**: Arbitrary line limits miss the point; function length is fine if the abstraction is clear
- **Generic names**: `process`, `handle`, `data` — forces reading implementation to understand intent

## Reference Files

**Read the file that matches your current problem:**

- `escalation-ladder.md` — **When**: Need thresholds and code examples for each complexity level. Full Complexity Reduction Ladder (L0-L5 with code examples, thresholds)
- `ousterhout-principles.md` — **When**: Evaluating module depth or interface design. Deep modules, information hiding, strategic programming, SRK interface design
- `references/metrics.md` — **When**: Measuring cognitive complexity numerically. Cognitive complexity metrics
- `references/patterns.md` — **When**: Looking for specific refactoring techniques. Refactoring patterns catalog
- `references/onboarding.md` — **When**: Assessing how hard code is for new developers. Onboarding difficulty assessment

## Commands

- **`/cognitive-audit`** — Full complexity analysis with onboarding difficulty assessment
- **`/review [file]`** — Review code including complexity evaluation

## Related Skills

- **elixir-patterns**: Protocols, behaviours, Phoenix contexts
- **production-quality**: Code quality standards, documentation

---
description: Fast iteration mode for experiments without production requirements
argument-hint: <spike-goal>
allowed-tools: [Read, Write, Edit, Bash, Task]
model: haiku
---

# Spike Mode

Rapid prototyping without production requirements:
- Skip typespecs initially
- Focus on working code first
- Minimal test coverage (smoke tests only)
- Mark code with `# SPIKE: <reason>`
- Track debt in `.claude/spike-debt.md`

[Full implementation pending]

---
description: Document patterns in project-learnings.md
argument-hint: <pattern-description>
allowed-tools:
  - "Read"
  - "Edit"
  - "Write"
model: haiku
---

# Learn Command

Interactive knowledge capture in `.claude/project-learnings.md` for building project-specific knowledge.

## What It Does

Captures and organizes project knowledge systematically by reading current knowledge, parsing the pattern, categorizing it appropriately, formatting for easy searching, updating the file, and confirming the addition.

## Usage

```bash
/learn "All Req HTTP calls need explicit timeout"
/learn "JSONB queries require explicit indexes for performance"
/learn "LiveView optimistic updates improve UX"
```

## When to Use

**Capture knowledge after**: Completing a feature, migrating SPIKE code, finding a gotcha or bug, discovering a performance pattern, learning a library-specific pattern, making an architectural decision, or resolving a tricky issue.

**Don't use for**: General Elixir patterns (those are universal), temporary notes (use spike-debt.md), TODO items (use TodoWrite), or general documentation (use module docs).

## Implementation

### Step 1: Initialize or Read project-learnings.md

Check if `.claude/project-learnings.md` exists. If present, read existing content. Otherwise, create from template.

### Step 2: Template Structure (Compact)

```markdown
# Project Learnings

Project-specific patterns, conventions, and gotchas for [Project Name].
Last updated: [Date]

## Domain Conventions
- Naming Conventions: Project-specific naming rules
- Module Organization: Where different code types live

## Common Patterns
- Data Access: How queries and data fetching work
- Error Handling: Approach to errors and failures
- Testing: Test organization and practices

## Library-Specific Patterns
- Phoenix LiveView: LiveView-specific patterns
- Oban: Job queue patterns
- [Other libraries]: Library-specific usage

## Performance Patterns
- Database: Query optimization and indexing
- Caching: Cache strategies and TTLs

## Common Gotchas
- Security: Avoiding security pitfalls
- Data Integrity: Transaction and consistency issues
- Concurrency: Process and timing issues

## Architectural Decisions
- Technology Choices: Why we chose specific technologies
- Design Patterns: Architectural patterns and trade-offs

## Development Workflow
- Code Review: Review process and requirements
- Testing Strategy: Test coverage strategy

## Production Considerations
- Monitoring: Alerts and metrics
- Feature Flags: Feature flag usage

## Learning Resources
- Internal Docs: Links to project documentation
- External Resources: Helpful external references
```

### Steps 3-6: Process Overview

**Parse Pattern**: Analyze the pattern to determine type (gotcha, performance, convention, etc.) and appropriate category. **Determine Section**: Map pattern to the correct section (Domain Conventions, Common Patterns, Library-Specific, Performance, Gotchas, or Architectural Decisions). **Format Pattern**: Structure with clear description, code examples, reason, and cross-references. **Update File**: Add formatted entry to appropriate section with date context.

### Step 7: Confirm Update

Show what was added: section, pattern name, and confirmation that it's now searchable.

## Pattern Categories

**Domain Conventions**: Project-specific business rules
- Example: `/learn "Money amounts stored in cents (integer) to avoid float precision"`

**Common Patterns**: Established coding patterns
- Example: `/learn "Use with statements for multi-step operations with error handling"`

**Library-Specific Patterns**: Third-party library usage
- Example: `/learn "Phoenix LiveView: use phx-debounce='300' for search inputs"`

**Performance Patterns**: Optimization knowledge
- Example: `/learn "JSONB columns need GIN indexes for queries: CREATE INDEX USING GIN"`

**Common Gotchas**: Mistakes to avoid
- Example: `/learn "LiveView: handle_info for PubSub must pattern match message shape"`

**Architectural Decisions**: Historical context
- Example: `/learn "Decision: PostgreSQL over MySQL - better JSON support, needed for preferences"`

## Format Examples

### Domain Convention Entry

```markdown
## Domain Conventions

### Money Handling

**Pattern**: All monetary amounts stored as integers in cents

**Reason**: Avoid floating-point precision errors in financial calculations

**Example**:
```elixir
# Schema
schema "orders" do
  field :amount_cents, :integer  # $19.99 stored as 1999
end

# Display
def format_price(cents), do: "$#{cents / 100}"
```

**Related**: Performance Patterns → Database Precision
```

### Common Gotcha Entry

```markdown
## Common Gotchas

### LiveView PubSub Message Handling

**Issue**: PubSub messages to LiveView require explicit pattern matching

**Why**: handle_info/2 needs to match exact message structure

**Solution**: Always pattern match PubSub message structure in handle_info

**Example**:
```elixir
# Good - explicit pattern match
def handle_info({:user_updated, user_id}, socket) do
  {:noreply, reload_user(socket, user_id)}
end
```

**Related**: Phoenix LiveView Patterns
```

### Performance Pattern Entry

```markdown
## Performance Patterns

### Batch Database Inserts

**Pattern**: Use Repo.insert_all for inserting multiple records

**Performance**: 10-20x faster than individual inserts

**Example**:
```elixir
# Good - single database round trip
users_list = Enum.map(users, fn attrs ->
  Map.put(attrs, :inserted_at, DateTime.utc_now())
end)

Repo.insert_all(User, users_list)
```

**Related**: Database → Bulk Operations
```

## Best Practices

1. **Be specific**: "Use X for Y" not "X is good"
2. **Include examples**: Code speaks louder than words
3. **Explain why**: Context helps future developers
4. **Cross-reference**: Link related patterns
5. **Date entries**: Track when pattern was added
6. **Keep updated**: Remove obsolete patterns
7. **One pattern per entry**: Focused and searchable

## Error Handling

### No project-learnings.md
Creates `.claude/project-learnings.md` with initial template and confirms initialization.

### Pattern Already Documented
Warns about similar existing entry, offers to update existing, add as separate pattern, or skip.

### Unclear Pattern
Requests more context if pattern is too vague. Asks for specific use case, reasoning, and example code.

## Success Criteria

Learn command succeeds when pattern is clearly described, code examples provided, placed in appropriate section, searchable keywords included, related patterns cross-referenced, date/context added, and file updated successfully.

## Related Commands

- `/feature` - Suggests patterns to document after completion
- `/spike-migrate` - Captures learnings from migration
- `/review` - May reference project-learnings.md for standards
- `/benchmark` - Performance findings worth documenting
- `/cognitive-audit` - Architectural patterns discovered

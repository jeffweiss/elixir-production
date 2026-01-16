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

Captures and organizes project knowledge systematically:

1. **Read Current Knowledge** - Load existing project-learnings.md
2. **Parse Pattern** - Understand what to document
3. **Categorize** - Place in appropriate section
4. **Format** - Structure for easy searching
5. **Update File** - Add to project knowledge base
6. **Confirm** - Show what was added

## Usage

```bash
/learn "All Req HTTP calls need explicit timeout"
/learn "JSONB queries require explicit indexes for performance"
/learn "LiveView optimistic updates improve UX"
```

## When to Use

**Capture knowledge after**:
- Completing a feature (/feature)
- Migrating SPIKE code (/spike-migrate)
- Finding a gotcha or bug
- Discovering a performance pattern
- Learning a library-specific pattern
- Making an architectural decision
- Resolving a tricky issue

**Don't use for**:
- General Elixir patterns (those are universal)
- Temporary notes (use spike-debt.md)
- TODO items (use TodoWrite)
- General documentation (use module docs)

## Implementation

### Step 1: Initialize or Read project-learnings.md

Check if `.claude/project-learnings.md` exists:

```bash
# Check for file
if [ -f ".claude/project-learnings.md" ]; then
  # Read existing
  cat .claude/project-learnings.md
else
  # Create from template
  mkdir -p .claude
  # Create initial template
fi
```

### Step 2: Template Structure

If creating new file, use this template:

```markdown
# Project Learnings

Project-specific patterns, conventions, and gotchas for [Project Name].

Last updated: [Date]

## Domain Conventions

Project-specific domain rules and patterns.

### Naming Conventions

<!-- Example:
- User-facing features use `UserFacing.*` namespace
- Background jobs suffix with `Worker`
-->

### Module Organization

<!-- Example:
- Contexts go in lib/my_app/
- Web layer in lib/my_app_web/
- Shared utilities in lib/my_app/utils/
-->

## Common Patterns

Established patterns used throughout the project.

### Data Access

<!-- Example:
- All Repo queries wrapped in contexts
- Use preload for associations, not joins
- Pagination uses Scrivener
-->

### Error Handling

<!-- Example:
- Public APIs return {:ok, result} | {:error, reason}
- Use with statements for pipeline error handling
- Log errors with correlation IDs
-->

### Testing

<!-- Example:
- Use describe/test blocks for organization
- Tag critical tests with @tag criticality: 9-10
- Use ExMachina factories for test data
-->

## Library-Specific Patterns

How we use third-party libraries.

### Phoenix LiveView

<!-- Example:
- Debounce user input with phx-debounce="300"
- Use streams for large lists
- Handle disconnects gracefully
-->

### Oban

<!-- Example:
- Max 3 retry attempts for jobs
- Use unique: true for idempotent jobs
- Queue priority: critical > default > low
-->

## Performance Patterns

Performance optimizations and guidelines.

### Database

<!-- Example:
- Always add indexes on foreign keys
- Use JSONB for flexible schemas
- Batch inserts with Repo.insert_all
-->

### Caching

<!-- Example:
- Cache computation results in ETS
- TTL: 5 minutes for user data, 1 hour for config
- Cache keys: "resource:id:field"
-->

## Common Gotchas

Mistakes to avoid, with examples.

### Security

<!-- Example:
- Always parameterize SQL (no string interpolation)
- Validate user input before processing
- Use Phoenix.Token, not plain JWTs
-->

### Data Integrity

<!-- Example:
- Wrap multi-step operations in transactions
- Use database constraints, not just validations
- Handle stale entry errors in updates
-->

### Concurrency

<!-- Example:
- GenServers should handle timeouts
- Use Task.Supervisor for supervised tasks
- Avoid long-running processes blocking
-->

## Architectural Decisions

Why things are the way they are.

### Technology Choices

<!-- Example:
Decision: Use PostgreSQL JSONB over separate tables for user preferences
Reason: Flexibility for variable preference schemas
Trade-off: Complex queries require GIN indexes
Date: 2025-01-16
-->

### Design Patterns

<!-- Example:
Pattern: Command pattern for all mutations
Reason: Consistent audit logging and rollback capability
Alternative considered: Direct changeset updates
Date: 2025-01-18
-->

## Development Workflow

Team-specific development practices.

### Code Review

<!-- Example:
- All PRs require 1 approval
- Run /precommit before requesting review
- Security changes require 2 approvals
-->

### Testing Strategy

<!-- Example:
- Unit tests for business logic (criticality 9-10)
- Integration tests for API endpoints (criticality 8-9)
- E2E tests for critical user flows (criticality 10)
-->

## Production Considerations

Deployment and operations knowledge.

### Monitoring

<!-- Example:
- Alert on error rate >1% in 5-minute window
- Track P95 response time <200ms
- Monitor Oban queue depth
-->

### Feature Flags

<!-- Example:
- Use FunWithFlags for gradual rollouts
- Always add flag for risky features
- Clean up flags after 2 weeks
-->

## Learning Resources

Helpful references for the team.

### Internal Docs

- Architecture overview: docs/architecture.md
- API documentation: docs/api.md
- Deployment guide: docs/deployment.md

### External Resources

- Phoenix LiveView patterns: [link]
- Ecto performance tips: [link]
```

### Step 3: Parse Pattern

Analyze what the user wants to document:

```markdown
Analyzing pattern: "All Req HTTP calls need explicit timeout"

Categorization:
- Type: Common Gotcha (avoiding mistakes)
- Category: Library-Specific Pattern (Req usage)
- Reason: Performance / reliability

Best fit: Common Gotchas → Performance / External Services
```

### Step 4: Determine Section

Map pattern types to sections:

**Domain Conventions**:
- Naming rules
- Module organization
- Business logic patterns

**Common Patterns**:
- Data access patterns
- Error handling approaches
- Testing practices

**Library-Specific Patterns**:
- How to use third-party libraries
- Configuration patterns
- Best practices for specific tools

**Performance Patterns**:
- Database optimizations
- Caching strategies
- Memory management

**Common Gotchas**:
- Mistakes to avoid
- Edge cases
- Known issues

**Architectural Decisions**:
- Why we chose X over Y
- Trade-offs documented
- Historical context

### Step 5: Format Pattern

Structure the knowledge entry:

```markdown
### [Pattern Name]

**Pattern**: [Clear description]

**Example**:
```elixir
# Good
Req.get!(url, receive_timeout: 5000)

# Bad - defaults to 5000ms but not explicit
Req.get!(url)
```

**Reason**: [Why this matters]

**Related**: [Cross-references to other patterns]
```

Or for gotchas:

```markdown
### [Gotcha Name]

**Issue**: [What goes wrong]

**Why**: [Root cause]

**Solution**:
```elixir
# Example of correct approach
```

**Related**: [Similar issues or patterns]
```

### Step 6: Update File

Add pattern to appropriate section:

```markdown
## Common Gotchas

### HTTP Client Timeouts

**Issue**: Req HTTP calls can hang indefinitely if remote service is slow or unresponsive

**Why**: Default timeout is infinite, causing processes to block

**Solution**: Always specify explicit timeout

```elixir
# Good - explicit timeout
Req.get!(url, receive_timeout: 5000)  # 5 second timeout

# Better - handle timeout errors
case Req.get(url, receive_timeout: 5000) do
  {:ok, %{status: 200, body: body}} -> {:ok, body}
  {:ok, %{status: status}} -> {:error, {:http_error, status}}
  {:error, %{reason: :timeout}} -> {:error, :timeout}
  {:error, reason} -> {:error, reason}
end
```

**Related**: Error Handling → Network Failures

**Added**: 2025-01-16 (during email preferences feature)
```

### Step 7: Confirm Update

Show what was added:

```markdown
✅ Knowledge Captured

Updated: .claude/project-learnings.md

Section: Common Gotchas → HTTP Client Timeouts

Added:
- Pattern description
- Code examples (good vs bad)
- Solution with error handling
- Related references

This pattern is now searchable and will help prevent similar issues.
```

## Pattern Categories

### Domain Conventions

Project-specific business rules:

```markdown
/learn "User roles: admin, manager, user - never 'superuser'"
/learn "Money amounts stored in cents (integer) to avoid float precision"
/learn "All timestamps use UTC, convert to user timezone in UI"
```

### Common Patterns

Established coding patterns:

```markdown
/learn "Use with statements for multi-step operations with error handling"
/learn "Prefix private functions with do_ to distinguish from public API"
/learn "Pagination uses keyset (cursor) not offset for performance"
```

### Library-Specific Patterns

Third-party library usage:

```markdown
/learn "Phoenix LiveView: use phx-debounce='300' for search inputs"
/learn "Oban: unique jobs use period: 60 to prevent duplicate work"
/learn "Ecto: use Repo.preload not joins for N+1 prevention"
```

### Performance Patterns

Optimization knowledge:

```markdown
/learn "ETS tables use read_concurrency: true for lookup-heavy workloads"
/learn "JSONB columns need GIN indexes for queries: CREATE INDEX USING GIN"
/learn "Batch database inserts with Repo.insert_all for 10x speedup"
```

### Common Gotchas

Mistakes to avoid:

```markdown
/learn "LiveView: handle_info for PubSub must pattern match message shape"
/learn "Ecto preload in transaction loads stale data - reload after commit"
/learn "Phoenix.Token.verify returns {:ok, user_id} not user struct"
```

### Architectural Decisions

Historical context:

```markdown
/learn "Decision: PostgreSQL over MySQL - better JSON support, needed for preferences"
/learn "Pattern: CQRS for orders - read model separate from write for performance"
```

## Integration with Other Commands

### Automatically triggered by

**After /feature**:
```markdown
Feature complete. Would you like to capture any patterns learned?

Suggested learnings:
- JSONB approach for preferences (Performance Pattern)
- Phoenix.Token usage (Library-Specific Pattern)
- Optimistic LiveView updates (Common Pattern)

Run: /learn "[pattern]" for any of these
```

**After /spike-migrate**:
```markdown
SPIKE migration complete. Patterns discovered:

1. JSONB indexes needed for query performance
2. Debouncing LiveView updates improves UX
3. Preference schema versioning prevents migration issues

Capture with: /learn "[pattern]"
```

**After /benchmark**:
```markdown
Benchmark complete. Performance findings:

- Stream better than Enum for large datasets (>10K items)
- Preprocessing into Map reduces O(n²) to O(n)

Document with: /learn "[finding]"
```

## Searching project-learnings.md

Project knowledge is searchable:

```bash
# Find patterns about LiveView
grep -i "liveview" .claude/project-learnings.md

# Find gotchas
grep -A 5 "Issue:" .claude/project-learnings.md

# Find architectural decisions
grep -A 10 "Decision:" .claude/project-learnings.md
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

```
Creating .claude/project-learnings.md...

# Project Learnings

[Initial template created]

✅ Knowledge base initialized
Ready to capture first pattern.
```

### Pattern Already Documented

```
⚠️  Similar Pattern Found

Existing entry in project-learnings.md:

## Common Gotchas → HTTP Timeouts
"All HTTP calls should have explicit timeouts"

Options:
1. Update existing entry with new information
2. Add as separate pattern
3. Skip (already documented)

Choose: [1/2/3]
```

### Unclear Pattern

```
⚠️  Pattern Unclear

Pattern: "use streams"

This is too vague. Please provide more context:
- What specific use case?
- Why use streams vs alternatives?
- Example code?

Try: /learn "Use Stream for large datasets (>10K items) when limiting results"
```

## Example Entries

### Domain Convention

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
def format_price(cents) do
  dollars = cents / 100
  "$#{:erlang.float_to_binary(dollars, decimals: 2)}"
end

# Calculations
def apply_discount(amount_cents, percent) do
  discount = div(amount_cents * percent, 100)
  amount_cents - discount
end
```

**Related**: Performance Patterns → Database Precision
```

### Common Gotcha

```markdown
## Common Gotchas

### LiveView PubSub Message Handling

**Issue**: PubSub messages to LiveView require explicit pattern matching

**Why**: handle_info/2 needs to match exact message structure

**Example**:
```elixir
# Bad - too generic, matches everything
def handle_info(msg, socket) do
  {:noreply, assign(socket, :data, msg)}
end

# Good - explicit pattern match
def handle_info({:user_updated, user_id}, socket) do
  # Handle specific message
  {:noreply, reload_user(socket, user_id)}
end

def handle_info(_unhandled, socket) do
  # Ignore unknown messages
  {:noreply, socket}
end
```

**Solution**: Always pattern match PubSub message structure in handle_info

**Related**: Phoenix LiveView Patterns
```

### Performance Pattern

```markdown
## Performance Patterns

### Batch Database Inserts

**Pattern**: Use Repo.insert_all for inserting multiple records

**Performance**: 10-20x faster than individual inserts

**Example**:
```elixir
# Bad - N database round trips
Enum.each(users, fn user_attrs ->
  User.changeset(%User{}, user_attrs)
  |> Repo.insert()
end)

# Good - single database round trip
users_list =
  Enum.map(users, fn attrs ->
    Map.put(attrs, :inserted_at, DateTime.utc_now())
    |> Map.put(:updated_at, DateTime.utc_now())
  end)

Repo.insert_all(User, users_list)
```

**Benchmark**: 1000 records - 15s → 1.2s (12.5x improvement)

**Trade-off**: No individual changesets, so manual validation required

**Related**: Database → Bulk Operations
```

## Success Criteria

Learn command succeeds when:
- ✅ Pattern clearly described
- ✅ Code examples provided
- ✅ Placed in appropriate section
- ✅ Searchable keywords included
- ✅ Related patterns cross-referenced
- ✅ Date/context added
- ✅ File updated successfully

## Related Commands

- `/feature` - Suggests patterns to document after completion
- `/spike-migrate` - Captures learnings from migration
- `/review` - May reference project-learnings.md for standards
- `/benchmark` - Performance findings worth documenting
- `/cognitive-audit` - Architectural patterns discovered

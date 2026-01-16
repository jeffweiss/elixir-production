# Claude Code Standards for Elixir Projects

## Philosophy

### Correctness Over Convenience
Every line of code should prioritize correctness and reliability over developer convenience. Production systems demand rigorous engineering:

- **Comprehensive error modeling**: Account for all failure modes
- **Explicit over implicit**: Make behavior obvious in code
- **Type safety**: Use typespecs to catch errors at compile time
- **No silent failures**: Every error must be handled or propagated explicitly

### User Experience Focus
Code quality directly impacts user experience. Write code that:

- **Fails gracefully**: Provide helpful error messages
- **Performs consistently**: Optimize for real-world usage patterns
- **Scales predictably**: Understand complexity implications
- **Maintains data integrity**: Never compromise user data

### Production-Grade Engineering
All code should be production-ready from the start:

- **Comprehensive testing**: Unit, integration, and property-based tests
- **Observable**: Include logging, metrics, and debugging hooks
- **Resilient**: Handle failures, retries, and edge cases
- **Maintainable**: Clear structure, good documentation, consistent patterns

## Development Workflow

### Test-Driven Development (TDD)
Write tests before implementation:

1. **Design test suite**: Explore entire result space (all success/error variants)
2. **Write failing tests**: Red phase
3. **Implement minimal code**: Green phase
4. **Refactor**: Improve design while keeping tests passing
5. **Repeat**: Continue cycle for each feature

### Precommit Quality Gate
Every commit must pass:

1. `mix compile --warnings-as-errors`
2. `mix format` (includes Styler)
3. `mix credo --strict`
4. `mix test`

No exceptions. Broken code never enters version control.

### Code Review Standards
All code changes require review focusing on:

- **Correctness**: Does it solve the problem without introducing bugs?
- **Clarity**: Can a new team member understand it?
- **Completeness**: Are all edge cases handled?
- **Consistency**: Does it follow project patterns?
- **Performance**: Are complexity implications understood?

## Code Quality Principles

### Simplicity and Clarity
- Prefer simple, obvious solutions over clever optimizations
- Write code for humans first, computers second
- Avoid premature abstractions (YAGNI principle)
- Use descriptive names that reveal intent

### Functional Core, Imperative Shell
- Pure business logic in the core (easy to test, reason about)
- Side effects pushed to boundaries (HTTP, database, external systems)
- Clear separation between computation and IO

### Railway-Oriented Programming
- Use `{:ok, value}` and `{:error, reason}` consistently
- Chain operations with `with` for clarity
- Handle all error cases explicitly
- No exceptions for control flow

### Domain-Driven Design (DDD)
- Organize code by business domain, not technical concerns
- Use ubiquitous language from business domain
- Define clear bounded contexts
- Maintain context boundaries (no cross-context queries)

## Documentation Philosophy

### Code Documentation
- **@moduledoc**: Purpose, responsibilities, usage examples
- **@doc**: Public function contracts, parameters, return values
- **@spec**: Type specifications for all public functions
- **Comments**: Explain "why" and non-obvious decisions (not "what")

### Project Documentation
- **README**: Quick start, setup, architecture overview
- **project-learnings.md**: Discovered patterns, conventions, gotchas
- **Architecture docs**: High-level system design and tradeoffs
- **API docs**: Generated from code with ExDoc

### Living Documentation
Documentation should evolve with code:
- Update docs when behavior changes
- Remove outdated information
- Agents auto-update project-learnings.md
- Keep examples working and tested

## Commit Conventions

### Commit Messages
Follow conventional commit format:

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types**:
- `feat`: New feature
- `fix`: Bug fix
- `refactor`: Code restructuring without behavior change
- `test`: Adding or updating tests
- `docs`: Documentation changes
- `perf`: Performance improvements
- `chore`: Maintenance tasks

**Example**:
```
feat(accounts): add email verification flow

Implements two-factor verification via email with:
- Token generation and expiration
- Email template with verification link
- Background job for cleanup

Closes #123
```

### Commit Scope
- Keep commits focused and atomic
- Each commit should be deployable
- Don't mix refactoring with feature work
- Write clear, descriptive messages

## Performance Philosophy

### Measure, Don't Guess
- Profile before optimizing
- Use Benchee for microbenchmarks
- Understand O(n) complexity with real data sizes
- Document performance decisions in project-learnings.md

### Optimization Strategy
1. **Identify bottleneck**: Profile to find actual slow parts
2. **Benchmark current approach**: Establish baseline
3. **Implement improvement**: With clear hypothesis
4. **Verify with benchmarks**: Confirm improvement
5. **Document tradeoffs**: Why this approach was chosen

### Complexity Awareness
- Analyze algorithm complexity before implementing
- Justify O(n²) or higher with real-world data
- Auto-create benchmarks for complex algorithms
- Consider memory usage and garbage collection

## Error Handling Philosophy

### Fail Fast, Fail Loudly
- Don't swallow errors silently
- Use "let it crash" for unexpected errors
- Provide context in error messages
- Log errors with sufficient debugging information

### User-Facing Errors
- Translate technical errors to user-friendly messages
- Provide actionable guidance when possible
- Never expose internal details to users
- Log full details for debugging

### Recovery Strategies
- Design for failure scenarios
- Implement retry logic for transient failures
- Use circuit breakers for external dependencies
- Maintain data consistency during failures

## Security Principles

### Defense in Depth
- Validate at every boundary
- Sanitize all user input
- Escape all output
- Use parameterized queries (Ecto default)

### Secrets Management
- Never commit secrets to version control
- Use environment variables or secret stores
- Rotate credentials regularly
- Audit access to sensitive data

### Authentication & Authorization
- Verify identity (authentication)
- Check permissions (authorization)
- Implement row-level security
- Use secure session management

## Team Collaboration

### Knowledge Sharing
- Document decisions in project-learnings.md
- Use `/learn` command to capture patterns
- Review and discuss tradeoffs
- Share insights from debugging and optimization

### Onboarding Support
- Maintain clear project structure
- Use consistent patterns throughout codebase
- Provide examples for complex features
- Run `/cognitive-audit` on complex modules

### Continuous Improvement
- Regular retrospectives on code quality
- Update standards based on lessons learned
- Refactor as patterns emerge
- Invest in tooling and automation

## Tools and Automation

### Required Tools
- **mise**: Version management
- **Credo**: Static analysis
- **Styler**: Automatic code formatting
- **ExUnit**: Testing framework
- **Mox**: Behavior mocking
- **StreamData**: Property-based testing

### Optional But Recommended
- **Dialyzer**: Type checking
- **ExDoc**: Documentation generation
- **Benchee**: Performance benchmarking
- **Oban**: Background job processing

### Claude Code Integration
This project uses Claude Code hooks for automation:

- **Safety net**: Prevents destructive operations
- **Quality enforcement**: Validates precommit checks
- **Context loading**: Loads project standards and learnings
- **Learning capture**: Suggests updating project knowledge

### Commands
- `/precommit`: Run full quality check suite
- `/feature <desc>`: Guided feature implementation
- `/review [file]`: Comprehensive code review
- `/spike <goal>`: Rapid prototyping mode
- `/spike-migrate`: Upgrade SPIKE code to production
- `/benchmark`: Create/run performance benchmarks
- `/pr-review <num>`: Review GitHub PR
- `/learn`: Document new patterns
- `/distributed-review`: Analyze distributed systems
- `/algorithm-research`: Research cutting-edge algorithms
- `/cognitive-audit`: Analyze cognitive complexity

## Scenarios

### Enterprise Maintenance (Large Teams)
- Strict quality gates
- Comprehensive reviews
- Expert consultation when needed
- Team knowledge in project-learnings.md

### Production Prototypes & POCs
- Balanced quality and speed
- Auto-precommit after changes
- Clear SPIKE migration paths
- Document proven patterns

### Rapid Experimentation
- SPIKE mode for fast iteration
- Minimal quality requirements
- Track technical debt
- Easy migration when patterns stabilize

## Getting Expert Help

### Distributed Systems
Use `/distributed-review` for:
- Consensus algorithm evaluation
- Clustering strategy analysis
- Detecting subtle distributed bugs
- CAP tradeoff assessment

### Cutting-Edge Algorithms
Use `/algorithm-research` for:
- Modern algorithmic approaches
- Recent research papers
- Performance vs. complexity analysis
- Library recommendations

### Cognitive Complexity
Use `/cognitive-audit` for:
- Onboarding difficulty assessment
- Code comprehension analysis
- Refactoring for clarity
- Deep module design

## Success Metrics

- **Zero precommit failures**: Code always passes quality gates
- **Comprehensive test coverage**: All business logic tested
- **Clear documentation**: New team members onboard quickly
- **Consistent patterns**: Code follows project conventions
- **Observable systems**: Production issues debuggable
- **High confidence**: Deploys without fear

## References

See AGENTS.md for detailed technical standards and patterns.

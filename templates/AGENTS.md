# Elixir Production Development Standards

## Version Management
- Use `mise` for managing Erlang/Elixir versions
- Keep versions specified in `.tool-versions`
- Never use `asdf` or other version managers in new projects

## Precommit Workflow
Before any commit, run these commands in order. All must pass:

1. **Compile with warnings as errors**: `mix compile --warnings-as-errors`
2. **Format code (includes Styler)**: `mix format`
3. **Static analysis**: `mix credo --strict`
4. **Run tests**: `mix test`

**Required Dependencies**:
```elixir
# In mix.exs deps:
{:credo, "~> 1.7", only: [:dev, :test], runtime: false}
{:styler, "~> 1.0", only: [:dev, :test], runtime: false}
```

**Required Formatter Configuration** (`.formatter.exs`):
```elixir
[
  plugins: [Styler],
  inputs: ["*.{ex,exs}", "{config,lib,test}/**/*.{ex,exs}"]
]
```

## Core Principles

### 1. Dave Thomas (PragDave) Philosophy
- **Domain-Driven Design (DDD)**: Organize code by business domain, not technical layers
- **Functional core, imperative shell**: Pure business logic inside, side effects at boundaries
- **YAGNI**: You Aren't Gonna Need It - build only what's required now
- **Simple over clever**: Prefer clarity over cleverness

### 2. Correctness Over Convenience
- **Comprehensive error modeling**: Every error case has explicit handling
- **No silent failures**: Always return `{:ok, result}` or `{:error, reason}`
- **Production-grade engineering**: Code should be ready for production from day one
- **Type safety**: Use typespecs for all public functions

### 3. Test-Driven Development (TDD)
- **Tests before implementation**: Write failing tests first
- **Explore entire result space**: Test all `{:ok, ...}` and `{:error, ...}` variants
- **Edge cases matter**: Empty, nil, zero, max values, boundaries
- **Property-based testing**: Use StreamData for input space exploration
- **Criticality scoring**: Rate tests 1-10 based on business impact

## Coding Standards

### Pattern Matching
- Use pattern matching in function heads for clarity
- Prefer pattern matching over case statements when possible
- Destructure data structures at function boundaries

```elixir
# Good
def process_user(%User{name: name, email: email}) do
  # ...
end

# Avoid
def process_user(user) do
  name = user.name
  email = user.email
  # ...
end
```

### Error Handling
- **Always use tagged tuples**: `{:ok, value}` / `{:error, reason}`
- **Railway-oriented programming**: Use `with` for sequential operations
- **Explicit error types**: Define custom error modules for domain errors

```elixir
# Good
def create_user(params) do
  with {:ok, validated} <- validate_params(params),
       {:ok, user} <- insert_user(validated),
       {:ok, _email} <- send_welcome_email(user) do
    {:ok, user}
  end
end

# Avoid
def create_user(params) do
  validated = validate_params(params)
  user = insert_user(validated)
  send_welcome_email(user)
  user
end
```

### Typespecs
- **Required for all public functions**: No exceptions
- **Use concrete types**: Avoid `term()` and `any()` unless truly necessary
- **Document complex types**: Use `@type` for domain-specific structures

```elixir
@type user_id :: pos_integer()
@type email :: String.t()
@type create_result :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}

@spec create_user(map()) :: create_result
def create_user(params) do
  # ...
end
```

### Ecto and Changesets
- **Validate at boundaries**: Use `Ecto.Changeset` for all input validation
- **Changesets are not just for databases**: Use for API validation too
- **Explicit error messages**: Custom validation errors for user-facing messages

### OTP and Processes
- **Use supervised processes**: Always start GenServers under supervision
- **"Let it crash" philosophy**: Don't defensively handle every error
- **Use `start_supervised!/1` in tests**: Ensures proper cleanup
- **Avoid `Process.sleep/1`**: Use `Process.monitor/1` for synchronization

### Phoenix and LiveView
See the `phoenix-liveview` skill for comprehensive patterns. Key rules:

- **Stream operations**: Use consistent ID formats (`"#{prefix}-#{id}"`)
- **Form handling**: Always use `to_form/2` and validate with changesets
- **Authentication scopes**: Use router scopes (`:require_authenticated_users`)
- **No `else if`**: JavaScript-style else-if doesn't exist in HEEx templates
- **Bracket notation**: Use `{...}` in attributes, not `{{...}}`

## Dependencies

### HTTP Clients
- **Use `Req`**: Modern, composable HTTP client
- **Avoid HTTPoison/Tesla**: Legacy libraries with more complexity

### Testing
- **ExUnit**: Standard test framework
- **Mox**: For mocking behaviors (define behaviors first)
- **StreamData**: For property-based testing
- **ExMachina**: For test factories (optional)

### Background Jobs
- **Oban**: Production-ready job processing
- **Configure properly**: Worker timeouts, retry logic, queues

### Static Analysis
- **Credo**: Required for all projects
- **Styler**: Automatic code style improvements (runs via formatter)
- **Dialyzer**: Optional but recommended for large codebases

## Performance and Complexity

### Complexity Analysis
- **Analyze before implementing**: Understand O(n) complexity implications
- **Anchor with real data**: "With 10,000 users, this is O(n)..." not just "O(n)"
- **Justify O(n²) or higher**: Require real-world data justification
- **Auto-benchmark**: Create Benchee benchmarks for O(n²)+ algorithms

### Optimization Guidelines
- **Profile before optimizing**: Use `:eprof`, `:fprof`, or `:observer`
- **Measure, don't guess**: Benchee for microbenchmarks
- **Identify N+1 queries**: Use `Ecto.Query` preloading
- **Consider caching**: ETS, Cachex, or external stores for hot data

### Benchee Benchmarks
```elixir
# bench/my_module_benchmark.exs
Benchee.run(%{
  "approach_a" => fn -> MyModule.approach_a(data) end,
  "approach_b" => fn -> MyModule.approach_b(data) end
},
  warmup: 2,
  time: 5,
  memory_time: 2,
  inputs: %{
    "small (100)" => generate_data(100),
    "medium (1,000)" => generate_data(1_000),
    "large (10,000)" => generate_data(10_000)
  }
)
```

Run with: `mix run bench/my_module_benchmark.exs`

## Project Structure

### Contexts (DDD)
- Organize by business domain: `Accounts`, `Products`, `Orders`
- Public API functions at context module level
- Internal implementation in context submodules
- Never cross-context database queries (use public APIs)

```
lib/
  my_app/
    accounts/               # Accounts context
      user.ex              # Schema
      user_token.ex        # Schema
    accounts.ex            # Public API
    products/              # Products context
      product.ex
      category.ex
    products.ex            # Public API
```

### Testing Structure
- Mirror lib/ structure in test/
- Use `describe` blocks for logical grouping
- Tag expensive tests: `@tag :integration`
- Async by default: `use MyApp.DataCase, async: true`

## Security

### Input Validation
- Validate all user input with `Ecto.Changeset`
- Sanitize HTML output with `Phoenix.HTML`
- Use parameterized queries (Ecto does this by default)

### Authentication & Authorization
- Use `Phoenix.Token` or JWT for tokens
- Scope routes by authentication: `:require_authenticated_users`
- Implement row-level security with Ecto policies

### Secrets Management
- Never commit secrets to version control
- Use environment variables or secret management systems
- Rotate secrets regularly in production

## Documentation

### Module Documentation
- `@moduledoc`: Explain module purpose and usage
- Include examples for complex modules
- Document public API contracts

### Function Documentation
- `@doc`: Document all public functions
- Explain parameters, return values, and side effects
- Include examples for non-obvious behavior

### Comments
- Explain "why", not "what"
- Document non-obvious decisions and tradeoffs
- Reference tickets/PRs for context

## SPIKE Mode

For rapid prototyping and experiments:

1. **Mark code**: Add `# SPIKE: <reason>` comments
2. **Track debt**: Document in `.claude/spike-debt.md`
3. **Minimal quality**: Skip typespecs, minimal tests (smoke tests only)
4. **Migration path**: Use `/spike-migrate` when patterns stabilize

## Project Knowledge

### project-learnings.md
Auto-updated by agents. Captures:
- Architecture decisions with rationale
- Domain conventions specific to this project
- Performance patterns discovered
- Common gotchas and solutions
- Testing patterns and factory usage
- Migration notes from SPIKE to production

Check this file first when starting new features.

## Hooks and Automation

This project uses Claude Code hooks for quality enforcement:
- **PreToolUse**: Safety-net blocks destructive operations
- **PostToolUse**: Validates code changes meet precommit standards
- **SessionStart**: Loads project-learnings.md and standards
- **SessionEnd**: Suggests updating project-learnings.md

## Getting Help

- **Elixir patterns**: The `elixir-patterns` skill has comprehensive examples
- **Phoenix/LiveView**: The `phoenix-liveview` skill covers common gotchas
- **Production quality**: The `production-quality` skill has detailed workflows
- **Commands**: Use `/feature`, `/review`, `/precommit`, `/benchmark`, etc.
- **Expert consultation**: Use `/distributed-review`, `/algorithm-research`, `/cognitive-audit`

## References

- Elixir official guides: https://elixir-lang.org/getting-started/introduction.html
- Phoenix guides: https://hexdocs.pm/phoenix/overview.html
- Ecto documentation: https://hexdocs.pm/ecto/Ecto.html
- LiveView guide: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html

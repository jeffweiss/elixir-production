# Production Readiness Escalation Ladder

Start at the top. Each level builds on the previous — don't skip ahead.

## Level 0: It Compiles Cleanly

The absolute minimum. Zero warnings, zero errors.

| Check | Command | What It Catches |
|-------|---------|-----------------|
| Compilation | `mix compile --warnings-as-errors` | Syntax errors, undefined functions, unused variables, type mismatches |

```elixir
# ❌ Warning: variable "context" is unused
def process(user, context), do: user.name

# ✅ Prefix unused vars with underscore
def process(user, _context), do: user.name
```

**This level means**: The code runs. Nothing more.

**Move to Level 1 when**: Code compiles. Always.

## Level 1: Consistent Formatting

Automated, zero-debate style. Run once, never think about it again.

| Check | Command | What It Does |
|-------|---------|--------------|
| Format + Styler | `mix format` | Consistent style, sorted aliases/imports, simplified pipes |

**Required** `.formatter.exs`:
```elixir
[
  plugins: [Styler],
  inputs: ["*.{ex,exs}", "{config,lib,test}/**/*.{ex,exs}"],
  line_length: 98
]
```

**This level means**: Any developer can read any file without style friction.

**Move to Level 2 when**: Code is formatted. Always.

## Level 2: Static Analysis Passes

Catch common mistakes, naming issues, and anti-patterns before tests run.

| Check | Command | What It Catches |
|-------|---------|-----------------|
| Credo strict mode | `mix credo --strict` | Naming inconsistencies, long functions, missing moduledocs, duplicated code, design anti-patterns |

| Common Credo Issue | Fix |
|-------------------|-----|
| Function too long (>40 lines) | Extract with `with` or helper functions |
| Module missing `@moduledoc` | Add module documentation or `@moduledoc false` for internal modules |
| Nested `if`/`case` | Flatten with pattern matching or `with` |
| Single-pipe `\|>` | Remove pipe, use direct function call |

**This level means**: Code follows community conventions and avoids common pitfalls.

**Move to Level 3 when**: No Credo warnings. Always.

## Level 3: Tested

Confidence that the code works — and keeps working when changed.

| Test Type | Proportion | Speed | What It Covers |
|-----------|-----------|-------|----------------|
| Unit tests | ~70% | <1ms each | Pure functions, business logic, edge cases |
| Integration tests | ~25% | <100ms each | Database operations, context functions, Mox-ed external services |
| E2E tests | ~5% | Seconds | LiveView flows, full API request/response |
| Property-based | As needed | Varies | Invariants across random input (StreamData) |

| Test Quality Check | Standard |
|-------------------|----------|
| All `{:ok, _}` paths tested | Required |
| All `{:error, _}` paths tested | Required |
| Edge cases (empty, nil, boundary values) | Required |
| Descriptive test names | `"returns error when email already exists"` not `"test email"` |
| Async when no shared state | `use MyApp.DataCase, async: true` |

**This level means**: You can refactor with confidence. Regressions are caught.

**Move to Level 4 when**: Tests cover all happy and error paths.

## Level 4: Typed

Type specifications on all public functions. Catches interface misunderstandings at boundaries.

| Standard | Example |
|----------|---------|
| `@spec` on every public function | `@spec get_user(integer()) :: {:ok, User.t()} \| {:error, :not_found}` |
| Custom `@type` for complex structures | `@type create_attrs :: %{required(:name) => String.t(), ...}` |
| Concrete types, not `any()` or `term()` | `String.t()` not `any()`, `User.t()` not `map()` |
| All error cases included in spec | Don't omit `:error` variants |
| Schema modules define `t()` type | `@type t :: %__MODULE__{name: String.t(), ...}` |

```elixir
@type create_result :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}

@spec create_user(%{required(:name) => String.t(), required(:email) => String.t()}) ::
        create_result()
def create_user(attrs) do
  %User{}
  |> User.changeset(attrs)
  |> Repo.insert()
end
```

**This level means**: Another developer can use your module without reading its implementation.

**Move to Level 5 when**: All public APIs have specs.

## Level 5: Secure

Defend against the OWASP top 10 relevant to Elixir/Phoenix. See `security.md` for full patterns.

| Threat | Defense | Elixir Mechanism |
|--------|---------|-----------------|
| SQL injection | Parameterized queries | Ecto queries with `^variable` — never string interpolation |
| XSS | Auto-escaped output | HEEx `<%= %>` escapes by default; avoid `raw/1` |
| Unvalidated input | Changeset validation at every boundary | `cast/3` → `validate_required/2` → `validate_format/3` |
| Mass assignment | Explicit field allowlists | `cast(struct, params, [:allowed, :fields])` — not `Map.merge` |
| Insecure secrets | Runtime env vars | `System.get_env("SECRET")` in `runtime.exs` — never in source |
| Missing auth checks | Router scopes + context checks | `pipe_through [:require_authenticated_user]` + per-action authorization |
| Timing attacks | Constant-time comparison | `Plug.Crypto.secure_compare/2` for tokens; Argon2/Bcrypt for passwords |

**This level means**: The app is defensible against common web attacks.

**Move to Level 6 when**: Security practices are applied consistently.

## Level 6: Observable

You can't fix what you can't see. See `observability.md` for full patterns.

| Layer | What to Measure | Elixir Tools |
|-------|----------------|--------------|
| OS/VM | Memory, CPU, scheduler utilization, GC | `:erlang.system_info/1`, `:erlang.statistics/1`, `recon` |
| Framework | Request latency, queue depths, pool utilization | `Telemetry`, `:telemetry.attach/4` |
| Application | Business metrics, context operation counts, error rates | Custom `Telemetry` events, StatsD/Prometheus |
| User | Satisfaction, error pages served, timeout rates | Application-level tracking |

**This level means**: When something goes wrong in production, you can diagnose it without adding new instrumentation.

**Move to Level 7 when**: Telemetry covers all four layers and drives actionable alerts.

## Level 7: Documented

Code explains itself. Documentation explains why. See `testing.md` for documentation standards.

| What to Document | Where | Standard |
|-----------------|-------|----------|
| Context purpose and public API | `@moduledoc` on context module | What it manages, key operations, examples |
| Function contract | `@doc` + `@spec` | What it does, return values, examples with `iex>` |
| Why a decision was made | Code comments | Link to ADR, ticket, or design doc |
| Non-obvious business rules | Code comments | Explain the *why*, not the *what* |
| Internal modules | `@moduledoc false` | Explicitly mark as internal |

**This level means**: A new developer can onboard by reading the code.

## Escalation Decision Flowchart

```
Where is the code in its lifecycle?
  Just written / SPIKE            → Level 0 (compile clean)
  Ready for precommit             → Level 1 (formatted) + Level 2 (Credo)
  Ready for tests                 → Level 3 (tested)
  Ready for team consumption      → Level 4 (typed)
  Ready for production deploy     → Level 5 (secure)
  Ready for production operations → Level 6 (observable)
  Ready for long-term maintenance → Level 7 (documented)
```

## Precommit Gate

Levels 0-3 are automated and enforced on every commit via a `mix precommit` alias:
```elixir
# mix.exs aliases
precommit: ["compile --warnings-as-errors", "deps.unlock --unused", "format", "credo --strict", "test"]
```

If the project does not have this alias, create it in `mix.exs` before running precommit checks.

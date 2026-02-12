# Pattern Escalation Ladder

Start at the top. Only reach for heavier patterns when simpler ones can't solve the problem.

## Level 0: Pure Functions and Data Transformations

No state. No processes. Just functions transforming data — this solves more problems than you think.

| Need | Pattern | Mechanism |
|------|---------|-----------|
| Transform data through steps | Pipe operator | `data \|> step1() \|> step2() \|> step3()` |
| Process a collection | Enum | `Enum.map/2`, `Enum.filter/2`, `Enum.reduce/3` |
| Branch on data shape | Pattern matching in function heads | Multiple `def` clauses with different patterns |
| Branch with conditions | Guards | `when is_binary(x)`, `when x > 0` |
| Access nested data | Access / kernel functions | `get_in/2`, `put_in/3`, `update_in/3` |
| Build up a result from a list | Reduce / comprehension | `Enum.reduce/3`, `for x <- list, do: ...` |
| Process large or infinite data lazily | Stream | `Stream.map/2`, `Stream.filter/2` (lazy, on-demand) |

```elixir
# Most business logic is just this — no GenServer needed
def calculate_order_total(order) do
  order.line_items
  |> Enum.map(&(&1.quantity * &1.unit_price))
  |> Enum.sum()
  |> apply_discount(order.discount_code)
  |> add_tax(order.tax_rate)
end
```

**Stay here when**: The function takes input and returns output with no side effects. This should be the vast majority of your code.

**Move to Level 1 when**: Operations can fail and you need to handle the failure path.

## Level 1: Error Handling and Control Flow

Make success and failure explicit. Never return bare values that might be nil.

| Need | Pattern | Mechanism |
|------|---------|-----------|
| Represent success/failure | Tagged tuples | `{:ok, value}` / `{:error, reason}` |
| Chain operations that can fail | Railway-oriented `with` | `with {:ok, a} <- step1(), {:ok, b} <- step2(a), do:` |
| Simple branching on a value | `case` | `case result do {:ok, v} -> ... ; {:error, r} -> ... end` |
| Handle different error types | `with` + `else` clause | Pattern match specific error tuples in `else` |
| Raise on truly unexpected errors | `!` functions | `Repo.get!(User, id)` — only when caller can't recover |

```elixir
# Chain fallible operations — first error short-circuits
def register_user(params) do
  with {:ok, validated} <- validate_params(params),
       {:ok, user} <- insert_user(validated),
       {:ok, _email} <- send_welcome_email(user) do
    {:ok, user}
  else
    {:error, %Ecto.Changeset{} = cs} -> {:error, {:validation, cs}}
    {:error, :email_failed} -> {:error, :email_failed}
  end
end
```

**Stay here when**: You're wiring together operations that return tagged tuples.

**Move to Level 2 when**: You're validating external input (forms, API params, CSV imports).

## Level 2: Data Validation at Boundaries

Validate and cast untrusted data at the edges of your system. Trust data inside.

| Need | Pattern | Mechanism |
|------|---------|-----------|
| Validate user/form input | Ecto.Changeset | `cast/3` → `validate_required/2` → `validate_format/3` |
| Cast types from string params | Changeset casting | `cast(struct, params, [:name, :email, :age])` |
| Database-level constraints | Changeset constraints | `unique_constraint/2`, `foreign_key_constraint/2` |
| Custom business rule validation | `validate_change/3` | Run custom function on specific field changes |
| Validate without a database | Embedded schema | `embedded_schema` + changeset — no Repo needed |
| Validate API request body | Schemaless changeset | `{%{}, types} \|> cast(params, keys) \|> validate_*` |

```elixir
# Schemaless changeset — validate API params without a database schema
types = %{email: :string, age: :integer, role: :string}

{%{}, types}
|> Ecto.Changeset.cast(params, Map.keys(types))
|> Ecto.Changeset.validate_required([:email])
|> Ecto.Changeset.validate_format(:email, ~r/@/)
|> Ecto.Changeset.validate_inclusion(:role, ["admin", "user"])
```

**Stay here when**: You're at a system boundary — user input, API params, file imports.

**Move to Level 3 when**: You need to hold mutable state across multiple calls.

## Level 3: Stateful Processes

See `otp-patterns.md` for full GenServer, Supervisor, Registry, Task patterns.

**The fundamental rule** (Jurić, "To spawn, or not to spawn?"): Use functions and modules to separate *thought concerns*. Use processes to separate *runtime concerns*. A process has a cost (memory, communication overhead, synchronization complexity). The only justification is a runtime benefit: fault isolation, parallelism, or managing state across calls.

| Need | Simplest Solution | NOT a GenServer |
|------|-------------------|-----------------|
| Read-heavy cache | ETS table with `:read_concurrency` | GenServer serializes all reads — bottleneck |
| Concurrent counters | `:atomics` or `:counters` | GenServer serializes all increments |
| App-wide config read at runtime | `:persistent_term` | Never changes or changes very rarely |
| Coordinate access to a shared resource | **GenServer** | This is when GenServer is right |
| Background processing with state | **GenServer** | State evolves based on incoming messages |

**Key question**: "Does every caller need to see the same, current state?" If yes → GenServer. If reads can be slightly stale → ETS.

**Move to Level 4 when**: Processes can crash and you need automatic recovery.

## Level 4: Fault Tolerance and Supervision

Supervisors turn "process crashed" from a catastrophe into a non-event. 131 of 132 production faults are transient (Heisenbugs) — restarting with clean state is the correct default.

| Need | Pattern | Strategy |
|------|---------|----------|
| Restart a crashed process | Supervisor | `:one_for_one` — restart only the failed child |
| Restart group when one fails | Supervisor | `:one_for_all` — all children restart together |
| Restart downstream dependencies | Supervisor | `:rest_for_one` — failed child + those started after it |
| Start processes on demand | DynamicSupervisor | `DynamicSupervisor.start_child/2` |
| Limit restart rate | Supervisor options | `max_restarts: 3, max_seconds: 5` |

**"Let it crash" means**: Handle *expected* errors with tagged tuples. Let *unexpected* errors crash the process — the supervisor restarts it with clean state.

**Move to Level 5 when**: You need many processes discovered by key, or concurrent one-off work.

## Level 5: Process Discovery and Concurrency

| Need | Pattern | Mechanism |
|------|---------|-----------|
| Find process by key | Registry | `{:via, Registry, {MyApp.Registry, key}}` |
| One process per entity | Registry + DynamicSupervisor | Supervisor starts it, Registry finds it |
| Run N things concurrently | Task.async_stream | `Task.async_stream(items, &work/1, max_concurrency: 10)` |
| Fire-and-forget concurrent work | Task.Supervisor | `Task.Supervisor.start_child(sup, fn -> ... end)` |
| Pub/Sub within application | Registry with `:duplicate` keys | `Registry.dispatch/3` to all subscribers |

**Move to Level 6 when**: You need to organize many modules into coherent domain boundaries.

## Level 6: Domain Architecture

Structure the codebase by business domain, not by technical layer. See `domain-patterns.md` for full context patterns.

| Need | Pattern | Mechanism |
|------|---------|-----------|
| Group related functionality | Phoenix Context | `Accounts`, `Orders`, `Products` — each owns its data |
| Polymorphic behavior across types | Protocol | `defprotocol` + `defimpl` per type |
| Enforce a contract for implementations | Behaviour | `@callback` + `@behaviour` |
| Cross-context communication | PubSub events | `Phoenix.PubSub.broadcast/3` — not direct function calls |

**Boundaries**: Never `import` or `alias` another context's internal modules. Never write cross-context Ecto joins. Each context owns its schemas.

## Escalation Decision Flowchart

```
What are you solving?
  Transform data with no side effects   → Level 0 (pure functions)
  Operations that can fail               → Level 1 (tagged tuples, with)
  Validating external input              → Level 2 (Ecto.Changeset)
  Need state across calls                → Level 3 (GenServer, but consider ETS first)
  Process might crash                    → Level 4 (Supervision)
  Many dynamic processes to coordinate   → Level 5 (Registry, Task, DynamicSupervisor)
  Organizing modules into domains        → Level 6 (Contexts, Protocols, Behaviours)
```

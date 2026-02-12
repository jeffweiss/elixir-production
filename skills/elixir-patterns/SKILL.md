---
name: elixir-patterns
description: Use when writing GenServer, Supervisor, Registry, or Protocol code, structuring Phoenix contexts, using pattern matching or railway-oriented programming with `with`, or needing idiomatic Elixir OTP patterns
---

# Elixir Patterns Skill

**Type:** Pattern

This skill provides comprehensive knowledge of production-ready Elixir patterns including functional programming principles, OTP design patterns, and idiomatic Elixir code structures.

## Pattern Escalation Ladder

Start at the top. Only reach for heavier patterns when simpler ones can't solve the problem.

### Level 0: Pure Functions and Data Transformations

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

### Level 1: Error Handling and Control Flow

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

### Level 2: Data Validation at Boundaries

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

### Level 3: Stateful Processes

**The fundamental rule** (Jurić, "To spawn, or not to spawn?"): Use functions and modules to separate *thought concerns*. Use processes to separate *runtime concerns*. Don't use processes — not even agents — to organize code. A process has a cost (memory, communication overhead, synchronization complexity). The only justification for that cost is a runtime benefit: fault isolation, parallelism, or managing state across calls. If activities are naturally sequential and synchronized, a single process is correct even if the domain has multiple "things."

**Separate domain logic from temporal logic**: Pure functions return *instructions* (data describing what should happen). The GenServer handles *when and how* — message delivery, timeouts, retries, persistence. This keeps domain logic testable without process infrastructure.

Reach for processes only when you genuinely need state that persists between calls.

| Need | Simplest Solution | NOT a GenServer |
|------|-------------------|-----------------|
| Read-heavy cache | ETS table with `:read_concurrency` | GenServer serializes all reads — bottleneck |
| Concurrent counters | `:atomics` or `:counters` | GenServer serializes all increments |
| App-wide config read at runtime | `:persistent_term` | Never changes or changes very rarely |
| One-time computation result | `Agent` or `Task` | GenServer is overkill for get/set |
| Coordinate access to a shared resource | **GenServer** | This is when GenServer is right |
| Background processing with state | **GenServer** | State evolves based on incoming messages |
| Rate limiting / throttling | **GenServer** | Track counts over sliding windows |

```elixir
# ETS for read-heavy cache — no process bottleneck
:ets.new(:user_cache, [:named_table, :public, read_concurrency: true])
:ets.insert(:user_cache, {user_id, user_data})
:ets.lookup(:user_cache, user_id)

# GenServer for stateful coordination — correct use
defmodule RateLimiter do
  use GenServer

  def allow?(client_id) do
    GenServer.call(__MODULE__, {:check, client_id})
  end

  @impl true
  def handle_call({:check, client_id}, _from, state) do
    {allowed, new_state} = check_and_update(client_id, state)
    {:reply, allowed, new_state}
  end
end
```

**Key question**: "Does every caller need to see the same, current state?" If yes → GenServer. If reads can be slightly stale → ETS.

**The Single Global Process anti-pattern**: A GenServer that caches database state for fast reads seems elegant but is "one of the most intricate patterns you can introduce to your system despite being one of the easiest to build" (Keathley, "The Dangers of the Single Global Process"). On multiple nodes behind a load balancer, each node spawns its own copy — creating duplicate state that diverges silently. Inconsistent data bugs produce no crashes or stack traces; they surface only when examining business metrics. During netsplits, nodes cannot tell whether peers failed or disconnected, compounding the problem. **Default to the database for consistency.** Only use GenServer-as-cache when you've explicitly addressed multi-node consistency (via CRDTs, consistent hashing, or accepting eventual consistency).

**Move to Level 4 when**: Processes can crash and you need automatic recovery.

### Level 4: Fault Tolerance and Supervision

Supervisors turn "process crashed" from a catastrophe into a non-event. 131 of 132 production faults are transient (Heisenbugs) — restarting with clean state is the correct default response.

| Need | Pattern | Strategy |
|------|---------|----------|
| Restart a crashed process | Supervisor | `:one_for_one` — restart only the failed child |
| Restart group when one fails | Supervisor | `:one_for_all` — all children restart together |
| Restart downstream dependencies | Supervisor | `:rest_for_one` — failed child + those started after it |
| Start processes on demand | DynamicSupervisor | `DynamicSupervisor.start_child/2` |
| Limit restart rate | Supervisor options | `max_restarts: 3, max_seconds: 5` |

```elixir
# Application supervision tree — order matters
children = [
  MyApp.Repo,                          # Database first
  {Phoenix.PubSub, name: MyApp.PubSub}, # PubSub before consumers
  {MyApp.Cache, []},                    # Cache before web
  {DynamicSupervisor, name: MyApp.WorkerSupervisor, strategy: :one_for_one},
  MyAppWeb.Endpoint                     # Web last
]

Supervisor.start_link(children, strategy: :one_for_one)
```

**"Let it crash" means**: Handle *expected* errors (user input, network timeouts) with tagged tuples. Let *unexpected* errors (corrupted state, bugs) crash the process — the supervisor restarts it with clean state.

**Callers determine failure tolerance**: The process encountering an error should expose it — the *caller* decides what to do (retry, queue, ignore, alert). Don't hide failures inside a module; return them as tagged tuples and let the calling context determine the appropriate response based on its own requirements.

```elixir
# ✅ Expose the failure — let the caller decide
def fetch_profile(user_id) do
  case HTTPClient.get("/profiles/#{user_id}") do
    {:ok, %{status: 200, body: body}} -> {:ok, decode(body)}
    {:ok, %{status: status}} -> {:error, {:http_status, status}}
    {:error, reason} -> {:error, {:connection, reason}}
  end
end

# Caller A: Critical path — fail loudly
{:ok, profile} = fetch_profile(user_id)

# Caller B: Best-effort — degrade gracefully
profile = case fetch_profile(user_id) do
  {:ok, p} -> p
  {:error, _} -> %{name: "Unknown", avatar: default_avatar()}
end
```

**Init guarantees**: What `init/1` guarantees determines fault tolerance:
- **Local dependencies** (ETS, file on disk): Guarantee in `init/1` or fail — if the process can't work without it, crash immediately
- **Remote dependencies** (database, external API): Degrade gracefully — start the process, connect asynchronously, serve degraded responses until connected

```elixir
# Local dep — guarantee or fail
def init(_opts) do
  table = :ets.new(:cache, [:named_table, :public, read_concurrency: true])
  {:ok, %{table: table}}  # If ETS fails, process crashes — correct
end

# Remote dep — degrade gracefully
def init(opts) do
  send(self(), :connect)  # Connect async after init
  {:ok, %{conn: nil, status: :connecting, retry_count: 0}}
end

def handle_info(:connect, state) do
  case try_connect(state) do
    {:ok, conn} -> {:noreply, %{state | conn: conn, status: :connected}}
    {:error, _} ->
      Process.send_after(self(), :connect, backoff(state.retry_count))
      {:noreply, %{state | retry_count: state.retry_count + 1}}
  end
end
```

**Whiteboard exercise for choosing supervision strategy**: Draw the process tree on a whiteboard. For each process, ask: "If this process dies, should its siblings die too?" If yes → `:one_for_all`. If only downstream → `:rest_for_one`. If independent → `:one_for_one`. The answer determines the strategy.

**Move to Level 5 when**: You need many processes discovered by key, or concurrent one-off work.

### Level 5: Process Discovery and Concurrency

Coordinate dynamic sets of processes.

| Need | Pattern | Mechanism |
|------|---------|-----------|
| Find process by key | Registry | `{:via, Registry, {MyApp.Registry, key}}` |
| One process per entity (user, room, game) | Registry + DynamicSupervisor | Supervisor starts it, Registry finds it |
| Run N things concurrently and collect results | Task.async_stream | `Task.async_stream(items, &work/1, max_concurrency: 10)` |
| Fire-and-forget concurrent work | Task.Supervisor | `Task.Supervisor.start_child(sup, fn -> ... end)` |
| Pub/Sub within the application | Registry with `:duplicate` keys | `Registry.dispatch/3` to all subscribers |

```elixir
# One process per user session, discoverable by user_id
defmodule SessionWorker do
  use GenServer

  def start_link(user_id) do
    GenServer.start_link(__MODULE__, user_id,
      name: {:via, Registry, {MyApp.SessionRegistry, user_id}})
  end
end

# Start on demand
DynamicSupervisor.start_child(MyApp.SessionSupervisor, {SessionWorker, user_id})

# Find later
GenServer.call({:via, Registry, {MyApp.SessionRegistry, user_id}}, :get_state)
```

**Move to Level 6 when**: You need to organize many modules into coherent domain boundaries.

### Level 6: Domain Architecture

Structure the codebase by business domain, not by technical layer.

| Need | Pattern | Mechanism |
|------|---------|-----------|
| Group related functionality | Phoenix Context | `Accounts`, `Orders`, `Products` — each owns its data |
| Polymorphic behavior across types | Protocol | `defprotocol` + `defimpl` per type |
| Enforce a contract for implementations | Behaviour | `@callback` + `@behaviour` |
| Cross-context communication | PubSub events | `Phoenix.PubSub.broadcast/3` — not direct function calls |
| Anti-corruption layer for external APIs | Wrapper context | Translate external data to internal domain structs |

```elixir
# Context is the public API — one module, clear boundary
defmodule MyApp.Accounts do
  def register_user(attrs)            # Public
  def authenticate(email, password)   # Public
  def get_user!(id)                   # Public

  # Everything below is internal
  defp hash_password(password), do: ...
  defp send_confirmation(user), do: ...
end

# Cross-context: Orders needs user data? Call through the public API
def create_order(user_id, items) do
  user = Accounts.get_user!(user_id)  # Public API, not direct Repo query
  ...
end
```

**Boundaries**: Never `import` or `alias` another context's internal modules. Never write cross-context Ecto joins. Each context owns its schemas.

### Escalation Decision Flowchart

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

## Core Patterns

### 1. Pattern Matching

Pattern matching is Elixir's fundamental control flow mechanism.

#### Function Head Pattern Matching

```elixir
# Match on data structure shape
def process_result({:ok, value}), do: {:success, value}
def process_result({:error, reason}), do: {:failure, reason}

# Match and destructure
def greet(%User{name: name, admin: true}), do: "Hello Admin #{name}"
def greet(%User{name: name}), do: "Hello #{name}"

# Match with guards
def calculate(x) when x > 0, do: x * 2
def calculate(x) when x <= 0, do: 0
```

**When to use**:
- Multiple code paths based on input shape
- Extracting values from complex structures
- Validating input at function boundary

**Avoid**:
```elixir
# Don't extract then check
def process_result(result) do
  case result do
    {:ok, value} -> {:success, value}
    {:error, reason} -> {:failure, reason}
  end
end
```

### 2. Railway-Oriented Programming

Chain operations that can fail using `with` for explicit error handling.

```elixir
def create_user(params) do
  with {:ok, validated} <- validate_params(params),
       {:ok, user} <- insert_user(validated),
       {:ok, _token} <- generate_token(user),
       {:ok, _email} <- send_welcome_email(user) do
    {:ok, user}
  else
    {:error, changeset = %Ecto.Changeset{}} ->
      {:error, {:validation, changeset}}

    {:error, :email_failed} = error ->
      # User created but email failed - different handling
      error

    error ->
      error
  end
end
```

**Key benefits**:
- **Explicit error handling**: Each step can fail independently
- **Early returns**: First error short-circuits the chain
- **Composable**: Easy to add/remove steps
- **Readable**: Vertical flow matches execution order

**When to use**:
- Sequential operations where each depends on previous success
- Multiple potential failure points
- Need different handling for different error types

**Avoid for**:
- Simple branching logic (use `case`)
- When you need side effects regardless of success/failure
- Single operation (just use `case` or pattern matching)

### 3. Tagged Tuples

Explicit return values for success and failure cases.

```elixir
# Standard return types
@type result :: {:ok, value} | {:error, reason}

# Success with value
{:ok, user} = Accounts.get_user(id)

# Failure with reason
{:error, :not_found} = Accounts.get_user(999)

# Multiple error types
@spec create_user(map()) ::
  {:ok, User.t()}
  | {:error, :validation_failed, Ecto.Changeset.t()}
  | {:error, :email_exists}
  | {:error, :service_unavailable}

def create_user(params) do
  with {:ok, changeset} <- validate(params),
       false <- email_exists?(changeset.changes.email),
       {:ok, user} <- insert(changeset) do
    {:ok, user}
  else
    true -> {:error, :email_exists}
    {:error, changeset} -> {:error, :validation_failed, changeset}
    {:error, :db_error} -> {:error, :service_unavailable}
  end
end
```

**Guidelines**:
- First element is `:ok` or `:error` (tagged)
- Second element is the value or reason
- Use atoms for error types (`:not_found`, `:unauthorized`)
- Complex errors can include additional context

**Never**:
```elixir
# Don't return bare values or raise for control flow
def get_user(id) do
  user  # What if nil?
end

# Don't use exceptions for expected failures
def get_user(id) do
  user = Repo.get!(User, id)  # Raises if not found
  user
end
```

### 4. Immutable Data Transformations

Data is immutable. Create new versions instead of modifying.

```elixir
# Transforming data with pipe operator
user
|> Map.put(:name, "New Name")
|> Map.put(:updated_at, DateTime.utc_now())
|> Map.update!(:login_count, &(&1 + 1))

# Updating nested structures
user = %User{
  name: "Alice",
  profile: %Profile{bio: "Hello"}
}

# Update nested immutably
updated_user = put_in(user.profile.bio, "Updated bio")

# Or with update_in
updated_user = update_in(user.profile.bio, &String.upcase/1)

# Lists - transformation not mutation
list = [1, 2, 3]
new_list = [0 | list]  # Prepend (O(1))
mapped = Enum.map(list, &(&1 * 2))
```

**Key patterns**:
- **Pipe operator** (`|>`): Chain transformations
- **Enum module**: map, filter, reduce for lists
- **Map module**: put, update, delete for maps
- **Access behavior**: get_in, put_in, update_in for nested

**Performance**:
- List prepend is O(1), append is O(n)
- Map operations are O(log n)
- Avoid modifying large lists repeatedly (use Enum.reduce)

### 5. Ecto.Changeset for Validation

Changesets validate and transform data at boundaries.

```elixir
defmodule MyApp.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :name, :string
    field :email, :string
    field :age, :integer
    timestamps()
  end

  @required_fields [:name, :email]
  @optional_fields [:age]

  def changeset(user, attrs) do
    user
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_format(:email, ~r/@/)
    |> validate_number(:age, greater_than: 0, less_than: 150)
    |> unique_constraint(:email)
  end
end

# Usage
def create_user(attrs) do
  %User{}
  |> User.changeset(attrs)
  |> Repo.insert()
end
```

**Key patterns**:
- **cast/3**: Filter and cast input data
- **validate_***: Built-in validations
- **custom validation**: Add with `validate_change/3`
- **constraints**: Database-level validation with *_constraint

**Use changesets for**:
- Form input validation
- API parameter validation
- Business rule validation
- Transforming external data

### 6. OTP: GenServer Pattern

GenServers provide stateful processes.

```elixir
defmodule MyApp.Cache do
  use GenServer

  # Client API
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get(key) do
    GenServer.call(__MODULE__, {:get, key})
  end

  def put(key, value) do
    GenServer.cast(__MODULE__, {:put, key, value})
  end

  # Server Callbacks
  @impl true
  def init(_opts) do
    {:ok, %{}}  # Initial state
  end

  @impl true
  def handle_call({:get, key}, _from, state) do
    {:reply, Map.get(state, key), state}
  end

  @impl true
  def handle_cast({:put, key, value}, state) do
    {:noreply, Map.put(state, key, value)}
  end
end
```

**Key concepts**:
- **Synchronous** (`call`): Wait for response, blocks caller
- **Asynchronous** (`cast`): Fire and forget, doesn't block
- **State**: Maintained between calls
- **Process mailbox**: Messages queued and processed sequentially

**When to use GenServer**:
- Need to maintain state
- Coordinating access to shared resource
- Background processing with state
- Rate limiting or throttling

**Avoid for**:
- Stateless operations (use plain modules)
- Simple caching (use ETS)
- Pure computation (use functions)

### 7. Supervision Trees

Supervisors monitor and restart child processes.

```elixir
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    children = [
      # Database connection pool
      MyApp.Repo,

      # PubSub for real-time features
      {Phoenix.PubSub, name: MyApp.PubSub},

      # GenServer with specific restart
      {MyApp.Cache, []},

      # Supervisor for dynamic workers
      {DynamicSupervisor, name: MyApp.WorkerSupervisor, strategy: :one_for_one},

      # Web endpoint
      MyAppWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

**Supervision strategies**:
- `:one_for_one`: Restart only failed child
- `:one_for_all`: Restart all children if one fails
- `:rest_for_one`: Restart failed child and those started after it

**"Let it crash" philosophy**:
- Don't defensively handle every error
- Let process crash for unexpected errors
- Supervisor restarts with clean state
- Focus on expected error cases only

### 8. Registry for Process Discovery

Registry provides process name registration.

```elixir
# Start registry
Registry.start_link(keys: :unique, name: MyApp.Registry)

# Register process
{:ok, pid} = MyWorker.start_link(user_id: 123)
Registry.register(MyApp.Registry, "user:123", pid)

# Find process
case Registry.lookup(MyApp.Registry, "user:123") do
  [{pid, _}] -> send(pid, :hello)
  [] -> {:error, :not_found}
end

# Use with via tuple in GenServer
defmodule MyWorker do
  use GenServer

  def start_link(user_id: user_id) do
    GenServer.start_link(__MODULE__, user_id, name: via_tuple(user_id))
  end

  defp via_tuple(user_id) do
    {:via, Registry, {MyApp.Registry, "user:#{user_id}"}}
  end
end
```

**Use Registry for**:
- Dynamic process pools
- User-specific processes (websocket connections)
- Pub/Sub within application
- Process discovery by key

### 9. Protocols for Polymorphism

Protocols enable polymorphic behavior.

```elixir
defprotocol Serializable do
  @doc "Serialize data to JSON-compatible format"
  def serialize(data)
end

defimpl Serializable, for: User do
  def serialize(%User{name: name, email: email}) do
    %{name: name, email: email}
  end
end

defimpl Serializable, for: Product do
  def serialize(%Product{id: id, name: name, price: price}) do
    %{id: id, name: name, price: Decimal.to_float(price)}
  end
end

# Usage - works for any type implementing Serializable
Serializable.serialize(%User{name: "Alice", email: "alice@example.com"})
Serializable.serialize(%Product{id: 1, name: "Widget", price: Decimal.new("19.99")})
```

### 10. Task for Concurrent Operations

Tasks provide simple concurrency.

```elixir
# Async/await for concurrent operations
tasks = [
  Task.async(fn -> fetch_user(user_id) end),
  Task.async(fn -> fetch_orders(user_id) end),
  Task.async(fn -> fetch_reviews(user_id) end)
]

results = Task.await_many(tasks, 5000)

# Task.Supervisor for fault tolerance
{:ok, result} = Task.Supervisor.start_child(MyApp.TaskSupervisor, fn ->
  expensive_operation()
end)
```

**Beyond async/await** (Jurić, "Beyond Task.Async"): `Task.await_many/2` processes results in submission order. If the first task is slowest, all others wait. For latency-sensitive fan-out, use `Task.yield_many/2` to process results as they arrive, and `Process.send_after/3` for a global timeout across all tasks.

### 11. Overload Management

When a system receives more work than it can handle, there are only two sustainable responses: **back-pressure** (slow the caller down) and **load-shedding** (drop work). Queues without bounds don't fix overload — they hide it until the system runs out of memory.

| Strategy | When | Mechanism |
|----------|------|-----------|
| Back-pressure | Caller can wait | Bounded mailboxes, `GenServer.call` timeouts, pool checkout limits |
| Load-shedding | Freshness matters more than completeness | Drop oldest messages, reject requests, sample |
| Circuit breaker | Remote dependency is failing | Trip open after N failures, half-open to test recovery |
| Bounded queue | Buffer small bursts | Fixed-size queue; reject or drop when full |

```elixir
# Back-pressure with GenServer.call timeout — caller slows down naturally
def submit_work(item) do
  GenServer.call(__MODULE__, {:submit, item}, 5_000)
end

# Load-shedding with ETS atomic counter
def allow_request?(client_id) do
  count = :ets.update_counter(:rate_limits, client_id, {2, 1}, {client_id, 0})
  count <= @max_requests_per_window
end

# Circuit breaker with :fuse library
:fuse.install(:external_api, {{:standard, 5, 10_000}, {:reset, 60_000}})

case :fuse.ask(:external_api, :sync) do
  :ok -> call_external_api(params)
  :blown -> {:error, :circuit_open}
end
```

**Key principle**: Every queue must be bounded. Unbounded queues are a latent memory leak triggered by any traffic spike. Measure **sojourn time** (how long items wait in queue) — if it grows, you're overloaded regardless of queue depth.

**Design for cold restart under load**: Systems must handle starting up when traffic is already flowing — not just warm, steady-state operation. If your application starts with empty caches and all connections initializing simultaneously, the thundering herd will overwhelm dependencies. Stagger connection establishment, use circuit breakers from the start, and serve degraded responses until warm.

**Make operations idempotent**: In production, messages get retried, requests get duplicated, and jobs get re-enqueued. Design operations so that executing them twice produces the same result as executing them once. Use unique request IDs, `ON CONFLICT` clauses, and idempotency keys.

```elixir
# Idempotent insert — safe to retry
def create_payment(attrs) do
  %Payment{}
  |> Payment.changeset(attrs)
  |> Repo.insert(
    on_conflict: :nothing,
    conflict_target: [:idempotency_key]
  )
end
```

**Adaptive concurrency** (Keathley, "Using Regulator"): Static concurrency limits guess wrong — too low wastes capacity, too high causes overload. Adaptive concurrency observes latency and error rates, then adjusts limits dynamically using Little's Law (L = λ × W). Use AIMD (Additive Increase, Multiplicative Decrease) for outbound calls with timeout set to maximum expected latency. **Autoscaling does not solve overload** — it often makes it worse by increasing downstream pressure, especially on databases.

**Libraries**: `fuse` (circuit breakers), `poolboy` (bounded worker pools), `sbroker` (sojourn-time-based broker), `regulator` (adaptive concurrency limits).

## Domain-Driven Design Patterns

### Contexts

Organize code by business domain, not technical layers.

```
lib/
  my_app/
    accounts/        # Accounts context
      user.ex
      user_token.ex
      user_notifier.ex
    accounts.ex      # Public API

    products/        # Products context
      product.ex
      category.ex
    products.ex      # Public API
```

**Context public API**:
```elixir
defmodule MyApp.Accounts do
  # Public API - business operations
  def register_user(attrs)
  def authenticate_user(email, password)
  def get_user!(id)
  def update_user(user, attrs)

  # Internal - don't expose
  defp hash_password(password)
  defp send_confirmation_email(user)
end
```

**Context boundaries**:
- Never cross-context database queries
- Use public APIs for cross-context calls
- Each context owns its data

## Code Quality Patterns

Idiomatic Elixir patterns that prevent common bugs (Keathley, "Good and Bad Elixir"):

**Use Access protocol over Map.get**: `opts[:foo]` works with both maps and keyword lists. `Map.get(opts, :foo)` locks you to maps — changing the data structure breaks all call sites.

**Only return error tuples when callers can act on them**: If nothing actionable exists, raise instead of returning `{:error, reason}`. Forcing callers to handle unrecoverable errors adds noise without safety.

```elixir
# ❌ Caller can't do anything useful with this error
def get_config!(key) do
  case Application.fetch_env(:my_app, key) do
    {:ok, value} -> {:ok, value}
    :error -> {:error, :missing_config}  # What can caller do? Nothing.
  end
end

# ✅ Raise for truly unrecoverable situations
def get_config!(key) do
  Application.fetch_env!(:my_app, key)
end
```

**Guard what IS, not what ISN'T**: Check `is_binary(req)` instead of `not is_nil(req)`. Positive guards catch more bugs — `not is_nil` accepts atoms, integers, lists, and everything else that isn't nil.

**Expose single-entity operations for composability**: Wrapping `Enum.map` around a function hides reuse opportunities. Exposing the single-item operation lets callers compose with `Enum`, `Stream`, `Task.async_stream`, or `Flow`.

## Additional References

For deeper dive into specific patterns, see:
- `${CLAUDE_PLUGIN_ROOT}/skills/elixir-patterns/references/contexts.md` - Context design patterns
- `${CLAUDE_PLUGIN_ROOT}/skills/elixir-patterns/references/processes.md` - OTP and process patterns
- `${CLAUDE_PLUGIN_ROOT}/skills/elixir-patterns/references/changesets.md` - Advanced changeset patterns

## When to Apply These Patterns

**Small projects (<10k LOC)**:
- Focus on tagged tuples and pattern matching
- Simple supervision trees
- Basic contexts

**Medium projects (10-50k LOC)**:
- Add GenServers for state management
- Use Registry for dynamic processes
- Implement protocols for polymorphism
- Well-defined context boundaries

**Large projects (>50k LOC)**:
- Comprehensive supervision strategies
- Complex OTP patterns (GenStateMachine, :gen_statem)
- Umbrella applications for separation
- Consider distributed systems patterns (see distributed-systems skill)

## BEAM-Specific Nuances

**Body vs tail recursion**: Tail recursion is not always faster for list-building. Body recursion builds the list naturally in order; tail recursion requires a final `Enum.reverse/1`. For small-to-medium lists, body recursion can outperform tail + reverse. Use `Enum` functions as the default — they're optimized. Only hand-roll recursion when profiling shows a bottleneck.

**Process dictionary**: Legitimate only for metadata that doesn't affect business logic — tracing context, profiling counters, logger metadata. Never use it for application state. It creates hidden global state that breaks referential transparency and makes testing unpredictable.

```elixir
# ✅ Legitimate: Logger metadata (doesn't affect logic)
Logger.metadata(request_id: conn.assigns.request_id)

# ❌ Never: Application state in process dictionary
Process.put(:current_user, user)  # Hidden global state
```

**Monotonic vs system time**: Use `System.monotonic_time/1` for measuring durations and elapsed time. Use `DateTime.utc_now/0` for timestamps displayed to humans. Never use wall-clock time for durations — NTP adjustments, VM migration, and leap seconds can make it jump backward or forward.

```elixir
# ✅ Monotonic for durations — immune to clock adjustments
start = System.monotonic_time(:millisecond)
result = do_work()
duration_ms = System.monotonic_time(:millisecond) - start

# ❌ Wall clock for durations — can produce negative values
start = DateTime.utc_now()
result = do_work()
duration = DateTime.diff(DateTime.utc_now(), start, :millisecond)  # Can be wrong
```

**Binary coalescence**: Never concatenate binaries in a loop (`<<buf/binary, data/binary>>`). Each concatenation copies both sides into a new, larger binary. As the accumulator grows, it crosses allocation thresholds — from fast multiblock carriers to slow single-block carriers — causing up to 20x slowdowns. Instead, collect chunks in a list and combine once with `IO.iodata_to_binary/1`.

```elixir
# ❌ Repeated concatenation — quadratic allocation, triggers slow allocator path
def collect_bad(socket, buf \\ <<>>) do
  case recv(socket) do
    {:ok, data} -> collect_bad(socket, <<buf/binary, data/binary>>)
    :done -> buf
  end
end

# ✅ Collect as iodata list, combine once at the end
def collect_good(socket, chunks \\ []) do
  case recv(socket) do
    {:ok, data} -> collect_good(socket, [chunks, data])
    :done -> IO.iodata_to_binary(chunks)
  end
end
```

**Money and precision**: Never use floats for monetary values. Use `Decimal` (or integer cents). Floating-point rounding errors accumulate silently — `0.1 + 0.2 != 0.3` in IEEE 754.

```elixir
# ✅ Decimal for money
field :price, :decimal
Decimal.add(Decimal.new("19.99"), Decimal.new("5.01"))  # => Decimal.new("25.00")

# ❌ Float for money — silent rounding errors
price = 19.99 + 5.01  # => 25.0 (happens to work, but won't always)
```

## Success Metrics

Code using these patterns should have:
- Clear error handling (no silent failures)
- Predictable behavior (no hidden state)
- Easy to test (pure functions, injectable dependencies)
- Self-documenting (pattern matching shows intent)
- Fault-tolerant (supervision trees handle failures)

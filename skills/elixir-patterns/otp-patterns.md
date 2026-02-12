# OTP Patterns

## GenServer

GenServers provide stateful processes with synchronous and asynchronous message handling.

```elixir
defmodule MyApp.Cache do
  use GenServer

  # Client API
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get(key), do: GenServer.call(__MODULE__, {:get, key})
  def put(key, value), do: GenServer.cast(__MODULE__, {:put, key, value})

  # Server Callbacks
  @impl true
  def init(_opts), do: {:ok, %{}}

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

**Separate domain logic from temporal logic**: Pure functions return *instructions* (data describing what should happen). The GenServer handles *when and how* — message delivery, timeouts, retries, persistence. This keeps domain logic testable without process infrastructure.

### The Single Global Process Anti-Pattern

A GenServer that caches database state for fast reads seems elegant but is "one of the most intricate patterns you can introduce to your system despite being one of the easiest to build" (Keathley, "The Dangers of the Single Global Process"). On multiple nodes behind a load balancer, each node spawns its own copy — creating duplicate state that diverges silently. During netsplits, nodes cannot tell whether peers failed or disconnected.

**Default to the database for consistency.** Only use GenServer-as-cache when you've explicitly addressed multi-node consistency (via CRDTs, consistent hashing, or accepting eventual consistency).

### Init Guarantees

What `init/1` guarantees determines fault tolerance:
- **Local dependencies** (ETS, file on disk): Guarantee in `init/1` or fail — crash immediately
- **Remote dependencies** (database, external API): Degrade gracefully — start the process, connect asynchronously

```elixir
# Local dep — guarantee or fail
def init(_opts) do
  table = :ets.new(:cache, [:named_table, :public, read_concurrency: true])
  {:ok, %{table: table}}
end

# Remote dep — degrade gracefully
def init(opts) do
  send(self(), :connect)
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

## Supervision Trees

Supervisors monitor and restart child processes.

```elixir
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    children = [
      MyApp.Repo,                           # Database first
      {Phoenix.PubSub, name: MyApp.PubSub}, # PubSub before consumers
      {MyApp.Cache, []},                    # Cache before web
      {DynamicSupervisor, name: MyApp.WorkerSupervisor, strategy: :one_for_one},
      MyAppWeb.Endpoint                     # Web last
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

**Whiteboard exercise**: Draw the process tree. For each process, ask: "If this process dies, should its siblings die too?" If yes → `:one_for_all`. If only downstream → `:rest_for_one`. If independent → `:one_for_one`.

**Callers determine failure tolerance**: The process encountering an error should expose it — the *caller* decides what to do (retry, queue, ignore, alert). Don't hide failures inside a module; return them as tagged tuples.

```elixir
# ✅ Expose the failure — let the caller decide
def fetch_profile(user_id) do
  case HTTPClient.get("/profiles/#{user_id}") do
    {:ok, %{status: 200, body: body}} -> {:ok, decode(body)}
    {:ok, %{status: status}} -> {:error, {:http_status, status}}
    {:error, reason} -> {:error, {:connection, reason}}
  end
end
```

## Registry

Registry provides process name registration and discovery.

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

## Task

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
Task.Supervisor.start_child(MyApp.TaskSupervisor, fn ->
  expensive_operation()
end)
```

**Beyond async/await** (Jurić, "Beyond Task.Async"): `Task.await_many/2` processes results in submission order. If the first task is slowest, all others wait. For latency-sensitive fan-out, use `Task.yield_many/2` to process results as they arrive, and `Process.send_after/3` for a global timeout across all tasks.

## Protocols

Protocols enable polymorphic behavior dispatched on data type.

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
```

## BEAM-Specific Nuances

**Body vs tail recursion**: Tail recursion is not always faster for list-building. Body recursion builds the list naturally in order; tail recursion requires a final `Enum.reverse/1`. Use `Enum` functions as the default — they're optimized.

**Process dictionary**: Legitimate only for metadata that doesn't affect business logic — tracing context, logger metadata. Never use it for application state.

```elixir
# ✅ Legitimate: Logger metadata
Logger.metadata(request_id: conn.assigns.request_id)

# ❌ Never: Application state
Process.put(:current_user, user)
```

### Process Dictionary for Request-Scoped Context

The process dictionary is pragmatic for values that would otherwise need threading through every function signature in a call chain. Logger metadata already uses this pattern. Appropriate for:

- **Deadline propagation**: Set a request deadline at the boundary, check it deep in the call stack without passing it through every intermediate function. Library: `deadline` (elixir-toniq).
- **Trace IDs / telemetry span context**: OpenTelemetry stores span context in the process dictionary.
- **Request-scoped metadata**: Audit user ID, tenant ID for multi-tenant systems.

```elixir
# deadline — propagate timeout budget through the call stack
# Set at the boundary (plug, consumer, GenServer call handler)
Deadline.set(timeout_ms)

# Check deep in the call stack — no need to pass through intermediaries
if Deadline.expired?() do
  {:error, :deadline_exceeded}
else
  do_expensive_work()
end
```

**Trade-off**: The process dictionary is mutable global state within a process. It bypasses explicit data flow, making code harder to reason about in isolation. **Rule**: only use for request-scoped cross-cutting concerns that would otherwise pollute every function signature in the call chain. Never for business logic state.

**Monotonic vs system time**: Use `System.monotonic_time/1` for measuring durations. Use `DateTime.utc_now/0` for timestamps displayed to humans. Never use wall-clock time for durations.

**Binary coalescence**: Never concatenate binaries in a loop. Collect chunks in a list and combine once with `IO.iodata_to_binary/1`.

```elixir
# ❌ Repeated concatenation — quadratic allocation
def collect_bad(socket, buf \\ <<>>) do
  case recv(socket) do
    {:ok, data} -> collect_bad(socket, <<buf/binary, data/binary>>)
    :done -> buf
  end
end

# ✅ Collect as iodata list, combine once
def collect_good(socket, chunks \\ []) do
  case recv(socket) do
    {:ok, data} -> collect_good(socket, [chunks, data])
    :done -> IO.iodata_to_binary(chunks)
  end
end
```

**Money and precision**: Never use floats for monetary values. Use `Decimal` (or integer cents).

```elixir
# ✅ Decimal for money
field :price, :decimal
Decimal.add(Decimal.new("19.99"), Decimal.new("5.01"))

# ❌ Float for money — silent rounding errors
price = 19.99 + 5.01
```

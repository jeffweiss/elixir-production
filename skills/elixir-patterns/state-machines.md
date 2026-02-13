# State Machines: :gen_statem and Alternatives

## Decision: GenServer or :gen_statem?

```
Does your process have distinct named states with different behavior in each?
  NO  → GenServer (simpler, covers most cases)
  YES → Do state transitions follow strict rules (A → B → C, never A → C)?
          NO  → GenServer with a :state field in its state map
          YES → :gen_statem
                Need timeouts per state (e.g., idle for 30s → auto-cancel)?
                  YES → :gen_statem (built-in state timeouts)
                Need to postpone events until a later state?
                  YES → :gen_statem (built-in postpone)
                Simple enough for a case statement?
                  YES → GenServer with explicit transitions is fine too
```

**Rule of thumb**: If you find yourself writing a GenServer with a large `case state.status do` in every callback, you want `:gen_statem`.

## Quick Comparison

| Feature | GenServer | :gen_statem | Pattern matching on status field |
|---------|-----------|------------|--------------------------------|
| Named states | No (manual) | Yes (first-class) | Manual |
| State-specific timeouts | Manual (`Process.send_after`) | Built-in (`:state_timeout`) | Manual |
| Postpone events | Not supported | Built-in | Not supported |
| State enter callbacks | Not supported | Built-in (`:enter` calls) | Manual |
| Complexity | Low | Medium | Low |
| Elixir docs/community familiarity | High | Low | High |
| Best for | General stateful processes | Processes with lifecycle/protocol states | Simple state tracking |

## :gen_statem Basics

### Callback Modes

`:gen_statem` has two callback modes. Use `state_functions` for clarity:

**`:state_functions`** — one function per state (clearer, recommended):

```elixir
defmodule MyApp.Order do
  @behaviour :gen_statem

  # States: :pending → :confirmed → :shipped → :delivered
  #                  ↘ :cancelled

  def callback_mode, do: [:state_functions, :state_enter]

  def start_link(order_id) do
    :gen_statem.start_link(__MODULE__, order_id, [])
  end

  def init(order_id) do
    {:ok, :pending, %{order_id: order_id, items: []}}
  end

  # --- State: pending ---

  def pending(:enter, _old_state, data) do
    # Called when entering :pending state
    {:keep_state, data, [{:state_timeout, :timer.minutes(30), :auto_cancel}]}
  end

  def pending({:call, from}, :confirm, data) do
    {:next_state, :confirmed, data, [{:reply, from, :ok}]}
  end

  def pending({:call, from}, :cancel, data) do
    {:next_state, :cancelled, data, [{:reply, from, :ok}]}
  end

  def pending(:state_timeout, :auto_cancel, data) do
    # 30 minutes with no confirmation → auto-cancel
    {:next_state, :cancelled, data}
  end

  # --- State: confirmed ---

  def confirmed(:enter, :pending, data) do
    # Only valid transition: pending → confirmed
    Logger.info("Order #{data.order_id} confirmed")
    {:keep_state, data}
  end

  def confirmed({:call, from}, :ship, data) do
    {:next_state, :shipped, data, [{:reply, from, :ok}]}
  end

  def confirmed({:call, from}, :cancel, data) do
    {:next_state, :cancelled, data, [{:reply, from, :ok}]}
  end

  # --- State: shipped ---

  def shipped(:enter, :confirmed, data) do
    {:keep_state, data, [{:state_timeout, :timer.hours(72), :delivery_check}]}
  end

  def shipped({:call, from}, :deliver, data) do
    {:next_state, :delivered, data, [{:reply, from, :ok}]}
  end

  def shipped(:state_timeout, :delivery_check, data) do
    Logger.warning("Order #{data.order_id} shipped 72h ago, not delivered")
    {:keep_state, data}
  end

  # --- State: delivered ---

  def delivered(:enter, :shipped, data) do
    Logger.info("Order #{data.order_id} delivered")
    {:keep_state, data}
  end

  # --- State: cancelled ---

  def cancelled(:enter, _old_state, data) do
    Logger.info("Order #{data.order_id} cancelled")
    {:keep_state, data}
  end
end
```

### Client API

```elixir
# Synchronous calls
{:ok, pid} = MyApp.Order.start_link("order-123")
:ok = :gen_statem.call(pid, :confirm)
:ok = :gen_statem.call(pid, :ship)
:ok = :gen_statem.call(pid, :deliver)

# Async casts
:gen_statem.cast(pid, :some_event)
```

## Key Features

### State Timeouts

Timeout that's automatically cancelled when the state changes — no manual timer management:

```elixir
def pending(:enter, _old, data) do
  # This timeout is automatically cancelled if we leave :pending
  {:keep_state, data, [{:state_timeout, 30_000, :expired}]}
end

def pending(:state_timeout, :expired, data) do
  {:next_state, :cancelled, data}
end

def pending({:call, from}, :confirm, data) do
  # Moving to :confirmed automatically cancels the :pending timeout
  {:next_state, :confirmed, data, [{:reply, from, :ok}]}
end
```

With GenServer, you'd need `Process.send_after` + manual cancellation with `Process.cancel_timer` — error-prone and verbose.

### Postpone

Defer an event until the state changes — the event is re-delivered in the new state:

```elixir
def connecting(:cast, {:send_data, _payload} = event, data) do
  # Can't send data while connecting — postpone until connected
  {:keep_state, data, [:postpone]}
end

def connected(:cast, {:send_data, payload}, data) do
  # Postponed events from :connecting are now delivered here
  do_send(payload)
  {:keep_state, data}
end
```

Without postpone, you'd need to buffer events manually in GenServer state and replay them on state transition.

### State Enter Callbacks

Run code when entering a state — regardless of which transition led there:

```elixir
def callback_mode, do: [:state_functions, :state_enter]

def cancelled(:enter, _old_state, data) do
  # Runs whether cancelled from :pending, :confirmed, or :shipped
  notify_customer(data.order_id, :cancelled)
  release_inventory(data.items)
  {:keep_state, data}
end
```

## When to Use :gen_statem

**Good fit:**
- Order/payment lifecycles (pending → confirmed → shipped → delivered)
- Connection management (connecting → authenticating → connected → disconnecting)
- Protocol implementations (handshake → ready → streaming → closed)
- Approval workflows (draft → submitted → reviewing → approved/rejected)
- Game state (lobby → playing → paused → game_over)

**Not needed:**
- Simple key-value state (use GenServer)
- Process that just holds data and responds to queries (use GenServer or ETS)
- Event handling without distinct lifecycle states (use GenServer)
- Pub/sub or event broadcasting (use Registry or Phoenix.PubSub)

## :gen_event — Don't Use

`:gen_event` is an older OTP behaviour for event handling. It has known issues:

- Event handlers run in the manager process — one slow handler blocks all others
- No back-pressure — events can pile up
- Error handling is awkward — handler crashes are silently swallowed by default
- The Elixir core team recommends against it

**Use instead:**
- **Registry** — for local pub/sub and process discovery
- **Phoenix.PubSub** — for distributed pub/sub
- **GenServer + Telemetry** — for event emission and handling
- **Broadway** — for event stream processing with back-pressure

```elixir
# ❌ :gen_event — avoid
{:ok, manager} = :gen_event.start_link()
:gen_event.add_handler(manager, MyHandler, [])
:gen_event.notify(manager, {:event, data})

# ✅ Registry — local pub/sub
Registry.register(MyApp.EventRegistry, :order_events, [])
Registry.dispatch(MyApp.EventRegistry, :order_events, fn entries ->
  for {pid, _value} <- entries, do: send(pid, {:order_event, data})
end)

# ✅ Telemetry — for metrics and instrumentation
:telemetry.execute([:my_app, :order, :created], %{duration: dur}, %{order_id: id})
```

## Testing :gen_statem

```elixir
test "order lifecycle: pending → confirmed → shipped → delivered" do
  {:ok, pid} = MyApp.Order.start_link("test-order")

  assert :sys.get_state(pid) |> elem(0) == :pending

  :ok = :gen_statem.call(pid, :confirm)
  assert :sys.get_state(pid) |> elem(0) == :confirmed

  :ok = :gen_statem.call(pid, :ship)
  assert :sys.get_state(pid) |> elem(0) == :shipped

  :ok = :gen_statem.call(pid, :deliver)
  assert :sys.get_state(pid) |> elem(0) == :delivered
end

test "pending order auto-cancels after timeout" do
  {:ok, pid} = MyApp.Order.start_link("test-order")

  # Manually trigger the state timeout
  send(pid, {:"$gen_event", {:timeout, :state_timeout, :auto_cancel}})

  # Allow time for processing
  Process.sleep(10)
  assert :sys.get_state(pid) |> elem(0) == :cancelled
end

test "invalid transition is rejected" do
  {:ok, pid} = MyApp.Order.start_link("test-order")

  # Can't ship a pending order
  catch_exit do
    :gen_statem.call(pid, :ship)
  end
end
```

## Common Mistakes

- **Using :gen_statem for simple state**: If your process doesn't have distinct behavioral modes, GenServer with a status field is simpler and more familiar to the team.
- **`:handle_event_function` callback mode for beginners**: The `state_functions` mode is clearer — one function per state. Use `handle_event_function` only when states are dynamic or numerous.
- **Forgetting `:state_enter` in callback mode**: State enter callbacks only fire if you include `:state_enter` in the callback mode list: `[:state_functions, :state_enter]`.
- **Not handling unexpected events**: In `state_functions` mode, an event with no matching clause crashes the process. Add a catch-all clause per state or a `handle_event` fallback.
- **Using :gen_event**: It's superseded. Use Registry, Phoenix.PubSub, or Telemetry for event handling.
- **Wrapping :gen_statem in unnecessary abstraction**: Some libraries wrap `:gen_statem` in Elixir-friendly APIs. Often the raw `:gen_statem` behaviour is clear enough — evaluate whether the wrapper adds value or just indirection.

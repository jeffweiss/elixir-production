# Distributed Transactions

When an operation spans multiple services, contexts, or databases and must either fully succeed or fully compensate.

## Decision Table

```
Operation spans multiple bounded contexts or services?
  NO  → Use Ecto.Multi (single database transaction)
  YES → Can you restructure to avoid distribution?
          YES → Restructure (simplest, always preferred)
          NO  → Failure modes acceptable?
                  Partial completion OK with eventual cleanup → Saga (choreography)
                  Need coordinated rollback → Saga (orchestration)
                  Need ACID across databases → 2PC (avoid if possible)
```

| Pattern | Coordination | Consistency | Complexity | Use When |
|---------|-------------|-------------|-----------|----------|
| Ecto.Multi | Single DB transaction | ACID | Low | All operations in one database |
| Saga (choreography) | Events between services | Eventual | Medium | Loosely coupled services, async OK |
| Saga (orchestration) | Central coordinator | Eventual | Medium | Complex workflows, need visibility |
| Oban workflow | Oban Pro orchestrates jobs | Eventual + durable | Medium | Multi-step background processing |
| 2PC | Distributed lock | Strong | High | Almost never in Elixir — avoid |

## Ecto.Multi — Single Database

When all operations touch one database, use `Ecto.Multi` — it's a single ACID transaction, not a distributed transaction:

```elixir
Ecto.Multi.new()
|> Ecto.Multi.insert(:order, Order.changeset(%Order{}, order_attrs))
|> Ecto.Multi.update(:inventory, fn %{order: order} ->
  Inventory.decrement_changeset(order.product_id, order.quantity)
end)
|> Ecto.Multi.insert(:payment, fn %{order: order} ->
  Payment.changeset(%Payment{}, %{order_id: order.id, amount: order.total})
end)
|> Repo.transaction()
```

If any step fails, everything rolls back. This is always preferred when possible.

## Saga Pattern

When operations span services or databases that can't share a transaction, use the Saga pattern: a sequence of local transactions where each step has a compensating action.

### Choreography (Event-Driven)

Each service listens for events and acts independently. No central coordinator.

```elixir
# Service A: Create order, publish event
def create_order(attrs) do
  with {:ok, order} <- Repo.insert(Order.changeset(%Order{}, attrs)) do
    Phoenix.PubSub.broadcast(MyApp.PubSub, "orders", {:order_created, order})
    {:ok, order}
  end
end

# Service B: Reserve inventory on order_created
def handle_info({:order_created, order}, state) do
  case Inventory.reserve(order.product_id, order.quantity) do
    {:ok, _} ->
      Phoenix.PubSub.broadcast(MyApp.PubSub, "orders", {:inventory_reserved, order.id})
    {:error, :out_of_stock} ->
      Phoenix.PubSub.broadcast(MyApp.PubSub, "orders", {:inventory_failed, order.id})
  end
  {:noreply, state}
end

# Service A: Compensate on inventory failure
def handle_info({:inventory_failed, order_id}, state) do
  Orders.cancel(order_id)  # Compensating action
  {:noreply, state}
end
```

**Pros**: Loosely coupled, each service is independent.
**Cons**: Hard to track overall progress, compensation chains can be complex to debug.

### Orchestration (Central Coordinator)

A coordinator manages the saga steps. Clearer flow, easier to monitor.

```elixir
defmodule MyApp.OrderSaga do
  use GenServer

  defstruct [:order_id, :step, :compensations]

  def execute(order_attrs) do
    GenServer.start_link(__MODULE__, order_attrs)
  end

  def init(attrs) do
    saga = %__MODULE__{step: :create_order, compensations: []}
    {:ok, saga, {:continue, {:execute, attrs}}}
  end

  def handle_continue({:execute, attrs}, saga) do
    result =
      with {:ok, order, saga} <- step_create_order(attrs, saga),
           {:ok, _reservation, saga} <- step_reserve_inventory(order, saga),
           {:ok, _payment, saga} <- step_charge_payment(order, saga) do
        {:ok, order, saga}
      end

    case result do
      {:ok, order, _saga} ->
        {:stop, :normal, order}
      {:error, reason, saga} ->
        compensate(saga)
        {:stop, {:error, reason}, saga}
    end
  end

  defp step_create_order(attrs, saga) do
    case Orders.create(attrs) do
      {:ok, order} ->
        saga = %{saga | compensations: [{:cancel_order, order.id} | saga.compensations]}
        {:ok, order, saga}
      {:error, reason} ->
        {:error, reason, saga}
    end
  end

  defp step_reserve_inventory(order, saga) do
    case Inventory.reserve(order.product_id, order.quantity) do
      {:ok, reservation} ->
        saga = %{saga | compensations: [{:release_inventory, reservation.id} | saga.compensations]}
        {:ok, reservation, saga}
      {:error, reason} ->
        {:error, reason, saga}
    end
  end

  defp step_charge_payment(order, saga) do
    case Payments.charge(order) do
      {:ok, payment} ->
        saga = %{saga | compensations: [{:refund_payment, payment.id} | saga.compensations]}
        {:ok, payment, saga}
      {:error, reason} ->
        {:error, reason, saga}
    end
  end

  defp compensate(saga) do
    Enum.each(saga.compensations, fn
      {:cancel_order, id} -> Orders.cancel(id)
      {:release_inventory, id} -> Inventory.release(id)
      {:refund_payment, id} -> Payments.refund(id)
    end)
  end
end
```

### Oban Workflows (Durable Sagas)

For sagas that must survive crashes and deploys, use Oban Pro workflows:

```elixir
# Each step is an Oban worker — durable, retryable, observable
Oban.Workflow.new()
|> Oban.Workflow.add(:create_order, CreateOrderWorker.new(%{attrs: attrs}))
|> Oban.Workflow.add(:reserve_inventory, ReserveInventoryWorker.new(%{}),
  deps: [:create_order])
|> Oban.Workflow.add(:charge_payment, ChargePaymentWorker.new(%{}),
  deps: [:reserve_inventory])
|> Oban.insert_all()
```

Each worker reads the result of its dependencies and can trigger compensation workers on failure. The workflow state is persisted in the database — it survives crashes, deploys, and node failures.

## Compensating Transactions

Every saga step needs a compensating action. Design compensations as **semantic undo**, not database rollback:

| Step | Compensation | Notes |
|------|-------------|-------|
| Create order | Cancel order (set status: cancelled) | Don't delete — keep audit trail |
| Reserve inventory | Release reservation | Must be idempotent |
| Charge payment | Refund payment | External API — may need retry |
| Send notification | Send correction notification | Can't unsend email |
| Grant access | Revoke access | Must handle already-used access |

### Compensation Rules

1. **Every step must have a compensation** — even if it's "log and alert"
2. **Compensations must be idempotent** — they may run more than once
3. **Compensations run in reverse order** — last successful step compensated first
4. **Some actions can't be undone** — sending an email, charging a card (refund != undo). Design for this.

## Why Not 2PC

Two-Phase Commit (prepare → commit/rollback across all participants) provides ACID guarantees across databases but:

- **Blocks on coordinator failure** — all participants hold locks waiting for a coordinator that may never respond
- **Not supported by most Elixir databases** — Ecto doesn't have 2PC support
- **Latency** — synchronous coordination across network adds significant latency
- **Availability** — any participant failure blocks the entire transaction

Use Sagas instead. Accept eventual consistency and design idempotent compensations.

## Common Mistakes

- **Not designing compensations upfront**: Every saga step needs a compensation. If you can't define one, the step can't be in a saga.
- **Non-idempotent compensations**: Compensations may run multiple times (retries, crash recovery). They must produce the same result regardless.
- **Ignoring partial failure visibility**: Without a coordinator or workflow engine, it's hard to know which saga steps completed. Use Oban workflows or an explicit state machine for observability.
- **Using GenServer saga without persistence**: The saga state is lost on crash. For durable sagas, use Oban workflows or persist state to the database.
- **Trying to make everything transactional**: If you can restructure to keep operations in a single database transaction (Ecto.Multi), do that instead of building a saga.

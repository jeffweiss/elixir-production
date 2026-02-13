# Event Sourcing and CQRS

## Decision Table

```
Do you need a full audit trail of every state change?
  NO  → Standard CRUD with Ecto (simpler, use this by default)
  YES → Is replay/recomputation of state from events valuable?
          NO  → Audit log table alongside CRUD (append-only log, not event sourcing)
          YES → Event sourcing
                Read and write patterns very different?
                  YES → CQRS (separate read/write models)
                  NO  → Event sourcing without CQRS
```

**Default to CRUD.** Event sourcing adds significant complexity. Use it when the audit trail and replay capability provide concrete business value — not as a default architecture.

## Core Concepts

### Event Sourcing

Instead of storing current state, store the sequence of events that led to it. Current state is derived by replaying events.

```
Traditional CRUD:
  Account { balance: 150 }  ← only current state

Event Sourced:
  1. AccountOpened { balance: 0 }
  2. MoneyDeposited { amount: 200 }
  3. MoneyWithdrawn { amount: 50 }
  → Current state: balance = 150 (computed from events)
```

**Benefits**: Complete audit trail, temporal queries ("what was the balance last Tuesday?"), replay for debugging, ability to build new projections retroactively.

**Costs**: Complexity of event schemas, eventual consistency between write and read models, event versioning as schemas evolve.

### CQRS (Command Query Responsibility Segregation)

Separate the write model (commands → events) from the read model (projections optimized for queries). Often paired with event sourcing but not required.

```
Command side:                     Query side:
  User sends command        →     Events stored in event store
  Command handler validates       Event handlers build projections
  Events emitted                  Projections optimized for reads
                                  (denormalized, pre-computed)
```

## Elixir Libraries

| Library | Maturity | Approach |
|---------|----------|---------|
| Commanded | Stable | Full CQRS/ES framework with aggregates, process managers, projections |
| EventStore | Stable | Event store backed by PostgreSQL (used by Commanded) |
| Incident | Lighter | Simpler event sourcing without full CQRS framework |

## Commanded Pattern

```elixir
# Define aggregate
defmodule MyApp.Accounts.BankAccount do
  defstruct [:account_id, :balance]

  # Command handling
  def execute(%__MODULE__{account_id: nil}, %OpenAccount{} = cmd) do
    %AccountOpened{account_id: cmd.account_id, initial_balance: cmd.initial_balance}
  end

  def execute(%__MODULE__{}, %DepositMoney{amount: amount}) when amount > 0 do
    %MoneyDeposited{amount: amount}
  end

  def execute(%__MODULE__{balance: balance}, %WithdrawMoney{amount: amount})
      when amount > 0 and balance >= amount do
    %MoneyWithdrawn{amount: amount}
  end

  def execute(%__MODULE__{balance: balance}, %WithdrawMoney{amount: amount})
      when amount > balance do
    {:error, :insufficient_funds}
  end

  # State mutation from events
  def apply(%__MODULE__{} = account, %AccountOpened{} = event) do
    %{account | account_id: event.account_id, balance: event.initial_balance}
  end

  def apply(%__MODULE__{} = account, %MoneyDeposited{amount: amount}) do
    %{account | balance: account.balance + amount}
  end

  def apply(%__MODULE__{} = account, %MoneyWithdrawn{amount: amount}) do
    %{account | balance: account.balance - amount}
  end
end
```

### Projections (Read Models)

```elixir
defmodule MyApp.Accounts.AccountBalanceProjector do
  use Commanded.Projections.Ecto,
    application: MyApp.App,
    repo: MyApp.Repo,
    name: "account_balance_projector"

  project(%AccountOpened{} = event, _metadata, fn multi ->
    Ecto.Multi.insert(multi, :account, %AccountBalance{
      account_id: event.account_id,
      balance: event.initial_balance
    })
  end)

  project(%MoneyDeposited{} = event, metadata, fn multi ->
    Ecto.Multi.update_all(multi, :account,
      from(a in AccountBalance, where: a.account_id == ^metadata.aggregate_id),
      inc: [balance: event.amount]
    )
  end)
end
```

## When to Use Event Sourcing

**Good fit:**
- Financial systems (regulatory requirement for audit trail)
- Collaborative editing (need to merge concurrent changes)
- Systems where "undo" or temporal queries are core features
- Complex domain workflows where process managers coordinate multiple aggregates

**Poor fit:**
- Simple CRUD applications (overwhelming complexity for no benefit)
- Systems where current state is all that matters
- High-throughput, low-latency systems (event replay adds latency)
- Small teams without ES experience (learning curve is steep)

## Lightweight Alternative: Audit Log

If you need an audit trail but not full event sourcing, append events alongside CRUD:

```elixir
def transfer_money(from_id, to_id, amount) do
  Ecto.Multi.new()
  |> Ecto.Multi.update(:debit, debit_changeset(from_id, amount))
  |> Ecto.Multi.update(:credit, credit_changeset(to_id, amount))
  |> Ecto.Multi.insert(:event, %AuditEvent{
    type: "money_transferred",
    data: %{from: from_id, to: to_id, amount: amount},
    occurred_at: DateTime.utc_now()
  })
  |> Repo.transaction()
end
```

This gives you an immutable audit trail without the complexity of rebuilding state from events.

## Common Mistakes

- **Using event sourcing for simple CRUD**: If you don't need audit trails, replay, or temporal queries, event sourcing is unnecessary complexity.
- **Mutable events**: Events are immutable facts. Never update or delete events. If an event was wrong, emit a compensating event.
- **Not versioning events**: Event schemas evolve. Use explicit versioning (e.g., `AccountOpened.v2`) and upcasters to handle old event formats.
- **Synchronous projections blocking writes**: Projections should be async. The write side emits events; projections consume them eventually. Accept that read models may lag.
- **Giant aggregates**: Aggregates with thousands of events are slow to rehydrate. Use snapshots (periodic state checkpoints) for long-lived aggregates.
- **CQRS without event sourcing**: CQRS (separate read/write models) can be used without event sourcing. Don't assume you need both.

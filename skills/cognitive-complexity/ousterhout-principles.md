# Ousterhout's Principles

From John Ousterhout's "A Philosophy of Software Design" — principles for reducing cognitive complexity through better abstractions.

## 1. Complexity is Incremental

Complexity doesn't come from single bad decisions, but from accumulation of many small decisions. Each "just this once" special case, each quick fix adds a small amount. Over time, these accumulate into systems that are hard to understand.

```elixir
# Each special case adds complexity
def calculate_discount(user) do
  cond do
    user.type == :admin -> 100
    user.type == :premium -> 20
    user.trial_expired? -> 0
    user.referral_count > 10 -> 15
    true -> 10
  end
end

# Use polymorphism to eliminate special cases
defprotocol DiscountPolicy do
  def calculate_discount(user)
end
# Adding new types doesn't increase complexity
```

## 2. Complexity Can Only Be Relocated

Complexity cannot be eliminated — only moved. Every "simplification" pushes complexity somewhere else: to the caller, to configuration, to documentation. The question is never "how do I remove this complexity?" but "where should this complexity live?"

**Write code that's easy to delete, not easy to maintain**: Code that's easy to delete has clear boundaries, minimal dependents, and doesn't entangle with unrelated systems. When requirements change, you can rip it out cleanly.

```elixir
# Easy to delete — self-contained context
defmodule MyApp.Promotions do
  # If promotions feature is cut, delete this directory.
  # No other context reaches into our schemas or queries.
end

# Hard to delete — cross-context coupling
defmodule MyApp.Orders do
  def create_order(params) do
    promo = Repo.get_by(MyApp.Promotions.PromoCode, code: params.promo_code)
    # Now Orders can't exist without Promotions schema
  end
end
```

## 3. Deep Modules

Best modules have **simple interfaces** but **powerful implementations**.

```
Module Depth = Implementation Power / Interface Complexity
```

```elixir
# Shallow module - complex interface, minimal power
defmodule ShallowCache do
  def put(cache, key, value, ttl, on_expire, compression_level, serializer) do
    # Just wraps a simple map operation!
  end
end

# Deep module - simple interface, powerful implementation
defmodule DeepCache do
  def put(cache, key, value) do
    # Handles internally: TTL, expiration cleanup, compression,
    # serialization, memory management, thread safety
  end
end
```

**Red flags** (shallow modules): Many parameters required, caller must read implementation, just delegates to other functions, exposes internal data structures.

## 4. Information Leakage

When implementation details escape through the abstraction boundary, changes to implementation affect all callers.

**Implicit decisions are hidden global state**: Every undocumented convention is a piece of global state living in team members' heads.

**Types of leakage**:

**Temporal coupling** — Must call functions in specific order:
```elixir
# Leakage — caller must know order
start_database()  # Must be first
load_config()     # Must be second

# No leakage — order hidden
with {:ok, db} <- start_database(),
     {:ok, config} <- load_config(db), do: {:ok, :started}
```

**Pass-through variables** — Same variable through many layers:
```elixir
# Leakage — config passed through 5 layers unchanged
def handle_request(conn, config), do: process_request(conn, config)
def process_request(conn, config), do: validate_request(conn, config)

# Better — get config where needed
def check_rate_limit(conn) do
  config = Application.get_env(:my_app, :rate_limit)
end
```

**Exposed data structures** — Internal representation visible:
```elixir
# Leakage — returns ETS table reference
def get_cache, do: :ets.whereis(:my_cache)

# No leakage — hide ETS behind module API
def get(key) do
  case :ets.lookup(:my_cache, key) do
    [{^key, value}] -> {:ok, value}
    [] -> {:error, :not_found}
  end
end
```

## 5. Pull Complexity Downward

It's better to add complexity to an implementation to simplify the interface than to push complexity to all callers.

```elixir
# Pushing complexity up (bad)
def get_user(id) do
  Repo.get(User, id)  # Returns nil or user
  # Caller must: check nil, verify active, verify verified, preload
end

# Pulling complexity down (good)
def get_active_user(id) do
  case Repo.get(User, id) do
    nil -> {:error, :not_found}
    user ->
      cond do
        !user.active -> {:error, :inactive}
        !user.verified_at -> {:error, :not_verified}
        true -> user |> Repo.preload([:profile, :settings]) |> wrap_ok()
      end
  end
end
```

## 6. Strategic vs Tactical Programming

**Tactical**: "Just get it working" — copy-paste, special cases, quick fixes, short-term thinking.

**Strategic**: "Make it right" — create abstractions, handle cases systematically, long-term thinking.

**Lehman's Laws**: Programs must undergo continual change or become progressively less useful. Without deliberate effort, systems accumulate cruft until replacement becomes cheaper than maintenance.

**Technical debt is not like financial debt**: Financial debt has known repayment terms. Technical shortcuts compound immediately and unpredictably — each makes the next change harder.

**When to invest strategically**: Feature will be extended, similar patterns appearing, code maintained long-term, team is growing.

**When tactical is okay**: Prototyping (mark `# SPIKE`), one-off scripts, time-critical fixes (refactor later).

## 7. Define Errors Out of Existence

Best error handling is preventing errors through better design.

```elixir
# Make invalid states unrepresentable
defmodule User do
  schema "users" do
    field :email_status, Ecto.Enum,
      values: [:unverified, :verified]
    # Either unverified or verified — invalid state impossible
  end
end
```

## 8. Comments Should Explain "Why"

Code shows **what** it does. Comments should explain **why** it does it that way.

```elixir
# Bad — repeats code
# Get user by ID
def get_user(id), do: Repo.get(User, id)

# Good — explains why
# Eager loading prevents N+1 queries.
# Dashboard displays profile and last 10 orders (measured: 500ms → 50ms)
def get_user_for_dashboard(id) do
  User
  |> where(id: ^id)
  |> preload([:profile, orders: from(o in Order, order_by: [desc: o.inserted_at], limit: 10)])
  |> Repo.one()
end
```

## Cognitive Interface Design (Rasmussen SRK)

Design interfaces to serve three cognitive levels:

| Level | Operator Mode | Information Type | Design Implication |
|-------|--------------|------------------|--------------------|
| **Skill-based** | Automatic, pattern recognition | Signals (spatial, colors) | Sparklines, color-coded status |
| **Rule-based** | If-then procedures | Signs (indicators) | Map to runbook steps |
| **Knowledge-based** | Novel problem-solving | Symbols (raw data) | Query tools, correlation views |

Most dashboards only serve knowledge level. Experienced operators need spatial patterns they can absorb peripherally.

## What to Avoid

**Clean Code Dogma**:
- Arbitrary function length rules ("5 lines max") — Ousterhout: function length is fine if it has clear abstraction
- Excessive fragmentation — tiny functions for every 3-line block increases shallow modules
- Class/module extraction for single use — adds complexity without benefit
- Rules over understanding — understand principles, apply contextually

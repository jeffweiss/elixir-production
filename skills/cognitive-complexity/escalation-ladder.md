# Complexity Reduction Escalation Ladder

Start at the top. Only move down when the current level doesn't resolve the confusion.

## Level 0: Name It Better

The cheapest fix. Most "confusing" code is just poorly named.

| Smell | Fix | Example |
|-------|-----|---------|
| Generic function name | Name describes what it returns or does | `process` → `calculate_shipping_cost` |
| Generic variable name | Name describes the domain concept | `data` → `pending_orders` |
| Boolean parameter | Replace with named function or atoms | `fetch(id, true)` → `fetch_with_preload(id)` |
| Inconsistent vocabulary | Pick one verb per operation across the codebase | `get_user`, `fetch_order`, `load_product` → all `get_*` |
| Abbreviation or acronym | Spell it out unless universally known | `calc_inv_amt` → `calculate_invoice_amount` |

```elixir
# Before — requires reading implementation to understand
def run(u, opts) do
  d = process(u.data, opts[:m])
  handle(d, opts[:t])
end

# After — reads like a sentence
def generate_invoice(user, opts) do
  line_items = calculate_line_items(user.cart, opts[:discount_method])
  apply_tax_rules(line_items, opts[:tax_region])
end
```

**Move to Level 1 when**: Names are clear but the function is still hard to follow.

## Level 1: Reduce Working Memory Load

A reader can hold ~4 things in working memory at once. Reduce what they need to track.

| Smell | Fix | Threshold |
|-------|-----|-----------|
| Too many parameters | Group into struct or keyword opts | >4 params |
| Variable defined far from use | Move definition closer or extract function | >15 lines apart |
| Deep nesting (if inside case inside with) | Extract inner logic to named function | >3 levels |
| Long function with multiple concerns | Split at the natural seams | >40 lines with topic changes |
| Multiple return shapes | Standardize on tagged tuples | Mixed `nil`, `{:ok, _}`, `{:error, _}` |

```elixir
# Before — 6 params, reader tracks all simultaneously
def create_order(user_id, items, payment_method, shipping_addr, discount_code, gift_wrap) do
  ...
end

# After — 2 concepts instead of 6
def create_order(user_id, %OrderParams{} = params) do
  ...
end
```

**Move to Level 2 when**: Individual functions are clear but callers are confused about how to use the module.

## Level 2: Deepen the Module Interface

Callers shouldn't need to read your implementation. Simplify the public API and hide the work.

| Smell | Fix | Ousterhout Principle |
|-------|-----|---------------------|
| Caller duplicates checks before calling you | Pull the checks into your function | Pull complexity downward |
| Caller must call functions in specific order | Chain internally with `with` | Eliminate temporal coupling |
| Many public functions that are always called together | Combine into one that does the right thing | Deepen the module |
| Caller handles your internal error types | Return domain-meaningful errors | Information hiding |
| Pass-through variables across many layers | Access config/state where needed | Reduce information leakage |

```elixir
# Shallow — caller must know the ritual
user = Accounts.get_user(id)
if user && user.active && user.email_verified do
  orders = Orders.list_for_user(user)
  Orders.preload_items(orders)
end

# Deep — one call, all complexity inside
{:ok, orders} = Orders.list_active_user_orders(user_id)
```

**Move to Level 3 when**: Individual modules are well-designed but branching keeps growing.

## Level 3: Eliminate Special Cases

Every `cond` branch, every pattern-matched clause on user type, every "if admin then..." is a special case the reader must track.

| Smell | Fix | Elixir Mechanism |
|-------|-----|-----------------|
| `cond`/`case` on entity type growing | Polymorphism | `defprotocol` + `defimpl` per type |
| Same branching logic duplicated | Strategy pattern | Protocol or behaviour |
| Default values scattered | Centralize defaults | Struct with `@enforce_keys` |
| Error conditions that "can't happen" | Define errors out of existence | Types that make invalid states unrepresentable |

```elixir
# Before — every new user type adds a branch everywhere
def notify(user) do
  case user.type do
    :admin -> send_admin_email(user)
    :premium -> send_premium_email(user)
    :trial when user.days_left < 7 -> send_trial_ending_email(user)
    _ -> send_standard_email(user)
  end
end

# After — new types add an implementation, not a branch
defprotocol Notifiable do
  def notify(user)
end
```

**Move to Level 4 when**: Code is clean at the module level but the overall architecture is hard to onboard onto.

## Level 4: Architectural Clarity

The structure of the codebase should match the structure of the domain.

| Smell | Fix | Elixir Pattern |
|-------|-----|---------------|
| File you need is hard to find | Organize by domain, not by layer | Phoenix contexts |
| Changing one feature touches 8 files | Colocate related code | Context owns schemas, queries, logic |
| Circular dependencies | Clarify boundaries, use events | `Phoenix.PubSub` |
| Unclear what's public vs internal | Explicit public module | Context module is API; internal modules `@moduledoc false` |

**Move to Level 5 when**: Architecture is sound but code has accumulated tactical debt across many files.

## Level 5: Strategic Refactoring

| Approach | When | How to Scope |
|----------|------|-------------|
| Extract deep module | Same checks repeated at 3+ call sites | One module at a time |
| Replace branching with protocol | `case` extended 3+ times | One protocol, migrate callers incrementally |
| Split bloated context | >500 lines or mixes unrelated concerns | Extract with backward-compatible delegates |
| Consolidate inconsistent patterns | Same thing done 3 different ways | Pick best, migrate one usage per PR |
| Delete dead code | Code exists "just in case" | Use `mix xref` to find unreferenced modules |

## Decision Flowchart

```
Code is confusing. Why?
  Names are unclear          → Level 0 (rename)
  Too much to track at once  → Level 1 (reduce working memory)
  Module is hard to use      → Level 2 (deepen the interface)
  Branching keeps growing    → Level 3 (eliminate special cases)
  Can't find things          → Level 4 (architectural clarity)
  Accumulated debt           → Level 5 (strategic refactoring)
```

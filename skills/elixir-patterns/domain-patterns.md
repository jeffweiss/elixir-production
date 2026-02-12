# Domain Patterns

## Phoenix Contexts

Structure the codebase by business domain, not by technical layer.

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

**Boundaries**: Never cross-context database queries. Use public APIs for cross-context calls. Each context owns its data.

See `references/contexts.md` for full context design patterns including boundaries, dependencies, anti-patterns, and testing.

## Code Quality Patterns

Idiomatic Elixir patterns that prevent common bugs (Keathley, "Good and Bad Elixir"):

**Use Access protocol over Map.get**: `opts[:foo]` works with both maps and keyword lists. `Map.get(opts, :foo)` locks you to maps — changing the data structure breaks all call sites.

**Only return error tuples when callers can act on them**: If nothing actionable exists, raise instead of returning `{:error, reason}`.

```elixir
# ❌ Caller can't do anything useful with this error
def get_config!(key) do
  case Application.fetch_env(:my_app, key) do
    {:ok, value} -> {:ok, value}
    :error -> {:error, :missing_config}
  end
end

# ✅ Raise for truly unrecoverable situations
def get_config!(key) do
  Application.fetch_env!(:my_app, key)
end
```

**Guard what IS, not what ISN'T**: Check `is_binary(req)` instead of `not is_nil(req)`. Positive guards catch more bugs — `not is_nil` accepts atoms, integers, lists, and everything else that isn't nil.

**Expose single-entity operations for composability**: Wrapping `Enum.map` around a function hides reuse opportunities. Exposing the single-item operation lets callers compose with `Enum`, `Stream`, `Task.async_stream`, or `Flow`.

## Pattern Matching

Pattern matching is Elixir's fundamental control flow mechanism.

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

**When to use**: Multiple code paths based on input shape, extracting values from complex structures, validating input at function boundary.

## Tagged Tuples

Explicit return values for success and failure cases.

```elixir
@type result :: {:ok, value} | {:error, reason}

# Multiple error types
@spec create_user(map()) ::
  {:ok, User.t()}
  | {:error, :validation_failed, Ecto.Changeset.t()}
  | {:error, :email_exists}
  | {:error, :service_unavailable}
```

**Guidelines**:
- First element is `:ok` or `:error` (tagged)
- Use atoms for error types (`:not_found`, `:unauthorized`)
- Complex errors can include additional context
- Never return bare values or raise for control flow

## Immutable Data Transformations

```elixir
# Pipe operator chains
user
|> Map.put(:name, "New Name")
|> Map.put(:updated_at, DateTime.utc_now())
|> Map.update!(:login_count, &(&1 + 1))

# Nested updates
updated_user = put_in(user.profile.bio, "Updated bio")
updated_user = update_in(user.profile.bio, &String.upcase/1)
```

**Performance**: List prepend is O(1), append is O(n). Map operations are O(log n). Avoid modifying large lists repeatedly (use `Enum.reduce`).

## Ecto.Changeset

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
```

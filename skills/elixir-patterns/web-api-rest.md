# REST APIs with Phoenix

Phoenix controllers should be thin adapters between HTTP and your context layer. Parse params, call one context function, pattern-match the result, render. If a controller action exceeds ~10 lines, business logic is leaking out of the context.

## Overview

Controllers in Phoenix are the HTTP boundary of your application:

```elixir
def create(conn, params) do
  # 1. Parse/validate params
  # 2. Call context function
  # 3. Pattern-match result
  # 4. Render response
end
```

**Core Principles:**
- Controllers orchestrate, contexts execute
- One context call per action (occasionally two for complex flows)
- No Ecto queries in controllers
- No business rules in controllers
- Use `action_fallback` for consistent error handling

## Fat Controllers — The #1 REST Anti-Pattern

Fat controllers contain business logic, Ecto queries, and conditional branching. This makes code untestable, unportable, and couples HTTP concerns to domain logic.

### ❌ Bad: Logic in Controller

```elixir
def create(conn, %{"order" => order_params}) do
  user = conn.assigns.current_user

  # Business logic leak: discount calculation
  discount = if user.premium?, do: 0.1, else: 0.0

  # Ecto query leak
  items = Repo.all(from i in Item, where: i.id in ^order_params["item_ids"])

  total = Enum.reduce(items, 0, fn item, acc ->
    acc + (item.price * (1 - discount))
  end)

  # More business logic: inventory check
  if Enum.all?(items, & &1.stock > 0) do
    order = %Order{
      user_id: user.id,
      total: total,
      items: items
    } |> Repo.insert!()

    # Side effect: send email
    OrderMailer.confirmation(order) |> Mailer.deliver_later()

    render(conn, "show.json", order: order)
  else
    conn
    |> put_status(:unprocessable_entity)
    |> render("error.json", message: "Out of stock")
  end
end
```

### ✅ Good: Thin Controller + Context

```elixir
# Controller: orchestrate only
def create(conn, %{"order" => order_params}) do
  user = conn.assigns.current_user

  case Orders.create_order(user, order_params) do
    {:ok, order} ->
      conn
      |> put_status(:created)
      |> render("show.json", order: order)

    {:error, %Ecto.Changeset{} = changeset} ->
      {:error, changeset}

    {:error, :out_of_stock} ->
      {:error, :out_of_stock}
  end
end

# Context: business logic and queries
defmodule Orders do
  def create_order(user, attrs) do
    with {:ok, items} <- fetch_items(attrs["item_ids"]),
         :ok <- validate_stock(items),
         {:ok, order} <- insert_order(user, items, attrs) do
      send_confirmation(order)
      {:ok, order}
    end
  end

  defp fetch_items(item_ids) do
    items = Repo.all(from i in Item, where: i.id in ^item_ids)
    if length(items) == length(item_ids), do: {:ok, items}, else: {:error, :invalid_items}
  end

  defp validate_stock(items) do
    if Enum.all?(items, & &1.stock > 0), do: :ok, else: {:error, :out_of_stock}
  end

  defp insert_order(user, items, attrs) do
    discount = if user.premium?, do: 0.1, else: 0.0
    total = calculate_total(items, discount)

    %Order{}
    |> Order.changeset(Map.merge(attrs, %{user_id: user.id, total: total}))
    |> Ecto.Changeset.put_assoc(:items, items)
    |> Repo.insert()
  end

  defp calculate_total(items, discount) do
    Enum.reduce(items, Decimal.new(0), fn item, acc ->
      Decimal.add(acc, Decimal.mult(item.price, Decimal.from_float(1 - discount)))
    end)
  end

  defp send_confirmation(order) do
    OrderMailer.confirmation(order) |> Mailer.deliver_later()
  end
end
```

**Why this is better:**
- Context function is testable without HTTP concerns
- Logic is reusable (CLI tools, background jobs)
- Controller action is 8 lines, readable at a glance
- Error handling is delegated to `action_fallback`

## Router Organization

Organize routes by API version, authentication requirement, and resource type. Use pipelines for cross-cutting concerns.

### ✅ Well-Organized Router

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
    plug :put_secure_browser_headers
  end

  pipeline :api_auth do
    plug :accepts, ["json"]
    plug MyAppWeb.Auth.Pipeline
  end

  pipeline :rate_limit do
    plug MyAppWeb.RateLimitPlug
  end

  # Public API (v1)
  scope "/api/v1", MyAppWeb.V1, as: :v1 do
    pipe_through [:api, :rate_limit]

    post "/auth/login", AuthController, :login
    post "/auth/register", AuthController, :register
    get "/health", HealthController, :index
  end

  # Authenticated API (v1)
  scope "/api/v1", MyAppWeb.V1, as: :v1 do
    pipe_through [:api_auth, :rate_limit]

    resources "/users", UserController, only: [:show, :update] do
      # Nested resources: max 2 levels
      resources "/orders", OrderController, only: [:index, :show]
    end

    resources "/orders", OrderController, only: [:create, :index, :show, :update]
    resources "/products", ProductController, only: [:index, :show]
  end

  # Admin API
  scope "/api/v1/admin", MyAppWeb.V1.Admin, as: :v1_admin do
    pipe_through [:api_auth, :require_admin]

    resources "/users", UserController
    resources "/products", ProductController
  end
end
```

**Best Practices:**
- Version your API (`/api/v1`) from day one
- Separate public and authenticated scopes
- Use pipeline plugs for auth, rate limiting, content negotiation
- Avoid deeply nested resources (max 2 levels: `/users/:id/orders`, not `/users/:id/orders/:oid/items/:iid`)
- Use `as:` option to namespace route helpers (`v1_user_path`, `v1_admin_user_path`)

### ❌ Anti-Pattern: Deep Nesting

```elixir
# Don't do this
resources "/users", UserController do
  resources "/teams", TeamController do
    resources "/projects", ProjectController do
      resources "/tasks", TaskController  # Too deep!
    end
  end
end

# Instead: flatten to meaningful paths
resources "/users", UserController
resources "/teams", TeamController
resources "/projects", ProjectController
resources "/team_projects", TeamProjectController, only: [:index]  # /teams/:team_id/projects
resources "/tasks", TaskController
```

## Fallback Controllers

Use `action_fallback` to centralize error rendering. Map context error tuples to HTTP responses in one place.

### ✅ FallbackController Pattern

```elixir
# In your controller
defmodule MyAppWeb.V1.OrderController do
  use MyAppWeb, :controller

  action_fallback MyAppWeb.FallbackController

  def create(conn, %{"order" => order_params}) do
    user = conn.assigns.current_user

    # All error tuples are caught by fallback controller
    with {:ok, order} <- Orders.create_order(user, order_params) do
      conn
      |> put_status(:created)
      |> render("show.json", order: order)
    end
  end

  def show(conn, %{"id" => id}) do
    # Returns {:ok, order} or {:error, :not_found}
    with {:ok, order} <- Orders.get_order(id) do
      render(conn, "show.json", order: order)
    end
  end
end

# Centralized error handling
defmodule MyAppWeb.FallbackController do
  use MyAppWeb, :controller

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(MyAppWeb.ChangesetView)
    |> render("error.json", changeset: changeset)
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(MyAppWeb.ErrorView)
    |> render("404.json")
  end

  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(:forbidden)
    |> put_view(MyAppWeb.ErrorView)
    |> render("403.json")
  end

  def call(conn, {:error, :out_of_stock}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(MyAppWeb.ErrorView)
    |> render("error.json", message: "One or more items are out of stock")
  end

  # Catch-all for unexpected errors (log and return 500)
  def call(conn, {:error, reason}) do
    require Logger
    Logger.error("Unhandled error in controller: #{inspect(reason)}")

    conn
    |> put_status(:internal_server_error)
    |> put_view(MyAppWeb.ErrorView)
    |> render("500.json")
  end
end
```

**Benefits:**
- No duplication of error handling across actions
- Consistent response shapes for all errors
- Easy to add new error types
- Controllers stay thin (no error-rendering logic)

## Parameter Handling

Never trust raw params. Validate with changesets or embedded schemas.

### ❌ Bad: Unvalidated Params

```elixir
def index(conn, params) do
  # Dangerous: arbitrary keys passed to Repo
  orders = Repo.all(from o in Order, where: ^Map.to_list(params))
  render(conn, "index.json", orders: orders)
end
```

### ✅ Good: Embedded Schema for Validation

```elixir
# Define schema for query params
defmodule MyAppWeb.V1.OrderController.IndexParams do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :status, :string
    field :min_total, :decimal
    field :max_total, :decimal
    field :sort_by, :string, default: "inserted_at"
    field :sort_order, :string, default: "desc"
    field :page, :integer, default: 1
    field :page_size, :integer, default: 20
  end

  def changeset(params) do
    %__MODULE__{}
    |> cast(params, [:status, :min_total, :max_total, :sort_by, :sort_order, :page, :page_size])
    |> validate_inclusion(:status, ["pending", "completed", "cancelled"])
    |> validate_inclusion(:sort_by, ["inserted_at", "total", "status"])
    |> validate_inclusion(:sort_order, ["asc", "desc"])
    |> validate_number(:page, greater_than: 0)
    |> validate_number(:page_size, greater_than: 0, less_than_or_equal_to: 100)
    |> validate_min_max_total()
  end

  defp validate_min_max_total(changeset) do
    min = get_field(changeset, :min_total)
    max = get_field(changeset, :max_total)

    if min && max && Decimal.compare(min, max) == :gt do
      add_error(changeset, :min_total, "must be less than max_total")
    else
      changeset
    end
  end
end

# Controller validates before calling context
def index(conn, params) do
  with {:ok, search_params} <- validate_params(params),
       {:ok, orders, total} <- Orders.list_orders(search_params) do
    render(conn, "index.json", orders: orders, total: total, page: search_params.page)
  end
end

defp validate_params(params) do
  case IndexParams.changeset(params) |> apply_action(:insert) do
    {:ok, valid_params} -> {:ok, valid_params}
    {:error, changeset} -> {:error, changeset}
  end
end
```

**Why embedded schemas:**
- Explicit whitelist of allowed params
- Type coercion and validation
- Self-documenting API (schema shows what params are accepted)
- Prevents SQL injection via dynamic queries

## JSON Rendering

Use explicit view modules for complex resources. Don't render raw Ecto schemas.

### ❌ Anti-Pattern: Rendering Raw Schemas

```elixir
# Don't do this
def show(conn, %{"id" => id}) do
  user = Repo.get!(User, id) |> Repo.preload(:orders)
  json(conn, user)  # Leaks all fields, including password_hash!
end
```

### ✅ Good: Explicit Views

```elixir
# View module with controlled serialization
defmodule MyAppWeb.V1.UserView do
  use MyAppWeb, :view

  def render("index.json", %{users: users}) do
    %{data: render_many(users, __MODULE__, "user.json")}
  end

  def render("show.json", %{user: user}) do
    %{data: render_one(user, __MODULE__, "user.json")}
  end

  def render("user.json", %{user: user}) do
    %{
      id: user.id,
      email: user.email,
      name: user.name,
      premium: user.premium?,
      inserted_at: user.inserted_at
      # Explicitly omit: password_hash, internal flags, etc.
    }
  end
end

# Controller
def show(conn, %{"id" => id}) do
  with {:ok, user} <- Users.get_user(id) do
    render(conn, "show.json", user: user)
  end
end
```

### Consistent Response Shapes

```elixir
# Success responses
%{data: resource}           # Single resource
%{data: [resource, ...]}    # Collection

# Success with metadata
%{
  data: [resource, ...],
  meta: %{
    page: 1,
    page_size: 20,
    total_count: 150,
    total_pages: 8
  }
}

# Error responses
%{
  errors: %{
    field_name: ["error message 1", "error message 2"]
  }
}

# Single error message
%{
  errors: %{
    detail: "Resource not found"
  }
}
```

### Jason.Encoder for Simple Cases

```elixir
# When you control the struct and need simple JSON
defmodule Order do
  @derive {Jason.Encoder, only: [:id, :total, :status, :inserted_at]}
  defstruct [:id, :total, :status, :inserted_at, :internal_flag]
end

# Works for simple cases, but views give more control
def show(conn, %{"id" => id}) do
  order = %Order{id: 1, total: 100, status: "completed", inserted_at: ~N[2025-01-01 00:00:00]}
  json(conn, %{data: order})
end
```

**Use views when:**
- Rendering associations (nested resources)
- Different representations for different endpoints
- Computed fields or transformations needed
- API versioning (same resource, different views)

## Testing

Test through the router using `ConnTest`. Test the full request cycle.

### ✅ Controller Test Example

```elixir
defmodule MyAppWeb.V1.OrderControllerTest do
  use MyAppWeb.ConnCase, async: true

  alias MyApp.Orders

  setup do
    user = insert(:user)
    product = insert(:product, price: 100, stock: 5)
    {:ok, user: user, product: product}
  end

  describe "POST /api/v1/orders" do
    test "creates order with valid params", %{conn: conn, user: user, product: product} do
      conn =
        conn
        |> authenticate(user)
        |> post(Routes.v1_order_path(conn, :create), %{
          order: %{
            item_ids: [product.id],
            shipping_address: "123 Main St"
          }
        })

      assert %{"data" => order} = json_response(conn, 201)
      assert order["total"] == "100.00"
      assert order["status"] == "pending"

      # Verify side effects
      assert Orders.get_order!(order["id"])
      assert_email_sent(subject: "Order Confirmation")
    end

    test "returns error when item is out of stock", %{conn: conn, user: user, product: product} do
      {:ok, _} = Orders.update_product(product, %{stock: 0})

      conn =
        conn
        |> authenticate(user)
        |> post(Routes.v1_order_path(conn, :create), %{
          order: %{item_ids: [product.id]}
        })

      assert %{"errors" => %{"detail" => message}} = json_response(conn, 422)
      assert message =~ "out of stock"
    end

    test "returns 401 when not authenticated", %{conn: conn, product: product} do
      conn = post(conn, Routes.v1_order_path(conn, :create), %{
        order: %{item_ids: [product.id]}
      })

      assert json_response(conn, 401)
    end

    test "returns error with invalid params", %{conn: conn, user: user} do
      conn =
        conn
        |> authenticate(user)
        |> post(Routes.v1_order_path(conn, :create), %{
          order: %{item_ids: []}  # Empty items
        })

      assert %{"errors" => errors} = json_response(conn, 422)
      assert errors["item_ids"]
    end
  end

  describe "GET /api/v1/orders" do
    test "lists orders with pagination", %{conn: conn, user: user} do
      insert_list(25, :order, user: user)

      conn =
        conn
        |> authenticate(user)
        |> get(Routes.v1_order_path(conn, :index), %{page: 1, page_size: 10})

      assert %{"data" => orders, "meta" => meta} = json_response(conn, 200)
      assert length(orders) == 10
      assert meta["total_count"] == 25
      assert meta["total_pages"] == 3
    end

    test "filters by status", %{conn: conn, user: user} do
      insert(:order, user: user, status: "completed")
      insert(:order, user: user, status: "pending")

      conn =
        conn
        |> authenticate(user)
        |> get(Routes.v1_order_path(conn, :index), %{status: "completed"})

      assert %{"data" => [order]} = json_response(conn, 200)
      assert order["status"] == "completed"
    end

    test "returns error for invalid filter params", %{conn: conn, user: user} do
      conn =
        conn
        |> authenticate(user)
        |> get(Routes.v1_order_path(conn, :index), %{status: "invalid_status"})

      assert %{"errors" => errors} = json_response(conn, 422)
      assert errors["status"]
    end
  end

  defp authenticate(conn, user) do
    token = MyAppWeb.Auth.generate_token(user)
    put_req_header(conn, "authorization", "Bearer #{token}")
  end
end
```

**Test Coverage Checklist:**
- ✅ Happy path (valid input → expected output)
- ✅ Authentication/authorization failures
- ✅ Validation errors (invalid params)
- ✅ Business logic errors (out of stock, insufficient funds)
- ✅ Side effects (emails sent, background jobs enqueued)
- ✅ Pagination and filtering
- ✅ Response shape matches API contract

## Common Mistakes

### 1. Business Logic in Controllers

**Problem:** Controllers contain calculations, validations, or decision-making logic.

**Fix:** Move all logic to context modules. Controllers should only orchestrate.

---

### 2. Not Using `action_fallback`

**Problem:** Error handling duplicated across every action.

```elixir
# Don't repeat this in every action
case Orders.create_order(user, params) do
  {:ok, order} -> render(conn, "show.json", order: order)
  {:error, %Changeset{} = cs} -> render(conn, "error.json", changeset: cs)
  {:error, :not_found} -> put_status(conn, 404) |> render("404.json")
end
```

**Fix:** Use `action_fallback` (see Fallback Controllers section).

---

### 3. Deeply Nested Routes

**Problem:** URLs become brittle and hard to construct.

```elixir
# Don't do this
/api/v1/organizations/:org_id/teams/:team_id/projects/:project_id/tasks/:id
```

**Fix:** Flatten to 2 levels max. Use separate endpoints.

```elixir
# Better
/api/v1/tasks/:id
/api/v1/projects/:project_id/tasks  # Get tasks for a project
```

---

### 4. Rendering Raw Ecto Schemas

**Problem:** Exposes internal fields (password hashes, foreign keys, `__meta__`), breaks when associations change.

**Fix:** Use explicit views or `@derive {Jason.Encoder, only: [...]}`.

---

### 5. Not Validating Query Params

**Problem:** Users can pass arbitrary filters, causing SQL injection or performance issues.

```elixir
# Dangerous
def index(conn, params) do
  orders = Repo.all(from o in Order, where: ^Map.to_list(params))
  # User could pass: ?__meta__=... or arbitrary SQL fragments
end
```

**Fix:** Use embedded schemas (see Parameter Handling section).

---

### 6. Missing Rate Limiting

**Problem:** Public endpoints can be abused (DDoS, scraping, credential stuffing).

**Fix:** Add rate limiting plug to public pipelines.

```elixir
pipeline :public_api do
  plug :accepts, ["json"]
  plug MyAppWeb.RateLimitPlug, max_requests: 100, interval: :timer.minutes(1)
end
```

---

### 7. Inconsistent Response Shapes

**Problem:** Some endpoints return `%{data: ...}`, others return bare resources. Some errors are strings, others are maps.

**Fix:** Standardize on one response shape across your entire API.

```elixir
# Always use this shape
%{data: resource}           # Success
%{errors: %{...}}           # Error
```

---

### 8. Not Testing Through the Router

**Problem:** Calling controller functions directly bypasses plugs (auth, parsing, rate limiting).

```elixir
# Don't do this
test "creates order" do
  result = OrderController.create(%Plug.Conn{}, %{"order" => %{...}})
end
```

**Fix:** Use `ConnTest` and test through the router (see Testing section).

---

**Summary:** Keep controllers thin, validate all input, use fallback controllers, test the full request cycle, and never expose raw Ecto schemas.

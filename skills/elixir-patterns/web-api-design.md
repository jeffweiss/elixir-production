# Web API Design Philosophy

APIs are boundary code. Domain logic lives in contexts; controllers and resolvers are thin adapters that translate between wire format and context calls. This applies whether you're building REST endpoints with Phoenix controllers or GraphQL APIs with Absinthe.

## Decision Framework

```
What format does the client need?
  REST (CRUD resources, mobile apps, third-party integrations)
    → Phoenix controllers + JSON views
  GraphQL (flexible queries, real-time updates, rich clients)
    → Absinthe resolvers + schemas
  Both?
    → Shared context layer, separate boundary adapters
```

**Rule of thumb**: Controllers and resolvers should be 5-15 lines each. All business logic belongs in context modules. If you're writing conditionals or database queries in a controller/resolver, move them to the context.

## Error Contracts

Consistent error shapes flowing from contexts to the wire prevent client confusion and simplify debugging.

### Context Error Convention

Context functions return tagged tuples:

```elixir
{:ok, result}                    # Success
{:error, :not_found}             # Resource doesn't exist
{:error, :unauthorized}          # Permission denied
{:error, %Ecto.Changeset{}}      # Validation failure
{:error, :rate_limited}          # Too many requests
```

### Translation Table

| Context Error | HTTP Status | GraphQL Error Code | When to Use |
|--------------|-------------|-------------------|-------------|
| `{:ok, result}` | 200/201 | Success response | Operation succeeded |
| `{:error, :not_found}` | 404 | `NOT_FOUND` | Resource doesn't exist |
| `{:error, :unauthorized}` | 401 | `UNAUTHENTICATED` | Missing/invalid auth |
| `{:error, :forbidden}` | 403 | `FORBIDDEN` | Valid auth, insufficient permissions |
| `{:error, changeset}` | 422 | `BAD_USER_INPUT` | Validation failed |
| `{:error, :rate_limited}` | 429 | `RATE_LIMITED` | Too many requests |
| `{:error, :conflict}` | 409 | `CONFLICT` | Resource state conflict |
| `{:error, _reason}` | 500 | `INTERNAL_SERVER_ERROR` | Unexpected error |

### REST: Fallback Controller

Phoenix fallback controllers centralize error translation:

```elixir
defmodule MyAppWeb.FallbackController do
  use Phoenix.Controller

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(MyAppWeb.ErrorJSON)
    |> render(:"404")
  end

  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(:unauthorized)
    |> put_view(MyAppWeb.ErrorJSON)
    |> render(:"401")
  end

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(MyAppWeb.ChangesetJSON)
    |> render(:error, changeset: changeset)
  end

  def call(conn, {:error, :rate_limited}) do
    conn
    |> put_status(:too_many_requests)
    |> put_view(MyAppWeb.ErrorJSON)
    |> render(:"429")
  end
end

defmodule MyAppWeb.UserController do
  use MyAppWeb, :controller

  action_fallback MyAppWeb.FallbackController

  def show(conn, %{"id" => id}) do
    # Context returns {:ok, user} or {:error, :not_found}
    # Fallback controller handles errors automatically
    with {:ok, user} <- Accounts.get_user(id) do
      render(conn, :show, user: user)
    end
  end
end
```

### GraphQL: Absinthe Middleware

Absinthe middleware translates context errors to GraphQL error extensions:

```elixir
defmodule MyAppWeb.Schema.Middleware.HandleErrors do
  @behaviour Absinthe.Middleware

  def call(resolution, _config) do
    %{resolution | errors: Enum.flat_map(resolution.errors, &handle_error/1)}
  end

  defp handle_error({:error, :not_found}) do
    [message: "Resource not found", extensions: %{code: "NOT_FOUND"}]
  end

  defp handle_error({:error, :unauthorized}) do
    [message: "Authentication required", extensions: %{code: "UNAUTHENTICATED"}]
  end

  defp handle_error({:error, :forbidden}) do
    [message: "Insufficient permissions", extensions: %{code: "FORBIDDEN"}]
  end

  defp handle_error({:error, %Ecto.Changeset{} = changeset}) do
    [
      message: "Validation failed",
      extensions: %{
        code: "BAD_USER_INPUT",
        fields: format_changeset_errors(changeset)
      }
    ]
  end

  defp handle_error({:error, reason}) when is_atom(reason) do
    [message: "Internal error", extensions: %{code: "INTERNAL_SERVER_ERROR"}]
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end

defmodule MyAppWeb.Schema do
  use Absinthe.Schema

  def middleware(middleware, _field, _object) do
    middleware ++ [MyAppWeb.Schema.Middleware.HandleErrors]
  end

  query do
    field :user, :user do
      arg :id, non_null(:id)

      resolve fn %{id: id}, %{context: context} ->
        # Same context function, different boundary adapter
        Accounts.get_user(id, context.current_user)
      end
    end
  end
end
```

### Anti-Pattern: Leaking Internal Errors

**Never expose internal error details to clients**:

```elixir
# ❌ Bad: Leaks implementation details
def call(conn, {:error, reason}) do
  conn
  |> put_status(:internal_server_error)
  |> json(%{error: inspect(reason)})  # Exposes stack traces, DB errors, etc.
end

# ✅ Good: Generic error, log details server-side
def call(conn, {:error, reason}) do
  Logger.error("Unexpected error: #{inspect(reason)}")

  conn
  |> put_status(:internal_server_error)
  |> put_view(MyAppWeb.ErrorJSON)
  |> render(:"500")
end
```

## Pagination

Choose pagination strategy based on use case and data characteristics.

### Comparison Table

| Factor | Offset Pagination | Cursor Pagination |
|--------|------------------|-------------------|
| **Use case** | Simple UIs, dashboards, admin panels | Infinite scroll, real-time feeds, mobile apps |
| **Query** | `OFFSET N LIMIT M` | `WHERE id > cursor ORDER BY id LIMIT M` |
| **Performance** | Degrades with high offsets (skips rows) | Constant time (index seek) |
| **Real-time** | Inconsistent (page drift if data changes) | Consistent (stable cursor) |
| **Jump to page** | Yes (`?page=42`) | No (cursor is opaque) |
| **Implementation** | Simple | Requires indexed cursor field |
| **Sorting** | Any field | Must match cursor field |

### Offset Pagination

Best for small datasets, admin UIs, and when users need page numbers.

```elixir
defmodule MyApp.Products do
  import Ecto.Query

  def list_products(opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 20)
    offset = (page - 1) * per_page

    products =
      Product
      |> order_by([p], desc: p.inserted_at)
      |> limit(^per_page)
      |> offset(^offset)
      |> Repo.all()

    total_count = Repo.aggregate(Product, :count)
    total_pages = ceil(total_count / per_page)

    %{
      products: products,
      page: page,
      per_page: per_page,
      total_count: total_count,
      total_pages: total_pages
    }
  end
end

# Controller
def index(conn, params) do
  page = Map.get(params, "page", "1") |> String.to_integer()
  result = Products.list_products(page: page, per_page: 20)
  render(conn, :index, result)
end
```

### Cursor Pagination

Best for large datasets, real-time feeds, infinite scroll.

```elixir
defmodule MyApp.Posts do
  import Ecto.Query

  @default_limit 20

  def list_posts(opts \\ []) do
    cursor = Keyword.get(opts, :cursor)
    limit = Keyword.get(opts, :limit, @default_limit) + 1  # Fetch one extra to check has_next

    query =
      Post
      |> order_by([p], desc: p.id)
      |> limit(^limit)

    query =
      if cursor do
        from p in query, where: p.id < ^cursor
      else
        query
      end

    posts = Repo.all(query)

    {posts, has_next_page} =
      if length(posts) > @default_limit do
        {Enum.take(posts, @default_limit), true}
      else
        {posts, false}
      end

    next_cursor = posts |> List.last() |> then(& &1 && &1.id)

    %{
      posts: posts,
      next_cursor: next_cursor,
      has_next_page: has_next_page
    }
  end
end

# Controller
def index(conn, params) do
  cursor = Map.get(params, "cursor") |> parse_cursor()
  result = Posts.list_posts(cursor: cursor)
  render(conn, :index, result)
end

defp parse_cursor(nil), do: nil
defp parse_cursor(cursor) when is_binary(cursor) do
  case Integer.parse(cursor) do
    {id, ""} -> id
    _ -> nil
  end
end
```

### GraphQL: Relay Connections

Relay-style connections standardize cursor pagination for GraphQL:

```elixir
defmodule MyAppWeb.Schema do
  use Absinthe.Schema
  import Absinthe.Resolution.Helpers

  connection(node_type: :post) do
    field :total_count, :integer do
      resolve fn _, %{source: conn} ->
        {:ok, length(conn.edges)}
      end
    end

    edge do
      field :cursor, :string
      field :node, :post
    end
  end

  query do
    connection field :posts, node_type: :post do
      arg :first, :integer, default_value: 20
      arg :after, :string

      resolve fn pagination_args, _ ->
        cursor = pagination_args[:after]
        limit = pagination_args[:first]

        Posts.list_posts(cursor: cursor, limit: limit)
        |> to_relay_connection()
      end
    end
  end

  defp to_relay_connection(%{posts: posts, next_cursor: next_cursor, has_next_page: has_next_page}) do
    edges =
      Enum.map(posts, fn post ->
        %{
          cursor: encode_cursor(post.id),
          node: post
        }
      end)

    {:ok,
     %{
       edges: edges,
       page_info: %{
         has_next_page: has_next_page,
         end_cursor: next_cursor && encode_cursor(next_cursor)
       }
     }}
  end

  defp encode_cursor(id), do: Base.encode64("Post:#{id}")
end
```

### Anti-Pattern: Offset on Large Unindexed Tables

```elixir
# ❌ Bad: High offset skips millions of rows
def list_logs(page) do
  offset = (page - 1) * 100

  from(l in Log, order_by: [desc: l.inserted_at], limit: 100, offset: ^offset)
  |> Repo.all()
  # Page 10000 forces Postgres to scan 1M rows then discard 999,900
end

# ✅ Good: Cursor pagination with indexed timestamp
def list_logs(cursor) do
  query = from l in Log, order_by: [desc: l.inserted_at], limit: 100

  query =
    if cursor do
      from l in query, where: l.inserted_at < ^cursor
    else
      query
    end

  Repo.all(query)
  # Always uses index seek, constant time regardless of position
end
```

## Authentication & Authorization

Auth decisions happen at the boundary. Authorization logic lives in contexts.

### REST: Plug Pipeline

```elixir
defmodule MyAppWeb.Plugs.AuthenticateUser do
  import Plug.Conn
  alias MyApp.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, user} <- Accounts.verify_token(token) do
      assign(conn, :current_user, user)
    else
      _ ->
        conn
        |> put_status(:unauthorized)
        |> Phoenix.Controller.put_view(MyAppWeb.ErrorJSON)
        |> Phoenix.Controller.render(:"401")
        |> halt()
    end
  end
end

defmodule MyAppWeb.Router do
  use MyAppWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :authenticated do
    plug MyAppWeb.Plugs.AuthenticateUser
  end

  scope "/api", MyAppWeb do
    pipe_through [:api, :authenticated]

    resources "/posts", PostController
    resources "/users", UserController
  end
end
```

### GraphQL: Context Builder

```elixir
defmodule MyAppWeb.Schema.Context do
  @behaviour Absinthe.Middleware

  def build_context(conn) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, user} <- MyApp.Accounts.verify_token(token) do
      %{current_user: user}
    else
      _ -> %{}
    end
  end
end

# In router
forward "/api/graphql", Absinthe.Plug,
  schema: MyAppWeb.Schema,
  context: %{build_context: &MyAppWeb.Schema.Context.build_context/1}
```

### Authorization in Contexts

**Authorization logic belongs in context functions, not controllers/resolvers**:

```elixir
defmodule MyApp.Posts do
  def update_post(%Post{} = post, attrs, %User{} = current_user) do
    with :ok <- authorize_update(post, current_user) do
      post
      |> Post.changeset(attrs)
      |> Repo.update()
    end
  end

  defp authorize_update(%Post{user_id: user_id}, %User{id: user_id}), do: :ok
  defp authorize_update(%Post{}, %User{admin: true}), do: :ok
  defp authorize_update(_, _), do: {:error, :forbidden}
end

# Controller just passes current_user from conn.assigns
def update(conn, %{"id" => id, "post" => post_params}) do
  with {:ok, post} <- Posts.get_post(id),
       {:ok, updated_post} <- Posts.update_post(post, post_params, conn.assigns.current_user) do
    render(conn, :show, post: updated_post)
  end
end

# Resolver does the same
def update_post(%{id: id, input: input}, %{context: %{current_user: current_user}}) do
  with {:ok, post} <- Posts.get_post(id),
       {:ok, updated_post} <- Posts.update_post(post, input, current_user) do
    {:ok, updated_post}
  end
end
```

### Anti-Pattern: Authorization in Controllers

```elixir
# ❌ Bad: Authorization scattered across controllers/resolvers
def update(conn, %{"id" => id, "post" => params}) do
  post = Posts.get_post!(id)

  if post.user_id == conn.assigns.current_user.id or conn.assigns.current_user.admin do
    case Posts.update_post(post, params) do
      {:ok, post} -> render(conn, :show, post: post)
      {:error, changeset} -> render(conn, :error, changeset: changeset)
    end
  else
    conn |> put_status(:forbidden) |> render(:"403")
  end
end

# ✅ Good: Authorization in context, boundary stays thin
def update(conn, %{"id" => id, "post" => params}) do
  with {:ok, post} <- Posts.get_post(id),
       {:ok, updated} <- Posts.update_post(post, params, conn.assigns.current_user) do
    render(conn, :show, post: updated)
  end
end
```

## Versioning

Most Phoenix/Absinthe apps don't need aggressive versioning. Additive changes + deprecation warnings cover 90% of cases.

### Comparison Table

| Approach | Example | Pros | Cons | When to Use |
|----------|---------|------|------|-------------|
| URL path | `/api/v1/users` | Explicit, easy to deprecate | Duplicates code, clutters routes | Breaking changes, long deprecation cycles |
| Accept header | `Accept: application/vnd.api.v1+json` | Clean URLs | Harder to test, not cacheable | REST purists, large enterprises |
| GraphQL schema evolution | Deprecate fields, add new ones | No version explosion | Requires client cooperation | Most GraphQL APIs |
| No versioning | Just `/api/users` | Simplest | Requires discipline | Internal APIs, tight client coupling |

### URL Path Versioning

```elixir
defmodule MyAppWeb.Router do
  scope "/api/v1", MyAppWeb.V1, as: :v1 do
    pipe_through :api
    resources "/users", UserController
  end

  scope "/api/v2", MyAppWeb.V2, as: :v2 do
    pipe_through :api
    resources "/users", UserController
  end
end

# Shared logic lives in contexts; controllers adapt to wire format
defmodule MyAppWeb.V1.UserController do
  def show(conn, %{"id" => id}) do
    case Accounts.get_user(id) do
      {:ok, user} ->
        render(conn, :show, user: UserView.to_v1_json(user))
      {:error, :not_found} ->
        conn |> put_status(:not_found) |> render(:"404")
    end
  end
end

defmodule MyAppWeb.V2.UserController do
  def show(conn, %{"id" => id}) do
    case Accounts.get_user(id) do
      {:ok, user} ->
        render(conn, :show, user: UserView.to_v2_json(user))  # Different JSON shape
      {:error, :not_found} ->
        conn |> put_status(:not_found) |> render(:"404")
    end
  end
end
```

### GraphQL Schema Evolution

**Preferred for GraphQL**: Add fields, deprecate old ones, never remove.

```elixir
object :user do
  field :id, :id
  field :email, :string

  # Old field - deprecated
  field :full_name, :string do
    deprecate "Use firstName and lastName instead"
    resolve fn user, _, _ ->
      {:ok, "#{user.first_name} #{user.last_name}"}
    end
  end

  # New fields - additive
  field :first_name, :string
  field :last_name, :string
end
```

### Additive Changes (No Version Needed)

Most changes are additive and don't break existing clients:

- Adding new endpoints/fields
- Adding optional parameters
- Returning additional data in responses
- Making required fields optional

**Breaking changes** require versioning:

- Removing fields/endpoints
- Changing field types
- Making optional fields required
- Changing error response shapes

## Input Validation

Validate at the boundary before data reaches contexts. Reject bad input early.

### Embedded Schemas for Non-DB Input

Use Ecto changesets even when data never touches the database:

```elixir
defmodule MyAppWeb.UserController do
  defmodule CreateUserInput do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      field :email, :string
      field :password, :string
      field :age, :integer
    end

    def changeset(input, attrs) do
      input
      |> cast(attrs, [:email, :password, :age])
      |> validate_required([:email, :password])
      |> validate_format(:email, ~r/@/)
      |> validate_length(:password, min: 8)
      |> validate_number(:age, greater_than_or_equal_to: 13)
    end
  end

  def create(conn, params) do
    with {:ok, input} <- validate_input(params),
         {:ok, user} <- Accounts.create_user(Map.from_struct(input)) do
      render(conn, :show, user: user)
    end
  end

  defp validate_input(params) do
    %CreateUserInput{}
    |> CreateUserInput.changeset(params)
    |> Ecto.Changeset.apply_action(:create)
  end
end
```

### Rate Limiting

ETS atomic counter pattern for per-client rate limits:

```elixir
defmodule MyAppWeb.Plugs.RateLimit do
  import Plug.Conn

  @max_requests 100
  @window_seconds 60

  def init(opts), do: opts

  def call(conn, _opts) do
    client_id = get_client_id(conn)
    window = current_window()

    case check_rate_limit(client_id, window) do
      :ok ->
        conn
      {:error, :rate_limited} ->
        conn
        |> put_status(:too_many_requests)
        |> Phoenix.Controller.put_view(MyAppWeb.ErrorJSON)
        |> Phoenix.Controller.render(:"429")
        |> halt()
    end
  end

  defp get_client_id(conn) do
    # Use API key, user ID, or IP address
    conn.assigns[:current_user]?.id || to_string(:inet.ntoa(conn.remote_ip))
  end

  defp current_window do
    div(System.system_time(:second), @window_seconds)
  end

  defp check_rate_limit(client_id, window) do
    key = {client_id, window}

    count = :ets.update_counter(:rate_limits, key, {2, 1}, {key, 0})

    if count <= @max_requests do
      :ok
    else
      {:error, :rate_limited}
    end
  end
end

# In application.ex
:ets.new(:rate_limits, [:named_table, :public, :set, write_concurrency: true])
```

### Request Body Size Limits

Configure in endpoint:

```elixir
# config/config.exs
config :my_app, MyAppWeb.Endpoint,
  http: [
    protocol_options: [
      max_request_line_length: 8192,
      max_header_length: 8192
    ]
  ]

# Per-route in router
plug Plug.Parsers,
  parsers: [:json],
  pass: ["application/json"],
  json_decoder: Jason,
  length: 1_000_000  # 1MB max body size
```

### GraphQL Query Complexity Limits

Prevent expensive nested queries:

```elixir
defmodule MyAppWeb.Schema do
  use Absinthe.Schema

  # Limit query depth
  def plugins do
    [Absinthe.Middleware.QueryDepthLimit.init(max_depth: 10)]
  end

  # Limit query complexity
  def middleware(middleware, _field, %{identifier: :query}) do
    [Absinthe.Middleware.QueryComplexity.init(max_complexity: 1000)] ++ middleware
  end
  def middleware(middleware, _field, _object), do: middleware

  object :user do
    field :id, :id
    field :posts, list_of(:post), complexity: fn args, child_complexity ->
      # Calculate complexity based on pagination args
      limit = Map.get(args, :limit, 10)
      limit * child_complexity
    end
  end
end
```

### Anti-Pattern: Validating Deep in Contexts

```elixir
# ❌ Bad: Validation happens after parsing, business logic begins
def create_user(attrs) do
  if valid_email?(attrs["email"]) and strong_password?(attrs["password"]) do
    # Business logic here
  else
    {:error, :invalid_input}
  end
end

# ✅ Good: Validation at boundary, contexts receive valid data
def create_user(attrs) do
  %User{}
  |> User.changeset(attrs)
  |> Repo.insert()
end
```

**See also**: `production-quality/security.md` for additional input validation patterns including SQL injection prevention and XSS protection.

# Plug and Controller Patterns

## Plug Pipeline

Every HTTP request flows through a pipeline of Plugs — composable middleware that transforms the connection:

```
Request → Endpoint → Router → Pipeline → Controller → Response
              │          │         │
              │          │         ├── :browser (session, CSRF, etc.)
              │          │         └── :api (JSON parsing, auth header)
              │          └── Route matching
              └── Static files, code reloading, parsers
```

### Writing Custom Plugs

```elixir
# Function plug — simplest form
defmodule MyAppWeb.Plugs.RequireApiKey do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_req_header(conn, "x-api-key") do
      [key] ->
        case MyApp.Auth.verify_api_key(key) do
          {:ok, client} -> assign(conn, :api_client, client)
          {:error, _} -> unauthorized(conn)
        end

      [] ->
        unauthorized(conn)
    end
  end

  defp unauthorized(conn) do
    conn
    |> put_status(:unauthorized)
    |> Phoenix.Controller.json(%{error: "Invalid or missing API key"})
    |> halt()
  end
end
```

### Pipeline Composition

```elixir
# router.ex
pipeline :browser do
  plug :accepts, ["html"]
  plug :fetch_session
  plug :fetch_live_flash
  plug :put_root_layout, html: {MyAppWeb.Layouts, :root}
  plug :protect_from_forgery
  plug :put_secure_browser_headers
end

pipeline :api do
  plug :accepts, ["json"]
  plug MyAppWeb.Plugs.RequireApiKey
  plug MyAppWeb.Plugs.RateLimiter, limit: 100, window: 60_000
end

pipeline :authenticated_api do
  plug :accepts, ["json"]
  plug MyAppWeb.Plugs.RequireApiKey
  plug MyAppWeb.Plugs.RequireBearerToken
end

scope "/api/v1", MyAppWeb.API.V1 do
  pipe_through :api

  resources "/products", ProductController, only: [:index, :show]
end

scope "/api/v1", MyAppWeb.API.V1 do
  pipe_through :authenticated_api

  resources "/orders", OrderController
  resources "/users", UserController, only: [:show, :update]
end
```

## Controller Patterns

### JSON API Controller

```elixir
defmodule MyAppWeb.API.V1.ProductController do
  use MyAppWeb, :controller

  action_fallback MyAppWeb.FallbackController

  def index(conn, params) do
    page = Map.get(params, "page", "1") |> String.to_integer()
    per_page = Map.get(params, "per_page", "20") |> String.to_integer() |> min(100)

    {products, total} = Products.list_products(page: page, per_page: per_page)

    conn
    |> put_resp_header("x-total-count", to_string(total))
    |> render(:index, products: products)
  end

  def show(conn, %{"id" => id}) do
    with {:ok, product} <- Products.get_product(id) do
      render(conn, :show, product: product)
    end
  end

  def create(conn, %{"product" => product_params}) do
    with {:ok, product} <- Products.create_product(product_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/v1/products/#{product}")
      |> render(:show, product: product)
    end
  end

  def update(conn, %{"id" => id, "product" => product_params}) do
    with {:ok, product} <- Products.get_product(id),
         {:ok, updated} <- Products.update_product(product, product_params) do
      render(conn, :show, product: updated)
    end
  end

  def delete(conn, %{"id" => id}) do
    with {:ok, product} <- Products.get_product(id),
         {:ok, _} <- Products.delete_product(product) do
      send_resp(conn, :no_content, "")
    end
  end
end
```

### Fallback Controller

Handles error tuples from `with` blocks centrally:

```elixir
defmodule MyAppWeb.FallbackController do
  use MyAppWeb, :controller

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(json: MyAppWeb.ErrorJSON)
    |> render(:"404")
  end

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: MyAppWeb.ChangesetJSON)
    |> render(:error, changeset: changeset)
  end

  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(:forbidden)
    |> put_view(json: MyAppWeb.ErrorJSON)
    |> render(:"403")
  end
end
```

### JSON Views (Phoenix 1.7+)

```elixir
defmodule MyAppWeb.API.V1.ProductJSON do
  def index(%{products: products}) do
    %{data: for(product <- products, do: data(product))}
  end

  def show(%{product: product}) do
    %{data: data(product)}
  end

  defp data(product) do
    %{
      id: product.id,
      name: product.name,
      price_cents: product.price_cents,
      inserted_at: product.inserted_at
    }
  end
end
```

## API Versioning

### URL Prefix (Recommended)

```elixir
scope "/api/v1", MyAppWeb.API.V1 do
  pipe_through :api
  resources "/products", ProductController
end

scope "/api/v2", MyAppWeb.API.V2 do
  pipe_through :api
  resources "/products", ProductController
end
```

### Header-Based

```elixir
defmodule MyAppWeb.Plugs.ApiVersion do
  import Plug.Conn

  def init(default: default), do: default

  def call(conn, default_version) do
    version =
      case get_req_header(conn, "accept") do
        ["application/vnd.myapp.v2+json"] -> "v2"
        _ -> default_version
      end

    assign(conn, :api_version, version)
  end
end
```

## Rate Limiting Plug

```elixir
defmodule MyAppWeb.Plugs.RateLimiter do
  import Plug.Conn

  def init(opts) do
    %{
      limit: Keyword.fetch!(opts, :limit),
      window: Keyword.fetch!(opts, :window)
    }
  end

  def call(conn, %{limit: limit, window: window}) do
    key = rate_limit_key(conn)

    case MyApp.RateLimiter.check(key, limit, window) do
      {:allow, count} ->
        conn
        |> put_resp_header("x-ratelimit-limit", to_string(limit))
        |> put_resp_header("x-ratelimit-remaining", to_string(limit - count))

      {:deny, _count} ->
        conn
        |> put_status(:too_many_requests)
        |> Phoenix.Controller.json(%{error: "Rate limit exceeded"})
        |> halt()
    end
  end

  defp rate_limit_key(conn) do
    case conn.assigns[:api_client] do
      %{id: client_id} -> "api:#{client_id}"
      nil -> "ip:#{to_string(:inet.ntoa(conn.remote_ip))}"
    end
  end
end
```

## Common Mistakes

- **Business logic in controllers**: Controllers should delegate to context modules. `Products.create_product(params)`, not raw Ecto queries in the controller.
- **Not using `action_fallback`**: Without it, every controller action needs its own error handling. `action_fallback` centralizes error-to-response mapping.
- **Forgetting `halt()` in plugs**: If a plug sends a response (e.g., 401), it must call `halt()` to stop the pipeline. Without `halt()`, downstream plugs and the controller still execute.
- **Raw `params` in queries**: Always go through a changeset or explicit allowlist. `Repo.insert(Post.changeset(%Post{}, params))`, not `Repo.insert(%Post{title: params["title"]})`.
- **No rate limiting on APIs**: Public APIs without rate limiting are DoS targets. Even internal APIs benefit from rate limiting to prevent cascade failures.
- **Returning Ecto structs directly as JSON**: Define explicit JSON views. Ecto structs include metadata (`__meta__`, loaded associations as `NotLoaded`) that shouldn't be serialized.

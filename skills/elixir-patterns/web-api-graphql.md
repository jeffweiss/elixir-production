# GraphQL with Absinthe

## Overview

Absinthe is powerful but has sharp edges. The most common failure mode is treating resolvers like controllers and putting business logic in them. This creates tight coupling, makes testing harder, and duplicates logic across REST and GraphQL endpoints.

**The core principle:** Resolvers are adapters — they call context functions and format results for GraphQL. They should not contain business rules, queries, or validation logic.

Good Absinthe code looks like thin resolvers that delegate to contexts, aggressive use of Dataloader to prevent N+1 queries, and authorization handled via middleware, not inline checks.

---

## N+1 Queries — Dataloader Is Required

The problem: each resolver that loads an association fires a separate query. If you query 100 users and each resolver loads their posts, you execute 101 queries (1 for users, 100 for posts).

**Dataloader is not optional for production Absinthe.** It batches association loading automatically.

### Setting up Dataloader

```elixir
# lib/my_app_web/schema.ex
defmodule MyAppWeb.Schema do
  use Absinthe.Schema
  import_types MyAppWeb.Schema.AccountTypes

  def context(ctx) do
    loader =
      Dataloader.new()
      |> Dataloader.add_source(Accounts, Accounts.data())
      |> Dataloader.add_source(Products, Products.data())

    Map.put(ctx, :loader, loader)
  end

  def plugins do
    [Absinthe.Middleware.Dataloader] ++ Absinthe.Plugin.defaults()
  end
end

# lib/my_app/accounts/accounts.ex
defmodule MyApp.Accounts do
  def data() do
    Dataloader.Ecto.new(MyApp.Repo, query: &query/2)
  end

  # Optional: customize queries per association
  def query(queryable, _params) do
    queryable
  end
end
```

### Resolver using Dataloader vs naive resolver

❌ **Bad: N+1 queries**

```elixir
object :user do
  field :id, non_null(:id)
  field :name, non_null(:string)

  field :posts, list_of(:post) do
    resolve fn user, _args, _resolution ->
      # Fires a query per user!
      posts = MyApp.Blog.list_posts_for_user(user.id)
      {:ok, posts}
    end
  end
end
```

✅ **Good: Dataloader batches automatically**

```elixir
object :user do
  field :id, non_null(:id)
  field :name, non_null(:string)

  field :posts, list_of(:post) do
    resolve dataloader(Blog, :posts)
  end
end
```

### Common misconfiguration

1. **Forgetting to add Dataloader to context** — `context/1` must return a map with `:loader`
2. **Not calling `Dataloader.add_source` for each context** — each domain needs its own source
3. **Wrong cardinality** — use `dataloader(Source, :assoc)` for `:many`, `dataloader(Source, :assoc, [default: nil])` for `:one`

### Testing Dataloader batching

```elixir
test "batches post queries" do
  users = insert_list(3, :user)
  insert_list(2, :post, user: users |> Enum.at(0))
  insert_list(2, :post, user: users |> Enum.at(1))

  query = """
  {
    users {
      id
      posts { id }
    }
  }
  """

  # Enable SQL logging
  :ok = Ecto.Adapters.SQL.Sandbox.checkout(MyApp.Repo)

  # Capture logs
  log =
    ExUnit.CaptureLog.capture_log(fn ->
      conn = build_conn() |> post("/graphql", %{query: query})
      assert json_response(conn, 200)
    end)

  # Should see 2 queries: one for users, one batched for posts
  assert log =~ "SELECT u0.\"id\""
  assert log =~ "SELECT p0.\"id\", p0.\"user_id\""
  refute log =~ "SELECT p0.\"id\", p0.\"user_id\" FROM \"posts\" AS p0 WHERE (p0.\"user_id\" = $1)"
end
```

---

## Resolver Bloat

Resolvers should be 3-5 lines: load context → call function → return result. If your resolver has conditionals, Ecto queries, or business rules, logic has leaked.

**Rule:** If you need to `import Ecto.Query` in a resolver, you've gone wrong.

❌ **Bad: bloated resolver**

```elixir
field :user_posts, list_of(:post) do
  arg :status, :string
  arg :min_likes, :integer

  resolve fn _parent, args, %{context: %{current_user: current_user}} ->
    # Business logic in resolver!
    query =
      from p in Post,
        where: p.user_id == ^current_user.id,
        where: p.deleted_at |> is_nil()

    query =
      if status = args[:status] do
        from p in query, where: p.status == ^status
      else
        query
      end

    query =
      if min_likes = args[:min_likes] do
        from p in query, where: p.likes >= ^min_likes
      else
        query
      end

    posts = Repo.all(query)
    {:ok, posts}
  end
end
```

✅ **Good: thin resolver delegates to context**

```elixir
field :user_posts, list_of(:post) do
  arg :status, :string
  arg :min_likes, :integer

  resolve fn _parent, args, %{context: %{current_user: user}} ->
    {:ok, Blog.list_user_posts(user, args)}
  end
end

# lib/my_app/blog.ex
defmodule MyApp.Blog do
  def list_user_posts(user, opts \\ []) do
    Post
    |> where(user_id: ^user.id)
    |> where([p], is_nil(p.deleted_at))
    |> filter_by_status(opts[:status])
    |> filter_by_min_likes(opts[:min_likes])
    |> Repo.all()
  end

  defp filter_by_status(query, nil), do: query
  defp filter_by_status(query, status), do: where(query, status: ^status)

  defp filter_by_min_likes(query, nil), do: query
  defp filter_by_min_likes(query, min), do: where(query, [p], p.likes >= ^min)
end
```

Now the query logic is testable without GraphQL, reusable from REST endpoints, and the resolver is trivial.

---

## Schema Organization

Split types by domain, not by GraphQL construct. Use `import_types` in the root schema. Type modules should mirror context boundaries: `AccountTypes` ↔ `Accounts` context.

❌ **Bad: monolithic schema**

```elixir
# lib/my_app_web/schema.ex (1000 lines)
defmodule MyAppWeb.Schema do
  use Absinthe.Schema

  object :user do
    # ...
  end

  object :post do
    # ...
  end

  object :product do
    # ...
  end

  query do
    field :user, :user do
      # ...
    end
    field :posts, list_of(:post) do
      # ...
    end
    field :products, list_of(:product) do
      # ...
    end
  end

  mutation do
    # ...
  end
end
```

✅ **Good: split by domain**

```elixir
# lib/my_app_web/schema.ex
defmodule MyAppWeb.Schema do
  use Absinthe.Schema

  import_types Absinthe.Type.Custom
  import_types MyAppWeb.Schema.AccountTypes
  import_types MyAppWeb.Schema.BlogTypes
  import_types MyAppWeb.Schema.ProductTypes

  query do
    import_fields :account_queries
    import_fields :blog_queries
    import_fields :product_queries
  end

  mutation do
    import_fields :account_mutations
    import_fields :blog_mutations
    import_fields :product_mutations
  end

  def context(ctx) do
    loader =
      Dataloader.new()
      |> Dataloader.add_source(Accounts, Accounts.data())
      |> Dataloader.add_source(Blog, Blog.data())
      |> Dataloader.add_source(Products, Products.data())

    Map.put(ctx, :loader, loader)
  end

  def plugins do
    [Absinthe.Middleware.Dataloader] ++ Absinthe.Plugin.defaults()
  end
end

# lib/my_app_web/schema/account_types.ex
defmodule MyAppWeb.Schema.AccountTypes do
  use Absinthe.Schema.Notation
  import Absinthe.Resolution.Helpers, only: [dataloader: 2]

  object :user do
    field :id, non_null(:id)
    field :email, non_null(:string)
    field :name, :string
    field :posts, list_of(:post), resolve: dataloader(Blog, :posts)
  end

  object :account_queries do
    field :me, :user do
      resolve fn _parent, _args, %{context: %{current_user: user}} ->
        {:ok, user}
      end
    end

    field :user, :user do
      arg :id, non_null(:id)
      resolve fn _parent, %{id: id}, _resolution ->
        case Accounts.get_user(id) do
          nil -> {:error, "User not found"}
          user -> {:ok, user}
        end
      end
    end
  end

  object :account_mutations do
    field :update_profile, :user do
      arg :name, :string
      arg :bio, :string

      resolve fn _parent, args, %{context: %{current_user: user}} ->
        Accounts.update_user(user, args)
      end
    end
  end
end

# lib/my_app_web/schema/blog_types.ex
defmodule MyAppWeb.Schema.BlogTypes do
  use Absinthe.Schema.Notation
  import Absinthe.Resolution.Helpers, only: [dataloader: 2]

  object :post do
    field :id, non_null(:id)
    field :title, non_null(:string)
    field :body, non_null(:string)
    field :author, :user, resolve: dataloader(Accounts, :user)
  end

  object :blog_queries do
    field :posts, list_of(:post) do
      arg :status, :string
      resolve fn _parent, args, _resolution ->
        {:ok, Blog.list_posts(args)}
      end
    end
  end

  object :blog_mutations do
    field :create_post, :post do
      arg :title, non_null(:string)
      arg :body, non_null(:string)

      resolve fn _parent, args, %{context: %{current_user: user}} ->
        Blog.create_post(user, args)
      end
    end
  end
end
```

Each type module is small, focused, and maps to a context. The root schema is just wiring.

---

## Authorization

Use Absinthe middleware, not inline permission checks in resolvers. Load `current_user` in the Absinthe context via Plug, check permissions in middleware, resolve in the resolver.

❌ **Bad: inline authorization**

```elixir
field :delete_post, :post do
  arg :id, non_null(:id)

  resolve fn _parent, %{id: id}, %{context: %{current_user: user}} ->
    post = Blog.get_post!(id)

    # Permission check in resolver!
    if post.user_id == user.id or user.admin? do
      Blog.delete_post(post)
    else
      {:error, "Unauthorized"}
    end
  end
end
```

This repeats in every mutation. Authorization logic leaks into resolvers.

✅ **Good: middleware for authorization**

```elixir
# lib/my_app_web/schema/middleware/authorize.ex
defmodule MyAppWeb.Schema.Middleware.Authorize do
  @behaviour Absinthe.Middleware

  def call(resolution, permission) do
    with %{current_user: user} <- resolution.context,
         true <- has_permission?(user, permission) do
      resolution
    else
      _ ->
        resolution
        |> Absinthe.Resolution.put_result({:error, "Unauthorized"})
    end
  end

  defp has_permission?(user, :admin), do: user.admin?
  defp has_permission?(user, {:owns_resource, resource}), do: resource.user_id == user.id
  defp has_permission?(_user, _), do: false
end

# lib/my_app_web/schema/blog_types.ex
defmodule MyAppWeb.Schema.BlogTypes do
  use Absinthe.Schema.Notation
  alias MyAppWeb.Schema.Middleware

  object :blog_mutations do
    field :delete_post, :post do
      arg :id, non_null(:id)
      middleware Middleware.Authorize, :admin

      resolve fn _parent, %{id: id}, _resolution ->
        post = Blog.get_post!(id)
        Blog.delete_post(post)
      end
    end

    field :update_post, :post do
      arg :id, non_null(:id)
      arg :title, :string
      arg :body, :string

      resolve fn _parent, %{id: id} = args, _resolution ->
        post = Blog.get_post!(id)
        Blog.update_post(post, args)
      end
      middleware Middleware.Authorize, {:owns_resource, :post}
    end
  end
end
```

Pattern: load `current_user` early (in a Plug), reference it in middleware. Middleware runs before the resolver.

```elixir
# lib/my_app_web/plugs/graphql_context.ex
defmodule MyAppWeb.Plugs.GraphQLContext do
  @behaviour Plug

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _) do
    context = build_context(conn)
    Absinthe.Plug.put_options(conn, context: context)
  end

  defp build_context(conn) do
    case conn.assigns[:current_user] do
      nil -> %{}
      user -> %{current_user: user}
    end
  end
end

# lib/my_app_web/router.ex
forward "/graphql", Absinthe.Plug,
  schema: MyAppWeb.Schema,
  before: [MyAppWeb.Plugs.Authenticate, MyAppWeb.Plugs.GraphQLContext]
```

Now authorization is declarative and centralized.

---

## Query Complexity & Depth Limiting

GraphQL's power is its weakness: clients can request deeply nested or expensive queries. Without limits, a malicious or naive client can DoS your API.

### Depth limiting

Prevent deeply nested queries:

```elixir
# lib/my_app_web/schema.ex
defmodule MyAppWeb.Schema do
  use Absinthe.Schema

  def plugins do
    [Absinthe.Middleware.Dataloader] ++ Absinthe.Plugin.defaults()
  end

  def middleware(middleware, _field, %{identifier: :mutation}) do
    middleware ++ [MyAppWeb.Schema.Middleware.ChangesetErrors]
  end

  def middleware(middleware, _field, _object) do
    [ApolloTracing.Middleware.Tracing, ApolloTracing.Middleware.Caching] ++ middleware
  end

  # Add depth limiting
  def context(ctx) do
    loader =
      Dataloader.new()
      |> Dataloader.add_source(Accounts, Accounts.data())

    ctx
    |> Map.put(:loader, loader)
  end
end

# lib/my_app_web/router.ex
forward "/graphql", Absinthe.Plug,
  schema: MyAppWeb.Schema,
  analyze_complexity: true,
  max_complexity: 1000,
  json_codec: Jason,
  pipeline: {__MODULE__, :absinthe_pipeline}

def absinthe_pipeline(config, pipeline_opts) do
  config
  |> Absinthe.Plug.default_pipeline(pipeline_opts)
  |> Absinthe.Pipeline.insert_before(
    Absinthe.Phase.Document.Execution.Resolution,
    {Absinthe.Phase.Document.Complexity.Analysis, max_complexity: 1000}
  )
  |> Absinthe.Pipeline.insert_before(
    Absinthe.Phase.Document.Execution.Resolution,
    {Absinthe.Phase.Document.Validation.MaxDepth, max_depth: 10}
  )
end
```

### Complexity analysis

Assign cost to expensive fields:

```elixir
object :user do
  field :id, non_null(:id)
  field :email, non_null(:string)

  # Expensive: loads all posts
  field :posts, list_of(:post) do
    complexity fn args, child_complexity ->
      # Base cost + (number of items * child complexity)
      50 + (args[:limit] || 10) * child_complexity
    end
    resolve dataloader(Blog, :posts)
  end

  # Expensive: aggregation query
  field :post_count, :integer do
    complexity 20
    resolve fn user, _args, _resolution ->
      {:ok, Blog.count_user_posts(user.id)}
    end
  end
end
```

**Rule of thumb:**
- Max depth: 10 (prevents deeply nested queries like `user.posts.author.posts.author...`)
- Max complexity: 1000 (adjust based on schema shape and server capacity)

Without these limits, a single query can request thousands of records:

```graphql
# This would fetch 100 * 100 * 100 = 1M records!
{
  users(limit: 100) {
    posts(limit: 100) {
      comments(limit: 100) {
        id
      }
    }
  }
}
```

Complexity analysis rejects this before execution.

---

## Input Types vs Object Types

`input_object` for mutation arguments, `object` for query return types. Never reuse the same type for both — they evolve independently.

❌ **Bad: sharing types**

```elixir
# Don't do this!
object :user_input do
  field :name, :string
  field :email, :string
  field :bio, :string
end

# Later you add a computed field...
object :user_input do
  field :name, :string
  field :email, :string
  field :bio, :string
  field :post_count, :integer  # ❌ Can't include this in input!
end
```

This breaks when you add computed fields, associations, or fields that don't make sense as input.

✅ **Good: separate input and output types**

```elixir
# Output type: what the API returns
object :user do
  field :id, non_null(:id)
  field :name, :string
  field :email, non_null(:string)
  field :bio, :string
  field :post_count, :integer
  field :posts, list_of(:post), resolve: dataloader(Blog, :posts)
  field :inserted_at, non_null(:datetime)
  field :updated_at, non_null(:datetime)
end

# Input type: what mutations accept
input_object :user_input do
  field :name, :string
  field :email, :string
  field :bio, :string
end

input_object :update_user_input do
  field :name, :string
  field :bio, :string
  # Email not updatable
end

object :account_mutations do
  field :update_profile, :user do
    arg :input, non_null(:update_user_input)

    resolve fn _parent, %{input: input}, %{context: %{current_user: user}} ->
      Accounts.update_user(user, input)
    end
  end
end
```

Input and output types evolve independently. Output types grow with computed fields and associations. Input types stay minimal and focused on what clients can change.

---

## Error Handling

Resolvers return `{:ok, result}` or `{:error, message_or_changeset}`. Absinthe converts these to GraphQL errors. Changeset errors need translation.

❌ **Bad: raising in resolvers**

```elixir
resolve fn _parent, %{id: id}, _resolution ->
  post = Blog.get_post!(id)  # Raises if not found!
  {:ok, post}
end
```

If the post doesn't exist, this crashes the entire query. Other fields won't resolve.

✅ **Good: return error tuples**

```elixir
resolve fn _parent, %{id: id}, _resolution ->
  case Blog.get_post(id) do
    nil -> {:error, "Post not found"}
    post -> {:ok, post}
  end
end
```

### Structured errors with extensions

```elixir
resolve fn _parent, %{id: id}, _resolution ->
  case Blog.get_post(id) do
    nil ->
      {:error,
       message: "Post not found",
       extensions: %{code: "NOT_FOUND", resource: "post", id: id}}

    post ->
      {:ok, post}
  end
end
```

Clients can programmatically handle errors via the `code` extension.

### Changeset errors

```elixir
# lib/my_app_web/schema/middleware/changeset_errors.ex
defmodule MyAppWeb.Schema.Middleware.ChangesetErrors do
  @behaviour Absinthe.Middleware

  def call(resolution, _config) do
    %{resolution | errors: Enum.flat_map(resolution.errors, &handle_error/1)}
  end

  defp handle_error(%Ecto.Changeset{} = changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map(fn {field, messages} ->
      %{
        message: "#{field}: #{Enum.join(messages, ", ")}",
        extensions: %{
          code: "VALIDATION_ERROR",
          field: field,
          details: messages
        }
      }
    end)
  end

  defp handle_error(error), do: [error]
end

# lib/my_app_web/schema.ex
def middleware(middleware, _field, %{identifier: :mutation}) do
  middleware ++ [MyAppWeb.Schema.Middleware.ChangesetErrors]
end

def middleware(middleware, _field, _object) do
  middleware
end
```

Now changeset errors become structured GraphQL errors:

```json
{
  "errors": [
    {
      "message": "email: can't be blank",
      "extensions": {
        "code": "VALIDATION_ERROR",
        "field": "email",
        "details": ["can't be blank"]
      }
    }
  ]
}
```

---

## Subscriptions Pitfalls

Each subscription holds WebSocket state. Thousands of subscriptions = significant memory. Subscriptions are powerful but expensive.

### Use Phoenix.PubSub, not the default in-memory store

```elixir
# lib/my_app_web/endpoint.ex
defmodule MyAppWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :my_app
  use Absinthe.Phoenix.Endpoint

  # ...
end

# lib/my_app_web/schema.ex
defmodule MyAppWeb.Schema do
  use Absinthe.Schema

  subscription do
    field :post_created, :post do
      config fn _args, _resolution ->
        {:ok, topic: "posts"}
      end

      trigger :create_post, topic: fn _post ->
        "posts"
      end
    end
  end
end

# lib/my_app/blog.ex
def create_post(user, attrs) do
  %Post{}
  |> Post.changeset(Map.put(attrs, :user_id, user.id))
  |> Repo.insert()
  |> case do
    {:ok, post} ->
      # Trigger subscription
      Absinthe.Subscription.publish(
        MyAppWeb.Endpoint,
        post,
        post_created: "posts"
      )
      {:ok, post}

    {:error, changeset} ->
      {:error, changeset}
  end
end
```

### Scope subscriptions tightly

❌ **Bad: subscribe to all changes**

```elixir
subscription do
  field :post_updated, :post do
    config fn _args, _resolution ->
      {:ok, topic: "all_posts"}
    end
  end
end
```

Every client receives every update, then filters client-side. Wastes bandwidth and server resources.

✅ **Good: subscribe to specific resources**

```elixir
subscription do
  field :post_updated, :post do
    arg :post_id, non_null(:id)

    config fn %{post_id: post_id}, _resolution ->
      {:ok, topic: "post:#{post_id}"}
    end
  end
end

# Publish to specific topic
Absinthe.Subscription.publish(
  MyAppWeb.Endpoint,
  post,
  post_updated: "post:#{post.id}"
)
```

Only clients subscribed to this specific post receive the update.

### Memory considerations

Each subscription holds:
- WebSocket connection state
- Absinthe document AST
- Subscription arguments
- PubSub subscription

1000 subscriptions ≈ 50-100MB memory. Plan capacity accordingly.

**Consider Phoenix Channels instead** if you're not already using GraphQL heavily. Channels give you the same real-time capabilities with more control over serialization and message routing.

---

## Testing Absinthe

Test through the GraphQL endpoint, not by calling resolvers directly. This tests the full stack: parsing, validation, middleware, resolution.

```elixir
# test/my_app_web/schema/blog_types_test.exs
defmodule MyAppWeb.Schema.BlogTypesTest do
  use MyAppWeb.ConnCase, async: true
  import MyApp.Factory

  describe "posts query" do
    test "lists published posts", %{conn: conn} do
      user = insert(:user)
      post1 = insert(:post, user: user, status: "published")
      post2 = insert(:post, user: user, status: "draft")

      query = """
      {
        posts(status: "published") {
          id
          title
          author {
            id
            name
          }
        }
      }
      """

      conn =
        conn
        |> auth_user(user)
        |> post("/graphql", %{query: query})

      assert %{
               "data" => %{
                 "posts" => [
                   %{
                     "id" => id,
                     "title" => title,
                     "author" => %{"id" => author_id, "name" => author_name}
                   }
                 ]
               }
             } = json_response(conn, 200)

      assert id == to_string(post1.id)
      assert title == post1.title
      assert author_id == to_string(user.id)
    end
  end

  describe "createPost mutation" do
    test "creates a post", %{conn: conn} do
      user = insert(:user)

      query = """
      mutation CreatePost($input: CreatePostInput!) {
        createPost(input: $input) {
          id
          title
          body
        }
      }
      """

      variables = %{
        "input" => %{
          "title" => "New Post",
          "body" => "Post content"
        }
      }

      conn =
        conn
        |> auth_user(user)
        |> post("/graphql", %{query: query, variables: variables})

      assert %{
               "data" => %{
                 "createPost" => %{
                   "id" => _id,
                   "title" => "New Post",
                   "body" => "Post content"
                 }
               }
             } = json_response(conn, 200)
    end

    test "returns validation errors", %{conn: conn} do
      user = insert(:user)

      query = """
      mutation CreatePost($input: CreatePostInput!) {
        createPost(input: $input) {
          id
        }
      }
      """

      variables = %{
        "input" => %{
          "title" => "",
          "body" => ""
        }
      }

      conn =
        conn
        |> auth_user(user)
        |> post("/graphql", %{query: query, variables: variables})

      assert %{
               "errors" => [
                 %{
                   "message" => message,
                   "extensions" => %{"code" => "VALIDATION_ERROR"}
                 }
                 | _
               ]
             } = json_response(conn, 200)

      assert message =~ "can't be blank"
    end

    test "requires authentication", %{conn: conn} do
      query = """
      mutation CreatePost($input: CreatePostInput!) {
        createPost(input: $input) {
          id
        }
      }
      """

      variables = %{
        "input" => %{
          "title" => "New Post",
          "body" => "Post content"
        }
      }

      conn = post(conn, "/graphql", %{query: query, variables: variables})

      assert %{"errors" => [%{"message" => "Unauthorized"}]} = json_response(conn, 200)
    end
  end
end
```

### Testing Dataloader batching

```elixir
test "batches author queries" do
  users = insert_list(3, :user)
  posts = Enum.map(users, fn user -> insert(:post, user: user) end)

  query = """
  {
    posts {
      id
      author {
        id
        name
      }
    }
  }
  """

  # Capture SQL logs
  log =
    ExUnit.CaptureLog.capture_log(fn ->
      conn = build_conn() |> post("/graphql", %{query: query})
      assert json_response(conn, 200)
    end)

  # Should see 2 queries: one for posts, one batched for users
  assert log =~ "SELECT p0"
  assert log =~ "SELECT u0"

  # Should NOT see N queries for users
  refute log =~ "WHERE (u0.\"id\" = $1)"
  refute String.contains?(log, "SELECT u0") |> then(&(&1 > 2))
end
```

### Testing subscriptions

```elixir
test "notifies subscribers when post is created" do
  user = insert(:user)

  # Subscribe
  ref = push_doc(socket, """
    subscription {
      postCreated {
        id
        title
      }
    }
  """)

  assert_reply ref, :ok, %{subscriptionId: subscription_id}

  # Trigger subscription
  {:ok, post} = Blog.create_post(user, %{title: "New Post", body: "Content"})

  # Assert notification
  assert_push "subscription:data", push_data
  assert %{
    result: %{
      data: %{
        "postCreated" => %{
          "id" => id,
          "title" => "New Post"
        }
      }
    },
    subscriptionId: ^subscription_id
  } = push_data

  assert id == to_string(post.id)
end
```

---

## Common Mistakes

Consolidated list of pitfalls:

1. **No Dataloader** — N+1 queries on every nested field. Dataloader is not optional in production.

2. **Business logic in resolvers** — Resolvers should delegate to context functions, not contain queries or business rules.

3. **Monolithic schema file** — Split types by domain, mirror context boundaries.

4. **Inline authorization** — Use middleware for permission checks, not conditionals in resolvers.

5. **No query complexity limits** — Without depth and complexity limits, clients can DoS your API with deeply nested or wide queries.

6. **Reusing types for input and output** — Input and output types evolve independently. Sharing types breaks when you add computed fields or associations.

7. **Raising in resolvers** — Return `{:error, message}` tuples. Raising crashes the entire query.

8. **In-memory subscription store in clustered deploys** — Use Phoenix.PubSub as the subscription backend, not the default in-memory store.

9. **Not testing through the endpoint** — Test the full GraphQL stack (parsing, validation, middleware, resolution) by posting queries to `/graphql`, not by calling resolvers directly.

10. **Forgetting Dataloader context setup** — `context/1` must return a map with `:loader`, and each domain needs `Dataloader.add_source`.

11. **Wrong Dataloader cardinality** — Use `:many` for lists, `:one` for singular associations. Mismatch causes runtime errors.

12. **Broad subscription topics** — Subscribe to specific resource IDs, not `"all_posts"`. Filter server-side, not client-side.

13. **Not translating changeset errors** — Raw changeset errors aren't GraphQL-friendly. Use middleware to convert them to structured errors with extensions.

14. **Missing complexity costs on expensive fields** — Assign cost to aggregations, searches, and association loading. Default cost is 1, which underestimates expensive operations.

15. **Importing Ecto.Query in resolver files** — If you need query logic in a resolver module, you've leaked business logic. Move it to a context.

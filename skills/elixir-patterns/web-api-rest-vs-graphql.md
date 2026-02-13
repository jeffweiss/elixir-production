# Web API: REST vs GraphQL

## Decision Framework

Choose based on **consumers** and **data complexity**:

```
Who consumes this API?
  Single frontend you control
    → Simple data model (mostly CRUD)?
        → REST (simpler, standard HTTP semantics)
    → Complex/nested data, rapid frontend iteration?
        → GraphQL (clients fetch exactly what they need)

  Multiple frontends with different data needs
    → GraphQL (each client fetches its own shape)

  External/public consumers
    → REST (universally understood, HTTP cacheable, stable contracts)

  Server-to-server integration
    → REST (simpler, no schema/resolver overhead)

  Need real-time updates?
    → Phoenix Channels or LiveView (not GraphQL subscriptions unless already using GraphQL)
```

| Dimension | REST | GraphQL |
|-----------|------|---------|
| **Caching** | HTTP cache-control, CDN-friendly, browser caching | Requires custom caching (POST requests), application-layer cache keys |
| **Overfetching/underfetching** | Server decides fields; often ships too much or too little | Client specifies exact fields needed |
| **File uploads** | Native multipart/form-data support | Requires workarounds (multipart spec or separate endpoint) |
| **Tooling maturity** | Universal (curl, Postman, every language) | Growing (GraphiQL, Apollo, Relay), less universal |
| **Schema/documentation** | Manual (OpenAPI/Swagger) | Self-documenting via introspection |
| **Learning curve** | Simpler mental model (resources + verbs) | Requires understanding queries, mutations, resolvers, N+1 problems |
| **N+1 prevention** | Eager loading in controller (`Repo.preload`) | Requires Dataloader or manual batching |
| **Error handling** | HTTP status codes (404, 422, 500) | Always 200 OK; errors in response body |
| **Versioning** | URL versioning (`/v1/`, `/v2/`) or header-based | Schema evolution (deprecate fields, add new ones) |
| **Rate limiting** | Per-endpoint (standard middleware) | Complex (query depth/complexity scoring needed) |

**Rule of thumb**: Use REST for simple, public, or external APIs. Use GraphQL when multiple frontend clients need different data shapes and you control both ends.

## When Both: REST + GraphQL

Common pattern: **REST for public/external API, GraphQL for internal/frontend consumption**.

### Phoenix Router

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Public REST API
  scope "/api/v1", MyAppWeb do
    pipe_through :api

    resources "/users", UserController, only: [:index, :show, :create]
    resources "/posts", PostController, only: [:index, :show]
  end

  # Internal GraphQL API
  scope "/graphql" do
    pipe_through :api

    forward "/", Absinthe.Plug,
      schema: MyAppWeb.Schema,
      interface: :playground  # Remove in production
  end
end
```

### When This Makes Sense

- **Public REST**: Stable contracts for third-party integrations, caching via CDN
- **Internal GraphQL**: Flexible data fetching for your own web/mobile clients
- **Authentication**: Both can share the same `Guardian` or session-based auth pipeline

## Anti-patterns

### GraphQL for Everything

**Problem**: Small API with one consumer doesn't benefit from schema/resolver/Dataloader/subscription overhead.

**Example**: Admin dashboard with 5 CRUD endpoints. REST is simpler — no schema, no Dataloader config, no N+1 prevention tooling.

**Fix**: Use REST unless you have multiple clients with divergent data needs.

### REST for Deeply Nested Data

**Problem**: Fetching a user, their posts, each post's comments, and comment authors results in:
- Multiple round-trip requests (chatty API)
- Or massive compound endpoints (`/users/123?include=posts.comments.author`) that overfetch

**Example**:
```elixir
# Chatty: 4 requests
GET /users/123
GET /users/123/posts
GET /posts/456/comments
GET /users/789  # comment author
```

**Fix**: For deeply nested data with varying client needs, GraphQL lets clients fetch their exact tree in one request:

```graphql
query {
  user(id: 123) {
    email
    posts {
      title
      comments {
        body
        author { name }
      }
    }
  }
}
```

### GraphQL Subscriptions for Real-time

**Problem**: GraphQL subscriptions add complexity (WebSocket transport, subscription server, resolver lifecycle) when Phoenix already has Channels and LiveView.

**Example**: Notification feed. Instead of:
```graphql
subscription {
  notificationAdded(userId: 123) {
    id
    message
  }
}
```

Use Phoenix Channels:
```elixir
# In your channel
def handle_in("notifications:subscribe", _payload, socket) do
  {:noreply, socket}
end

# Broadcast from worker
MyAppWeb.Endpoint.broadcast("notifications:#{user_id}", "new", %{id: 1, message: "..."})
```

**Fix**: Use Phoenix Channels or LiveView for real-time. Only use GraphQL subscriptions if you're already heavily invested in GraphQL and need tight integration with the rest of your schema.

**See also**: `web-api-rest.md` for Phoenix REST patterns, `web-api-graphql.md` for Absinthe pitfalls.

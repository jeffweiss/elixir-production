# Ecto N+1 Queries and Preloading

## The N+1 Problem

Loading a list then querying each item's association individually — 1 query for the list + N queries for associations:

```elixir
# ❌ N+1 — 1 query for posts, then 1 query PER post for its author
posts = Repo.all(Post)
Enum.map(posts, fn post ->
  author = Repo.get!(User, post.author_id)  # Executes N times
  %{post | author: author}
end)

# ❌ Also N+1 — accessing association triggers lazy load per item
posts = Repo.all(Post)
Enum.map(posts, fn post ->
  post.author.name  # Each access fires a query
end)
```

## Preloading Strategies

### Repo.preload — Separate Query (Default)

Fires one additional query per association. Simple and works everywhere:

```elixir
# 2 queries: SELECT * FROM posts; SELECT * FROM users WHERE id IN (...)
posts =
  Post
  |> Repo.all()
  |> Repo.preload(:author)

# Nested preloads
posts =
  Post
  |> Repo.all()
  |> Repo.preload([:author, comments: :user])
```

**Best for**: Simple cases, when you already have loaded structs, LiveView `assign_async`.

### Inline Preload in Query

```elixir
# 2 queries, same as Repo.preload but in one expression
posts = Repo.all(from p in Post, preload: [:author, :comments])
```

### Join Preload — Single Query

Uses a JOIN to load data in one query. More efficient for belongs_to/has_one:

```elixir
# 1 query with JOIN
posts =
  from(p in Post,
    join: a in assoc(p, :author),
    preload: [author: a]
  )
  |> Repo.all()

# With filtering on the association
published_posts_by_active_authors =
  from(p in Post,
    join: a in assoc(p, :author),
    where: a.active == true,
    where: p.published == true,
    preload: [author: a]
  )
  |> Repo.all()
```

**Best for**: `belongs_to` and `has_one` associations, when you need to filter by the association.

**Caution with has_many**: JOIN + has_many produces duplicate parent rows. Ecto deduplicates, but the data transferred from the database is larger.

### Subquery Preload — Best of Both Worlds

Uses a subquery for the association, avoiding the duplication problem of joins:

```elixir
# 2 queries, but the second is constrained by the first
comments_query = from(c in Comment, order_by: [desc: c.inserted_at], limit: 5)

posts =
  from(p in Post,
    where: p.published == true,
    preload: [comments: ^comments_query]
  )
  |> Repo.all()
```

**Best for**: `has_many` associations where you want to filter, limit, or order the associated records.

## Decision Table

| Situation | Strategy | Queries | Notes |
|-----------|----------|---------|-------|
| Simple association loading | `Repo.preload(:assoc)` | N+1 → 2 | Easiest, works with existing structs |
| belongs_to / has_one | `join` + `preload` | 1 | Most efficient for single associations |
| has_many (all records) | `Repo.preload(:assoc)` or inline `preload:` | 2 | Separate query avoids row duplication |
| has_many (filtered/limited) | Subquery preload `preload: [assoc: ^query]` | 2 | Control over which associated records load |
| Need to filter by association | `join` + `where` + `preload` | 1 | Can't filter by association without a join |
| Already have loaded structs | `Repo.preload(structs, :assoc)` | 1 | Works on any list of structs |
| Deeply nested | `preload: [a: [b: :c]]` | 1 per level | Each level is a separate query |

## Ecto.assoc — Building Association Queries

For querying associations without preloading:

```elixir
# Get all comments for a specific user
user = Repo.get!(User, user_id)
comments = Repo.all(Ecto.assoc(user, :comments))

# Chain with further filtering
recent_comments =
  user
  |> Ecto.assoc(:comments)
  |> where([c], c.inserted_at > ago(7, "day"))
  |> order_by([c], desc: c.inserted_at)
  |> Repo.all()
```

## Avoiding N+1 in LiveView

```elixir
# ❌ N+1 in template — each row triggers a lazy load
def mount(_params, _session, socket) do
  posts = Repo.all(Post)  # No preload
  {:ok, assign(socket, :posts, posts)}
end

# In template: @posts |> Enum.map(& &1.author.name) — N queries!

# ✅ Preload before assigning
def mount(_params, _session, socket) do
  posts = Repo.all(from p in Post, preload: [:author, :comments])
  {:ok, assign(socket, :posts, posts)}
end
```

For streams:

```elixir
# ✅ Preload when building the stream
def mount(_params, _session, socket) do
  posts = Repo.all(from p in Post, preload: [:author]) 
  {:ok, stream(socket, :posts, posts)}
end
```

## Detecting N+1 Queries

### Ecto Telemetry

```elixir
# In test or dev, log queries with their source
config :my_app, MyApp.Repo,
  log: :debug  # Shows all queries in console
```

### Ecto.DevLogger

```elixir
# {:ecto_dev_logger, "~> 0.4"} — better formatted query logs
config :my_app, MyApp.Repo,
  log: false  # Disable default logger

# In application.ex
Ecto.DevLogger.install(MyApp.Repo)
```

### AppSignal / Datadog / New Relic

APM tools automatically detect N+1 patterns by correlating repeated similar queries within a single request.

## Common Mistakes

- **Accessing associations without preloading**: `post.author` raises `Ecto.Association.NotLoaded` unless preloaded. Always preload what the template/consumer needs.
- **Preloading everything**: Don't `preload: [:author, :comments, :tags, :category]` if you only need `:author`. Each preload is a query.
- **JOIN preload with has_many**: Produces N×M rows. Use separate query preload or subquery preload for has_many.
- **Preloading in a loop**: `Enum.map(posts, &Repo.preload(&1, :author))` is N queries. Preload the entire list at once: `Repo.preload(posts, :author)`.
- **Not using subquery preload for filtered associations**: If you need "last 5 comments per post," a regular preload loads ALL comments. Use `preload: [comments: ^limited_query]`.
- **Forgetting to preload after updates**: If you update a record and return it, associations are not automatically re-preloaded. Call `Repo.preload(updated, :assoc, force: true)` if needed.

**See also**: `database.md` for safe Ecto migrations, `production-quality/testing.md` for testing preloaded associations.

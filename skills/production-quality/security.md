# Security Practices

## Input Validation

```elixir
# ✅ Validate all user input with Ecto.Changeset
def create_user(attrs) do
  %User{}
  |> cast(attrs, [:name, :email, :age])
  |> validate_required([:name, :email])
  |> validate_format(:email, ~r/@/)
  |> validate_number(:age, greater_than: 0)
  |> Repo.insert()
end

# ❌ Don't trust input
def create_user(attrs) do
  Repo.insert(%User{
    name: attrs["name"],  # Unvalidated!
    email: attrs["email"]
  })
end
```

## SQL Injection Prevention

```elixir
# ✅ Use Ecto's parameterized queries
def find_by_email(email) do
  from(u in User, where: u.email == ^email)
  |> Repo.one()
end

# ❌ Don't interpolate into queries
def find_by_email(email) do
  query = "SELECT * FROM users WHERE email = '#{email}'"  # SQL injection!
  Ecto.Adapters.SQL.query!(Repo, query)
end
```

## XSS Prevention

```elixir
# Phoenix.HTML escapes by default
<p><%= @user_input %></p>  # ✅ Escaped automatically

# Explicit escape
<p><%= Phoenix.HTML.html_escape(@user_input) %></p>

# Raw HTML (use with caution)
<p><%= raw(@trusted_html) %></p>  # ❌ Only if you trust the source
```

## Authentication & Authorization

```elixir
# Scope routes by authentication
scope "/", MyAppWeb do
  pipe_through [:browser, :require_authenticated_user]

  live "/dashboard", DashboardLive
  live "/settings", SettingsLive
end

# Check permissions in context
def delete_post(user, post) do
  if user.id == post.author_id or user.admin? do
    Repo.delete(post)
  else
    {:error, :unauthorized}
  end
end
```

## Secrets Management

```elixir
# ✅ Use runtime configuration
config :my_app, MyApp.Mailer,
  adapter: Swoosh.Adapters.Sendgrid,
  api_key: System.get_env("SENDGRID_API_KEY")

# ❌ Don't commit secrets
config :my_app, MyApp.Mailer,
  api_key: "SG.abc123..."  # Never commit!
```

## Timing Attacks

Use constant-time comparison for tokens and secrets:

```elixir
# ✅ Constant-time comparison
Plug.Crypto.secure_compare(provided_token, stored_token)

# ❌ Early-return comparison leaks timing information
provided_token == stored_token
```

Use Argon2 or Bcrypt for passwords — they include constant-time comparison internally.

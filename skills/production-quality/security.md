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

**Phoenix 1.8+**: `phx.gen.auth` now generates passwordless **magic link** auth by default.
Email/password auth is available as a fallback option. Key additions:
- Magic link tokens with configurable expiry
- `require_sudo_mode` plug for sensitive operations (re-authentication)
- Simplified registration flow

```elixir
# Scope routes by authentication
scope "/", MyAppWeb do
  pipe_through [:browser, :require_authenticated_user]

  live "/dashboard", DashboardLive
  live "/settings", SettingsLive
end

# Phoenix 1.8+: require sudo mode for sensitive operations
scope "/", MyAppWeb do
  pipe_through [:browser, :require_authenticated_user, :require_sudo_mode]

  live "/settings/security", SecuritySettingsLive
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

**Note on Phoenix 1.8+ magic links**: Magic link auth avoids password storage entirely. Token security considerations:
- Tokens must be single-use and time-limited (default: 10 minutes)
- Always show "If that email exists, you will receive a link" to prevent enumeration
- Use `Plug.Crypto.secure_compare/2` for token verification

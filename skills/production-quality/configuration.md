# Configuration Management

## The Three Config Contexts

| Context | File | When Evaluated | Use For |
|---------|------|---------------|---------|
| Build-time | `config/config.exs` | During compilation | Logger level, Ecto repos, compiler options |
| Environment-specific build | `config/dev.exs`, `config/prod.exs`, `config/test.exs` | During compilation, per env | Dev server settings, test async, prod compile-time flags |
| Runtime | `config/runtime.exs` | At application start | Secrets, URLs, ports, database credentials, anything from env vars |

```
Compilation                     Deployment / Boot
    │                                │
    ├── config/config.exs            ├── config/runtime.exs
    ├── config/prod.exs              │   (reads System.get_env)
    │   (values baked into release)  │   (evaluated fresh each start)
    │                                │
    └── Release built ──────────────→└── Application starts
```

## The Critical Rule

**If the value comes from the environment (secrets, URLs, ports, feature flags), it MUST be in `runtime.exs`.**

```elixir
# ❌ BROKEN in release — evaluated at compile time, not at runtime
# config/prod.exs
config :my_app, MyApp.Repo,
  url: System.get_env("DATABASE_URL")  # Baked in at build time!

# ✅ CORRECT — evaluated when the release starts
# config/runtime.exs
config :my_app, MyApp.Repo,
  url: System.get_env("DATABASE_URL") ||
    raise "DATABASE_URL not set"
```

## Application.compile_env vs Application.get_env

| Function | When Evaluated | Use For |
|----------|---------------|---------|
| `Application.compile_env/3` | Compile time | Module attributes, constants, compile-time validation |
| `Application.get_env/3` | Runtime | Runtime configuration, values that change per environment |

```elixir
# Compile-time — value baked into the module's bytecode
# Raises at compile time if missing (good for required build config)
@pool_size Application.compile_env!(:my_app, :pool_size)

# Runtime — reads from application env at call time
def pool_size do
  Application.get_env(:my_app, :pool_size, 10)
end
```

### When to Use Each

```
Is this value the same for all deployments of this release?
  YES → compile_env (config.exs or prod.exs)
        Examples: Logger backends, Ecto adapter, Phoenix endpoint module
  NO  → runtime.exs + get_env
        Examples: DATABASE_URL, SECRET_KEY_BASE, API keys, ports
```

## runtime.exs Patterns

### Required Environment Variables

```elixir
# config/runtime.exs
import Config

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  config :my_app, MyApp.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

  config :my_app, MyAppWeb.Endpoint,
    http: [port: String.to_integer(System.get_env("PORT") || "4000")],
    secret_key_base: secret_key_base
end
```

### Feature Flags via Config

```elixir
# config/runtime.exs
config :my_app, :features,
  new_checkout: System.get_env("FEATURE_NEW_CHECKOUT") == "true",
  beta_api: System.get_env("FEATURE_BETA_API") == "true"

# Usage — reads at runtime
def checkout_enabled? do
  Application.get_env(:my_app, :features)[:new_checkout]
end
```

For high-frequency reads, move feature flags to `:persistent_term` (see `algorithms/ets-and-persistent-term.md`).

## Config Provider for External Sources

For pulling config from Vault, AWS Secrets Manager, or other sources at boot time:

```elixir
# mix.exs
def project do
  [
    releases: [
      my_app: [
        config_providers: [{MyApp.VaultConfigProvider, []}]
      ]
    ]
  ]
end
```

```elixir
defmodule MyApp.VaultConfigProvider do
  @behaviour Config.Provider

  def init(opts), do: opts

  def load(config, _opts) do
    {:ok, _} = Application.ensure_all_started(:req)

    secrets = fetch_from_vault()

    Config.Reader.merge(config,
      my_app: [
        {MyApp.Repo, [password: secrets["db_password"]]},
        {MyAppWeb.Endpoint, [secret_key_base: secrets["secret_key_base"]]}
      ]
    )
  end
end
```

## Common Mistakes

- **`System.get_env` in `config.exs` or `prod.exs`**: These are evaluated at compile time. The env var's value at build time is baked into the release — not the runtime value.
- **Not raising on missing required config**: `System.get_env("DATABASE_URL")` returns `nil` silently. Always `|| raise` for required variables. Fail fast at boot, not on first database query.
- **Using `Application.get_env` in module body**: Module body runs at compile time. Use `Application.compile_env` if you need it at compile time, or put it in a function for runtime.
- **Putting secrets in `config.exs`**: Secrets committed to source control. Always use `runtime.exs` + environment variables.
- **Not wrapping `String.to_integer` for env vars**: `System.get_env` returns strings. `config :my_app, port: System.get_env("PORT")` passes a string where an integer is expected.
- **Forgetting `import Config` in runtime.exs**: Without it, the `config` macro isn't available and you get a confusing compile error.

**See also**: `deployment.md` for release configuration, `ecto-preloading.md` and `database.md` for database configuration patterns.

# Deployment and Releases

## Mix Release

Elixir releases are self-contained bundles — compiled BEAM bytecode, the Erlang runtime, and your application, packaged for deployment without requiring Elixir/Erlang on the target machine.

### Building a Release

```elixir
# mix.exs — release configuration
def project do
  [
    app: :my_app,
    version: "1.0.0",
    releases: [
      my_app: [
        include_executables_for: [:unix],
        applications: [runtime_tools: :permanent]  # For remote debugging
      ]
    ]
  ]
end
```

```bash
# Build
MIX_ENV=prod mix release

# Start
_build/prod/rel/my_app/bin/my_app start

# Other commands
_build/prod/rel/my_app/bin/my_app stop
_build/prod/rel/my_app/bin/my_app remote  # IEx session on running node
_build/prod/rel/my_app/bin/my_app eval "MyApp.Release.migrate()"
```

### Release Migration Module

```elixir
defmodule MyApp.Release do
  @moduledoc """
  Tasks that run via `bin/my_app eval` in production.
  No Mix or build tools available — only compiled code.
  """
  @app :my_app

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end
```

## Health Check Endpoints

Every production app needs a health check endpoint for load balancers and orchestrators:

```elixir
# Simple health check — returns 200 if the app is running
scope "/health", MyAppWeb do
  get "/", HealthController, :check
  get "/ready", HealthController, :ready
end
```

```elixir
defmodule MyAppWeb.HealthController do
  use MyAppWeb, :controller

  # Liveness: is the BEAM running?
  def check(conn, _params) do
    send_resp(conn, 200, "ok")
  end

  # Readiness: can we serve traffic?
  def ready(conn, _params) do
    checks = %{
      database: check_database(),
      migrations: check_migrations()
    }

    if Enum.all?(checks, fn {_, v} -> v == :ok end) do
      json(conn, %{status: "ready", checks: checks})
    else
      conn
      |> put_status(503)
      |> json(%{status: "not_ready", checks: checks})
    end
  end

  defp check_database do
    case Ecto.Adapters.SQL.query(MyApp.Repo, "SELECT 1") do
      {:ok, _} -> :ok
      {:error, _} -> :error
    end
  end

  defp check_migrations do
    # Verify no pending migrations
    if MyApp.Repo
       |> Ecto.Migrator.migrations()
       |> Enum.any?(fn {status, _, _} -> status == :down end) do
      :pending
    else
      :ok
    end
  end
end
```

### Liveness vs Readiness

| Check | Purpose | Fails When | Response |
|-------|---------|-----------|----------|
| Liveness (`/health`) | "Is the process alive?" | BEAM crashed | Restart container |
| Readiness (`/health/ready`) | "Can it serve traffic?" | DB down, migrations pending | Remove from load balancer |

Kubernetes uses both: liveness probes restart unhealthy pods, readiness probes stop routing traffic to pods that can't serve.

## Graceful Shutdown

Phoenix and OTP handle graceful shutdown, but you need to configure timeouts:

```elixir
# config/runtime.exs
# Give in-flight requests time to complete before shutdown
config :my_app, MyAppWeb.Endpoint,
  drainer: [
    batch_size: 1_000,     # Close connections in batches
    batch_interval: 1_000, # ms between batches
    shutdown: 30_000       # Total drain timeout (ms)
  ]
```

```elixir
# For Oban: stop inserting new jobs and let running jobs finish
config :my_app, Oban,
  shutdown_grace_period: 30_000  # Wait up to 30s for running jobs
```

### Shutdown Order

1. Platform sends SIGTERM
2. Phoenix Endpoint drainer stops accepting new connections
3. In-flight HTTP requests and LiveView processes complete (up to drain timeout)
4. Oban stops fetching new jobs, waits for running jobs
5. Application supervision tree shuts down (children in reverse start order)
6. BEAM exits

**Key**: Set container/orchestrator shutdown timeout > application drain timeout. If your app needs 30s to drain, set the container timeout to 45s.

## Docker

```dockerfile
# Dockerfile for Elixir release
FROM hexpm/elixir:1.18.2-erlang-27.2.4-debian-bookworm-20250113-slim AS build

RUN apt-get update && apt-get install -y build-essential git
RUN mix local.hex --force && mix local.rebar --force

WORKDIR /app
ENV MIX_ENV=prod

# Dependencies first (cached layer)
COPY mix.exs mix.lock ./
COPY config/config.exs config/prod.exs config/
RUN mix deps.get --only $MIX_ENV && mix deps.compile

# Application code
COPY lib lib
COPY priv priv
COPY config/runtime.exs config/

# Compile and build release
RUN mix compile
RUN mix assets.deploy  # If using Phoenix assets
RUN mix release

# Runtime image — minimal
FROM debian:bookworm-slim AS runtime
RUN apt-get update && apt-get install -y libstdc++6 openssl libncurses5 locales \
    && apt-get clean && rm -rf /var/lib/apt/lists/*
RUN sed -i '/en_US.UTF-8/s/^# //' /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8

WORKDIR /app
COPY --from=build /app/_build/prod/rel/my_app ./

CMD ["bin/my_app", "start"]
```

## Environment-Specific Concerns

### Fly.io

```elixir
# config/runtime.exs
config :my_app, MyAppWeb.Endpoint,
  url: [host: System.get_env("PHX_HOST"), port: 443, scheme: "https"],
  http: [ip: {0, 0, 0, 0, 0, 0, 0, 0}, port: String.to_integer(System.get_env("PORT") || "4000")]

# Clustering on Fly.io
config :libcluster,
  topologies: [
    fly6pn: [strategy: Cluster.Strategy.DNSPoll,
             config: [polling_interval: 5_000,
                      query: System.get_env("FLY_APP_NAME") <> ".internal",
                      node_basename: System.get_env("FLY_APP_NAME")]]
  ]
```

### Kubernetes

```yaml
# Health check configuration
livenessProbe:
  httpGet:
    path: /health
    port: 4000
  initialDelaySeconds: 10
  periodSeconds: 10
readinessProbe:
  httpGet:
    path: /health/ready
    port: 4000
  initialDelaySeconds: 5
  periodSeconds: 5
terminationGracePeriodSeconds: 45  # > app drain timeout
```

## Common Mistakes

- **Forgetting `runtime_tools` in release**: Without it, you can't attach a remote IEx session or use Observer in production. Always include `applications: [runtime_tools: :permanent]`.
- **Running migrations at startup**: Migrations should run as a separate step (`bin/my_app eval "MyApp.Release.migrate()"`), not during application boot. Parallel pod startups would race on migrations.
- **Container timeout < drain timeout**: If the orchestrator kills the container before the app finishes draining, in-flight requests are dropped. Always set container timeout higher.
- **No readiness probe**: Without readiness, the load balancer sends traffic to pods that haven't finished starting or are shutting down.
- **Compile-time config for runtime values**: See `configuration.md` — using `Application.compile_env` for values that change per environment causes values to be baked into the release at build time.
- **Large Docker images**: Use multi-stage builds. The build stage has Elixir/Erlang/build tools; the runtime stage has only the release and minimal OS packages.

**See also**: `configuration.md` for runtime.exs patterns, `observability.md` for health check telemetry.

# Clustering Strategies

## Distributed Erlang Architecture

**Capabilities**:
- Transparent remote process communication
- Location transparency (`send/2` works across nodes)
- Distributed process registry
- Global name registration (`:global` module)
- Automatic network failure detection

**Limitations**:
- **Full-mesh topology**: Every node connects to every other node
- **O(n²) network overhead**: Breaks down at ~50-100 nodes
- **All-or-nothing security**: Either fully trusted or isolated
- **Global namespace conflicts**: Name collisions across nodes
- **Netsplits**: Network partitions create split-brain scenarios

**When Distributed Erlang is good enough**:
```elixir
# Small to medium clusters (< 50 nodes)
# Trusted network environment
# Simple clustering needs

# Setup with libcluster
config :libcluster,
  topologies: [
    k8s: [
      strategy: Cluster.Strategy.Kubernetes,
      config: [
        mode: :dns,
        kubernetes_node_basename: "myapp",
        kubernetes_selector: "app=myapp",
        polling_interval: 10_000
      ]
    ]
  ]
```

## Partisan: Large-Scale Clustering

**Why Partisan?**:
- Overlay network topology (not full-mesh)
- Support for 100s-1000s of nodes
- Configurable topologies (client-server, HyParView)
- Partial connectivity between nodes
- Better network efficiency

**Architecture**:
```elixir
# Partisan configuration
config :partisan,
  peer_service: Partisan.PeerService.HyParView,
  active_max_size: 6,
  passive_max_size: 30

# Partisan membership
Partisan.PeerService.join(:"node@other_host")

# Partisan messaging
Partisan.forward_message(node, pid, message)
```

**Use Partisan when**:
- Cluster size > 50 nodes
- Need custom network topology
- Building multi-datacenter systems
- Require gossip protocols
- Implementing peer-to-peer systems

## libcluster Integration

**Kubernetes DNS**:
```elixir
config :libcluster,
  topologies: [
    k8s: [
      strategy: Cluster.Strategy.Kubernetes,
      config: [
        mode: :dns,
        kubernetes_node_basename: "myapp",
        kubernetes_selector: "app=myapp",
        polling_interval: 10_000
      ]
    ]
  ]
```

**Consul**:
```elixir
config :libcluster,
  topologies: [
    consul: [
      strategy: Cluster.Strategy.Consul,
      config: [
        host: "consul.service.consul",
        port: 8500,
        service_name: "myapp",
        polling_interval: 10_000
      ]
    ]
  ]
```

**Gossip (UDP multicast)**:
```elixir
config :libcluster,
  topologies: [
    gossip: [
      strategy: Cluster.Strategy.Gossip,
      config: [
        port: 45892,
        multicast_addr: "230.1.1.251",
        multicast_ttl: 1
      ]
    ]
  ]
```

## Phoenix.PubSub for Distributed State

**Cluster-wide broadcasts**:
```elixir
# Broadcast to all nodes
Phoenix.PubSub.broadcast(
  MyApp.PubSub,
  "cache:invalidate",
  {:invalidate, key}
)

# Subscribe on all nodes
Phoenix.PubSub.subscribe(MyApp.PubSub, "cache:invalidate")

# Handle invalidation
def handle_info({:invalidate, key}, state) do
  LocalCache.delete(key)
  {:noreply, state}
end
```

**Distributed process registry**:
```elixir
# Use Phoenix.Tracker for distributed presence
defmodule MyApp.Presence do
  use Phoenix.Presence,
    otp_app: :my_app,
    pubsub_server: MyApp.PubSub
end

# Track user across cluster
MyApp.Presence.track(
  self(),
  "users:lobby",
  user.id,
  %{name: user.name, joined_at: System.system_time(:second)}
)

# List all users (all nodes)
MyApp.Presence.list("users:lobby")
```

## Distributed Debugging Patterns

### Distributed Tracing

```elixir
# Using :telemetry for distributed traces
:telemetry.span(
  [:myapp, :distributed_call],
  %{node: target_node, operation: :fetch_data},
  fn ->
    result = :rpc.call(target_node, Module, :function, [args])
    {result, %{status: :ok}}
  end
)

# Correlate across nodes with trace_id
def distributed_operation(trace_id) do
  Logger.metadata(trace_id: trace_id)

  :rpc.call(other_node, RemoteModule, :operation, [trace_id])
end
```

### Distributed Observer

```elixir
# Connect to production cluster
Node.connect(:"prod@node1.example.com")

# Start observer on remote node
:observer.start()

# Or use :rpc for information
:rpc.call(remote_node, :erlang, :memory, [])
:rpc.call(remote_node, :erlang, :system_info, [:process_count])
```

### Investigating Netsplits

```elixir
defmodule NetsplitDebug do
  # Detect and log partition events
  def monitor_cluster do
    :net_kernel.monitor_nodes(true, [:nodedown_reason])
  end

  def handle_info({:nodedown, node, reason}, state) do
    Logger.error("Node down: #{node}, reason: #{inspect(reason)}")
    log_cluster_state()
    {:noreply, state}
  end

  def log_cluster_state do
    Logger.info("""
    Cluster state:
    - Current node: #{node()}
    - Visible nodes: #{inspect(Node.list())}
    - Hidden nodes: #{inspect(Node.list(:hidden))}
    - Connected: #{inspect(Node.list(:connected))}
    """)
  end
end
```

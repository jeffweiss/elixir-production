# Phoenix Channels

## When to Use Channels vs LiveView

```
Real-time communication needed?
  Browser-based UI with server-rendered HTML?
    → LiveView (simpler, no client-side state management)
  Mobile app, IoT device, or custom client?
    → Phoenix Channels (raw WebSocket or long-polling)
  Need bidirectional communication from non-browser client?
    → Phoenix Channels
  Broadcasting server events to many clients?
    → Either works. LiveView for web, Channels for multi-platform.
```

| Feature | LiveView | Channels |
|---------|----------|----------|
| Client | Browser only | Any WebSocket client |
| Rendering | Server-side HTML diffs | Client handles rendering |
| State | Server process per connection | Minimal server state |
| Best for | Web UI, forms, dashboards | Mobile, IoT, APIs, games |
| JavaScript | Minimal (LiveView.js) | Custom client code required |
| Overhead | Higher (full process + HTML tracking) | Lower (just message passing) |

## Channel Basics

### Server Side

```elixir
# lib/my_app_web/channels/user_socket.ex
defmodule MyAppWeb.UserSocket do
  use Phoenix.Socket

  channel "room:*", MyAppWeb.RoomChannel
  channel "notifications:*", MyAppWeb.NotificationChannel

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    case MyApp.Auth.verify_socket_token(token) do
      {:ok, user_id} ->
        {:ok, assign(socket, :user_id, user_id)}
      {:error, _} ->
        :error
    end
  end

  def connect(_params, _socket, _connect_info), do: :error

  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.user_id}"
end
```

```elixir
# lib/my_app_web/channels/room_channel.ex
defmodule MyAppWeb.RoomChannel do
  use MyAppWeb, :channel

  @impl true
  def join("room:" <> room_id, _payload, socket) do
    if authorized?(socket.assigns.user_id, room_id) do
      send(self(), :after_join)
      {:ok, assign(socket, :room_id, room_id)}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  @impl true
  def handle_info(:after_join, socket) do
    # Send current state to the newly joined client
    messages = Chat.recent_messages(socket.assigns.room_id, limit: 50)
    push(socket, "messages:history", %{messages: messages})
    {:noreply, socket}
  end

  @impl true
  def handle_in("message:new", %{"body" => body}, socket) do
    case Chat.create_message(socket.assigns.room_id, socket.assigns.user_id, body) do
      {:ok, message} ->
        broadcast!(socket, "message:new", %{
          id: message.id,
          body: message.body,
          user_id: message.user_id,
          inserted_at: message.inserted_at
        })
        {:reply, :ok, socket}

      {:error, changeset} ->
        {:reply, {:error, %{errors: format_errors(changeset)}}, socket}
    end
  end

  @impl true
  def handle_in("typing:start", _payload, socket) do
    broadcast_from!(socket, "typing:start", %{user_id: socket.assigns.user_id})
    {:noreply, socket}
  end

  defp authorized?(user_id, room_id) do
    Chat.member?(user_id, room_id)
  end
end
```

### Client Side (JavaScript)

```javascript
import { Socket } from "phoenix"

const socket = new Socket("/socket", {
  params: { token: userToken }
})
socket.connect()

const channel = socket.channel("room:123", {})

channel.join()
  .receive("ok", resp => console.log("Joined", resp))
  .receive("error", resp => console.log("Failed to join", resp))

// Send messages
channel.push("message:new", { body: "Hello!" })
  .receive("ok", () => console.log("Sent"))
  .receive("error", resp => console.log("Error", resp))

// Receive broadcasts
channel.on("message:new", msg => {
  appendMessage(msg)
})

channel.on("typing:start", ({ user_id }) => {
  showTypingIndicator(user_id)
})
```

### Socket Configuration

```elixir
# lib/my_app_web/endpoint.ex
socket "/socket", MyAppWeb.UserSocket,
  websocket: [
    timeout: 45_000,           # Close idle connections after 45s
    compress: true,            # Enable per-message compression
    check_origin: ["//myapp.com", "//www.myapp.com"]
  ],
  longpoll: false              # Disable long-polling fallback if not needed
```

## Broadcasting Patterns

### From Anywhere (Not Just Channels)

```elixir
# Broadcast from a context module, Oban worker, or anywhere
MyAppWeb.Endpoint.broadcast("room:123", "message:new", %{
  body: "System notification",
  system: true
})

# Broadcast to a specific user (using socket id)
MyAppWeb.Endpoint.broadcast("user_socket:42", "disconnect", %{})
```

### PubSub for Cross-Node Broadcasting

Channels use Phoenix.PubSub internally. For multi-node clusters, configure a distributed adapter:

```elixir
# config/config.exs — works across nodes automatically
config :my_app, MyAppWeb.Endpoint,
  pubsub_server: MyApp.PubSub

# In application.ex
{Phoenix.PubSub, name: MyApp.PubSub}
```

## Authentication

### Token-Based (Recommended)

```elixir
# Generate token in controller/LiveView (send to client)
def create_socket_token(conn, user) do
  Phoenix.Token.sign(conn, "user socket", user.id)
end

# Verify in UserSocket.connect/3
def connect(%{"token" => token}, socket, _connect_info) do
  case Phoenix.Token.verify(socket, "user socket", token, max_age: 86_400) do
    {:ok, user_id} -> {:ok, assign(socket, :user_id, user_id)}
    {:error, _} -> :error
  end
end
```

## Presence (Who's Online)

```elixir
defmodule MyAppWeb.Presence do
  use Phoenix.Presence,
    otp_app: :my_app,
    pubsub_server: MyApp.PubSub
end

# In channel
def handle_info(:after_join, socket) do
  {:ok, _} = MyAppWeb.Presence.track(socket, socket.assigns.user_id, %{
    online_at: System.system_time(:second),
    device: "web"
  })

  push(socket, "presence_state", MyAppWeb.Presence.list(socket))
  {:noreply, socket}
end
```

## Testing Channels

```elixir
defmodule MyAppWeb.RoomChannelTest do
  use MyAppWeb.ChannelCase

  setup do
    user = insert(:user)
    room = insert(:room, members: [user])
    token = Phoenix.Token.sign(MyAppWeb.Endpoint, "user socket", user.id)

    {:ok, socket} = connect(MyAppWeb.UserSocket, %{"token" => token})
    {:ok, _, socket} = subscribe_and_join(socket, "room:#{room.id}", %{})

    %{socket: socket, user: user, room: room}
  end

  test "sends message and broadcasts", %{socket: socket} do
    ref = push(socket, "message:new", %{"body" => "hello"})
    assert_reply ref, :ok
    assert_broadcast "message:new", %{body: "hello"}
  end

  test "rejects unauthorized join" do
    other_user = insert(:user)
    token = Phoenix.Token.sign(MyAppWeb.Endpoint, "user socket", other_user.id)
    {:ok, socket} = connect(MyAppWeb.UserSocket, %{"token" => token})

    assert {:error, %{reason: "unauthorized"}} =
      subscribe_and_join(socket, "room:#{room.id}", %{})
  end
end
```

## Common Mistakes

- **Using Channels when LiveView suffices**: If the client is a browser and you're building UI, LiveView is simpler. Use Channels for non-browser clients or when you need minimal server-side state.
- **Not authenticating socket connections**: Always verify tokens in `connect/3`. An unauthenticated socket can join any channel with the matching topic pattern.
- **Not authorizing channel joins**: Authentication (who are you?) is separate from authorization (can you join this room?). Check both.
- **Broadcasting large payloads**: Channels send the full payload to every subscriber. For large data, send an ID and let clients fetch details via API.
- **Not handling disconnections in the client**: Mobile clients disconnect frequently. Implement reconnection logic and state reconciliation on rejoin.
- **Forgetting `check_origin`**: Without origin checking, any website can open a WebSocket to your server. Always set `check_origin` in production.

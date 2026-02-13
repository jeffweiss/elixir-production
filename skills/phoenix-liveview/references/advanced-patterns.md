# Advanced LiveView Patterns

## Async Operations

### assign_async/3

Load data asynchronously without blocking mount. The task runs in a linked process with error handling.

```elixir
def mount(%{"slug" => slug}, _, socket) do
  {:ok,
   socket
   |> assign(:page_title, "Dashboard")
   |> assign_async(:org, fn -> {:ok, %{org: fetch_org!(slug)}} end)
   |> assign_async([:profile, :rank], fn ->
     {:ok, %{profile: fetch_profile(slug), rank: fetch_rank(slug)}}
   end)}
end
```

**Template** — use `async_result` component for loading/error/success states:

```heex
<.async_result :let={org} assign={@org}>
  <:loading>Loading organization...</:loading>
  <:failed :let={_failure}>Failed to load organization</:failed>
  {org.name}
</.async_result>
```

**Critical rule**: Never pass the socket into the async function — it copies the entire struct to the Task process. Capture the specific assigns you need:

```elixir
# ❌ Copies entire socket to Task process
assign_async(:org, fn -> {:ok, %{org: fetch_org(socket.assigns.slug)}} end)

# ✅ Capture only what you need
slug = socket.assigns.slug
assign_async(:org, fn -> {:ok, %{org: fetch_org(slug)}} end)
```

### start_async/3

For lower-level control when `assign_async` doesn't fit. You handle the result manually via `handle_async/3`:

```elixir
def mount(%{"id" => id}, _, socket) do
  {:ok,
   socket
   |> assign(:org, AsyncResult.loading())
   |> start_async(:fetch_org, fn -> fetch_org!(id) end)}
end

def handle_async(:fetch_org, {:ok, org}, socket) do
  {:noreply, assign(socket, :org, AsyncResult.ok(socket.assigns.org, org))}
end

def handle_async(:fetch_org, {:exit, reason}, socket) do
  {:noreply, assign(socket, :org, AsyncResult.failed(socket.assigns.org, {:exit, reason}))}
end
```

### stream_async/4

Populate streams asynchronously:

```elixir
def mount(_params, _session, socket) do
  {:ok,
   socket
   |> stream_configure(:posts, dom_id: &("post-#{&1.id}"))
   |> stream_async(:posts, fn -> {:ok, Blog.list_posts()} end)}
end
```

### Testing Async Operations

Always call `render_async/2` in tests to wait for async operations to complete:

```elixir
{:ok, view, _html} = live(conn, "/dashboard")
html = render_async(view)
assert html =~ "Organization Name"
```

Not calling `render_async/2` can cause database connection errors when the test process exits before the async task completes.

## Reusable Widget Pattern with attach_hook/4

LiveComponents can't access the process mailbox for PubSub. Embedded LiveViews add overhead and complex communication. The `attach_hook/4` pattern combines function components with lifecycle hooks for truly independent widgets.

### Pattern

```elixir
defmodule MyAppWeb.NotificationWidget do
  @moduledoc """
  Self-contained notification widget. Manages its own state, events,
  and PubSub subscriptions without coupling to the parent LiveView.
  """
  import Phoenix.Component
  import Phoenix.LiveView

  def on_mount(:default, _params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(MyApp.PubSub, "notifications:#{socket.assigns.current_user.id}")
    end

    socket =
      socket
      |> assign(:notifications, [])
      |> assign(:notification_count, 0)
      |> attach_hook(:notification_handler, :handle_info, &handle_notification_info/2)
      |> attach_hook(:notification_events, :handle_event, &handle_notification_event/3)

    {:cont, socket}
  end

  defp handle_notification_info({:new_notification, notif}, socket) do
    {:cont,
     socket
     |> update(:notifications, &[notif | &1])
     |> update(:notification_count, &(&1 + 1))}
  end

  defp handle_notification_info(_msg, socket), do: {:cont, socket}

  defp handle_notification_event("dismiss-notification", %{"id" => id}, socket) do
    {:halt,
     socket
     |> update(:notifications, &Enum.reject(&1, fn n -> n.id == id end))
     |> update(:notification_count, &max(&1 - 1, 0))}
  end

  defp handle_notification_event(_event, _params, socket), do: {:cont, socket}

  # Function component for rendering
  def notifications(assigns) do
    ~H"""
    <div class="notifications" id="notification-widget">
      <span class="badge">{@notification_count}</span>
      <div :for={notif <- @notifications}>
        <p>{notif.message}</p>
        <button phx-click="dismiss-notification" phx-value-id={notif.id}>Dismiss</button>
      </div>
    </div>
    """
  end
end
```

**Usage** — mount in router and render in template:

```elixir
# Router
live_session :authenticated,
  on_mount: [
    {MyAppWeb.UserAuth, :ensure_authenticated},
    {MyAppWeb.NotificationWidget, :default}
  ] do
  live "/dashboard", DashboardLive
end

# Template
<MyAppWeb.NotificationWidget.notifications
  notifications={@notifications}
  notification_count={@notification_count}
/>
```

### When to Use Each Pattern

| Need | LiveComponent | Embedded LiveView | attach_hook/4 |
|------|-------------|-------------------|---------------|
| Self-contained UI with own state | Good | Good | Good |
| PubSub subscriptions | Cannot (no mailbox) | Can | Can |
| Independent event handling | Limited (parent delegates) | Full | Full |
| Performance overhead | Low | Higher (separate process) | Low |
| Reusable across LiveViews | Yes (but coupled) | Yes (but heavy) | Yes (truly independent) |

## State Management During Reconnects

### phx-auto-recover

Forms can automatically recover state during reconnection:

```heex
<.form for={@form} phx-change="validate" phx-submit="save" phx-auto-recover="recover">
  <.input field={@form[:name]} />
  <.input field={@form[:email]} />
</.form>
```

```elixir
def handle_event("recover", params, socket) do
  # Called during reconnect with the last form state from the DOM
  changeset = Accounts.change_user(socket.assigns.user, params["user"])
  {:noreply, assign(socket, form: to_form(changeset))}
end
```

### Ephemeral UI State

For non-form state that should survive reconnects (dropdowns, tabs, scroll position), cache in the DOM:

```heex
<div id="dashboard" phx-hook="StateCache" data-active-tab={@active_tab}>
  <!-- content -->
</div>
```

```javascript
// Hook recovers state from DOM attributes after reconnect
Hooks.StateCache = {
  mounted() {
    this.handleEvent("restore_state", ({tab}) => {
      // restore UI state
    })
  },
  reconnected() {
    const tab = this.el.dataset.activeTab
    this.pushEvent("restore_tab", {tab})
  }
}
```

### Delay Reconnecting Message

For short disconnects (mobile network blips), delay showing the "reconnecting..." overlay:

```javascript
// app.js
let liveSocket = new LiveSocket("/live", Socket, {
  // Don't show reconnecting UI for disconnects under 1 second
  disconnectedTimeout: 1000
})
```

## Common Mistakes

- **Passing socket into assign_async** — copies entire socket struct to Task process. Capture specific assigns instead.
- **Not calling render_async in tests** — async operations may not complete before assertions, causing flaky tests and DB connection errors.
- **Using LiveComponent for PubSub widgets** — LiveComponents run in the parent process but can't receive `handle_info`. Use `attach_hook` pattern instead.
- **Not handling reconnect state** — users lose form progress and UI state on mobile disconnects. Use `phx-auto-recover` and DOM caching.
- **Blocking mount with data loading** — use `assign_async` for any data that takes >50ms to load. Users see a loading state immediately instead of a blank page.

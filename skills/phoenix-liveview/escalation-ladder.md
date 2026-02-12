# LiveView Interactivity Escalation Ladder

Start at the top. Only reach for heavier patterns when simpler ones can't do the job.

## Level 0: Static LiveView (Assigns Only)

Replace dead views with LiveView for live navigation, but no interactivity yet.

| Need | Pattern | Mechanism |
|------|---------|-----------|
| Display data from the database | Assign in `mount/3` | `assign(socket, :users, list_users())` |
| Conditional rendering | `:if` / `:for` attributes | `<div :if={@user}>`, `<li :for={item <- @items}>` |
| Multi-branch display | `case` in template | `<%= case @status do %>` |
| Page title | Assign `:page_title` | `assign(socket, :page_title, "Dashboard")` |
| Shared layout data | `on_mount` hooks | `live_session :default, on_mount: [...]` |

```elixir
def mount(_params, _session, socket) do
  {:ok, assign(socket, :users, Accounts.list_users())}
end
```

**Stay here when**: The page just displays data. No user input, no updates after load.

**Move to Level 1 when**: Users need to click, navigate, or trigger actions.

## Level 1: Events and Navigation

Handle user clicks, navigate between pages, show flash messages.

| Need | Pattern | Mechanism |
|------|---------|-----------|
| Button click | `phx-click` event | `<button phx-click="delete" phx-value-id={@id}>` |
| Navigate within LiveView | `push_navigate/2` | `push_navigate(socket, to: ~p"/users/#{user}")` |
| Full redirect (leave LiveView) | `redirect/2` | `redirect(socket, to: ~p"/login")` |
| Success/error banners | Flash messages | `put_flash(socket, :info, "Saved!")` |
| Confirmation dialog | `data-confirm` | `<button phx-click="delete" data-confirm="Sure?">` |
| Pass data with events | `phx-value-*` attributes | `phx-value-id={item.id}` -> `%{"id" => id}` in handler |

```elixir
def handle_event("delete", %{"id" => id}, socket) do
  Accounts.delete_user!(id)

  {:noreply,
   socket
   |> put_flash(:info, "User deleted")
   |> push_navigate(to: ~p"/users")}
end
```

**Stay here when**: Interactions are simple click -> action -> navigate/flash.

**Move to Level 2 when**: You need form input with validation feedback.

## Level 2: Forms with Live Validation

The most common LiveView pattern. Changeset-backed forms with real-time validation.

| Need | Pattern | Mechanism |
|------|---------|-----------|
| Render a form | `to_form/2` + `<.simple_form>` | `assign(socket, :form, to_form(changeset))` |
| Live validation on keystrokes | `phx-change` event | Set `action: :validate` on changeset |
| Submit form | `phx-submit` event | Handle `{:ok, _}` and `{:error, changeset}` |
| Field access in template | Bracket syntax | `@form[:email]` (NOT `@form.email`) |
| Debounce validation | `phx-debounce` | `<.input phx-debounce="300">` |

```elixir
def mount(_params, _session, socket) do
  {:ok, assign(socket, :form, to_form(Accounts.change_user(%User{})))}
end

def handle_event("validate", %{"user" => params}, socket) do
  changeset =
    %User{}
    |> Accounts.change_user(params)
    |> Map.put(:action, :validate)

  {:noreply, assign(socket, :form, to_form(changeset))}
end

def handle_event("save", %{"user" => params}, socket) do
  case Accounts.create_user(params) do
    {:ok, user} ->
      {:noreply,
       socket
       |> put_flash(:info, "Created!")
       |> push_navigate(to: ~p"/users/#{user}")}

    {:error, changeset} ->
      {:noreply, assign(socket, :form, to_form(changeset))}
  end
end
```

**Template:**

```heex
<.simple_form for={@form} phx-change="validate" phx-submit="save">
  <.input field={@form[:name]} label="Name" />
  <.input field={@form[:email]} type="email" label="Email" />
  <:actions>
    <.button>Save</.button>
  </:actions>
</.simple_form>
```

**Stay here when**: You have CRUD forms with validation. This covers most apps.

**Move to Level 3 when**: You have dynamic lists that update without full page reload.

## Level 3: Streams for Dynamic Lists

Efficient DOM patching for lists — add, remove, reorder items without re-rendering everything.

| Need | Pattern | Mechanism |
|------|---------|-----------|
| Render a dynamic list | `stream/3` in mount | `stream(socket, :items, list_items())` |
| Add item to list | `stream_insert/4` | `stream_insert(socket, :items, new_item)` |
| Remove item from list | `stream_delete/3` | `stream_delete(socket, :items, item)` |
| Replace entire list | `stream/4` with reset | `stream(socket, :items, new_list, reset: true)` |
| Control insert position | `:at` option | `stream_insert(socket, :items, item, at: 0)` for prepend |
| Paginate / infinite scroll | Stream + page tracking | Append pages with `stream/4` at `-1` |

```elixir
# Mount
stream(socket, :users, Accounts.list_users())

# Template — container ID MUST match stream name
<div id="users" phx-update="stream">
  <div :for={{dom_id, user} <- @streams.users} id={dom_id}>
    <%= user.name %>
  </div>
</div>
```

**Critical rules:**
- Container `id` must match stream name (`id="users"` for `:users` stream)
- Each item must have unique `id` via `{dom_id, item}` tuple
- Use `@streams.name` (not `@name`) in `:for`

**Stay here when**: Lists change from user actions in the current session.

**Move to Level 4 when**: Data changes from outside the current session (other users, background jobs, PubSub).

## Level 4: Real-Time Updates (PubSub + Async)

Data arrives from external sources — other users, background jobs, timers.

| Need | Pattern | Mechanism |
|------|---------|-----------|
| Receive broadcasts from other processes | PubSub subscribe + `handle_info` | Subscribe in `mount` (when `connected?`), handle in `handle_info` |
| Load slow data without blocking mount | `assign_async/3` | Renders loading state, then fills in when ready |
| Periodic refresh | `Process.send_after` | Self-send `:tick` message on interval |
| Presence tracking ("who's online") | `Phoenix.Presence` | Track joins/leaves, broadcast diffs |
| Optimistic updates with rollback | Immediate stream update + async verify | Update UI first, revert if server rejects |

```elixir
def mount(_params, _session, socket) do
  if connected?(socket) do
    Phoenix.PubSub.subscribe(MyApp.PubSub, "orders")
  end

  {:ok,
   socket
   |> stream(:orders, Orders.list_recent())
   |> assign_async(:stats, fn ->
     {:ok, %{stats: Orders.calculate_stats()}}
   end)}
end

def handle_info({:new_order, order}, socket) do
  {:noreply, stream_insert(socket, :orders, order, at: 0)}
end
```

**Key rule**: Only subscribe to PubSub when `connected?(socket)` — mount runs twice (disconnected HTTP render, then connected WebSocket).

**Stay here when**: Server-side Elixir can handle all reactivity.

**Move to Level 5 when**: You need client-side DOM manipulation, third-party JS libraries, or browser APIs.

## Level 5: JavaScript Hooks

Escape hatch to the client. Use sparingly — every hook is code outside LiveView's declarative model.

| Need | Pattern | Mechanism |
|------|---------|-----------|
| Initialize a JS library on an element | `phx-hook` + `mounted()` | Map library, chart library, rich text editor |
| React to server-pushed data in JS | `this.handleEvent()` | Server calls `push_event/3`, JS hook receives |
| Send data from JS to server | `this.pushEvent()` | JS hook pushes, server `handle_event/3` receives |
| Update JS when assigns change | `updated()` callback | Fires when element's attributes change |
| Clean up on removal | `destroyed()` callback | Remove event listeners, destroy library instances |
| Pass data to hook | `data-*` attributes | `data-lat={@lat}` -> `this.el.dataset.lat` in JS |

```elixir
# Server — push event to JS
push_event(socket, "chart-data", %{points: points})
```

```javascript
// JS hook
Hooks.Chart = {
  mounted() {
    this.chart = new Chart(this.el, {})
    this.handleEvent("chart-data", ({points}) => {
      this.chart.update(points)
    })
  },
  destroyed() {
    this.chart.destroy()
  }
}
```

**Key rule**: Hook element MUST have a unique `id`. No `id` = hook silently doesn't work.

**When NOT to use hooks**:
- Showing/hiding elements -> use `:if` or CSS classes via assigns
- Simple animations -> use CSS transitions triggered by assign changes
- Form validation -> use changesets (Level 2)

## Escalation Decision Flowchart

```
What does the page need to do?
  Display data, no interaction       -> Level 0 (assigns only)
  Buttons, links, navigation         -> Level 1 (events)
  Form input with validation         -> Level 2 (forms + changesets)
  Dynamic list add/remove/reorder    -> Level 3 (streams)
  Data from other users/background   -> Level 4 (PubSub + async)
  Browser APIs or JS libraries       -> Level 5 (hooks)
```

## Authentication Scopes

Phoenix 1.7+ uses router scopes for authentication:

```elixir
# In router.ex
scope "/", MyAppWeb do
  pipe_through [:browser, :require_authenticated_user]

  live_session :require_authenticated_user,
    on_mount: [{MyAppWeb.UserAuth, :ensure_authenticated}] do
    live "/dashboard", DashboardLive
    live "/settings", SettingsLive
  end
end

scope "/", MyAppWeb do
  pipe_through [:browser, :redirect_if_user_is_authenticated]

  live_session :redirect_if_user_is_authenticated,
    on_mount: [{MyAppWeb.UserAuth, :redirect_if_user_authenticated}] do
    live "/users/register", UserRegistrationLive
    live "/users/log_in", UserLoginLive
  end
end

scope "/", MyAppWeb do
  pipe_through [:browser]

  live_session :current_user,
    on_mount: [{MyAppWeb.UserAuth, :mount_current_user}] do
    live "/", HomeLive
  end
end
```

**Common on_mount hooks:**
- `:ensure_authenticated` — Require logged-in user, redirect to login if not
- `:redirect_if_user_authenticated` — Redirect logged-in users away (for login/register pages)
- `:mount_current_user` — Load current user if present, allow anonymous if not

## Real-World Patterns

### Infinite Scroll with Streams

```elixir
def mount(_params, _session, socket) do
  {:ok,
   socket
   |> assign(:page, 1, :per_page, 20)
   |> stream(:items, list_items(1, 20))}
end

def handle_event("load_more", _, socket) do
  %{page: page, per_page: per_page} = socket.assigns
  next_page = page + 1
  items = list_items(next_page, per_page)

  {:noreply,
   socket
   |> assign(:page, next_page)
   |> stream(:items, items, at: -1)}
end
```

### Debounced Search

```elixir
def handle_event("search", %{"query" => query}, socket) do
  Process.send_after(self(), {:run_search, query}, 300)
  {:noreply, assign(socket, :query, query)}
end

def handle_info({:run_search, query}, socket) do
  if socket.assigns.query == query do
    results = search(query)
    {:noreply, stream(socket, :results, results, reset: true)}
  else
    {:noreply, socket}
  end
end
```

## Testing LiveView

```elixir
test "creates item when form is valid", %{conn: conn} do
  {:ok, lv, _html} = live(conn, ~p"/items/new")

  # Test validation
  lv
  |> form("#item-form", item: %{name: ""})
  |> render_change()

  assert has_element?(lv, "#item-form .invalid-feedback")

  # Test submission
  {:ok, _lv, html} =
    lv
    |> form("#item-form", item: %{name: "Buy milk"})
    |> render_submit()
    |> follow_redirect(conn)

  assert html =~ "Item created successfully"
  assert html =~ "Buy milk"
end
```

**Key testing points:**
- Use `live/2` to mount LiveView in tests
- Use `has_element?/2` to check for presence
- Use `form/2` with `render_change/1` for validation
- Use `render_submit/1` and `follow_redirect/2` for form submission
- Test PubSub integration by broadcasting messages

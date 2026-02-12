---
name: phoenix-liveview
description: Use when working with LiveView streams, forms with changesets and to_form, phx-hook JavaScript integration, live_session authentication scopes, or debugging LiveView gotchas (no else-if, stream ID mismatches, mount runs twice)
---

# Phoenix LiveView Patterns

## Overview

Start with server-rendered HTML. Escalate through streams, assign_async, PubSub, and hooks only when simpler patterns can't do the job.

## Escalation Ladder

| Level | Need | Pattern |
|-------|------|---------|
| L0 | Display data, no interaction | Assigns in `mount/3` |
| L1 | Buttons, links, navigation | `phx-click`, `push_navigate/2`, flash |
| L2 | Form input with validation | `to_form/2` + changeset + `phx-change`/`phx-submit` |
| L3 | Dynamic list add/remove/reorder | `stream/3`, `stream_insert/4`, `stream_delete/3` |
| L4 | Data from other users/background | PubSub subscribe, `assign_async/3`, `handle_info` |
| L5 | Browser APIs or JS libraries | `phx-hook` with `mounted()`/`destroyed()` |

## Quick Reference

| Operation | Function | Notes |
|-----------|----------|-------|
| Add stream item | `stream_insert(socket, :name, item, at: pos)` | Default appends (`:at -1`) |
| Remove stream item | `stream_delete(socket, :name, item)` | Requires item with `:id` |
| Reset stream | `stream(socket, :name, items, reset: true)` | Clears existing items |
| Push event to client | `push_event(socket, "event-name", %{data})` | Received by JS hooks |
| Navigate | `push_navigate(socket, to: path)` | Client-side navigation |
| Redirect | `redirect(socket, to: path)` | Server redirect |

## Common Gotchas

- **No `else if` in HEEx** — use `case`/`cond` or multiple `:if` attributes
- **Stream ID mismatch** — container `id` MUST match stream name (`id="users"` for `:users`)
- **Mount runs twice** — once for HTTP, once for WebSocket; check `connected?(socket)` for PubSub
- **Form field access** — use `@form[:email]` not `@form.email`
- **Missing `to_form`** — always convert changesets with `to_form/2`
- **Hook needs `id`** — hook element MUST have unique `id` or it silently won't work
- **Attribute interpolation** — use `{@class}` not `@class` in HEEx attributes

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Forgot `:id` on `phx-update` element | Add unique `id` matching stream name |
| Form not using `to_form/2` | Always convert changesets with `to_form/2` |
| Missing `:action` on validation | Set `Map.put(:action, :validate)` on changeset |
| Race condition in async | Use `assign_async/3` instead of manual async |
| Hook not receiving events | Check element has unique `id` and hook name matches |

## Reference Files

- `escalation-ladder.md` — Full L0-L5 with code examples, auth scopes, real-world patterns, testing
- `references/streams.md` — Comprehensive stream patterns and pagination
- `references/forms.md` — Advanced form patterns including uploads and nested forms
- `references/hooks.md` — JavaScript hooks with third-party library integration
- `references/authentication.md` — Role-based authorization and session management

## Related Skills

- **elixir-patterns**: OTP patterns (GenServer, supervision) underlying LiveView
- **production-quality**: Testing strategies and observability

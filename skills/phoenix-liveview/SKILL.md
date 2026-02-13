---
name: phoenix-liveview
description: Use when working with Phoenix LiveView, Plug pipelines, controllers, JSON APIs, channels, streams, forms, phx-hook, authentication, or debugging Phoenix/LiveView gotchas
---

# Phoenix Patterns

## Overview

Start with server-rendered HTML. Escalate through streams, assign_async, PubSub, and hooks only when simpler patterns can't do the job. For non-LiveView needs (APIs, mobile clients), use Plug pipelines and Channels.

## Escalation Ladder

| Level | Need | Pattern |
|-------|------|---------|
| L0 | Display data | Assigns in `mount/3` |
| L1 | User interaction | `phx-click`, `push_navigate/2` |
| L2 | Forms | `to_form/2` + changeset |
| L3 | Dynamic lists | Streams (`stream/3`, `stream_insert/4`) |
| L4 | Real-time updates | PubSub, `assign_async/3` |
| L5 | Browser APIs | `phx-hook` |

## Common Gotchas

- **No `else if` in HEEx** — use `case`/`cond` or `:if` attributes
- **Stream ID mismatch** — container `id` MUST match stream name
- **Mount runs twice** — check `connected?(socket)` for PubSub
- **Form field access** — `@form[:email]` not `@form.email`
- **Hook needs `id`** — element MUST have unique `id`
- **`phx-feedback-for` removed (LV 1.0)** — use `used_input?/1`
- **`phx-page-loading` removed (LV 1.0)** — use `page_loading: true` in `JS.push/2`

## Reference Files

- `escalation-ladder.md` — Full L0-L5 with code examples, auth scopes, testing
- `references/streams.md` — Stream patterns and pagination
- `references/forms.md` — Form patterns including uploads and nested forms
- `references/hooks.md` — JavaScript hooks with third-party library integration
- `references/authentication.md` — Authorization, session management, magic link auth
- `references/advanced-patterns.md` — assign_async, attach_hook widgets, reconnect state management
- `references/plug-and-controllers.md` — Plug pipelines, JSON APIs, fallback controllers, rate limiting
- `references/channels.md` — Phoenix Channels, WebSockets, Presence, when Channels vs LiveView

## Commands

- **`/feature <desc>`** — Guided feature implementation with TDD
- **`/review [file]`** — Review code against production standards

## Related Skills

- **elixir-patterns**: OTP patterns underlying LiveView
- **production-quality**: Testing strategies, observability, Ecto preloading

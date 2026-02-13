# Interval and Range Algorithms

## Decision Table

| Problem | Approach | Tool | Use When |
|---------|----------|------|----------|
| Range queries on sorted data | `:gb_trees` iterator | OTP built-in | In-memory ordered traversal |
| Time range queries | Ecto + Postgres range types | `tstzrange`, `daterange` | Scheduling, availability, booking |
| Overlapping interval detection | Postgres range overlap `&&` | Ecto + exclusion constraints | Conflict detection (meetings, bookings) |
| In-memory interval search | Sorted list + binary search | Custom | Small datasets (<10K intervals) |
| Recurring schedules | RRULE + date math | `ex_ical` or custom | Calendar events, cron-like schedules |

## Postgres Range Types

PostgreSQL has native range types that handle intervals correctly, including overlap detection, containment, and exclusion constraints. Use these rather than implementing interval logic in Elixir.

### Schema

```elixir
# Migration
create table(:bookings) do
  add :room_id, references(:rooms)
  add :period, :tstzrange  # timestamp with timezone range
  add :booked_by, references(:users)
  timestamps()
end

# Prevent overlapping bookings for the same room
create constraint(:bookings, :no_overlapping_bookings,
  exclude: ~s|gist (room_id WITH =, period WITH &&)|
)
```

```elixir
defmodule MyApp.Booking do
  use Ecto.Schema

  schema "bookings" do
    field :room_id, :integer
    field :period, Postgrex.Range
    field :booked_by, :integer
    timestamps()
  end
end
```

### Queries

```elixir
# Find bookings that overlap with a time range
def conflicts(room_id, start_time, end_time) do
  range = %Postgrex.Range{
    lower: start_time,
    upper: end_time,
    lower_inclusive: true,
    upper_inclusive: false
  }

  from(b in Booking,
    where: b.room_id == ^room_id,
    where: fragment("? && ?", b.period, type(^range, Postgrex.Range))
  )
  |> Repo.all()
end

# Check if a time falls within any booking
def active_booking(room_id, time) do
  from(b in Booking,
    where: b.room_id == ^room_id,
    where: fragment("? @> ?::timestamptz", b.period, ^time)
  )
  |> Repo.one()
end

# Find gaps (available slots) between bookings
def available_slots(room_id, day_start, day_end) do
  bookings = from(b in Booking,
    where: b.room_id == ^room_id,
    where: fragment("? && tstzrange(?, ?)", b.period, ^day_start, ^day_end),
    order_by: b.period,
    select: b.period
  ) |> Repo.all()

  find_gaps(bookings, day_start, day_end)
end
```

### Postgres Range Operators

| Operator | Meaning | Example |
|----------|---------|---------|
| `&&` | Overlaps | `period && '[2024-01-01, 2024-02-01)'` |
| `@>` | Contains element | `period @> '2024-01-15'::timestamptz` |
| `@>` | Contains range | `period @> '[2024-01-10, 2024-01-20)'` |
| `<@` | Contained by | `period <@ '[2024-01-01, 2024-12-31)'` |
| `-|-` | Adjacent to | `period -|- '[2024-02-01, 2024-03-01)'` |
| `<<` | Strictly left of | `period << '[2024-06-01,)'` |

### Range Types Available

| Type | Postgres Type | Content |
|------|--------------|---------|
| `int4range` | Integer range | `[1, 100)` |
| `int8range` | Bigint range | Large integer ranges |
| `numrange` | Numeric range | Decimal ranges |
| `tsrange` | Timestamp (no tz) | Time intervals |
| `tstzrange` | Timestamp with tz | Time intervals (recommended) |
| `daterange` | Date range | Day-level intervals |

## In-Memory: :gb_trees for Range Queries

When you need ordered iteration and range queries in memory:

```elixir
tree = :gb_trees.empty()
tree = :gb_trees.insert(10, "a", tree)
tree = :gb_trees.insert(20, "b", tree)
tree = :gb_trees.insert(30, "c", tree)
tree = :gb_trees.insert(40, "d", tree)

# Range query: find all entries with key between 15 and 35
defp range_query(tree, low, high) do
  iter = :gb_trees.iterator_from(low, tree)
  collect_range(iter, high, [])
end

defp collect_range(iter, high, acc) do
  case :gb_trees.next(iter) do
    {key, value, next_iter} when key <= high ->
      collect_range(next_iter, high, [{key, value} | acc])
    _ ->
      Enum.reverse(acc)
  end
end
```

## Common Mistakes

- **Implementing overlap detection in Elixir**: Postgres exclusion constraints with `&&` operator catch overlaps at the database level, preventing race conditions that application-level checks miss.
- **Using two separate columns for start/end**: Postgres range types are a single column with built-in operators. Two columns require manual overlap logic.
- **Forgetting exclusion constraint index**: The `EXCLUDE USING gist` constraint requires the `btree_gist` extension: `CREATE EXTENSION btree_gist`.
- **Inclusive vs exclusive bounds**: `[start, end)` (inclusive start, exclusive end) is the convention. Avoid `[start, end]` which makes adjacency detection harder.

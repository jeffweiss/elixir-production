# BEAM Efficiency Guide

Key performance characteristics of the BEAM VM that affect everyday Elixir code. Based on the [Erlang Efficiency Guide](https://www.erlang.org/doc/system/efficiency_guide.html).

## The Seven Myths

Things that are **not actually slow** on modern BEAM:

| Myth | Reality |
|------|---------|
| Tail-recursive functions are much faster | Body-recursive and tail-recursive functions perform similarly since OTP R12B. Measure, don't assume. |
| `++` is always bad | Only bad when left operand grows in a loop. `short_list ++ long_list` is fine. |
| Funs are slow | Funs are fast since R6B — roughly between a local call and `apply/3`. |
| List comprehensions are slow | The compiler rewrites them into efficient recursive functions. |
| Strings are slow | Strings (charlists) have known overhead but aren't pathologically slow. Use binaries for performance-critical paths. |
| `_` makes programs faster | The compiler already optimizes unused variables. Prefixing with `_` is for warnings, not performance. |
| A NIF always speeds up your program | NIFs have call overhead, block schedulers if not yielding, and prevent GC of the calling process. Measure first. |

## Binary Handling

### How Binaries Work

- **Heap binaries** (≤64 bytes): stored directly on the process heap
- **Reference-counted binaries** (>64 bytes): stored in a shared binary heap, processes hold references
- **Sub-binaries**: cheap references into existing binaries (no copy) — created by pattern matching

### Efficient Binary Construction

**Appending** is optimized by the runtime — it over-allocates and fills in place:

```elixir
# ✅ Efficient — runtime optimizes sequential appends
defp build_binary([], acc), do: acc
defp build_binary([chunk | rest], acc) do
  build_binary(rest, acc <> chunk)  # Append is O(1) amortized
end

# ✅ Also efficient — IO lists avoid binary construction entirely
defp build_iodata(chunks), do: chunks  # Just return the list!
IO.iodata_to_binary(chunks)  # Single allocation at the end
```

**Prepending** defeats the optimization — creates a new binary each time:

```elixir
# ❌ Inefficient — prepending copies the entire binary
defp bad_build([chunk | rest], acc) do
  bad_build(rest, chunk <> acc)  # O(n) per prepend
end
```

### IO Lists — The Performance Secret

For building output (HTTP responses, templates, file writes), **use IO lists instead of binary concatenation**:

```elixir
# ❌ Allocates and copies a new binary for each concatenation
html = "<div>" <> title <> "</div><p>" <> body <> "</p>"

# ✅ Zero allocation until sent — just nested lists
html = ["<div>", title, "</div><p>", body, "</p>"]
# Phoenix templates and HEEx already produce IO lists internally
```

IO lists are lists of binaries, integers (bytes), and nested IO lists. Functions like `IO.write/2`, `File.write/2`, and `:gen_tcp.send/2` accept IO lists directly — no conversion needed.

### Binary Pattern Matching

Pattern matching on binaries creates efficient **match contexts** that avoid copying:

```elixir
# ✅ Efficient — match context traverses without copying
def parse(<<type::8, length::16, payload::binary-size(length), rest::binary>>) do
  {type, payload, rest}
end

# ❌ Inefficient — :binary.part/3 in a loop creates sub-binaries
def parse_loop(bin, pos) do
  chunk = :binary.part(bin, pos, 4)  # Creates a sub-binary each time
  parse_loop(bin, pos + 4)
end
```

## Map Efficiency

### Small Maps (≤32 keys) vs Large Maps (>32 keys)

This is the most important map performance detail:

| Property | Small Map (≤32) | Large Map (>32) |
|----------|----------------|-----------------|
| Implementation | Flat tuple of sorted keys + values | HAMT (Hash Array Mapped Trie) |
| Key sharing | Keys tuple shared across instances | Partial sharing via HAMT structure |
| Multi-key update | Constant time (one operation) | O(n) proportional to keys updated |
| Multi-key match | Constant time | O(n) proportional to keys matched |
| Memory overhead | 5 words + keys + values | ~proportional to element count |
| Best for | Struct-like records | Dictionaries, dynamic keys |

### Map Performance Rules

```elixir
# ✅ Use := for updates (slightly faster, catches typos)
updated = %{map | name: "new"}   # Elixir syntax compiles to :=

# ❌ => for known keys (doesn't verify key exists)
updated = Map.put(map, :name, "new")  # Slightly slower for small maps

# ✅ Match multiple keys at once (one operation for small maps)
%{name: name, email: email, age: age} = user

# ❌ Multiple Map.get calls (separate operations each)
name = Map.get(user, :name)
email = Map.get(user, :email)
age = Map.get(user, :age)

# ✅ Update multiple keys at once
%{user | name: "new", email: "new@example.com"}

# ❌ Sequential updates
user |> Map.put(:name, "new") |> Map.put(:email, "new@example.com")
```

### Key Sharing for Memory Efficiency

All small maps with the same keys share a single key tuple:

```elixir
# ✅ Factory function ensures key sharing
def new_user(attrs) do
  %{name: nil, email: nil, age: nil, role: :user}
  |> Map.merge(attrs)
end

# When you create 100,000 users this way, the key tuple
# {name, email, age, role} exists only once in memory
```

### When Maps Are Not the Best Choice

| Situation | Better Alternative |
|-----------|-------------------|
| Need sorted iteration | `:gb_trees` |
| Integer keys (sparse) | `:array` |
| Frequent sorted list conversion | `:gb_trees` |
| Set intersection performance | `:ordsets` |
| >32 elements used as struct | Group into sub-maps to stay under 32 |

## List Handling

### The `++` Operator

`++` copies the **left** operand. The right operand is shared:

```elixir
# ❌ O(n²) — left operand (result) grows each iteration
Enum.reduce(items, [], fn item, acc -> acc ++ [item] end)

# ✅ O(n) — prepend then reverse
items |> Enum.reduce([], fn item, acc -> [item | acc] end) |> Enum.reverse()

# ✅ OK — left operand is small and constant-size
[:header] ++ long_list  # Only copies [:header], not long_list
```

### `length/1` is O(n)

```elixir
# ❌ O(n) — traverses entire list to count
if length(list) > 3, do: ...

# ✅ O(1) — pattern match checks only what's needed
case list do
  [_, _, _, _ | _] -> ...  # At least 4 elements
  _ -> ...
end

# ❌ O(n) twice — length is computed for the comparison
if length(list) == 0, do: ...

# ✅ O(1)
if list == [], do: ...
# or
case list do
  [] -> ...
  [_ | _] -> ...
end
```

## Process Efficiency

### Accidental Data Copying

When spawning a process or sending a message, **all referenced data is deep-copied** to the new process heap. Shared sub-terms are duplicated.

```elixir
# ❌ Copies entire socket/state struct into the Task
Task.async(fn -> process(socket.assigns.user_id) end)

# ✅ Extract only what you need before spawning
user_id = socket.assigns.user_id
Task.async(fn -> process(user_id) end)
```

This applies to:
- `Task.async/1` and `Task.Supervisor.async/2`
- `spawn/1` and `GenServer.start_link/3`
- `assign_async/3` in LiveView
- `send/2` for inter-process messages

### Atom Table

Atoms are never garbage collected. The default limit is 1,048,576 atoms.

```elixir
# ❌ DANGEROUS — attacker can exhaust atom table
String.to_atom(user_input)

# ✅ Safe — only converts to existing atoms
String.to_existing_atom(user_input)
```

Never convert untrusted input to atoms. This is both a performance concern and a denial-of-service vector.

### Timer Module

The `timer` module uses a single process — it can become a bottleneck under load:

```elixir
# ❌ Bottleneck at scale — goes through timer server process
:timer.send_after(5000, :timeout)

# ✅ Direct — no intermediary process
Process.send_after(self(), :timeout, 5000)

# ✅ Also direct
:erlang.send_after(5000, self(), :timeout)
```

Note: `timer:tc/3` and `timer:sleep/1` do NOT use the timer server and are fine to use.

## Process Hibernation (OTP 28+)

**`erlang:hibernate/0` requires Erlang/OTP 28 or later.** Puts the calling process into a minimal-memory wait state until the next message arrives. Unlike `erlang:hibernate/3` (available since OTP R9), it preserves the call stack.

### Memory Impact

OTP team benchmarks show the difference for idle processes:

| Idle Processes | Without hibernate | With `hibernate/0` | Reduction |
|---------------|-------------------|-------------------|-----------|
| 10,000 | 73 MB | 56 MB | 24% |
| 100,000 | 307 MB | 130 MB | 58% |
| 1,000,000 | 2,687 MB | 828 MB | 69% |

### Usage

```elixir
# In a GenServer that idles for long periods
def handle_info(:idle_timeout, state) do
  # Hibernate until next message — preserves call stack
  :erlang.hibernate()
  # Execution resumes here when a message arrives
  {:noreply, state}
end
```

### When to Use

- Long-lived processes that are idle most of the time (connection holders, session state)
- Systems with many thousands of LiveView processes (each is a process)
- Processes holding large heaps that could be compacted during idle periods

### Caveats

- **OTP 28+ only** — check with `:erlang.system_info(:otp_release)` before using
- **GenServer/LiveView already support `:hibernate_after`** — the existing `hibernate_after: 15_000` option (default for LiveView) calls `erlang:hibernate/3` automatically after idle timeout. The new `hibernate/0` is for custom processes or cases where you want explicit control.
- **Wake-up cost** — the process must rebuild its heap on the first message after hibernating. Don't hibernate processes that receive messages frequently.
- **Not a substitute for fixing memory leaks** — if a process accumulates state, hibernation only delays the problem.

## NIFs: Last Resort

NIFs (Native Implemented Functions) run C/Rust code in the BEAM. They can speed things up but have serious risks:

- **Scheduler blocking**: A NIF that runs too long blocks the scheduler, degrading all other processes on that scheduler
- **No preemption**: Unlike Erlang/Elixir code, NIFs can't be preempted — they must yield explicitly
- **Crash = VM crash**: A segfault in a NIF crashes the entire BEAM VM, not just one process
- **GC interference**: The calling process can't be garbage collected while the NIF runs

```
Consider NIF?
  Can you solve it with pure Elixir? → Do that
  Can you use a Port (separate OS process)? → Safer isolation
  Need NIF for performance?
    → Use Rustler (Rust NIFs with safety guarantees)
    → Implement dirty NIF schedulers for long-running work
    → Always benchmark to verify NIF is actually faster
```

## Common Mistakes

- **Assuming tail recursion is faster**: Measure with Benchee. Body-recursive `Enum.map` is often as fast or faster than a tail-recursive version with `Enum.reverse`.
- **Building large binaries with `<>` in the wrong direction**: Append is optimized, prepend is not. Or better yet, use IO lists.
- **Ignoring the 32-key threshold for maps**: Crossing from 32 to 33 keys changes the internal representation and performance characteristics. Group related fields into sub-maps if needed.
- **Using `length/1` in guards or conditions**: It traverses the full list. Pattern match on structure instead.
- **Copying large state into spawned processes**: Extract only the fields you need before spawning.
- **Using `String.to_atom/1` on user input**: Atoms are never GC'd. This is a DoS vector.
- **Using `timer` module for high-frequency timers**: Use `Process.send_after/3` directly.
- **Reaching for NIFs before profiling**: The overhead of crossing the NIF boundary may negate the performance gain for small workloads.

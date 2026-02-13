# Metaprogramming and Macros

## Decision: Function or Macro?

```
Can you solve it with a regular function?
  YES → Use a function (always preferred)
  NO  → Can you solve it with a higher-order function (passing functions as args)?
          YES → Use a higher-order function
          NO  → Can you solve it with a behaviour or protocol?
                  YES → Use a behaviour/protocol
                  NO  → Do you need to transform code at compile time?
                          YES → Use a macro (last resort)
                          NO  → Rethink the approach
```

**Macros are the tool of last resort.** They're powerful but make code harder to read, debug, and maintain. Every macro introduces a new mini-language that every developer on the team must learn.

## When Macros Are Justified

| Use Case | Why Macro | Example |
|----------|-----------|---------|
| DSLs that define structure | Can't express with functions | Ecto `schema`, Phoenix `router` |
| Compile-time validation | Must fail at compile time, not runtime | Config validation, route checking |
| Code generation from external data | Generate functions from specs | API clients from OpenAPI, i18n from YAML |
| Eliminating boilerplate across many modules | Same pattern repeated 20+ times | `use GenServer`, `use Phoenix.LiveView` |
| Compile-time optimizations | Pre-compute at compile time | Regex compilation, lookup tables |

## When Macros Are NOT Justified

| Temptation | Better Alternative |
|------------|-------------------|
| "Shorter syntax" | A function with a good name |
| "Avoid passing an argument" | Higher-order function or default argument |
| "Dynamic dispatch" | Behaviour or protocol |
| "Configuration" | Application config or module attributes |
| "I want it to look like a keyword" | A function — readability comes from naming, not syntax |
| "Runtime code generation" | `apply/3`, function references, or pattern matching |

## How `use` Works

`use MyModule` is syntactic sugar for calling `MyModule.__using__/1` macro at compile time:

```elixir
# When you write:
use GenServer

# The compiler expands it to:
require GenServer
GenServer.__using__([])

# Which typically injects:
@behaviour GenServer
# ... default callback implementations ...
```

### Writing a `__using__` Macro

```elixir
defmodule MyApp.Schema do
  defmacro __using__(opts) do
    quote do
      use Ecto.Schema
      import Ecto.Changeset

      # Every schema gets timestamps and a t() type
      @primary_key {:id, :binary_id, autogenerate: true}
      @timestamps_opts [type: :utc_datetime_usec]

      # Inject caller-provided options
      unquote(opts[:extra] || [])
    end
  end
end

# Usage — clean, hides boilerplate
defmodule MyApp.Accounts.User do
  use MyApp.Schema

  schema "users" do
    field :name, :string
    timestamps()
  end
end
```

## quote and unquote

`quote` captures code as AST (Abstract Syntax Tree). `unquote` injects values into quoted code.

```elixir
# quote captures code as data
quote do
  1 + 2
end
# => {:+, [context: Elixir, imports: [{2, Kernel}]], [1, 2]}

# unquote injects runtime values into quoted code
name = :hello
quote do
  def unquote(name)(), do: "world"
end
# => defines: def hello(), do: "world"
```

### Practical Macro: Compile-Time Validation

```elixir
defmodule MyApp.Config do
  defmacro validate_config!(key) do
    value = Application.compile_env(:my_app, key)

    unless value do
      raise CompileError,
        description: "Missing required config: config :my_app, #{inspect(key)}"
    end

    quote do
      unquote(value)
    end
  end
end

# Fails at compile time if config is missing — not at runtime
defmodule MyApp.Mailer do
  require MyApp.Config
  @api_key MyApp.Config.validate_config!(:sendgrid_api_key)
end
```

### Practical Macro: Code Generation from Data

```elixir
defmodule MyApp.ErrorCodes do
  # Generate functions from a map at compile time
  @codes %{
    not_found: {404, "Not Found"},
    unauthorized: {401, "Unauthorized"},
    forbidden: {403, "Forbidden"},
    conflict: {409, "Conflict"}
  }

  for {name, {status, message}} <- @codes do
    def unquote(name)() do
      {unquote(status), unquote(message)}
    end
  end

  def all_codes, do: unquote(Macro.escape(@codes))
end

MyApp.ErrorCodes.not_found()   # => {404, "Not Found"}
MyApp.ErrorCodes.unauthorized() # => {401, "Unauthorized"}
```

## DSL Patterns

### Schema/Definition DSL

The pattern used by Ecto, Absinthe, and other libraries — accumulate definitions at compile time using module attributes:

```elixir
defmodule MyApp.Validator do
  defmacro __using__(_opts) do
    quote do
      import MyApp.Validator, only: [validate: 2]
      Module.register_attribute(__MODULE__, :validations, accumulate: true)
      @before_compile MyApp.Validator
    end
  end

  defmacro validate(field, rules) do
    quote do
      @validations {unquote(field), unquote(rules)}
    end
  end

  defmacro __before_compile__(env) do
    validations = Module.get_attribute(env.module, :validations)

    quote do
      def __validations__, do: unquote(Macro.escape(validations))

      def validate(data) do
        Enum.reduce(__validations__(), {:ok, data}, fn {field, rules}, acc ->
          # Apply validation rules...
          acc
        end)
      end
    end
  end
end

# Clean DSL usage
defmodule MyApp.UserValidator do
  use MyApp.Validator

  validate :name, required: true, min_length: 1
  validate :email, required: true, format: ~r/@/
  validate :age, min: 0, max: 150
end
```

## Macro Hygiene

Elixir macros are **hygienic by default** — variables defined inside a macro don't leak into the caller's scope:

```elixir
defmacro my_macro do
  quote do
    x = 42  # This x is isolated — doesn't affect caller's x
  end
end

x = 1
my_macro()
x  # => still 1, not 42
```

To intentionally override hygiene (rare, be careful):

```elixir
defmacro my_macro do
  quote do
    var!(x) = 42  # This DOES affect the caller's x
  end
end
```

**Rule**: If you're using `var!`, reconsider whether a macro is the right tool.

## Debugging Macros

```elixir
# See what a macro expands to
IO.puts(Macro.to_string(quote do
  use GenServer
end |> Macro.expand(__ENV__)))

# In IEx — expand macro step by step
iex> quote do: use GenServer
iex> Macro.expand(v(), __ENV__)

# Macro.to_string for readable output
iex> Macro.to_string(Macro.expand(quote(do: use GenServer), __ENV__))
```

## Common Mistakes

- **Using a macro when a function works**: If the code doesn't need to run at compile time, a function is always simpler. Macros that could be functions add complexity for no benefit.
- **Debugging macro-generated code**: Stack traces point to the macro call site, not the generated code. Use `Macro.to_string` and `Macro.expand` to see what's actually generated.
- **Overusing `var!`**: Breaking hygiene makes macros unpredictable. If you need to set a variable in the caller's scope, return a value instead and let the caller bind it.
- **Complex logic inside `quote`**: Keep quoted blocks simple — pure structure. Put complex logic in helper functions called from the quoted code.
- **Not documenting macro behavior**: Macros create implicit APIs. Document what code they inject, what module attributes they set, and what callbacks they expect.
- **Macros for runtime dispatch**: If you're generating code based on runtime values, you don't need a macro — use `apply/3`, function captures, or pattern matching.
- **Deeply nested macros**: A macro that calls another macro that calls another macro creates an expansion chain that's nearly impossible to debug. Keep macro depth to 1-2 levels.

## The Ousterhout Connection

Macros embody Ousterhout's "pull complexity downward" principle — a well-designed macro (like `schema` or `pipe_through`) creates a **deep module**: simple interface hiding significant implementation. But a poorly designed macro creates a **leaky abstraction**: the user must understand both the DSL and the generated code to debug issues.

The test: if a developer can use your macro without ever looking at its implementation, it's a good macro. If they need to run `Macro.expand` to understand what's happening, reconsider whether a plain function would be clearer.

# Boundary Enforcement

Mechanical enforcement of architectural invariants. Don't rely on discipline alone — make violations fail loudly.

> "Enforce invariants, don't micromanage implementations." — OpenAI Harness Engineering

## Structural Tests

Tests that verify architecture, not behavior. These catch violations before code review.

### Context Boundary Test

Verify no context module imports/aliases another context's internals:

```elixir
defmodule MyApp.ArchitectureTest do
  use ExUnit.Case, async: true

  @contexts ~w(accounts products orders)

  test "contexts don't import other contexts' internal modules" do
    for context <- @contexts do
      context_dir = Path.join(["lib", "my_app", context])

      context_dir
      |> Path.join("**/*.ex")
      |> Path.wildcard()
      |> Enum.each(fn file ->
        content = File.read!(file)

        other_contexts = @contexts -- [context]
        for other <- other_contexts do
          other_module = other |> Macro.camelize()
          refute content =~ ~r/alias MyApp\.#{other_module}\.[A-Z]/,
            "#{file} aliases internal module from #{other} context"
          refute content =~ ~r/import MyApp\.#{other_module}\.[A-Z]/,
            "#{file} imports internal module from #{other} context"
        end
      end)
    end
  end

  test "schemas don't call context public APIs" do
    for context <- @contexts do
      schema_dir = Path.join(["lib", "my_app", context])

      schema_dir
      |> Path.join("*.ex")
      |> Path.wildcard()
      |> Enum.reject(&String.ends_with?(&1, "/#{context}.ex"))
      |> Enum.each(fn file ->
        content = File.read!(file)

        other_contexts = @contexts -- [context]
        for other <- other_contexts do
          other_module = other |> Macro.camelize()
          refute content =~ ~r/MyApp\.#{other_module}\.\w+\(/,
            "Schema #{file} calls #{other} context API directly"
        end
      end)
    end
  end

  test "controllers don't call Repo directly" do
    "lib/my_app_web/controllers/**/*.ex"
    |> Path.wildcard()
    |> Enum.each(fn file ->
      content = File.read!(file)
      refute content =~ ~r/Repo\.\w+/,
        "Controller #{file} calls Repo directly — use context functions"
    end)
  end

  test "LiveViews don't call Repo directly" do
    "lib/my_app_web/live/**/*.ex"
    |> Path.wildcard()
    |> Enum.each(fn file ->
      content = File.read!(file)
      refute content =~ ~r/Repo\.\w+/,
        "LiveView #{file} calls Repo directly — use context functions"
    end)
  end
end
```

### Cross-Context Join Detection

Verify no Ecto query joins across context boundaries:

```elixir
test "no cross-context joins in queries" do
  # Map schemas to their owning context
  schema_owners = %{
    "User" => "accounts",
    "UserToken" => "accounts",
    "Product" => "products",
    "Category" => "products",
    "Order" => "orders",
    "LineItem" => "orders"
  }

  for context <- @contexts do
    context_dir = Path.join(["lib", "my_app", context])

    context_dir
    |> Path.join("**/*.ex")
    |> Path.wildcard()
    |> Enum.each(fn file ->
      content = File.read!(file)

      # Find join references to schemas from other contexts
      Regex.scan(~r/join:\s+(\w+)\s+in\s+(\w+)/, content)
      |> Enum.each(fn [_match, _binding, schema] ->
        case Map.get(schema_owners, schema) do
          ^context -> :ok
          nil -> :ok  # Unknown schema, skip
          other ->
            flunk("#{file} joins #{schema} (owned by #{other}) — " <>
              "use context API instead of cross-context join")
        end
      end)
    end)
  end
end
```

## Custom Credo Rules

For invariants that should be checked on every `mix credo` run. Place in `lib/my_app/credo/` and configure in `.credo.exs`.

### No Repo in Controllers

```elixir
defmodule MyApp.Credo.Check.Design.NoRepoInControllers do
  @moduledoc "Controllers must not call Repo directly. Use context functions."

  use Credo.Check,
    base_priority: :high,
    category: :design,
    explanations: [
      check: """
      Controllers should be thin adapters that delegate to context modules.
      Direct Repo calls bypass context boundaries and authorization.

      ## Fix
      Move the Repo call into the appropriate context module and call
      that context function from the controller instead.
      """
    ]

  @impl true
  def run(%SourceFile{} = source_file, params) do
    if controller_file?(source_file.filename) do
      issue_meta = IssueMeta.for(source_file, params)

      source_file
      |> Credo.Code.prewalk(&traverse(&1, &2, issue_meta))
      |> Enum.reverse()
    else
      []
    end
  end

  defp controller_file?(filename) do
    String.contains?(filename, "/controllers/") and String.ends_with?(filename, ".ex")
  end

  defp traverse(
    {{:., _, [{:__aliases__, meta, [:Repo]}, _func]}, _, _args} = ast,
    issues,
    issue_meta
  ) do
    issue = issue_for(issue_meta, meta[:line], "Repo")
    {ast, [issue | issues]}
  end

  defp traverse(ast, issues, _issue_meta), do: {ast, issues}

  defp issue_for(issue_meta, line_no, trigger) do
    format_issue(issue_meta,
      message: "Controller calls Repo.#{trigger} directly — use a context function.",
      trigger: trigger,
      line_no: line_no
    )
  end
end
```

### Configuration

```elixir
# .credo.exs
%{
  configs: [
    %{
      name: "default",
      checks: %{
        extra: [
          {MyApp.Credo.Check.Design.NoRepoInControllers, []}
          # Add more custom checks here
        ]
      }
    }
  ]
}
```

## Enforcement Strategy

Choose enforcement level based on invariant importance:

| Invariant | Enforcement | Catches at |
|-----------|------------|------------|
| Context boundary violations | Structural test | `mix test` |
| Repo in controllers | Custom credo rule | `mix credo` |
| Cross-context joins | Structural test | `mix test` |
| Missing typespecs | Credo + compiler | `mix credo` / `mix compile` |
| Authorization in wrong layer | Code review | Review phase |

**Priority order for adding enforcement:**
1. Write the invariant in ARCHITECTURE.md first (human-readable)
2. Add a structural test (fails loudly, easy to write)
3. Add a custom credo rule if it should run on every edit (not just test suite)
4. Only then rely on code review for nuance the tools can't catch

## Error Messages for Agents

When structural tests or credo rules fail, include remediation in the error message. Agents can read these and self-correct:

```elixir
# Bad: agent doesn't know what to do
refute content =~ ~r/Repo\.\w+/, "found Repo call"

# Good: agent knows exactly how to fix it
refute content =~ ~r/Repo\.\w+/,
  "Controller #{file} calls Repo directly — " <>
  "move the query into the appropriate context module " <>
  "(e.g., MyApp.Accounts.list_users/1) and call that instead"
```

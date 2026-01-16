---
description: Run full precommit quality checks
argument-hint: [--fix]
allowed-tools:
  - "Bash(mix compile*)"
  - "Bash(mix format*)"
  - "Bash(mix credo*)"
  - "Bash(mix test*)"
  - "Read"
  - "Edit"
model: haiku
---

# Precommit Command

Executes the production-ready precommit workflow to ensure code quality before commits.

## What It Does

Runs four quality checks in sequence:

1. **Compilation** with warnings as errors
2. **Code formatting** with Styler
3. **Static analysis** with Credo
4. **Test suite** execution

## Usage

```bash
/precommit          # Run all checks
/precommit --fix    # Run checks and auto-fix formatting issues
```

## Implementation

### Step 1: Check Dependencies

First verify that required tools are installed:

```bash
# Check if credo is in mix.exs
if ! grep -q ':credo' mix.exs; then
  echo "❌ Missing dependency: credo"
  echo "Add to mix.exs:"
  echo '  {:credo, "~> 1.7", only: [:dev, :test], runtime: false}'
  exit 1
fi

# Check if styler is in mix.exs
if ! grep -q ':styler' mix.exs; then
  echo "❌ Missing dependency: styler"
  echo "Add to mix.exs:"
  echo '  {:styler, "~> 1.0", only: [:dev, :test], runtime: false}'
  exit 1
fi

# Check if styler is configured in .formatter.exs
if [[ -f ".formatter.exs" ]]; then
  if ! grep -q 'Styler' .formatter.exs; then
    echo "⚠️  Styler not configured in .formatter.exs"
    echo "Add: plugins: [Styler]"
  fi
fi
```

### Step 2: Run Checks

Execute each check in order:

```bash
echo "🔍 Running precommit checks..."
echo ""

# 1. Compile with warnings as errors
echo "1/4 Compiling..."
if mix compile --warnings-as-errors; then
  echo "✅ Compilation passed"
else
  echo "❌ Compilation failed with warnings"
  exit 1
fi

echo ""

# 2. Format code (with --fix flag) or check formatting
echo "2/4 Formatting..."
if [[ "$1" == "--fix" ]]; then
  mix format
  echo "✅ Code formatted"
else
  if mix format --check-formatted 2>&1 | grep -q "mix format"; then
    echo "❌ Code needs formatting. Run: mix format"
    exit 1
  else
    echo "✅ Formatting correct"
  fi
fi

echo ""

# 3. Run credo
echo "3/4 Static analysis..."
if mix credo --strict; then
  echo "✅ Credo passed"
else
  echo "❌ Credo found issues"
  exit 1
fi

echo ""

# 4. Run tests
echo "4/4 Running tests..."
if mix test; then
  echo "✅ All tests passed"
else
  echo "❌ Tests failed"
  exit 1
fi

echo ""
echo "✅ All precommit checks passed!"
```

### Step 3: Report Results

If all checks pass:

```
✅ Precommit Checks Complete

All checks passed:
✅ Compilation (0 warnings)
✅ Formatting (all files formatted)
✅ Credo (strict mode)
✅ Tests (X tests, 0 failures)

Ready to commit!
```

If any check fails:

```
❌ Precommit Checks Failed

Results:
✅ Compilation
❌ Formatting - 3 files need formatting
  Run: mix format

Next steps:
1. Run: mix format
2. Review changes
3. Run /precommit again
```

## Auto-Fix Mode

With `--fix` flag:

```
🔧 Precommit with Auto-Fix

1/4 Compilation... ✅
2/4 Formatting... 🔧 Fixed 3 files
3/4 Static analysis... ✅
4/4 Tests... ✅

Auto-fixed:
- Formatted 3 files
- Run git diff to review changes

✅ All checks passed!
```

## Error Handling

### Missing Dependencies

```
❌ Required dependencies not found

Missing:
- credo: Add {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
- styler: Add {:styler, "~> 1.0", only: [:dev, :test], runtime: false}

After adding to mix.exs, run:
mix deps.get
```

### Compilation Errors

```
❌ Compilation Failed

Errors found:
  lib/my_app/accounts.ex:42: warning: variable "user" is unused

Fix:
- Remove unused variables or prefix with underscore: _user
- Address all warnings

Run: mix compile --warnings-as-errors
```

### Test Failures

```
❌ Tests Failed

Failed tests:
  1) test create_user/1 creates user (MyApp.AccountsTest)
     test/my_app/accounts_test.exs:42
     Assertion with == failed
     left:  "Alice"
     right: "Bob"

Fix:
- Review test failure details above
- Fix implementation or update tests
- Run: mix test test/my_app/accounts_test.exs:42
```

## Configuration

Create `.precommit.exs` in project root to customize (optional):

```elixir
[
  checks: [
    compile: true,
    format: true,
    credo: true,
    test: true
  ],
  # Skip specific checks (not recommended)
  skip: []
]
```

## Integration with Git Hooks

To run automatically before each commit, add to `.git/hooks/pre-commit`:

```bash
#!/bin/bash
set -e

echo "Running precommit checks..."
claude-code /precommit

if [ $? -ne 0 ]; then
  echo ""
  echo "Precommit checks failed. Commit aborted."
  echo "Fix issues and try again, or use --no-verify to skip (not recommended)."
  exit 1
fi
```

Make executable:
```bash
chmod +x .git/hooks/pre-commit
```

## Tips

1. **Run frequently**: Don't wait until commit time
2. **Fix as you go**: Address warnings immediately
3. **Use --fix**: Auto-fix formatting issues
4. **Focus on tests first**: If tests fail, fix before other checks
5. **Batch formatting**: Run `mix format` on entire codebase periodically

## Success Criteria

Precommit succeeds when:
- ✅ All code compiles without warnings
- ✅ All files properly formatted
- ✅ Credo passes in strict mode
- ✅ All tests pass
- ✅ No flaky tests (consistent pass/fail)

## Related Commands

- `/review` - Comprehensive code review beyond precommit checks
- `/spike` - Fast prototyping mode (skips some checks)
- `/spike-migrate` - Upgrade SPIKE code to pass precommit

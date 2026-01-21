#!/bin/bash
# SessionStart hook - loads project context files and injects them into the session

# List of files to load
files=(
  "AGENTS.md"
  "CLAUDE.md"
  ".claude/project-learnings.md"
  ".claude/spike-debt.md"
)

context=""
found_any=false

for f in "${files[@]}"; do
  if [ -f "$f" ]; then
    found_any=true
    context+="\\n\\n--- $f ---\\n"
    # Read file and escape for JSON using jq
    escaped=$(jq -Rs '.' < "$f" | sed 's/^"//;s/"$//')
    context+="$escaped"
  fi
done

if [ "$found_any" = true ]; then
  # Use jq to build proper JSON
  jq -n --arg ctx "Project standards loaded:$context" \
    '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":$ctx}}'
else
  echo '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"No project context files found (AGENTS.md, CLAUDE.md, .claude/project-learnings.md, .claude/spike-debt.md)"}}'
fi

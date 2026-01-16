#!/usr/bin/env bash
#
# Safety Net: Blocks destructive git and filesystem operations
#
# Based on claude-code-safety-net patterns with semantic command analysis.
# Prevents common destructive operations that could lose work.
#
# Environment Variables:
#   SAFETY_NET_STRICT=1     - Fail-closed on unparseable commands
#   SAFETY_NET_PARANOID=1   - Enhanced checks including rm -rf in cwd
#
# Exit codes:
#   0 - Safe command, proceed
#   1 - Dangerous command, blocked
#   2 - Parse error (proceeds unless SAFETY_NET_STRICT=1)

set -euo pipefail

# Get the command from stdin or args
COMMAND="${BASH_COMMAND_TO_VALIDATE:-${1:-}}"

if [[ -z "$COMMAND" ]]; then
  echo "Error: No command provided" >&2
  exit 2
fi

# Mode flags
STRICT_MODE="${SAFETY_NET_STRICT:-0}"
PARANOID_MODE="${SAFETY_NET_PARANOID:-0}"

# Current working directory
CWD="$(pwd)"

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Block command with message
block_command() {
  local reason="$1"
  local alternative="${2:-}"

  echo -e "${RED}🛡️  BLOCKED by Safety Net${NC}" >&2
  echo -e "${RED}Reason: ${reason}${NC}" >&2

  if [[ -n "$alternative" ]]; then
    echo -e "${YELLOW}Consider: ${alternative}${NC}" >&2
  fi

  exit 1
}

# Extract nested shell commands up to 5 levels deep
extract_shell_command() {
  local cmd="$1"
  local depth="${2:-0}"

  # Max depth to prevent infinite loops
  if [[ $depth -ge 5 ]]; then
    echo "$cmd"
    return
  fi

  # Check for shell wrappers: bash -c, sh -c, etc.
  if [[ "$cmd" =~ (bash|sh|zsh|fish)[[:space:]]+-c[[:space:]]+[\'\"](.*)[\'"] ]]; then
    local inner="${BASH_REMATCH[2]}"
    extract_shell_command "$inner" $((depth + 1))
    return
  fi

  # Check for interpreter one-liners: python -c, perl -e, ruby -e
  if [[ "$cmd" =~ (python|perl|ruby|node)[[:space:]]+-[ce][[:space:]]+[\'\"](.*)[\'"] ]]; then
    local inner="${BASH_REMATCH[2]}"
    # Look for subprocess calls within
    if [[ "$inner" =~ (os\.system|subprocess|exec|system)\((.*)\) ]]; then
      extract_shell_command "${BASH_REMATCH[2]}" $((depth + 1))
      return
    fi
  fi

  echo "$cmd"
}

# Normalize command (handle flag reordering, etc.)
normalize_command() {
  local cmd="$1"

  # Extract the main command and flags
  # This is simplified - full implementation would use proper parsing
  echo "$cmd"
}

# Check if path is in safe directory
is_safe_path() {
  local path="$1"

  # Resolve to absolute path
  if [[ ! "$path" =~ ^/ ]]; then
    path="$CWD/$path"
  fi

  # Safe directories
  if [[ "$path" =~ ^/tmp/ ]] || [[ "$path" =~ ^/var/tmp/ ]]; then
    return 0
  fi

  # Current working directory (unless paranoid mode)
  if [[ $PARANOID_MODE -eq 0 ]] && [[ "$path" =~ ^"$CWD" ]]; then
    return 0
  fi

  # Otherwise unsafe
  return 1
}

# Check for dry-run flags
has_dry_run_flag() {
  local cmd="$1"

  [[ "$cmd" =~ --dry-run ]] || [[ "$cmd" =~ -n[[:space:]] ]]
}

# Extract command from full line
extract_nested() {
  extract_shell_command "$COMMAND"
}

# Main command analysis
EXTRACTED_CMD=$(extract_nested)

# Check for dry-run (always safe)
if has_dry_run_flag "$EXTRACTED_CMD"; then
  exit 0
fi

#
# GIT COMMAND CHECKS
#

if [[ "$EXTRACTED_CMD" =~ ^git[[:space:]] ]]; then

  # git reset --hard or --merge (destroys uncommitted work)
  if [[ "$EXTRACTED_CMD" =~ git[[:space:]]+reset[[:space:]]+.*(--hard|--merge) ]]; then
    block_command \
      "git reset --hard/--merge destroys uncommitted changes" \
      "git stash or commit your changes first"
  fi

  # git push --force (rewrites history)
  if [[ "$EXTRACTED_CMD" =~ git[[:space:]]+push.*[[:space:]]+-f([[:space:]]|$) ]] || \
     [[ "$EXTRACTED_CMD" =~ git[[:space:]]+push.*[[:space:]]+--force([[:space:]]|$) ]]; then
    # Check if it's --force-with-lease (safer)
    if [[ ! "$EXTRACTED_CMD" =~ --force-with-lease ]]; then
      block_command \
        "git push --force rewrites remote history" \
        "Use --force-with-lease for safer force push, or coordinate with team"
    fi
  fi

  # git clean -f (removes untracked files permanently)
  if [[ "$EXTRACTED_CMD" =~ git[[:space:]]+clean.*-f ]]; then
    block_command \
      "git clean -f permanently deletes untracked files" \
      "Review with git clean -n first, or git stash --include-untracked"
  fi

  # git stash drop/clear (permanent deletion)
  if [[ "$EXTRACTED_CMD" =~ git[[:space:]]+stash[[:space:]]+(drop|clear) ]]; then
    block_command \
      "git stash drop/clear permanently deletes stashed changes" \
      "Review with git stash list and git stash show first"
  fi

  # git branch -D (force delete without merge check)
  if [[ "$EXTRACTED_CMD" =~ git[[:space:]]+branch[[:space:]]+-D ]]; then
    block_command \
      "git branch -D force deletes branch without checking if merged" \
      "Use -d to safely delete only merged branches, or verify merge status first"
  fi

  # git checkout -- (discards changes)
  if [[ "$EXTRACTED_CMD" =~ git[[:space:]]+checkout[[:space:]]+-- ]]; then
    block_command \
      "git checkout -- discards uncommitted changes permanently" \
      "git stash to save changes, or commit them first"
  fi

fi

#
# FILESYSTEM COMMAND CHECKS
#

# rm -rf checks
if [[ "$EXTRACTED_CMD" =~ rm[[:space:]].*-.*r.*f ]] || \
   [[ "$EXTRACTED_CMD" =~ rm[[:space:]].*-.*f.*r ]]; then

  # Extract target path(s)
  # Simplified: look for paths after flags
  local targets=$(echo "$EXTRACTED_CMD" | sed -E 's/^rm[[:space:]]+-[a-z]+[[:space:]]+//')

  # Check each target
  while IFS= read -r target; do
    [[ -z "$target" ]] && continue

    # Remove quotes
    target=$(echo "$target" | tr -d '"' | tr -d "'")

    if ! is_safe_path "$target"; then
      block_command \
        "rm -rf on paths outside current directory or /tmp" \
        "Review the path carefully, or use git clean for repository cleanup"
    fi
  done <<< "$targets"

fi

# find ... -delete
if [[ "$EXTRACTED_CMD" =~ find[[:space:]].*-delete ]]; then
  block_command \
    "find with -delete can remove many files at once" \
    "Test with -print first, then use -exec rm if needed"
fi

# find ... -exec rm -rf
if [[ "$EXTRACTED_CMD" =~ find.*-exec[[:space:]]+rm[[:space:]]+-rf ]]; then
  block_command \
    "find -exec rm -rf can remove many files recursively" \
    "Test with -print first, verify paths carefully"
fi

# xargs with rm -rf
if [[ "$EXTRACTED_CMD" =~ xargs[[:space:]]+rm[[:space:]]+-rf ]] || \
   [[ "$EXTRACTED_CMD" =~ parallel[[:space:]]+rm[[:space:]]+-rf ]]; then
  block_command \
    "xargs/parallel with rm -rf can remove many files at once" \
    "Review input list carefully, test with echo first"
fi

# chmod/chown -R on system directories
if [[ "$EXTRACTED_CMD" =~ (chmod|chown)[[:space:]].*-R.*(^/|/usr|/etc|/var|/bin|/sbin) ]]; then
  block_command \
    "Recursive chmod/chown on system directories can break your system" \
    "Be very specific with paths, or use sudo if truly needed"
fi

#
# DATABASE COMMAND CHECKS
#

# DROP DATABASE/TABLE without transaction
if [[ "$EXTRACTED_CMD" =~ DROP[[:space:]]+(DATABASE|TABLE|SCHEMA) ]]; then
  # Allow if in transaction or has IF EXISTS
  if [[ ! "$EXTRACTED_CMD" =~ IF[[:space:]]+EXISTS ]] && \
     [[ ! "$EXTRACTED_CMD" =~ BEGIN ]] && \
     [[ ! "$EXTRACTED_CMD" =~ TRANSACTION ]]; then
    block_command \
      "DROP DATABASE/TABLE without IF EXISTS or transaction" \
      "Add IF EXISTS clause, or wrap in transaction for safety"
  fi
fi

# TRUNCATE TABLE
if [[ "$EXTRACTED_CMD" =~ TRUNCATE[[:space:]]+TABLE ]]; then
  block_command \
    "TRUNCATE TABLE permanently deletes all data" \
    "Use DELETE with WHERE clause if you need to keep some data, or backup first"
fi

#
# UNPARSEABLE COMMAND HANDLING
#

# If we couldn't determine command safety and strict mode is on
if [[ $STRICT_MODE -eq 1 ]]; then
  # Check if command looks potentially dangerous
  if [[ "$EXTRACTED_CMD" =~ (rm|delete|drop|truncate|force|reset|clean) ]]; then
    echo -e "${YELLOW}⚠️  Warning: Could not fully parse command in strict mode${NC}" >&2
    echo -e "${YELLOW}Command: $EXTRACTED_CMD${NC}" >&2
    block_command \
      "Unparseable command with dangerous keywords in strict mode" \
      "Review command carefully, or disable SAFETY_NET_STRICT"
  fi
fi

# Command appears safe
exit 0

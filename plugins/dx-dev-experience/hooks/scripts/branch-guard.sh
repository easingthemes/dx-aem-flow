#!/usr/bin/env bash
# branch-guard.sh — Deny commits on protected branches
# Used by PreToolUse hook. Reads tool info from stdin (JSON).
# Returns permissionDecision: deny if on a protected branch.

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)

# Only check for commit commands
case "$TOOL_NAME" in
  Bash|execute|shell) ;;
  *) exit 0 ;;
esac

COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
if ! echo "$COMMAND" | grep -q 'git commit'; then
  exit 0
fi

BRANCH=$(git branch --show-current 2>/dev/null)
case "$BRANCH" in
  main|master|development|develop)
    echo "{\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"BLOCKED: Do not commit on $BRANCH. Create a feature/* or bugfix/* branch first.\"}"
    ;;
esac

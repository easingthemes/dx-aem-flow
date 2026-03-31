#!/usr/bin/env bash
# session-start.sh — Validate project setup on session start
# Returns warnings via additionalContext if issues found.

# Profile gate — validation hook, skip in minimal mode
source "$(dirname "$0")/hook-profile.sh"
require_profile "standard" || exit 0

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

# Only run in dx-initialized projects
[ ! -d "$PROJECT_DIR/.ai" ] && exit 0

WARNINGS=""

# Check .ai/config.yaml exists
if [ ! -f "$PROJECT_DIR/.ai/config.yaml" ]; then
  WARNINGS="$WARNINGS\n⚠ .ai/config.yaml not found — run /dx-init first"
fi

# Check Node version if .nvmrc exists
if [ -f "$PROJECT_DIR/.nvmrc" ]; then
  EXPECTED=$(cat "$PROJECT_DIR/.nvmrc" | tr -d '[:space:]')
  ACTUAL=$(node -v 2>/dev/null | sed 's/^v//')
  if [ -n "$ACTUAL" ] && [ "${ACTUAL%%.*}" != "${EXPECTED%%.*}" ]; then
    WARNINGS="$WARNINGS\n⚠ Node version mismatch: expected v$EXPECTED, got v$ACTUAL — run nvm use"
  fi
fi

if [ -n "$WARNINGS" ]; then
  echo -e "$WARNINGS" | jq -Rs '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: .}}'
fi

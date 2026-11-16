#!/usr/bin/env bash
# session-start.sh — Validate project setup on session start
# Returns warnings via additionalContext if issues found.

source "$(dirname "$0")/hook-profile.sh"

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

emit() {
  echo -e "$1" | jq -Rs '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: .}}'
}

# Only run in dx-initialized projects
[ ! -d "$PROJECT_DIR/.ai" ] && exit 0

# dx-core's playwright MCP server loads this file with --init-page and exits at
# startup when it is missing, so browser tools just show up as "not found".
# Runs at every profile (minimal included, which pipelines use): the failure is
# otherwise silent, and the check is one stat. Warning only, never blocks.
WARNINGS=""
if [ ! -f "$PROJECT_DIR/.ai/lib/playwright-basic-auth.cjs" ]; then
  WARNINGS="\n⚠ .ai/lib/playwright-basic-auth.cjs is missing — the playwright MCP server cannot start, so browser tools are unavailable. Run /dx-upgrade (or /dx-init) to install it."
fi

# Profile gate — the remaining checks are informational, skip in minimal mode
if ! require_profile "standard"; then
  [ -n "$WARNINGS" ] && emit "$WARNINGS"
  exit 0
fi
dx_progress_on_exit "Environment checked"

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
  emit "$WARNINGS"
fi
exit 0

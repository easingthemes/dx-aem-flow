#!/usr/bin/env bash
# compaction-reminder.sh — Suggest /compact after prolonged tool usage
# Triggered by PostToolUse on Edit|Write. Tracks call count in a temp file
# and suggests compaction every N calls to prevent context degradation.
#
# DX_COMPACT_INTERVAL controls the threshold (default: 50).

# Guard: only count real Edit/Write tool calls. Claude Code and Copilot CLI
# (v1.0.63+) honor the hook matcher; this is defense-in-depth for older Copilot
# builds. Neither Claude Code (v2.1.322) nor Copilot CLI (v1.0.108) sets
# CLAUDE_TOOL_NAME; read the `tool_name` field of the hook's stdin JSON.
TOOL_NAME="${CLAUDE_TOOL_NAME:-}"
if [ -z "$TOOL_NAME" ] && [ ! -t 0 ]; then
    TOOL_NAME="$(sed -n 's/.*"tool_name" *: *"\([^"]*\)".*/\1/p' | head -1 || true)"
fi
case "$TOOL_NAME" in
    Edit|Write|MultiEdit|NotebookEdit) ;;
    *) exit 0 ;;
esac

# Profile gate — informational hook, skip in minimal mode
PROFILE_LIB="$(dirname "$0")/hook-profile.sh"
[ -f "$PROFILE_LIB" ] && source "$PROFILE_LIB" && require_profile "standard" || exit 0

INTERVAL="${DX_COMPACT_INTERVAL:-50}"
COUNTER_FILE="${TMPDIR:-/tmp}/dx-tool-count-$$"

# Use session-scoped counter (parent PID as session proxy)
COUNTER_FILE="${TMPDIR:-/tmp}/dx-tool-count-${PPID}"

COUNT=0
[ -f "$COUNTER_FILE" ] && COUNT=$(cat "$COUNTER_FILE" 2>/dev/null || echo 0)
COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNTER_FILE"

if [ "$((COUNT % INTERVAL))" -eq 0 ]; then
  echo "💡 $COUNT tool calls this session. Consider running /compact to free context window."
fi

#!/usr/bin/env bash
# compaction-reminder.sh — Suggest /compact after prolonged tool usage
# Triggered by PostToolUse on Edit|Write. Tracks call count in a temp file
# and suggests compaction every N calls to prevent context degradation.
#
# DX_COMPACT_INTERVAL controls the threshold (default: 50).

# Profile gate — informational hook, skip in minimal mode
source "$(dirname "$0")/hook-profile.sh"
require_profile "standard" || exit 0

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

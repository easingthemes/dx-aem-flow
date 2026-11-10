#!/usr/bin/env bash
# Playwright screenshot hook — logs screenshots taken during AEM sessions.
# Triggered by PostToolUse on playwright browser_take_screenshot/browser_snapshot.

set -euo pipefail

# Guard: only log real screenshot/snapshot calls. Hook matchers are honored by
# Claude Code and Copilot CLI v1.0.63+; this is defense-in-depth for older
# builds. Copilot CLI never sets CLAUDE_TOOL_NAME (verified v1.0.108), so fall
# back to the `tool_name` field of the hook's stdin JSON.
TOOL_NAME="${CLAUDE_TOOL_NAME:-}"
if [ -z "$TOOL_NAME" ] && [ ! -t 0 ]; then
    TOOL_NAME="$(sed -n 's/.*"tool_name" *: *"\([^"]*\)".*/\1/p' | head -1 || true)"
fi
case "$TOOL_NAME" in
    *take_screenshot|*take_snapshot) ;;
    *) exit 0 ;;
esac

LOG_DIR="${CLAUDE_PROJECT_DIR:-.}/.ai/screenshots"
LOG_FILE="${LOG_DIR}/screenshot-log.txt"

mkdir -p "$LOG_DIR"

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

echo "[${TIMESTAMP}] ${TOOL_NAME}" >> "$LOG_FILE"

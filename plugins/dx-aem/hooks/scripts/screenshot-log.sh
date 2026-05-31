#!/usr/bin/env bash
# Playwright screenshot hook — logs screenshots taken during AEM sessions.
# Triggered by PostToolUse on playwright browser_take_screenshot/browser_snapshot.

set -euo pipefail

# Guard: Copilot CLI (v1.0.40+) fires plugin PostToolUse hooks after every model
# turn regardless of the matcher field, so this script can be invoked when no
# screenshot tool was actually called. Only proceed when the tool name confirms
# a real screenshot/snapshot — otherwise exit silently.
TOOL_NAME="${CLAUDE_TOOL_NAME:-}"
case "$TOOL_NAME" in
    *take_screenshot|*take_snapshot) ;;
    *) exit 0 ;;
esac

LOG_DIR="${CLAUDE_PROJECT_DIR:-.}/.ai/screenshots"
LOG_FILE="${LOG_DIR}/screenshot-log.txt"

mkdir -p "$LOG_DIR"

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

echo "[${TIMESTAMP}] ${TOOL_NAME}" >> "$LOG_FILE"

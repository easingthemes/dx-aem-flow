#!/usr/bin/env bash
# Chrome DevTools screenshot hook — logs screenshots taken during AEM sessions.
# Triggered by PostToolUse on chrome-devtools-mcp take_screenshot/take_snapshot.

set -euo pipefail

LOG_DIR="${CLAUDE_PROJECT_DIR:-.}/.ai/screenshots"
LOG_FILE="${LOG_DIR}/screenshot-log.txt"

mkdir -p "$LOG_DIR"

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
TOOL_NAME="${CLAUDE_TOOL_NAME:-unknown}"

echo "[${TIMESTAMP}] ${TOOL_NAME}" >> "$LOG_FILE"

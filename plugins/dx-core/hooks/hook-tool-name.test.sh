#!/usr/bin/env bash
# hook-tool-name.test.sh — PostToolUse scripts must learn the tool name on Copilot CLI.
#
# Claude Code-style `CLAUDE_TOOL_NAME` is not set by Copilot CLI (verified v1.0.108):
# the tool name only arrives as `tool_name` in the hook's stdin JSON. The tool-name
# guards in compaction-reminder.sh and screenshot-log.sh must accept either source,
# otherwise they silently never act on Copilot.
# Hermetic: temp dirs only, no network.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
COMPACT="$HERE/scripts/compaction-reminder.sh"
SHOT="$REPO/plugins/dx-aem/hooks/scripts/screenshot-log.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0; FAIL=0
check() { # check <label> <want> <got>
  if [ "$2" = "$3" ]; then echo "PASS $1"; PASS=$((PASS + 1)); else echo "FAIL $1 (want $2, got $3)"; FAIL=$((FAIL + 1)); fi
}

compact() { # compact <env tool name or ""> <stdin json> → output
  rm -f "$TMP"/dx-tool-count-*
  printf '%s' "$2" | env -u CLAUDE_TOOL_NAME ${1:+CLAUDE_TOOL_NAME="$1"} TMPDIR="$TMP" DX_COMPACT_INTERVAL=1 bash "$COMPACT" 2>&1
}
fired() { [ -n "$1" ] && echo yes || echo no; }

check "compaction: env Edit"            yes "$(fired "$(compact Edit '')")"
check "compaction: stdin Write (Copilot)" yes "$(fired "$(compact '' '{"hook_event_name":"PostToolUse","tool_name":"Write","tool_input":{}}')")"
check "compaction: stdin Bash ignored"  no  "$(fired "$(compact '' '{"tool_name":"Bash"}')")"
check "compaction: no tool name"        no  "$(fired "$(compact '' '{}')")"

shot() { # shot <env tool name or ""> <stdin json> → yes if the log was written
  local d="$TMP/p-$RANDOM"; mkdir -p "$d"
  printf '%s' "$2" | env -u CLAUDE_TOOL_NAME ${1:+CLAUDE_TOOL_NAME="$1"} CLAUDE_PROJECT_DIR="$d" bash "$SHOT" >/dev/null 2>&1
  [ -s "$d/.ai/screenshots/screenshot-log.txt" ] && echo yes || echo no
}

check "screenshot: env tool"            yes "$(shot mcp__plugin_dx-aem_playwright__browser_take_screenshot '')"
check "screenshot: stdin tool (Copilot)" yes "$(shot '' '{"tool_name":"playwright-browser_take_snapshot"}')"
check "screenshot: stdin other tool"    no  "$(shot '' '{"tool_name":"Write"}')"
check "screenshot: no tool name"        no  "$(shot '' '')"

echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]

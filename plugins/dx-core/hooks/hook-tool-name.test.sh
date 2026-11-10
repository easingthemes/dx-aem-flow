#!/usr/bin/env bash
# hook-tool-name.test.sh — PostToolUse scripts must learn the tool name on Copilot CLI.
#
# Claude Code-style `CLAUDE_TOOL_NAME` is not set by Copilot CLI plugin PostToolUse
# (verified v1.0.108): the tool name arrives as `tool_name` in stdin JSON. The
# guards in compaction-reminder.sh and screenshot-log.sh must accept either source.
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
check "compaction: stdin Edit (Copilot)" yes "$(fired "$(compact '' '{"hook_event_name":"PostToolUse","tool_name":"Edit","tool_input":{}}')")"
check "compaction: stdin Bash ignored"  no  "$(fired "$(compact '' '{"tool_name":"Bash"}')")"
check "compaction: no tool name"        no  "$(fired "$(compact '' '{}')")"

shot() { # shot <env tool name or ""> <stdin json> → yes if the log was written
  local d="$TMP/p-$RANDOM"; mkdir -p "$d"
  printf '%s' "$2" | env -u CLAUDE_TOOL_NAME ${1:+CLAUDE_TOOL_NAME="$1"} CLAUDE_PROJECT_DIR="$d" bash "$SHOT" >/dev/null 2>&1
  [ -s "$d/.ai/screenshots/screenshot-log.txt" ] && echo yes || echo no
}

check "screenshot: env tool"            yes "$(shot mcp__plugin_dx-aem_playwright__browser_take_screenshot '')"
check "screenshot: stdin tool (Copilot)" yes "$(shot '' '{"tool_name":"playwright-browser_take_snapshot"}')"
check "screenshot: stdin Edit ignored"  no  "$(shot '' '{"hook_event_name":"PostToolUse","tool_name":"Edit","tool_input":{}}')"
check "screenshot: stdin other tool"    no  "$(shot '' '{"tool_name":"Write"}')"
check "screenshot: no tool name"        no  "$(shot '' '')"

# Inline hooks.json commands: neither platform sets CLAUDE_TOOL_NAME or
# CLAUDE_TOOL_ARG_* (Claude Code v2.1.322, Copilot v1.0.108), so they must not depend on them.
HOOKS="$HERE/hooks.json"
check "hooks.json: no CLAUDE_TOOL_* env" 0 "$(grep -c 'CLAUDE_TOOL_' "$HOOKS")"

# validate-plugin-edit hook reads file_path from stdin and blocks (exit 2) on broken JSON.
VCMD="$(python3 -c 'import json,sys
for e in json.load(open(sys.argv[1]))["hooks"]["PostToolUse"]:
    for h in e["hooks"]:
        if "validate-plugin-edit" in h["command"]: print(h["command"])' "$HOOKS")"
vedit() { # vedit <file content> → exit code of the hook
  local d="$TMP/v-$RANDOM"; mkdir -p "$d/.claude-plugin"; printf '%s' "$1" > "$d/.claude-plugin/plugin.json"
  printf '{"hook_event_name":"PostToolUse","tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$d/.claude-plugin/plugin.json" \
    | env -u CLAUDE_TOOL_NAME -u CLAUDE_TOOL_ARG_file_path CLAUDE_PLUGIN_ROOT="$REPO/plugins/dx-core" bash -c "$VCMD" >/dev/null 2>&1
  echo $?
}
check "validate-plugin-edit: broken JSON blocks" 2 "$(vedit '{"name": "p",}')"
check "validate-plugin-edit: valid JSON passes"  0 "$(vedit '{"name": "p"}')"

echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]

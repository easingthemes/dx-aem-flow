#!/usr/bin/env bash
# session-start.test.sh — the init-page check in hooks/scripts/session-start.sh.
#
# dx-core's playwright MCP server exits at startup when
# .ai/lib/playwright-basic-auth.cjs is missing; the hook tells the model so, at
# every profile (minimal included), and never blocks.
# Hermetic: throwaway dirs, no network.

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
HOOK="$HERE/scripts/session-start.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
unset COPILOT_HOOK_DIR

PASS=0; FAIL=0
check() { if [ "$2" = "$3" ]; then echo "PASS $1"; PASS=$((PASS + 1)); else echo "FAIL $1 (want $2, got $3)"; FAIL=$((FAIL + 1)); fi; }

# run <proj> [profile]: sets OUT and RC
run() {
  OUT=$(cd "$1" && CLAUDE_PROJECT_DIR="$1" DX_HOOK_PROFILE="${2:-standard}" bash "$HOOK" </dev/null 2>/dev/null); RC=$?
}
ctx() { printf '%s' "$OUT" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null; }
mentions() { case "$(ctx)" in *"$1"*) echo yes ;; *) echo no ;; esac; }

# 1. missing init page → warning, exit 0
P="$TMP/missing"; mkdir -p "$P/.ai"; : > "$P/.ai/config.yaml"
run "$P"
check "missing: exit 0" 0 "$RC"
check "missing: names the file" yes "$(mentions 'playwright-basic-auth.cjs')"
check "missing: points to /dx-upgrade" yes "$(mentions '/dx-upgrade')"

# 2. minimal profile still warns (pipelines run minimal)
run "$P" minimal
check "minimal: exit 0" 0 "$RC"
check "minimal: still warns" yes "$(mentions 'playwright-basic-auth.cjs')"

# 3. present → no output at all
P="$TMP/present"; mkdir -p "$P/.ai/lib"; : > "$P/.ai/config.yaml"; : > "$P/.ai/lib/playwright-basic-auth.cjs"
run "$P"
check "present: exit 0" 0 "$RC"
check "present: silent" "" "$OUT"
run "$P" minimal
check "present, minimal: silent" "" "$OUT"

# 4. not a dx project → silent
P="$TMP/plain"; mkdir -p "$P"
run "$P"
check "no .ai: silent" "" "$OUT"

# 5. other warnings are merged into one JSON object
P="$TMP/both"; mkdir -p "$P/.ai"
run "$P"
check "merged: single JSON object" 1 "$(printf '%s' "$OUT" | jq -s 'length' 2>/dev/null)"
check "merged: init page" yes "$(mentions 'playwright-basic-auth.cjs')"
check "merged: config.yaml" yes "$(mentions 'config.yaml not found')"

echo "session-start: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]

#!/usr/bin/env bash
# hook-progress.test.sh — Copilot progress lines appear on Copilot only.
#
# Copilot CLI has no hook statusMessage; dx hooks print a
# {"type":"progress",...} stdout line instead, gated on COPILOT_HOOK_DIR (set by
# Copilot, never by Claude Code). On Claude Code that line would reach the model
# (SessionStart) or the Stop decision parser, so it must not be printed there.
# Hermetic: throwaway dirs and repos, no network.

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN="$(cd "$HERE/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
unset COPILOT_HOOK_DIR

PASS=0; FAIL=0
check() { if [ "$2" = "$3" ]; then echo "PASS $1"; PASS=$((PASS + 1)); else echo "FAIL $1 (want $2, got $3)"; FAIL=$((FAIL + 1)); fi; }
is_progress() { jq -e 'select(.type == "progress" and (.message | length) > 0 and (.message | test("\\.\\.\\.$") | not))' >/dev/null 2>&1 && echo yes || echo no; }   # no trailing "..." — Copilot keeps the line

mkdir -p "$TMP/proj/.ai"
for s in session-start context-loader next-step; do
  out_claude=$(cd "$TMP/proj" && CLAUDE_PROJECT_DIR="$TMP/proj" bash "$PLUGIN/hooks/scripts/$s.sh" </dev/null 2>/dev/null | grep -c '"type":"progress"')
  check "$s: no progress line on Claude Code" 0 "$out_claude"
  line=$(cd "$TMP/proj" && COPILOT_HOOK_DIR="$TMP" CLAUDE_PROJECT_DIR="$TMP/proj" bash "$PLUGIN/hooks/scripts/$s.sh" </dev/null 2>/dev/null | grep '"type":"progress"' | tail -1)
  check "$s: past-tense progress line on Copilot" yes "$(printf '%s' "$line" | is_progress)"
done

# minimal profile skips the hook entirely — no progress line either
out=$(cd "$TMP/proj" && DX_HOOK_PROFILE=minimal COPILOT_HOOK_DIR="$TMP" bash "$PLUGIN/hooks/scripts/session-start.sh" </dev/null 2>/dev/null)
check "minimal profile: nothing printed" "" "$out"

# stop guard: Claude gets nothing on a clean repo; Copilot gets only the progress line
R="$TMP/repo"; git init -q -b main "$R"
in=$(printf '{"cwd":"%s"}' "$R")
check "stop-guard: silent on Claude Code" "" "$(printf '%s' "$in" | bash "$PLUGIN/data/hooks/stop-guard.sh" 2>/dev/null)"
check "stop-guard: \"passed\" line on Copilot (clean repo)" yes "$(printf '%s' "$in" | COPILOT_HOOK_DIR="$TMP" bash "$PLUGIN/data/hooks/stop-guard.sh" 2>/dev/null | is_progress)"

echo "hook-progress: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]

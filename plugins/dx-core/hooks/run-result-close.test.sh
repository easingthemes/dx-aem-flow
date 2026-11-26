#!/usr/bin/env bash
# run-result-close.test.sh — the SessionEnd hook closes only this session's open runs.
# Hermetic: throwaway project dirs, run-result.sh from this plugin, no network, no git.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN="$(cd "$HERE/.." && pwd)"
HOOK="$PLUGIN/hooks/scripts/run-result-close.sh"
RR="$PLUGIN/data/lib/run-result.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
unset DX_RUN_ID DX_ENGINE DX_SESSION_ID CLAUDECODE CLAUDE_CODE_SESSION_ID COPILOT_AGENT_SESSION_ID COPILOT_CLI

PASS=0 FAIL=0
check() { if [ "$2" = "$3" ]; then PASS=$((PASS + 1)); else FAIL=$((FAIL + 1)); printf 'FAIL %s\n  expected: %s\n  actual:   %s\n' "$1" "$2" "$3"; fi; }
status_of() { sed -n 's/^  "status": "\(.*\)",$/\1/p' "$1"; }

P="$TMP/proj"; mkdir -p "$P"
( cd "$P" && DX_RUN_ID=run-a bash "$RR" --start --skill dx-agent-all --id 11 >/dev/null \
  && DX_RUN_ID=run-a bash "$RR" --start --skill dx-step-all --id 11 >/dev/null \
  && DX_RUN_ID=run-b bash "$RR" --start --skill dx-prep --id 12 >/dev/null \
  && env -u DX_RUN_ID bash "$RR" --start --skill dx-pr-review --id 13 >/dev/null )
D="$P/.ai/run-results"

# no DX_RUN_ID → nothing touched
( cd "$TMP" && env -u DX_RUN_ID CLAUDE_PROJECT_DIR="$P" bash "$HOOK" </dev/null ); rc=$?
check "no run id: exit 0" 0 "$rc"
check "no run id: markers untouched" 4 "$(ls "$D"/*.running.json | wc -l | tr -d ' ')"

# run-a via stdin cwd (no CLAUDE_PROJECT_DIR) → its two markers closed, others kept
( cd "$TMP" && printf '{"session_id":"s","cwd":"%s","reason":"other"}' "$P" | env -u CLAUDE_PROJECT_DIR DX_RUN_ID=run-a bash "$HOOK" ); rc=$?
check "run-a: exit 0" 0 "$rc"
check "run-a: coordinator marker removed" no "$([ -e "$D/dx-agent-all-11.running.json" ] && echo yes || echo no)"
check "run-a: nested marker removed" no "$([ -e "$D/dx-step-all-11.running.json" ] && echo yes || echo no)"
check "run-a: result failed" failed "$(status_of "$D/dx-agent-all-11.json")"
check "run-a: nested result failed" failed "$(status_of "$D/dx-step-all-11.json")"
check "run-a: summary says interrupted" yes "$(grep -q '"summary": "interrupted' "$D/dx-agent-all-11.json" && echo yes)"
check "run-a: run id kept" yes "$(grep -q '"run_id": "run-a"' "$D/dx-agent-all-11.json" && echo yes)"
check "run-a: next is the re-run" yes "$(grep -q '"next_action": "/dx-agent-all 11"' "$D/dx-agent-all-11.json" && echo yes)"
check "run-a: metric interrupted" yes "$(grep -q '"interrupted": true' "$D/dx-agent-all-11.json" && echo yes)"
check "run-b marker kept" yes "$([ -e "$D/dx-prep-12.running.json" ] && echo yes)"
check "marker without run id kept" yes "$([ -e "$D/dx-pr-review-13.running.json" ] && echo yes)"
check "history got two lines" 2 "$(wc -l < "$D/history.jsonl" | tr -d ' ')"

# a finished run is not rewritten
( cd "$P" && DX_RUN_ID=run-b bash "$RR" --skill dx-prep --id 12 --status done >/dev/null )
( cd "$TMP" && CLAUDE_PROJECT_DIR="$P" DX_RUN_ID=run-b bash "$HOOK" </dev/null )
check "finished run stays done" done "$(status_of "$D/dx-prep-12.json")"

# no results dir → exit 0
( cd "$TMP" && CLAUDE_PROJECT_DIR="$TMP/none" DX_RUN_ID=x bash "$HOOK" </dev/null ); check "no dir: exit 0" 0 "$?"

# manual runs (no DX_RUN_ID): closed by the ending session's id, others left alone
M="$TMP/manual"; mkdir -p "$M"
A=aaaaaaaa-0000-4000-8000-000000000001 B=bbbbbbbb-0000-4000-8000-000000000002 C=cccccccc-0000-4000-8000-000000000003
( cd "$M" && CLAUDECODE=1 CLAUDE_CODE_SESSION_ID=$A bash "$RR" --start --skill dx-agent-all --id 21 >/dev/null \
  && CLAUDECODE=1 CLAUDE_CODE_SESSION_ID=$A bash "$RR" --start --skill dx-step-all --id 21 >/dev/null \
  && CLAUDECODE=1 CLAUDE_CODE_SESSION_ID=$B bash "$RR" --start --skill dx-prep --id 22 >/dev/null \
  && COPILOT_AGENT_SESSION_ID=$C bash "$RR" --start --skill dx-bug-all --id 23 >/dev/null \
  && bash "$RR" --start --skill dx-pr-review --id 24 >/dev/null \
  && DX_RUN_ID=$A-kai bash "$RR" --start --skill dx-dor --id 25 >/dev/null )
MD="$M/.ai/run-results"
( cd "$TMP" && printf '{"session_id":"%s","cwd":"%s","reason":"prompt_input_exit"}' "$(printf '%s' $A | tr a-z A-Z)" "$M" \
  | env -u CLAUDE_PROJECT_DIR bash "$HOOK" ); rc=$?
check "manual: exit 0" 0 "$rc"
check "manual: session A coordinator closed" no "$([ -e "$MD/dx-agent-all-21.running.json" ] && echo yes || echo no)"
check "manual: session A nested closed" no "$([ -e "$MD/dx-step-all-21.running.json" ] && echo yes || echo no)"
check "manual: result failed" failed "$(status_of "$MD/dx-agent-all-21.json")"
check "manual: result keeps <uuid>.1" yes "$(grep -q "\"run_id\": \"$A.1\"" "$MD/dx-agent-all-21.json" && echo yes)"
check "manual: nested keeps <uuid>.2" yes "$(grep -q "\"run_id\": \"$A.2\"" "$MD/dx-step-all-21.json" && echo yes)"
check "manual: interrupted metric" yes "$(grep -q '"interrupted": true' "$MD/dx-agent-all-21.json" && echo yes)"
check "manual: session B kept" yes "$([ -e "$MD/dx-prep-22.running.json" ] && echo yes)"
check "manual: copilot session C kept" yes "$([ -e "$MD/dx-bug-all-23.running.json" ] && echo yes)"
check "manual: marker without run id kept" yes "$([ -e "$MD/dx-pr-review-24.running.json" ] && echo yes)"
check "manual: caller id that only starts with the uuid kept" yes "$([ -e "$MD/dx-dor-25.running.json" ] && echo yes)"
check "manual: counter kept for a resumed session" yes "$([ -f "$MD/.sessions/$A" ] && echo yes)"
# Copilot's SessionEnd input names the id "sessionId"
( cd "$TMP" && printf '{"sessionId":"%s","timestamp":1,"cwd":"%s","reason":"complete"}' "$C" "$M" | env -u CLAUDE_PROJECT_DIR bash "$HOOK" )
check "copilot: session C closed" failed "$(status_of "$MD/dx-bug-all-23.json")"
check "copilot: session B still kept" yes "$([ -e "$MD/dx-prep-22.running.json" ] && echo yes)"
# a bad session id closes nothing
( cd "$TMP" && printf '{"session_id":"x.y","cwd":"%s"}' "$M" | env -u CLAUDE_PROJECT_DIR bash "$HOOK" ); rc=$?
check "bad session id: exit 0" 0 "$rc"
check "bad session id: B kept" yes "$([ -e "$MD/dx-prep-22.running.json" ] && echo yes)"
# stale counters pruned, fresh ones kept
touch -t 202001010000 "$MD/.sessions/old-session"
( cd "$TMP" && printf '{"session_id":"%s","cwd":"%s"}' "$B" "$M" | env -u CLAUDE_PROJECT_DIR bash "$HOOK" )
check "session B closed" failed "$(status_of "$MD/dx-prep-22.json")"
check "stale counter pruned" no "$([ -e "$MD/.sessions/old-session" ] && echo yes || echo no)"
check "fresh counter kept" yes "$([ -f "$MD/.sessions/$B" ] && echo yes)"

# registered as a SessionEnd hook
check "registered in hooks.json" yes "$(jq -e '.hooks.SessionEnd[0].hooks[0].command | test("run-result-close.sh")' "$PLUGIN/hooks/hooks.json" >/dev/null 2>&1 && echo yes)"

echo "run-result-close: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]

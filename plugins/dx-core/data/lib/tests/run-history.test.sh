#!/usr/bin/env bash
# Hermetic tests for data/lib/run-history.sh. Builds .ai/run-results/ with
# run-result.sh itself, so a change to either side shows up here. No network, no git.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
RH="$HERE/../run-history.sh"
RR="$HERE/../run-result.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0 FAIL=0
check() { # name expected actual
  if [ "$2" = "$3" ]; then PASS=$((PASS + 1)); else FAIL=$((FAIL + 1)); printf 'FAIL %s\n  expected: %s\n  actual:   %s\n' "$1" "$2" "$3"; fi
}
command -v jq >/dev/null 2>&1 || { echo "run-history: jq missing, skipped"; exit 0; }
q() { jq -r "$1"; }

cd "$TMP" || exit 1

# --- empty ---
out=$(bash "$RH"); rc=$?
check "empty: exit 0" 0 "$rc"
check "empty: message" yes "$(printf '%s' "$out" | grep -q 'No dx runs recorded yet' && echo yes)"
check "empty json: total 0" 0 "$(bash "$RH" --json | q .total)"
check "empty json: no skills" 0 "$(bash "$RH" --json | q '.skills | length')"

# --- runs ---
bash "$RR" --start --skill dx-agent-all --id 1 >/dev/null
sed -i.bak 's/"started_at": "[^"]*"/"started_at": "2020-01-01T00:00:00Z"/' .ai/run-results/dx-agent-all-1.running.json && rm -f .ai/run-results/*.bak
bash "$RR" --skill dx-agent-all --id 1 --status done --metric fail_at=ignored-on-done >/dev/null
bash "$RR" --skill dx-agent-all --id 2 --status failed --metric fail_at=Build >/dev/null
bash "$RR" --skill dx-agent-all --id 3 --status failed --metric fail_at=Build >/dev/null
bash "$RR" --skill dx-agent-all --id 4 --status blocked --metric fail_at=Review >/dev/null
bash "$RR" --skill dx-pr-review --id 9 --status done >/dev/null
echo 'not json' >> .ai/run-results/history.jsonl
echo '{"no":"skill"}' >> .ai/run-results/history.jsonl
# an old run outside --days
printf '%s\n' '{"schema":1,"skill":"dx-prep","id":"7","status":"done","finished_at":"2020-01-01T00:00:00Z","duration_s":10}' >> .ai/run-results/history.jsonl

J=$(bash "$RH" --json)
check "bad lines skipped: total" 6 "$(printf '%s' "$J" | q .total)"
A='.skills[] | select(.skill == "dx-agent-all")'
check "runs" 4 "$(printf '%s' "$J" | q "$A | .runs")"
check "done" 1 "$(printf '%s' "$J" | q "$A | .done")"
check "failed" 2 "$(printf '%s' "$J" | q "$A | .failed")"
check "blocked" 1 "$(printf '%s' "$J" | q "$A | .blocked")"
check "success_pct floors" 25 "$(printf '%s' "$J" | q "$A | .success_pct")"
check "top fail_at ignores done runs" "Build 2" "$(printf '%s' "$J" | q "$A | \"\(.top_fail_at.at) \(.top_fail_at.count)\"")"
check "median from runs with duration" true "$(printf '%s' "$J" | q "$A | .median_duration_s > 100000000")"
check "no duration -> null median" null "$(printf '%s' "$J" | q '.skills[] | select(.skill == "dx-pr-review") | .median_duration_s')"

check "--days drops old run" 5 "$(bash "$RH" --json --days 30 | q .total)"
check "--days sets since" true "$(bash "$RH" --json --days 30 | q '.since != null')"
check "--skill filters" '["dx-pr-review"]' "$(bash "$RH" --json --skill dx-pr-review | jq -c '[.skills[].skill]')"

# --- markers: running vs stale ---
bash "$RR" --start --skill dx-prep --id 5 >/dev/null
bash "$RR" --start --skill dx-prep --id 6 >/dev/null
sed -i.bak 's/"started_at": "[^"]*"/"started_at": "2020-01-01T00:00:00Z"/' .ai/run-results/dx-prep-6.running.json && rm -f .ai/run-results/*.bak
J=$(bash "$RH" --json)
P='.skills[] | select(.skill == "dx-prep")'
check "fresh marker counts as running" 1 "$(printf '%s' "$J" | q "$P | .running")"
check "old marker counts as stale" 1 "$(printf '%s' "$J" | q "$P | .stale")"
check "markers listed" 2 "$(printf '%s' "$J" | q '.running | length')"
check "--stale-hours 0 makes both stale" 2 "$(bash "$RH" --json --stale-hours 0 --skill dx-prep | q '[.running[] | select(.stale)] | length')"
T=$(bash "$RH")
check "table has header" yes "$(printf '%s' "$T" | grep -q '^| Skill | Runs |' && echo yes)"
check "table lists stale marker" yes "$(printf '%s' "$T" | grep -q -- '- dx-prep 6 — started 2020-01-01T00:00:00Z' && echo yes)"

# --- usage errors ---
bash "$RH" --days x 2>/dev/null; check "bad --days exits 2" 2 "$?"
bash "$RH" --skill "../x" 2>/dev/null; check "bad --skill exits 2" 2 "$?"
bash "$RH" --bogus 1 2>/dev/null; check "unknown option exits 2" 2 "$?"

echo "run-history: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]

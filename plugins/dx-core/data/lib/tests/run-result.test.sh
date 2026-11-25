#!/usr/bin/env bash
# Hermetic tests for data/lib/run-result.sh. No network, no git.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../run-result.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0 FAIL=0
check() { # name expected actual
  if [ "$2" = "$3" ]; then PASS=$((PASS + 1)); else FAIL=$((FAIL + 1)); printf 'FAIL %s\n  expected: %s\n  actual:   %s\n' "$1" "$2" "$3"; fi
}
has_node=0; command -v node >/dev/null 2>&1 && has_node=1
# Parse with node when present, so the file is proven to be valid JSON.
field() { node -e 'const j=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const v=process.argv[2].split(".").reduce((o,k)=>o[k],j);process.stdout.write(v===null?"null":String(v))' "$1" "$2"; }

cd "$TMP" || exit 1

out=$(bash "$SCRIPT" --skill dx-pr-review --id 123 --status done --verdict approved --vote Approved \
  --next "none" --pr "https://dev.example.com/pr/123" --summary 'Posted 2 threads, "voted" \ ok')
check "prints path" ".ai/run-results/dx-pr-review-123.json" "$out"
check "file exists" yes "$([ -f "$out" ] && echo yes)"
check "no temp left" "" "$(ls .ai/run-results | grep tmp || true)"

if [ "$has_node" = 1 ]; then
  check "schema" 1 "$(field "$out" schema)"
  check "skill" dx-pr-review "$(field "$out" skill)"
  check "id is a string" "123" "$(field "$out" id)"
  check "vote" Approved "$(field "$out" vote)"
  check "pr link" "https://dev.example.com/pr/123" "$(field "$out" links.pr)"
  check "missing link is null" null "$(field "$out" links.wiki)"
  check "quotes and backslash escaped" 'Posted 2 threads, "voted" \ ok' "$(field "$out" summary)"
  check "finished_at is ISO" yes "$(field "$out" finished_at | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z$' && echo yes)"
fi

out=$(bash "$SCRIPT" --skill dx-bug-all --id 77 --status blocked --next $'line one\nline\ttwo' --vote "")
if [ "$has_node" = 1 ]; then
  check "newline/tab flattened" "line one line two" "$(field "$out" next_action)"
  check "empty vote is null" null "$(field "$out" vote)"
  check "verdict omitted is null" null "$(field "$out" verdict)"
fi

bash "$SCRIPT" --skill dx-bug-all --id 77 --status done >/dev/null
check "overwrite: latest wins" '  "status": "done",' "$(grep '"status"' .ai/run-results/dx-bug-all-77.json)"

bash "$SCRIPT" --skill dx-prep --id PROJ-12 --status failed --dir out/x >/dev/null
check "custom dir + jira key id" yes "$([ -f out/x/dx-prep-PROJ-12.json ] && echo yes)"

bash "$SCRIPT" --skill dx-prep --id 1 --status weird 2>/dev/null; check "bad status exits 2" 2 "$?"
bash "$SCRIPT" --skill dx-prep --id "../etc" --status done 2>/dev/null; check "path in id rejected" 2 "$?"
bash "$SCRIPT" --skill "Dx Prep" --id 1 --status done 2>/dev/null; check "bad skill rejected" 2 "$?"
bash "$SCRIPT" --skill dx-prep --id 1 --status 2>/dev/null; check "missing value exits 2" 2 "$?"
bash "$SCRIPT" --skill dx-prep --id 1 --status done --bogus x 2>/dev/null; check "unknown option exits 2" 2 "$?"
check "nothing written on usage errors" no "$([ -e .ai/run-results/dx-prep-1.json ] && echo yes || echo no)"

# --- running marker, run id, duration, history ---
cd "$TMP" && rm -rf .ai || exit 1
unset DX_RUN_ID
m=$(DX_RUN_ID=run-abc.1 bash "$SCRIPT" --start --skill dx-agent-all --id 42 --progress-file dev-all-progress.md --spec-dir .ai/specs/42-x)
check "start prints marker path" ".ai/run-results/dx-agent-all-42.running.json" "$m"
check "start: no result file yet" no "$([ -e .ai/run-results/dx-agent-all-42.json ] && echo yes || echo no)"
if [ "$has_node" = 1 ]; then
  check "marker status running" running "$(field "$m" status)"
  check "marker run_id from env" run-abc.1 "$(field "$m" run_id)"
  check "marker progress_file" dev-all-progress.md "$(field "$m" progress_file)"
  check "marker spec_dir" .ai/specs/42-x "$(field "$m" spec_dir)"
fi
# Backdate the marker so duration is non-zero without sleeping.
sed -i.bak 's/"started_at": "[^"]*"/"started_at": "2020-01-01T00:00:00Z"/' "$m" && rm -f "$m.bak"
out=$(bash "$SCRIPT" --skill dx-agent-all --id 42 --status done --summary ok)
check "final: marker removed" no "$([ -e "$m" ] && echo yes || echo no)"
if [ "$has_node" = 1 ]; then
  check "final: run_id carried from marker" run-abc.1 "$(field "$out" run_id)"
  check "final: started_at carried" 2020-01-01T00:00:00Z "$(field "$out" started_at)"
  check "final: duration_s computed" yes "$(d=$(field "$out" duration_s); [ "$d" -gt 100000000 ] 2>/dev/null && echo yes)"
fi
H=.ai/run-results/history.jsonl
check "history: one line" 1 "$(wc -l < "$H" | tr -d ' ')"
if [ "$has_node" = 1 ]; then
  check "history line is JSON with run_id" run-abc.1 "$(node -e 'const l=require("fs").readFileSync(process.argv[1],"utf8").trim().split("\n");process.stdout.write(JSON.parse(l[l.length-1]).run_id)' "$H")"
fi

out=$(bash "$SCRIPT" --skill dx-agent-all --id 42 --status failed --run-id explicit-1)
check "history: appended" 2 "$(wc -l < "$H" | tr -d ' ')"
if [ "$has_node" = 1 ]; then
  check "no marker: started_at null" null "$(field "$out" started_at)"
  check "no marker: duration null" null "$(field "$out" duration_s)"
  check "--run-id flag" explicit-1 "$(field "$out" run_id)"
fi
out=$(DX_RUN_ID='bad id; rm' bash "$SCRIPT" --skill dx-agent-all --id 42 --status done 2>/dev/null)
[ "$has_node" = 1 ] && check "invalid run id dropped" null "$(field "$out" run_id)"
out=$(DX_RUN_ID=from-env bash "$SCRIPT" --skill dx-agent-all --id 42 --status done)
[ "$has_node" = 1 ] && check "run id from env on final" from-env "$(field "$out" run_id)"

bash "$SCRIPT" --start --skill dx-prep --id 1 --status done 2>/dev/null; check "--start with --status exits 2" 2 "$?"

for _ in 1 2 3 4 5; do DX_RUN_HISTORY_MAX=4 DX_RUN_HISTORY_KEEP=2 bash "$SCRIPT" --skill dx-prep --id 9 --status done >/dev/null; done
check "history trimmed" yes "$(n=$(wc -l < "$H" | tr -d ' '); [ "$n" -le 4 ] && echo yes)"

echo "run-result: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]

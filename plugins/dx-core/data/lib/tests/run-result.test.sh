#!/usr/bin/env bash
# Hermetic tests for data/lib/run-result.sh. No network, no git.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../run-result.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
# The engine's own variables would make every run a manual run of this session.
unset DX_RUN_ID DX_ENGINE DX_SESSION_ID CLAUDECODE CLAUDE_CODE_SESSION_ID COPILOT_AGENT_SESSION_ID COPILOT_CLI

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

# --- metrics and env ---
cd "$TMP" && rm -rf .ai || exit 1
out=$(env -u CLAUDECODE -u DX_ENGINE bash "$SCRIPT" --skill dx-pr-review --id 5 --status done \
  --metric threads_posted=3 --metric must_fix=007 --metric threads_posted=4 --metric fail_at="Phase 3: build" \
  --metric ok=true --metric neg=-2 --metric BAD=1 --metric novalue --metric long="$(printf 'x%.0s' $(seq 1 120))" \
  --mode automation --mode-reason args 2>"$TMP/warn")
check "bad metrics warn, write still succeeds" 2 "$(grep -c 'skipping bad --metric' "$TMP/warn")"
if [ "$has_node" = 1 ]; then
  check "metric repeated key: last wins" 4 "$(field "$out" metrics.threads_posted)"
  check "metric leading zeros -> number" 7 "$(field "$out" metrics.must_fix)"
  check "metric string" "Phase 3: build" "$(field "$out" metrics.fail_at)"
  check "metric boolean" true "$(field "$out" metrics.ok)"
  check "metric negative" -2 "$(field "$out" metrics.neg)"
  check "metric string capped at 80" 80 "$(field "$out" metrics.long | wc -c | tr -d ' ')"
  check "metric key order" "threads_posted,must_fix,fail_at,ok,neg,long" "$(node -e 'process.stdout.write(Object.keys(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).metrics).join(","))' "$out")"
  check "env.mode" automation "$(field "$out" env.mode)"
  check "env.mode_reason" args "$(field "$out" env.mode_reason)"
  check "env.dx_version from manifest" yes "$(field "$out" env.dx_version | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+' && echo yes)"
  check "env.engine unknown is null" null "$(field "$out" env.engine)"
fi
out=$(CLAUDECODE=1 bash "$SCRIPT" --skill dx-prep --id 6 --status done)
if [ "$has_node" = 1 ]; then
  check "no metrics -> {}" "{}" "$(node -e 'process.stdout.write(JSON.stringify(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).metrics))' "$out")"
  check "engine claude under Claude Code" claude "$(field "$out" env.engine)"
fi
out=$(CLAUDECODE=1 DX_ENGINE=copilot bash "$SCRIPT" --skill dx-prep --id 6 --status done --engine other)
[ "$has_node" = 1 ] && check "--engine wins" other "$(field "$out" env.engine)"
out=$(CLAUDECODE=1 DX_ENGINE=copilot bash "$SCRIPT" --skill dx-prep --id 6 --status done)
[ "$has_node" = 1 ] && check "DX_ENGINE over CLAUDECODE" copilot "$(field "$out" env.engine)"
out=$(COPILOT_AGENT_SESSION_ID=abc bash "$SCRIPT" --skill dx-prep --id 6 --status done)
[ "$has_node" = 1 ] && check "engine copilot from COPILOT_AGENT_SESSION_ID" copilot "$(field "$out" env.engine)"
out=$(COPILOT_CLI=1 bash "$SCRIPT" --skill dx-prep --id 6 --status done)
[ "$has_node" = 1 ] && check "engine copilot from COPILOT_CLI" copilot "$(field "$out" env.engine)"
out=$(CLAUDECODE=1 COPILOT_AGENT_SESSION_ID=abc bash "$SCRIPT" --skill dx-prep --id 6 --status done)
[ "$has_node" = 1 ] && check "copilot inside a Claude Code shell is copilot" copilot "$(field "$out" env.engine)"
check "history lines stay JSON" yes "$(node -e 'require("fs").readFileSync(process.argv[1],"utf8").trim().split("\n").forEach(l=>JSON.parse(l));process.stdout.write("yes")' .ai/run-results/history.jsonl 2>/dev/null)"


# --- manual runs: run_id = <engine session id>.<n> ---
cd "$TMP" && rm -rf .ai || exit 1
U=3F1C2B9E-0000-4000-8000-00000000000A; u=3f1c2b9e-0000-4000-8000-00000000000a
m=$(CLAUDECODE=1 CLAUDE_CODE_SESSION_ID=$U bash "$SCRIPT" --start --skill dx-agent-all --id 50)
if [ "$has_node" = 1 ]; then
  check "manual claude: marker run_id <uuid>.1, lowercase" "$u.1" "$(field "$m" run_id)"
  out=$(CLAUDECODE=1 CLAUDE_CODE_SESSION_ID=$U bash "$SCRIPT" --skill dx-agent-all --id 50 --status done)
  check "manual claude: final carries the marker's id" "$u.1" "$(field "$out" run_id)"
  check "manual claude: engine claude" claude "$(field "$out" env.engine)"
  m=$(CLAUDECODE=1 CLAUDE_CODE_SESSION_ID=$U bash "$SCRIPT" --start --skill dx-step-all --id 50)
  check "manual claude: second run in session is .2" "$u.2" "$(field "$m" run_id)"
  m=$(CLAUDECODE=1 CLAUDE_CODE_SESSION_ID=$U bash "$SCRIPT" --start --skill dx-pr-review --id 51)
  check "manual claude: third run (other ticket) is .3" "$u.3" "$(field "$m" run_id)"
  out=$(CLAUDECODE=1 CLAUDE_CODE_SESSION_ID=other-session bash "$SCRIPT" --skill dx-pr-review --id 51 --status done)
  check "final takes the marker's id, not a new one" "$u.3" "$(field "$out" run_id)"
  m=$(COPILOT_AGENT_SESSION_ID=7e5602a7-9aca-4958-958d-10dc407ba73e bash "$SCRIPT" --start --skill dx-bug-all --id 52)
  check "manual copilot: own counter" "7e5602a7-9aca-4958-958d-10dc407ba73e.1" "$(field "$m" run_id)"
  out=$(COPILOT_AGENT_SESSION_ID=7e5602a7-9aca-4958-958d-10dc407ba73e bash "$SCRIPT" --skill dx-bug-all --id 52 --status blocked)
  check "manual copilot: final same id" "7e5602a7-9aca-4958-958d-10dc407ba73e.1" "$(field "$out" run_id)"
  check "manual copilot: engine copilot" copilot "$(field "$out" env.engine)"
  out=$(CLAUDECODE=1 CLAUDE_CODE_SESSION_ID=$U bash "$SCRIPT" --skill dx-dor --id 53 --status done)
  check "final with no marker mints the next id" "$u.4" "$(field "$out" run_id)"
  m=$(DX_SESSION_ID=Sess-X CLAUDECODE=1 CLAUDE_CODE_SESSION_ID=$U bash "$SCRIPT" --start --skill dx-prep --id 54)
  check "DX_SESSION_ID overrides the engine's" "sess-x.1" "$(field "$m" run_id)"
  # caller id: unchanged behavior, no counter consumed
  m=$(DX_RUN_ID=kai-flow-1 CLAUDECODE=1 CLAUDE_CODE_SESSION_ID=$U bash "$SCRIPT" --start --skill dx-prep --id 55)
  check "DX_RUN_ID set: marker keeps it" kai-flow-1 "$(field "$m" run_id)"
  out=$(CLAUDECODE=1 CLAUDE_CODE_SESSION_ID=$U DX_RUN_ID=kai-flow-1 bash "$SCRIPT" --skill dx-prep --id 55 --status done)
  check "DX_RUN_ID set: final keeps it" kai-flow-1 "$(field "$out" run_id)"
  out=$(CLAUDECODE=1 CLAUDE_CODE_SESSION_ID=$U bash "$SCRIPT" --skill dx-prep --id 56 --status done --run-id "")
  check "explicit empty --run-id stays null" null "$(field "$out" run_id)"
  m=$(CLAUDECODE=1 CLAUDE_CODE_SESSION_ID=$U bash "$SCRIPT" --start --skill dx-prep --id 57)
  check "caller ids consumed no counter" "$u.5" "$(field "$m" run_id)"
  # invalid session ids → null, never a broken id
  m=$(CLAUDECODE=1 CLAUDE_CODE_SESSION_ID='a.b' bash "$SCRIPT" --start --skill dx-prep --id 58 2>/dev/null)
  check "session id with a dot: null" null "$(field "$m" run_id)"
  m=$(CLAUDECODE=1 CLAUDE_CODE_SESSION_ID='x y;rm' bash "$SCRIPT" --start --skill dx-prep --id 58 2>"$TMP/warn")
  check "session id with bad characters: null" null "$(field "$m" run_id)"
  check "bad session id warns" 1 "$(grep -c 'ignoring session id' "$TMP/warn")"
  m=$(CLAUDECODE=1 CLAUDE_CODE_SESSION_ID="$(printf 'a%.0s' $(seq 1 61))" bash "$SCRIPT" --start --skill dx-prep --id 58 2>/dev/null)
  check "session id too long: null" null "$(field "$m" run_id)"
  m=$(bash "$SCRIPT" --start --skill dx-prep --id 59)
  check "no engine, no session: null" null "$(field "$m" run_id)"
fi
check "no counter lock left" "" "$(ls .ai/run-results/.sessions | grep lock || true)"
check "counter files are not result files" 0 "$(ls .ai/run-results/.sessions | grep -c json || true)"
# concurrent starts in one session never share an id
for i in 1 2 3 4 5 6; do (CLAUDECODE=1 CLAUDE_CODE_SESSION_ID=par bash "$SCRIPT" --start --skill dx-prep --id "p$i" >/dev/null) & done; wait
if [ "$has_node" = 1 ]; then
  check "parallel starts: 6 distinct ids" 6 "$(for i in 1 2 3 4 5 6; do field .ai/run-results/dx-prep-p$i.running.json run_id; echo; done | sort -u | grep -c '^par\.[1-6]$')"
fi

echo "run-result: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]

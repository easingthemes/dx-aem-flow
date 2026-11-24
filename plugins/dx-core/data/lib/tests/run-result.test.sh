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

echo "run-result: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]

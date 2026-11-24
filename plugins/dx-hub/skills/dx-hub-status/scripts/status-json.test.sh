#!/usr/bin/env bash
# Hermetic tests for status-json.sh. No network, no git.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/status-json.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0 FAIL=0
check() {
  if [ "$2" = "$3" ]; then PASS=$((PASS + 1)); else FAIL=$((FAIL + 1)); printf 'FAIL %s\n  expected: %s\n  actual:   %s\n' "$1" "$2" "$3"; fi
}
has_node=0; command -v node >/dev/null 2>&1 && has_node=1
# Evaluate a JS expression over the parsed array `a` (proves the output is valid JSON).
q() { node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const a=JSON.parse(s);process.stdout.write(String(eval(process.argv[1])))})' "$1"; }

cd "$TMP" || exit 1

check "missing state dir" "[]" "$(bash "$SCRIPT" state)"
mkdir -p state
check "empty state dir" "[]" "$(bash "$SCRIPT")"

mkdir -p state/111 state/222 state/333 state/444
cat > state/111/status.json <<'EOF'
{
  "ticket": "111",
  "engine": "copilot",
  "repos": { "repo-a": "running", "repo-b": "done" },
  "sessions": { "repo-a": "0b1c2d3e-0000-4000-8000-000000000001" }
}
EOF
printf '  {"ticket": "222", "repos": {"repo-a": "blocked"}}\n\n' > state/222/status.json
printf '{"ticket": "333", "repos": {' > state/333/status.json   # half-written
: > state/444/status.json                                         # empty
mkdir -p state/555                                                # no status.json

out="$(bash "$SCRIPT")"
if [ "$has_node" = 1 ]; then
  check "four entries" 4 "$(printf '%s' "$out" | q 'a.length')"
  check "keeps fields" "copilot" "$(printf '%s' "$out" | q 'a.find(e=>e.ticket==="111").engine')"
  check "keeps session ids" "0b1c2d3e-0000-4000-8000-000000000001" "$(printf '%s' "$out" | q 'a.find(e=>e.ticket==="111").sessions["repo-a"]')"
  check "trims whitespace" "blocked" "$(printf '%s' "$out" | q 'a.find(e=>e.ticket==="222").repos["repo-a"]')"
  check "half-written → error entry" "unreadable status.json" "$(printf '%s' "$out" | q 'a.find(e=>e.ticket==="333").error')"
  check "empty → error entry" "unreadable status.json" "$(printf '%s' "$out" | q 'a.find(e=>e.ticket==="444").error')"
  check "one ticket" "1:222" "$(bash "$SCRIPT" state 222 | q 'a.length+":"+a[0].ticket')"
  check "unknown ticket" 0 "$(bash "$SCRIPT" state 999 | q 'a.length')"
else
  check "four entries (no node)" 4 "$(printf '%s\n' "$out" | grep -c '"ticket"')"
fi

echo "status-json: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]

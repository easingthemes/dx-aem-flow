#!/usr/bin/env bash
# Behavioral fixture harness for /dx-bug-all resumable recovery.
#
# Mirrors dx-simple's resume-recovery test but over the coarse bug steps
# (triage → verify → fix → finalize). Without any live ADO/AEM, it seeds throwaway
# git repos + a resume-state.json and asserts resume-check.sh dispatches correctly
# and save-state.sh's commit + bump invariants hold.
#
# Run: bash plugins/dx-core/skills/dx-bug-all/scripts/__tests__/resume-recovery.test.sh
# Exits non-zero on any failed assertion.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="$(cd "$SCRIPT_DIR/.." && pwd)"
RESUME="$SCRIPTS/resume-check.sh"
SAVE="$SCRIPTS/save-state.sh"
TMPL="$(cd "$SCRIPTS/../templates" && pwd)/resume-state.json.tmpl"

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not installed — recovery fixture needs jq"; exit 0; }

PASS=0; FAIL=0
ROOT=$(mktemp -d)
trap 'rm -rf "$ROOT"' EXIT

ok()  { echo "PASS: $1"; PASS=$((PASS+1)); }
bad() { echo "FAIL: $1"; echo "    $2"; FAIL=$((FAIL+1)); }

assert_kv() {  # name, output, "key=value"
  local name="$1" out="$2" want="$3"
  if grep -qxF "$want" <<<"$out"; then ok "$name"; else
    bad "$name" "expected line '$want' in:
$(sed 's/^/      | /' <<<"$out")"
  fi
}
assert_not_substr() {  # name, output, substring-that-must-be-absent
  local name="$1" out="$2" no="$3"
  if grep -qF "$no" <<<"$out"; then bad "$name" "did NOT expect '$no'"; else ok "$name"; fi
}

# Seed a repo with a bugfix branch carrying a committed resume-state.json.
# Args: <repo-dir> <ticket-id> <state-json> [extra-branch ...]   (HEAD left on main)
seed_repo() {
  local dir="$1" id="$2" state="$3"; shift 3
  git init -q -b main "$dir"
  ( cd "$dir"
    git config user.email t@t.t; git config user.name t
    echo seed > seed.txt; git add seed.txt; git commit -qm init
    git checkout -qb "bugfix/${id}-preview"
    mkdir -p ".ai/specs/${id}-preview"
    printf '%s\n' "$state" > ".ai/specs/${id}-preview/resume-state.json"
    git add ".ai/specs/${id}-preview/resume-state.json"
    git commit -qm checkpoint
    local b; for b in "$@"; do git checkout -qb "$b" main; done
    git checkout -q main
  )
}

state() {  # status last-completed-step blocked-at-step attempts
  jq -nc --arg st "$1" --arg lc "$2" --arg ba "$3" --argjson at "${4:-0}" \
    '{ticket:"x",status:$st,"last-completed-step":$lc,"blocked-at-step":$ba,"answer-attempts":$at,"comment-cursor":"","run-history":[]}'
}

# --- 1. fresh: no branch at all -----------------------------------------------
R=$(mktemp -d); git init -q -b main "$R" >/dev/null
( cd "$R"; git config user.email t@t.t; git config user.name t; git commit -q --allow-empty -m init )
OUT=$(cd "$R" && bash "$RESUME" 2453532)
assert_kv "fresh: no branch → DISPATCH=fresh" "$OUT" "DISPATCH=fresh"

# --- 2. resume-forward: crashed after triage ----------------------------------
D=$ROOT/rf; seed_repo "$D" 2453532 "$(state in-progress triage '')"
OUT=$(cd "$D" && bash "$RESUME" 2453532)
assert_kv "crash after triage → resume-forward" "$OUT" "DISPATCH=resume-forward"
assert_kv "crash after triage → re-enter verify" "$OUT" "RE_ENTER_STEP=verify"

# --- 3. resume-forward: crashed after verify ----------------------------------
D=$ROOT/rf2; seed_repo "$D" 2453532 "$(state in-progress verify '')"
OUT=$(cd "$D" && bash "$RESUME" 2453532)
assert_kv "crash after verify → re-enter fix" "$OUT" "RE_ENTER_STEP=fix"

# --- 4. resume-forward: crashed after fix → finalize --------------------------
D=$ROOT/rf3; seed_repo "$D" 2453532 "$(state in-progress fix '')"
OUT=$(cd "$D" && bash "$RESUME" 2453532)
assert_kv "crash after fix → re-enter finalize" "$OUT" "RE_ENTER_STEP=finalize"

# --- 5. blocked-needs-input under cap -----------------------------------------
D=$ROOT/bi; seed_repo "$D" 2453532 "$(state blocked-needs-input triage verify 1)"
OUT=$(cd "$D" && bash "$RESUME" 2453532)
assert_kv "needs-input under cap → resume-blocked-input" "$OUT" "DISPATCH=resume-blocked-input"
assert_kv "needs-input re-enters blocked step" "$OUT" "RE_ENTER_STEP=verify"

# --- 6. blocked-needs-input cap reached → downgraded to hard -------------------
D=$ROOT/cap; seed_repo "$D" 2453532 "$(state blocked-needs-input triage verify 3)"
OUT=$(cd "$D" && bash "$RESUME" 2453532)
assert_kv "needs-input cap → resume-blocked-hard" "$OUT" "DISPATCH=resume-blocked-hard"

# --- 7. done ------------------------------------------------------------------
D=$ROOT/done; seed_repo "$D" 2453532 "$(state done fix '')"
OUT=$(cd "$D" && bash "$RESUME" 2453532)
assert_kv "done → DISPATCH=done" "$OUT" "DISPATCH=done"

# --- 8. ambiguous: >1 anchored branch -----------------------------------------
D=$ROOT/amb; seed_repo "$D" 2453532 "$(state in-progress triage '')" "bugfix/2453532-other"
OUT=$(cd "$D" && bash "$RESUME" 2453532)
assert_kv "two branches → ambiguous-branch" "$OUT" "DISPATCH=ambiguous-branch"

# --- 9. anchor safety: 245 must NOT match bugfix/2453532-* --------------------
D=$ROOT/anchor; seed_repo "$D" 2453532 "$(state in-progress triage '')"
OUT=$(cd "$D" && bash "$RESUME" 245)
assert_kv "anchor: 245 ≠ 2453532 → fresh" "$OUT" "DISPATCH=fresh"
assert_not_substr "anchor: 245 emits no 2453532 branch" "$OUT" "2453532"

# --- 10. save-state: bumps last-completed-step + commits ----------------------
D=$ROOT/ss; seed_repo "$D" 2453532 "$(state in-progress triage '')"
( cd "$D"
  git checkout -q "bugfix/2453532-preview"
  echo "# triage" > ".ai/specs/2453532-preview/triage.md"
  bash "$SAVE" ".ai/specs/2453532-preview" "verify" >/dev/null 2>&1
)
LC=$(jq -r '.["last-completed-step"]' "$D/.ai/specs/2453532-preview/resume-state.json")
[[ "$LC" == "verify" ]] && ok "save-state bumps last-completed-step → verify" \
  || bad "save-state bumps last-completed-step" "got '$LC'"
( cd "$D" && git log -1 --format='%s' | grep -q 'chore(dx-bug-all): checkpoint verify' ) \
  && ok "save-state commits checkpoint" || bad "save-state commits checkpoint" "no checkpoint commit"

echo
echo "================ $PASS passed, $FAIL failed ================"
[[ "$FAIL" -eq 0 ]]

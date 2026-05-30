#!/usr/bin/env bash
# Behavioral fixture harness for /dx-simple resumable recovery (TODO #141, M6).
#
# This is the REAL verification of the recovery design: without any live ADO/AEM,
# it seeds throwaway git repos + a resume-state.json and asserts that
# resume-check.sh dispatches correctly and save-state.sh's commit-and-push +
# rebase-bail invariants hold.
#
# Run from anywhere: bash plugins/dx-core/skills/dx-simple/scripts/__tests__/resume-recovery.test.sh
# Exits non-zero on any failed assertion.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="$(cd "$SCRIPT_DIR/.." && pwd)"
RESUME="$SCRIPTS/resume-check.sh"
SAVE="$SCRIPTS/save-state.sh"

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not installed — recovery fixture needs jq"; exit 0; }

PASS=0
FAIL=0
ROOT=$(mktemp -d)
trap 'rm -rf "$ROOT"' EXIT

ok()   { echo "PASS: $1"; PASS=$((PASS+1)); }
bad()  { echo "FAIL: $1"; echo "    $2"; FAIL=$((FAIL+1)); }

# assert that "$haystack" contains line "key=value"
assert_kv() {
  local name="$1" out="$2" want="$3"
  if grep -qxF "$want" <<<"$out"; then ok "$name"; else
    bad "$name" "expected line '$want' in:
$(sed 's/^/      | /' <<<"$out")"
  fi
}
assert_not_kv() {
  local name="$1" out="$2" notwant="$3"
  if grep -qxF "$notwant" <<<"$out"; then
    bad "$name" "did NOT expect line '$notwant'"
  else ok "$name"; fi
}

# Seed a git repo with a feature branch carrying a committed resume-state.json.
# Args: <repo-dir> <ticket-id> <state-json> [extra-branch ...]
# Leaves HEAD on 'main' so resume-check must discover + checkout the feature branch.
seed_repo() {
  local dir="$1" id="$2" state="$3"; shift 3
  git init -q -b main "$dir"
  ( cd "$dir"
    git config user.email t@t.t; git config user.name t
    echo seed > seed.txt; git add seed.txt; git commit -qm init
    git checkout -qb "feature/${id}-simple"
    mkdir -p ".ai/specs/${id}-simple"
    printf '%s\n' "$state" > ".ai/specs/${id}-simple/resume-state.json"
    git add ".ai/specs/${id}-simple/resume-state.json"
    git commit -qm "checkpoint"
    local b
    for b in "$@"; do git checkout -qb "$b" main; done
    git checkout -q main
  )
}

state() {  # build a resume-state.json with given status/last/blocked/attempts
  jq -n --arg s "$1" --arg l "$2" --arg b "$3" --argjson a "${4:-0}" \
    '{ticket:"x",status:$s,"last-completed-phase":$l,"blocked-at-phase":$b,"answer-attempts":$a,blocker:{},"comment-cursor":"","run-history":[]}'
}

echo "=== resume-check.sh dispatch ==="

# 1. in-progress @ Phase 1 → resume forward at Phase 2, no replay.
R=$ROOT/r1; seed_repo "$R" 111 "$(state in-progress 'Phase 1' '')"
OUT=$(cd "$R" && bash "$RESUME" 111)
assert_kv "in-progress Phase1 → resume-forward" "$OUT" "DISPATCH=resume-forward"
assert_kv "in-progress Phase1 → re-enter Phase 2" "$OUT" "RE_ENTER_PHASE=Phase 2"
assert_kv "in-progress Phase1 → no code replay"  "$OUT" "REPLAY_CODE_EDITS=false"

# 2. in-progress @ Phase 5 → replay code edits (past 3b).
R=$ROOT/r2; seed_repo "$R" 222 "$(state in-progress 'Phase 5' '')"
OUT=$(cd "$R" && bash "$RESUME" 222)
assert_kv "in-progress Phase5 → resume-forward" "$OUT" "DISPATCH=resume-forward"
assert_kv "in-progress Phase5 → replay code edits" "$OUT" "REPLAY_CODE_EDITS=true"

# 3. blocked-needs-input @ G4 → re-enter Phase 3b (authoring NOT rolled back —
#    resume-check never rolls back; that is the ABORT path's job).
R=$ROOT/r3; seed_repo "$R" 333 "$(state blocked-needs-input 'Phase 3a' 'G4' 1)"
OUT=$(cd "$R" && bash "$RESUME" 333)
assert_kv "G4 block → resume-blocked-input" "$OUT" "DISPATCH=resume-blocked-input"
assert_kv "G4 block → re-enter Phase 3b"    "$OUT" "RE_ENTER_PHASE=Phase 3b"
assert_kv "G4 block → 3b re-applies, no separate replay" "$OUT" "REPLAY_CODE_EDITS=false"

# 4. done → no-op.
R=$ROOT/r4; seed_repo "$R" 444 "$(state done 'Phase 7' '')"
OUT=$(cd "$R" && bash "$RESUME" 444)
assert_kv "done → done dispatch" "$OUT" "DISPATCH=done"

echo "=== anchored branch matching (M1) ==="

# 5a. Two feature/<id>-* refs → ambiguous-branch.
R=$ROOT/r5; git init -q -b main "$R"
( cd "$R"; git config user.email t@t.t; git config user.name t
  echo x>x; git add x; git commit -qm init
  git checkout -qb feature/555-alpha main
  git checkout -qb feature/555-beta  main
  git checkout -q main )
OUT=$(cd "$R" && bash "$RESUME" 555)
assert_kv "two matches → ambiguous-branch" "$OUT" "DISPATCH=ambiguous-branch"

# 5b. id 123 must NOT match feature/1234-x (anchored, no substring) → fresh.
R=$ROOT/r6; git init -q -b main "$R"
( cd "$R"; git config user.email t@t.t; git config user.name t
  echo x>x; git add x; git commit -qm init
  git checkout -qb feature/1234-x main
  git checkout -q main )
OUT=$(cd "$R" && bash "$RESUME" 123)
assert_kv "123 does not match 1234 → fresh" "$OUT" "DISPATCH=fresh"
assert_kv "fresh creates feature/123-simple" "$OUT" "BRANCH=feature/123-simple"

echo "=== answer-attempts cap (M4) ==="

# 6a. answer-attempts == max (3) + still blocked → downgrade to hard.
R=$ROOT/r7; seed_repo "$R" 777 "$(state blocked-needs-input 'Phase 3b' 'G4' 3)"
OUT=$(cd "$R" && bash "$RESUME" 777)
assert_kv "attempts==cap → downgrade to blocked-hard" "$OUT" "DISPATCH=resume-blocked-hard"

# 6b. A crash resume (in-progress) does NOT increment answer-attempts (read-only).
R=$ROOT/r8; seed_repo "$R" 888 "$(state in-progress 'Phase 2' '' 2)"
BEFORE=$(cd "$R" && cat ".ai/specs/888-simple/resume-state.json" 2>/dev/null || true)
# (file is on the feature branch; check out happens inside resume-check)
OUT=$(cd "$R" && bash "$RESUME" 888)
AFTER=$(cd "$R" && jq -r '."answer-attempts"' ".ai/specs/888-simple/resume-state.json")
if [[ "$AFTER" == "2" ]]; then ok "crash resume keeps answer-attempts at 2 (no increment)"
else bad "crash resume must not bump answer-attempts" "got answer-attempts=$AFTER"; fi
assert_kv "crash resume reports attempts=2" "$OUT" "ANSWER_ATTEMPTS=2"

echo "=== save-state.sh commit + push + rebase-bail (H2) ==="

# Bare remote + clone A. Checkpoint should commit AND push.
BARE=$ROOT/bare.git; git init -q --bare -b main "$BARE"
A=$ROOT/cloneA; git clone -q "$BARE" "$A"
( cd "$A"; git config user.email a@a.a; git config user.name a
  echo base > base.txt; git add base.txt; git commit -qm base
  git branch -M main; git push -q -u origin main
  git checkout -qb feature/999-simple
  mkdir -p .ai/specs/999-simple
  state in-progress 'Phase 1' '' > .ai/specs/999-simple/resume-state.json )
OUT=$( cd "$A" && bash "$SAVE" .ai/specs/999-simple "Phase 1" 2>&1 ); RC=$?
[[ "$RC" -eq 0 ]] && ok "save-state checkpoint exits 0" || bad "save-state should exit 0" "rc=$RC out=$OUT"

# Committed AND pushed: a fresh clone sees the state on the branch.
C=$ROOT/cloneC; git clone -q "$BARE" "$C"
if ( cd "$C" && git show "origin/feature/999-simple:.ai/specs/999-simple/resume-state.json" >/dev/null 2>&1 ); then
  ok "resume-state.json is committed AND pushed (visible in fresh clone)"
else bad "resume-state.json must be pushed to origin" "not found via git show in fresh clone"; fi

# Concurrent advance: clone B pushes a CONFLICTING change to the same file, then
# A's next checkpoint must rebase-then-bail (exit 3) rather than force-push.
B=$ROOT/cloneB; git clone -q "$BARE" "$B"
( cd "$B"; git config user.email b@b.b; git config user.name b
  git checkout -q feature/999-simple
  state in-progress 'Phase 9-from-B' '' > .ai/specs/999-simple/resume-state.json
  git add .ai/specs/999-simple/resume-state.json
  git commit -qm "B advances the branch"
  git push -q origin feature/999-simple )
# A makes its own conflicting change and checkpoints → branch advanced.
( cd "$A"; state in-progress 'Phase 2-from-A' '' > .ai/specs/999-simple/resume-state.json )
OUT=$( cd "$A" && bash "$SAVE" .ai/specs/999-simple "Phase 2" 2>&1 ); RC=$?
if [[ "$RC" -eq 3 ]]; then ok "save-state bails (exit 3) on branch advanced under another run"
else bad "save-state should exit 3 on un-rebasable non-ff" "rc=$RC out=$OUT"; fi
if grep -q "BRANCH-ADVANCED" <<<"$OUT"; then ok "save-state prints BRANCH-ADVANCED message"
else bad "save-state should print BRANCH-ADVANCED" "out=$OUT"; fi

echo
echo "================ $PASS passed, $FAIL failed ================"
[[ "$FAIL" -eq 0 ]]

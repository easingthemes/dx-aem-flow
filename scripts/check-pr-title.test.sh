#!/usr/bin/env bash
# check-pr-title.test.sh — the title check accepts conventional titles only.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
PASS=0; FAIL=0
expect() { # expect <0|1> <title>
  bash "$HERE/check-pr-title.sh" "$2" >/dev/null 2>&1; local rc=$?
  if [ "$rc" = "$1" ]; then PASS=$((PASS + 1)); else echo "FAIL want $1 got $rc: $2"; FAIL=$((FAIL + 1)); fi
}
expect 0 "fix(dx-core): skills find shared/ files on Copilot CLI"
expect 0 "feat: dx agents get project instructions"
expect 0 "docs(todo): close TODO-86"
expect 0 "feat(dx-core)!: drop the old config"
expect 1 "Copilot CLI re-test checklist; hook status lines read as done (TODO-271, TODO-270)"
expect 1 "Fix: capitalised type"
expect 1 "fix:no space"
expect 1 "fixes(dx-core): wrong type"
expect 1 ""
echo "check-pr-title: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]

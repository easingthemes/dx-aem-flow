#!/usr/bin/env bash
# rules-freshness.sh: a rule file is stale only when it is both old AND the code
# moved a lot since; untracked files are reported, not judged; rule edits under
# .ai/ and .claude/ do not count as code churn.
#
# Hermetic: throwaway git repo with per-repo identity and fixed commit dates,
# DX_NOW pins "today", so the result does not depend on the clock.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="${SCRIPT:-$HERE/../rules-freshness.sh}"
FAIL=0; PASS=0
ok()  { PASS=$((PASS+1)); echo "  ok   $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL $1"; }

T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
R="$T/repo"; mkdir -p "$R"; cd "$R" || exit 1
git init -q
git config user.email bot@example.com
git config user.name "Test Bot"
git config commit.gpgsign false

DAY=86400
BASE=1767225600                 # 2026-01-01T00:00:00Z
export DX_NOW=$((BASE + 200*DAY))   # "today" = day 200

commit_at() { # day message
  GIT_AUTHOR_DATE="@$((BASE + $1*DAY)) +0000" GIT_COMMITTER_DATE="@$((BASE + $1*DAY)) +0000" \
    git commit -q -m "$2"
}

mkdir -p .ai/rules .ai/project .claude/rules src
echo "old rule"   > .ai/rules/old.md
echo "seed"       > .ai/project/project.yaml
echo "code"       > src/a.txt
git add -A; commit_at 0 "init"

# 5 code commits after the old rule (day 1..5)
for i in 1 2 3 4 5; do echo "$i" >> src/a.txt; git add -A; commit_at "$i" "code $i"; done
# churn under .ai/ and .claude/ must not count as code commits
echo x > .claude/rules/r.md; git add -A; commit_at 6 "claude rule"
echo y > .ai/rules/other-note.md; git add -A; commit_at 7 "ai note"
# a fresh rule on day 195, then 1 code commit
echo "new rule" > .ai/rules/new.md; git add -A; commit_at 195 "new rule"
echo 6 >> src/a.txt; git add -A; commit_at 196 "code 6"
# untracked file
echo "draft" > .ai/rules/draft.md

row() { printf '%s\n' "$OUT" | awk -F'\t' -v f="$1" '$2==f'; }

echo "== thresholds 90 days / 3 commits"
OUT=$(bash "$SCRIPT" --max-days 90 --max-commits 3); rc=$?
[ "$rc" -eq 0 ] && ok "exit 0" || bad "exit $rc"
r=$(row .ai/rules/old.md)
[ "$(cut -f1 <<<"$r")" = stale ] && ok "old + busy → stale" || bad "old.md: $r"
[ "$(cut -f3 <<<"$r")" = 2026-01-01 ] && ok "last-change date" || bad "date: $r"
[ "$(cut -f4 <<<"$r")" = 200 ] && ok "age 200 days" || bad "age: $r"
[ "$(cut -f5 <<<"$r")" = 6 ] && ok ".ai/.claude commits excluded (6 code commits)" || bad "since: $r"
r=$(row .ai/rules/new.md)
[ "$(cut -f1 <<<"$r")" = fresh ] && ok "recent rule → fresh" || bad "new.md: $r"
r=$(row .ai/rules/draft.md)
[ "$(cut -f1 <<<"$r")" = untracked ] && ok "untracked reported" || bad "draft.md: $r"
r=$(row .ai/project/project.yaml)
[ "$(cut -f1 <<<"$r")" = stale ] && ok "seed data checked too" || bad "project.yaml: $r"

echo "== old but quiet repo is not stale (commit threshold not reached)"
OUT=$(bash "$SCRIPT" --max-days 90 --max-commits 50)
[ "$(row .ai/rules/old.md | cut -f1)" = fresh ] && ok "old + quiet → fresh" || bad "$(row .ai/rules/old.md)"

echo "== busy but recent is not stale (age threshold not reached)"
OUT=$(bash "$SCRIPT" --max-days 365 --max-commits 3)
[ "$(row .ai/rules/old.md | cut -f1)" = fresh ] && ok "busy + young → fresh" || bad "$(row .ai/rules/old.md)"

echo "== runs from a subdirectory"
OUT=$(cd src && bash "$SCRIPT" --max-days 90 --max-commits 3)
[ "$(row .ai/rules/old.md | cut -f1)" = stale ] && ok "resolves repo root" || bad "subdir: $OUT"

echo "== usage errors"
bash "$SCRIPT" --max-days abc >/dev/null 2>&1; [ $? -eq 2 ] && ok "non-numeric threshold → 2" || bad "non-numeric accepted"
bash "$SCRIPT" --bogus >/dev/null 2>&1; [ $? -eq 2 ] && ok "unknown flag → 2" || bad "unknown flag accepted"
mkdir -p "$T/nogit"
bash "$SCRIPT" --repo "$T/nogit" >/dev/null 2>&1; [ $? -eq 2 ] && ok "not a git repo → 2" || bad "no-git accepted"

echo
echo "passed: $PASS  failed: $FAIL"
[ "$FAIL" -eq 0 ]

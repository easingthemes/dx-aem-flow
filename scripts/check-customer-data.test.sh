#!/usr/bin/env bash
# check-customer-data.sh: finds denylisted terms in diffs, paths, commit
# messages, stdin and files; never prints the term or the matching text.
# Hermetic: throwaway git repo, made-up terms, no network.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
CHECK="$HERE/check-customer-data.sh"
FAIL=0; PASS=0
ok()  { PASS=$((PASS+1)); echo "  ok   $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL $1"; }

T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
R="$T/repo"; mkdir -p "$R"; cd "$R" || exit 1
git init -q -b main . && git config user.email t@example.com && git config user.name t
echo "clean" > a.txt && git add . && git commit -qm "init"
git checkout -qb work

export CUSTOMER_DENYLIST="zorblax, \bqux\b"
export CUSTOMER_DENYLIST_FILE="$T/none"   # only the env list

run() { OUT=$(bash "$CHECK" "$@" 2>"$T/err"); RC=$?; }

# 1. clean branch
echo "fine" >> a.txt && git commit -qam "fix: generic change"
run diff main
[ "$RC" -eq 0 ] && ok "clean diff passes" || bad "clean diff rc=$RC: $OUT"

# 2. term in an added line, case-insensitive
printf 'line one\norg: ZorbLax\n' > b.txt && git add b.txt && git commit -qm "add b"
run diff main
[ "$RC" -eq 1 ] && grep -q "LEAK: b.txt:2 matches denylist entry #1" <<<"$OUT" \
  && ok "added line caught with path:line" || bad "added line: rc=$RC $OUT"
grep -qi zorblax <<<"$OUT$(cat "$T/err")" && bad "term echoed in output" || ok "term never printed"

# 3. word-anchored entry: 'quxx' is not 'qux'
git reset -q --hard main && git checkout -q -B work
echo "quxx is fine" > c.txt && git add c.txt && git commit -qm "add c"
run diff main
[ "$RC" -eq 0 ] && ok "anchored entry ignores longer word" || bad "anchor: $OUT"

# 4. term only in a commit message
git commit -q --allow-empty -m "fix: thing for qux team"
run diff main
grep -q "LEAK: commit [0-9a-f]* message matches denylist entry #2" <<<"$OUT" \
  && ok "commit message caught" || bad "commit message: $OUT"

# 5. term only in a file path
git reset -q --hard main && git checkout -q -B work
mkdir -p docs && echo ok > docs/zorblax-notes.md && git add . && git commit -qm "add notes"
run diff main
grep -q "LEAK: docs/zorblax-notes.md matches" <<<"$OUT" && ok "file path caught" || bad "path: $OUT"

# 6. worktree mode: staged + unstaged, not yet committed
git reset -q --hard main && git checkout -q -B work
echo "zorblax" >> a.txt
run worktree
[ "$RC" -eq 1 ] && ok "uncommitted change caught" || bad "worktree rc=$RC"
git checkout -q -- a.txt

# 7. text mode (PR body)
run text "PR body" <<<$'Summary\nSeen on qux builds'
grep -q "LEAK: PR body:2 matches denylist entry #2" <<<"$OUT" && ok "stdin text caught" || bad "text: $OUT"

# 8. files mode + denylist file with comments
printf '# comment line\nplughwump   # trailing comment\n' > "$T/list"
echo "x plughwump y" > "$T/f.md"
OUT=$(CUSTOMER_DENYLIST="" CUSTOMER_DENYLIST_FILE="$T/list" bash "$CHECK" files "$T/f.md" 2>/dev/null); RC=$?
[ "$RC" -eq 1 ] && grep -q "f.md:1 matches denylist entry #1" <<<"$OUT" \
  && ok "denylist file + files mode" || bad "file list: rc=$RC $OUT"

# 9. no denylist → skip, exit 0, says so
OUT=$(CUSTOMER_DENYLIST="" CUSTOMER_DENYLIST_FILE="$T/none" bash "$CHECK" text x <<<"zorblax" 2>&1); RC=$?
[ "$RC" -eq 0 ] && grep -q "no denylist configured" <<<"$OUT" && ok "no denylist skips loudly" || bad "no list: rc=$RC"

# 10. bad mode is a usage error
run bogus
[ "$RC" -eq 2 ] && ok "unknown mode exits 2" || bad "bogus rc=$RC"

echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]

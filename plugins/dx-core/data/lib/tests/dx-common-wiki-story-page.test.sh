#!/usr/bin/env bash
# Hermetic tests for `dx-common.sh wiki-story-page` — picks the existing wiki
# story page for a work item. Page names below are invented placeholders in the
# shapes seen on hand-made wikis: "<id>-<slug>", "<id> <title>", "<id>: <title>",
# several leading ids, brackets and parentheses in titles.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../dx-common.sh"
PASS=0; FAIL=0
R="/My-Wiki/Tech-Docs"

# run <stdin-paths> <args...>: sets OUT, RC
run() {
  local input="$1"; shift
  OUT="$(printf '%s' "$input" | bash "$SCRIPT" wiki-story-page "$@" 2>/dev/null)"; RC=$?
}
check() { # name expected actual
  if [ "$2" = "$3" ]; then PASS=$((PASS+1)); echo "ok   - $1"
  else FAIL=$((FAIL+1)); echo "FAIL - $1"; echo "  expected: $(printf %q "$2")"; echo "  actual:   $(printf %q "$3")"; fi
}
match() { printf '%s\n' "$OUT" | sed -n 's/^MATCH=//p'; }
scope() { printf '%s\n' "$OUT" | sed -n 's/^SCOPE=//p'; }
others() { printf '%s\n' "$OUT" | sed -n 's/^OTHER=//p'; }
nl=$'\n'

# --- each name form, alone in a sprint folder ---
for name in \
  "1000001-Add-Widget-Option" \
  "1000001 Capture user response" \
  "1000001: [API] Care flow update" \
  "1000001 - Title after a dash" \
  "1000001: [AEM] Banner (Brand A,Brand B,Plan C)" \
  "1000001"; do
  run "$R/Sprint 10/$name$nl" --id 1000001
  check "form matches: $name" "$R/Sprint 10/$name" "$(match)"
done

# --- several leading ids ---
run "$R/Sprint 10/1000005 1000001 [API] Shared work$nl" --id 1000001
check "second of two space-separated ids" "$R/Sprint 10/1000005 1000001 [API] Shared work" "$(match)"
run "$R/Sprint 10/1000005, 1000001: Shared work$nl" --id 1000001
check "second of comma-separated ids" "$R/Sprint 10/1000005, 1000001: Shared work" "$(match)"
run "$R/Sprint 10/1000005 1000001 [API] Shared work$nl" --id 1000005
check "first of two ids" "$R/Sprint 10/1000005 1000001 [API] Shared work" "$(match)"

# --- false positives ---
run "$R/Sprint 10/1000001 Capture user response$nl" --id 1000
check "prefix of a longer id does not match" "1" "$RC"
run "$R/Sprint 10/10000012 Other story$nl" --id 1000001
check "longer id starting with the id does not match" "1" "$RC"
run "$R/Sprint 10/91000001 Other story$nl" --id 1000001
check "longer id ending with the id does not match" "1" "$RC"
run "$R/Sprint 10/Release notes 1000001$nl" --id 1000001
check "id only later in the title does not match" "1" "$RC"
run "$R/Sprint 10/1000001x Other$nl" --id 1000001
check "id glued to letters does not match" "1" "$RC"
run "" --id 1000001
check "empty list: no match" "1" "$RC"
check "no match prints nothing" "" "$OUT"

# --- several matches ---
run "$R/Sprint 10/1000001 A much longer hand-written title$nl$R/Sprint 10/1000001-Short$nl" --id 1000001
check "shortest path wins" "$R/Sprint 10/1000001-Short" "$(match)"
check "the other match is listed" "$R/Sprint 10/1000001 A much longer hand-written title" "$(others)"
run "$R/Sprint 10/1000001 X$nl$R/Sprint 10/1000001-Add-Widget-Option$nl" --id 1000001 --prefer "1000001-Add-Widget-Option"
check "exact <id>-<slug> beats shorter" "$R/Sprint 10/1000001-Add-Widget-Option" "$(match)"

# --- sprint folders and carried-over stories ---
TREE="$R/Sprint 9$nl$R/Sprint 9/1000001 Capture user response$nl$R/Sprint 9/1000001 Capture user response/Development Plan$nl$R/Sprint 10$nl$R/Sprint 10/1000002 Other story$nl"
run "$TREE" --id 1000001 --root "$R" --sprint "Sprint 10"
check "carried-over story found in another sprint" "$R/Sprint 9/1000001 Capture user response" "$(match)"
check "scope says other-sprint" "other-sprint" "$(scope)"
run "$TREE$R/Sprint 10/1000001: Capture user response$nl" --id 1000001 --root "$R" --sprint "Sprint 10"
check "current sprint beats another sprint" "$R/Sprint 10/1000001: Capture user response" "$(match)"
check "scope says current" "current" "$(scope)"
check "other-sprint match listed" "$R/Sprint 9/1000001 Capture user response" "$(others)"
run "$R/1000001 Directly under root$nl$R/Sprint 9/1000001 Story/1000001 sub page$nl" --id 1000001 --root "$R" --sprint "Sprint 10"
check "with --root only <sprint>/<story> depth counts" "1" "$RC"
run "$R/Sprint 9/1000001 Story$nl" --id 1000001
check "without --root, scope is any" "any" "$(scope)"

# --- input hygiene and errors ---
run "  $R/Sprint 10/1000001 Padded  "$'\r\n' --id 1000001
check "trims spaces and CR" "$R/Sprint 10/1000001 Padded" "$(match)"
run "$R/Sprint 10/1000001 X$nl" --id abc
check "non-numeric id is an error" "2" "$RC"
run "$R/Sprint 10/1000001 X$nl" --id 1000001 --bogus x
check "unknown argument is an error" "2" "$RC"

echo "---"
echo "Total: $((PASS+FAIL)), Pass: $PASS, Fail: $FAIL"
[ "$FAIL" -eq 0 ]

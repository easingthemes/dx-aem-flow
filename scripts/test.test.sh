#!/usr/bin/env bash
# test.test.sh — Prove scripts/test.sh selects the right suites for a set of changed paths.
#
# CLAUDE.md: "a validator nobody has watched fail is indistinguishable from a blind one."
# Every selection rule has at least one case below that fails if the rule is deleted.
# Hermetic: builds a throwaway fixture tree (DX_TEST_ROOT), never touches git, the network
# or ambient config. `--list -` only prints a selection; `--all` runs the suites of a second
# throwaway fixture (FX2) and never the real repo's.

set -uo pipefail

RUNNER="${DX_TEST_RUNNER:-$(cd "$(dirname "$0")" && pwd)/test.sh}"
PASS=0
FAIL=0

FX="$(mktemp -d "${TMPDIR:-/tmp}/dx-test-select.XXXXXX")"
trap 'rm -rf "$FX"' EXIT

mk() { mkdir -p "$FX/$(dirname "$1")"; : > "$FX/$1"; }

mk plugins/dx-x/skills/alpha/tests/run-tests.sh
mk plugins/dx-x/skills/alpha/SKILL.md
mk plugins/dx-x/skills/beta/scripts/__tests__/b.test.sh
mk plugins/dx-x/skills/beta/SKILL.md
echo "calls helper.sh" > "$FX/plugins/dx-x/skills/beta/SKILL.md"
mk plugins/dx-x/data/lib/helper.sh
mk plugins/dx-x/data/lib/tests/helper.test.sh
mk cli/test/scaffold.test.js
mk scripts/check-foo.sh
mk scripts/check-foo.test.sh
mk scripts/validate-skills.sh
mk scripts/validate-skills.test.sh
mk scripts/validate-agents.sh
mk scripts/validate-structure.sh
mk scripts/validate-stats.sh

# check <label> <expected> <actual>
check() {
  if [ "$2" = "$3" ]; then
    echo "PASS: $1"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $1"
    echo "      expected: $2"
    echo "      actual:   $3"
    FAIL=$((FAIL + 1))
  fi
}

# list <paths...> — raw --list output
list() { printf '%s\n' "$@" | DX_TEST_ROOT="$FX" bash "$RUNNER" --list - 2>&1; }
# sel <paths...> — selected suites, sorted, space-joined
sel() { list "$@" | cut -f1 | LC_ALL=C sort | tr '\n' ' '; }
# exp <suites...> — expected value in the same shape
exp() { printf '%s\n' "$@" | LC_ALL=C sort | tr '\n' ' '; }

SKILLS=plugins/dx-x/skills
ALPHA=$SKILLS/alpha/tests/run-tests.sh
BETA=$SKILLS/beta/scripts/__tests__/b.test.sh
HELPER=plugins/dx-x/data/lib/tests/helper.test.sh
CLI=cli/test/scaffold.test.js
ALL="$ALPHA $BETA $HELPER $CLI scripts/check-foo.test.sh scripts/validate-agents.sh scripts/validate-skills.sh scripts/validate-skills.test.sh scripts/validate-stats.sh scripts/validate-structure.sh"

# Guards rules 1 (home) and 5 (validators: skills + structural)
check "skill change selects its own suite + validators" \
  "$(exp "$ALPHA" scripts/validate-skills.sh scripts/validate-stats.sh scripts/validate-structure.sh)" \
  "$(sel $SKILLS/alpha/SKILL.md)"

# Guards rules 3 (uses <basename>), 4 (scaffold input) and 1 (lib home)
LIB_EXPECT="$(exp "$BETA" "$CLI" "$HELPER" scripts/validate-stats.sh scripts/validate-structure.sh)"
check "lib change selects lib suite, consumers, cli" "$LIB_EXPECT" "$(sel plugins/dx-x/data/lib/helper.sh)"

# Guards rule 1 prefix match and rule 3 when the file is gone from the tree
rm "$FX/plugins/dx-x/data/lib/helper.sh"
check "deleted lib file still selects its consumers" "$LIB_EXPECT" "$(sel plugins/dx-x/data/lib/helper.sh)"
mk plugins/dx-x/data/lib/helper.sh

# Guards rule 2 (pair) — selection (rule 1 would also pick it, so the reason check below is the guard)
check "script change selects its pair only" \
  "$(exp scripts/check-foo.test.sh)" "$(sel scripts/check-foo.sh)"
# Rule 2 runs before rule 1 for scripts/: reason is pair, not home (fails if rule 2 is removed)
check "script change reason is pair" "pair" "$(list scripts/check-foo.sh | cut -f2)"

# suite_home must not make validate-skills.test.sh its own home (exercised via rule 2:
# editing validate-skills.sh must select the .test.sh, which needs it paired, not self-homed)
check "validator test is homed on its validator" "pair" \
  "$(list scripts/validate-skills.sh | awk -F'\t' '$1=="scripts/validate-skills.test.sh"{print $2}')"

# Guards the suite_home case order: with the .test.sh case first, validate-skills.test.sh is homed
# on validate-skills.sh, so a lib name mentioned only there selects the test via rule 3.
mk plugins/dx-x/data/lib/only-in-validator.sh
echo "uses only-in-validator.sh" > "$FX/scripts/validate-skills.sh"
check "validator test is homed on its validator (rule 3 greps the validator)" "uses only-in-validator.sh" \
  "$(list plugins/dx-x/data/lib/only-in-validator.sh | awk -F'\t' '$1=="scripts/validate-skills.test.sh"{print $2}')"
: > "$FX/scripts/validate-skills.sh"; rm -f "$FX/plugins/dx-x/data/lib/only-in-validator.sh"

# Guards rule 2 for validators (pair + the validator itself)
check "validator change selects validator and its test" \
  "$(exp scripts/validate-skills.sh scripts/validate-skills.test.sh)" "$(sel scripts/validate-skills.sh)"

# Guards rule 6 (inert)
check "docs-only change selects nothing" "No suites affected." \
  "$(list docs/x.md website/README.md README.md)"

# Spec ruling: validate-structure.sh scans website/src/ for hardcoded secrets
check "website/src change selects the structure validator only" \
  "$(exp scripts/validate-structure.sh)" "$(sel website/src/pages/a.md)"
check "website/src reason is structural" "structural" \
  "$(list website/src/pages/a.md | cut -f2)"

# Guards rule 6's carve-out (stats.ts) + rule 5 (structural)
check "stats.ts is not inert" \
  "$(exp scripts/validate-stats.sh scripts/validate-structure.sh)" "$(sel website/src/config/stats.ts)"

# Guards rule 7 (fallback)
check "unmapped path forces everything" "$(exp $ALL)" "$(sel .github/workflows/validate.yml)"
check "fallback names the unmapped path" "fallback: .github/workflows/validate.yml" \
  "$(list .github/workflows/validate.yml | cut -f2 | sort -u)"

# Guards rule 1 (suite file equals path)
check "suite file change selects that suite" "$(exp "$BETA" scripts/validate-skills.sh scripts/validate-stats.sh scripts/validate-structure.sh)" "$(sel $BETA)"

# Guards rule 3 for scripts/ suites: the suite file itself is grepped, not only its home
echo "uses check-foo.sh" > "$FX/scripts/check-foo.test.sh"
mk plugins/dx-x/data/lib/check-foo.sh
check "lib file named in a scripts/ suite selects that suite" "yes" \
  "$(sel plugins/dx-x/data/lib/check-foo.sh | grep -q 'scripts/check-foo.test.sh' && echo yes || echo no)"
rm -f "$FX/plugins/dx-x/data/lib/check-foo.sh"; : > "$FX/scripts/check-foo.test.sh"

# Guards rule 1 (exact-file home) — a scripts/ test selects itself
check "editing a scripts/ test selects it" \
  "$(exp scripts/check-foo.test.sh)" "$(sel scripts/check-foo.test.sh)"

# Guards rule 5 (agents validator)
check "agent change selects agents validator" \
  "$(exp scripts/validate-agents.sh scripts/validate-stats.sh scripts/validate-structure.sh)" \
  "$(sel plugins/dx-x/agents/a.md)"

# Output shape: tab-separated, one line per suite, first reason wins
check "reason is home for own-suite hit" "home" \
  "$(list $SKILLS/alpha/SKILL.md | awk -F'\t' -v s="$ALPHA" '$1==s{print $2}')"
check "lib consumer reason names the file" "uses helper.sh" \
  "$(list plugins/dx-x/data/lib/helper.sh | awk -F'\t' -v s="$BETA" '$1==s{print $2}')"

# CLI behaviour
# Task 4 turns bare --list into git-diff mode: replace this case then.
DX_TEST_ROOT="$FX" bash "$RUNNER" --list >/dev/null 2>&1
check "--list without '-' exits 2 (pre-git-diff mode)" "2" "$?"
DX_TEST_ROOT="$FX" bash "$RUNNER" --bogus >/dev/null 2>&1
check "unknown flag exits 2" "2" "$?"
DX_TEST_ROOT="$FX" bash "$RUNNER" -h 2>&1 | grep -q 'Usage' ; check "-h prints usage" "0" "$?"

# ---- Execution (--all): a second fixture whose suites have real bodies ----
FX2="$(mktemp -d "${TMPDIR:-/tmp}/dx-test-run.XXXXXX")"
trap 'rm -rf "$FX" "$FX2"' EXIT
mk2() { mkdir -p "$FX2/$(dirname "$1")"; printf '%s\n' "$2" > "$FX2/$1"; }
mk2 plugins/dx-x/skills/ok/tests/run-tests.sh 'echo fine; exit 0'
mk2 plugins/dx-x/skills/bad/tests/run-tests.sh 'echo boom-marker; exit 1'
mk2 plugins/dx-x/skills/js/x.test.js "require('node:test')('ok', () => {});"
mk2 plugins/dx-x/skills/jsbad/y.test.js "require('node:test')('nope', () => { throw new Error('js-boom'); });"

# runall <extra args...> — sets OUT and RC
runall() { OUT=$(DX_TEST_ROOT="$FX2" bash "$RUNNER" --all "$@" 2>&1); RC=$?; }

runall -j 2
[ "$RC" -ne 0 ]; check "--all exits non-zero when one suite fails" "0" "$?"
case "$OUT" in *boom-marker*) r=yes ;; *) r=no ;; esac
check "failed suite log is printed" "yes" "$r"
case "$OUT" in *fine*) r=leaked ;; *) r=hidden ;; esac
check "passing suite log is not printed" "hidden" "$r"
case "$OUT" in *"2 passed, 2 failed"*) r=yes ;; *) r=no ;; esac
check "summary counts" "yes" "$r"

rm -rf "$FX2/plugins/dx-x/skills/bad"
runall -j 2
case "$OUT" in *FAIL*y.test.js*) r=yes ;; *) r=no ;; esac
[ "$RC" -ne 0 ]; check "failing node suite fails the run" "0 yes" "$? $r"

rm -rf "$FX2/plugins/dx-x/skills/jsbad"
runall -j 2
check "all-green exits 0" "0" "$RC"
runall -j 1
case "$OUT" in *"2 passed, 0 failed"*) r=yes ;; *) r=no ;; esac
check "-j 1 gives the same result" "0 yes" "$RC $r"

# A path with a quote must still run (xargs quote parsing must not drop it) and its failure count
mk2 "plugins/dx-x/skills/it's/tests/run-tests.sh" 'echo quote-boom; exit 1'
runall -j 2
case "$OUT" in *quote-boom*) r=ran ;; *) r=skipped ;; esac
[ "$RC" -ne 0 ]; check "suite under a dir with a quote runs and fails the run" "0 ran" "$? $r"
rm -rf "$FX2/plugins/dx-x/skills/it's"

# A suite that never reports must fail the run, by name. A suite that kills its own runner
# process (the --run-one child) before it can record a result stands in for a killed child.
mk2 plugins/dx-x/skills/killed/tests/run-tests.sh 'kill -9 $PPID; sleep 1; exit 0'
runall -j 2
case "$OUT" in *"NOT RUN"*killed/tests/run-tests.sh*) r=named ;; *) r=unnamed ;; esac
[ "$RC" -ne 0 ]; check "unaccounted suite fails the run and is named" "0 named" "$? $r"
rm -rf "$FX2/plugins/dx-x/skills/killed"

DX_TEST_ROOT="$FX2" bash "$RUNNER" --all -j 0 >/dev/null 2>&1
check "-j 0 exits 2" "2" "$?"

echo ""
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]

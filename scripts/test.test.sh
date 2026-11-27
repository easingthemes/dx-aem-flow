#!/usr/bin/env bash
# test.test.sh — Prove scripts/test.sh selects the right suites for a set of changed paths.
#
# CLAUDE.md: "a validator nobody has watched fail is indistinguishable from a blind one."
# Every selection rule has at least one case below that fails if the rule is deleted.
# Hermetic: builds a throwaway fixture tree (DX_TEST_ROOT), never touches git, the network
# or ambient config. `--list -` only prints a selection; no suite is executed.

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

# Guards rule 2 (pair)
check "script change selects its pair only" \
  "$(exp scripts/check-foo.test.sh)" "$(sel scripts/check-foo.sh)"

# Guards rule 2 for validators (pair + the validator itself)
check "validator change selects validator and its test" \
  "$(exp scripts/validate-skills.sh scripts/validate-skills.test.sh)" "$(sel scripts/validate-skills.sh)"

# Guards rule 6 (inert)
check "docs-only change selects nothing" "No suites affected." \
  "$(list docs/x.md website/src/pages/a.md README.md)"

# Guards rule 6's carve-out (stats.ts) + rule 5 (structural)
check "stats.ts is not inert" \
  "$(exp scripts/validate-stats.sh scripts/validate-structure.sh)" "$(sel website/src/config/stats.ts)"

# Guards rule 7 (fallback)
check "unmapped path forces everything" "$(exp $ALL)" "$(sel .github/workflows/validate.yml)"
check "fallback names the unmapped path" "fallback: .github/workflows/validate.yml" \
  "$(list .github/workflows/validate.yml | cut -f2 | sort -u)"

# Guards rule 1 (suite file equals path)
case "$(sel $BETA)" in
  *b.test.sh*) check "suite file change selects that suite" ok ok ;;
  *)           check "suite file change selects that suite" ok "got: $(sel $BETA)" ;;
esac

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
DX_TEST_ROOT="$FX" bash "$RUNNER" --bogus >/dev/null 2>&1
check "unknown flag exits 2" "2" "$?"
DX_TEST_ROOT="$FX" bash "$RUNNER" -h 2>&1 | grep -q 'Usage' ; check "-h prints usage" "0" "$?"

echo ""
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]

#!/usr/bin/env bash
# validate-skills.test.sh — prove the skill limit checks actually fire.
#
# A structural validator nobody has watched fail is indistinguishable from one
# that is blind (see CLAUDE.md, "A structural check cannot tell you a script
# works"). Both limits added for TODO #203 land green on today's tree, so the
# only evidence they work is a deliberately over-long fixture.
#
# Hermetic: builds a throwaway plugin tree under a temp dir and points the
# validator at it via REPO_ROOT. No network, no git config, no real plugins.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VALIDATOR="$SCRIPT_DIR/validate-skills.sh"
PASS=0
FAIL=0

FIXTURE_ROOT=$(mktemp -d)
trap 'rm -rf "$FIXTURE_ROOT"' EXIT

# Build one skill under the fixture tree.
#   make_skill <name> <description> <body-line-count>
make_skill() {
  local name="$1" desc="$2" body_lines="$3"
  local dir="$FIXTURE_ROOT/plugins/dx-test/skills/$name"
  mkdir -p "$dir"
  {
    echo "---"
    echo "name: $name"
    echo "description: $desc"
    echo "---"
    echo
    for ((i = 0; i < body_lines; i++)); do echo "line $i"; done
  } > "$dir/SKILL.md"
}

reset_fixture() {
  rm -rf "${FIXTURE_ROOT:?}/plugins"
}

# run_validator <env assignments...> — echoes output, returns validator exit code
run_validator() {
  REPO_ROOT="$FIXTURE_ROOT" "$@" bash "$VALIDATOR" 2>&1
}

check() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $label — expected '$expected', got '$actual'"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== validate-skills.sh limit checks ==="
echo

# --- 1. a normal skill passes -------------------------------------------------
reset_fixture
make_skill "dx-small" "A short description." 10
out=$(run_validator); rc=$?
check "clean fixture exits 0" "0" "$rc"
check "clean fixture warns 0 times" "0" "$(echo "$out" | grep -c '^WARN:')"

# --- 2. description over 1024 chars is an ERROR -------------------------------
reset_fixture
long_desc=$(printf 'x%.0s' $(seq 1 1025))
make_skill "dx-long-desc" "$long_desc" 10
out=$(run_validator); rc=$?
check "over-long description exits non-zero" "1" "$rc"
check "over-long description reports the cap" "1" \
  "$(echo "$out" | grep -c 'description too long (1025 chars, max 1024)')"

# A description exactly at the cap is legal — the check is > not >=.
reset_fixture
at_cap=$(printf 'x%.0s' $(seq 1 1024))
make_skill "dx-cap-desc" "$at_cap" 10
out=$(run_validator); rc=$?
check "description exactly at the cap passes" "0" "$rc"

# --- 3. body over 500 lines WARNs, and counts frontmatter out -----------------
reset_fixture
make_skill "dx-fat" "Fine description." 501
out=$(run_validator); rc=$?
check "over-long body warns" "1" "$(echo "$out" | grep -c 'body is 502 lines')"
check "over-long body alone does not fail (under baseline)" "0" "$rc"

# 500 body lines + 5 frontmatter lines must NOT warn: if the check counted file
# lines instead of body lines this fixture would trip it.
reset_fixture
make_skill "dx-borderline" "Fine description." 499
out=$(run_validator); rc=$?
check "frontmatter is excluded from the body count" "0" "$(echo "$out" | grep -c '^WARN:')"

# --- 4. the ratchet errors when the count grows -------------------------------
reset_fixture
make_skill "dx-fat-a" "Fine description." 600
make_skill "dx-fat-b" "Fine description." 600
out=$(BODY_OVER_BASELINE=1 run_validator); rc=$?
check "ratchet fails when oversized count exceeds baseline" "1" "$rc"
check "ratchet names the baseline" "1" \
  "$(echo "$out" | grep -c 'baseline is 1')"

out=$(BODY_OVER_BASELINE=2 run_validator); rc=$?
check "ratchet passes at the baseline" "0" "$rc"

out=$(BODY_OVER_BASELINE=5 run_validator); rc=$?
check "ratchet notes an improvement below the baseline" "1" \
  "$(echo "$out" | grep -c 'lower BODY_OVER_BASELINE')"

# --- 5. the real tree is still green ------------------------------------------
if bash "$VALIDATOR" > /dev/null 2>&1; then
  echo "PASS: real plugin tree still validates"
  PASS=$((PASS + 1))
else
  echo "FAIL: real plugin tree no longer validates"
  FAIL=$((FAIL + 1))
fi

echo
echo "=== Summary: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]

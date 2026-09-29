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

# Build one skill from raw SKILL.md content on stdin, for shapes make_skill
# cannot express (wrapped descriptions, missing frontmatter keys).
#   write_skill <name> <<'EOF' ... EOF
write_skill() {
  local dir="$FIXTURE_ROOT/plugins/dx-test/skills/$1"
  mkdir -p "$dir"
  cat > "$dir/SKILL.md"
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

# --- 5. a wrapped description is measured in full -----------------------------
# `grep | head -1` saw only the first line, so a folded scalar of any length
# measured as ~0 chars and sailed past the cap.
reset_fixture
{
  echo "---"
  echo "name: dx-folded"
  echo "description: >-"
  for ((i = 0; i < 20; i++)); do printf '  %s\n' "$(printf 'y%.0s' $(seq 1 60))"; done
  echo "---"
  echo
  echo "body"
} | write_skill "dx-folded"
out=$(run_validator); rc=$?
check "folded description over the cap errors" "1" "$rc"
check "folded description is measured joined, not first-line" "1" \
  "$(echo "$out" | grep -c 'description too long (1219 chars, max 1024)')"

# --- 6. a missing frontmatter key reports, it does not abort ------------------
# Under `set -euo pipefail` a grep that matches nothing returns 1 and killed the
# whole run: no message, no further skills scanned, just a bare exit 1.
reset_fixture
write_skill "dx-nodesc" <<'SKILL'
---
name: dx-nodesc
---

body
SKILL
make_skill "dx-fine" "A short description." 10
out=$(run_validator); rc=$?
check "missing description exits non-zero" "1" "$rc"
check "missing description says so" "1" \
  "$(echo "$out" | grep -c 'missing or empty description: field')"
check "a broken skill does not stop the scan" "1" \
  "$(echo "$out" | grep -c 'Skills scanned: 2')"

reset_fixture
write_skill "dx-noname" <<'SKILL'
---
description: A short description.
---

body
SKILL
out=$(run_validator); rc=$?
check "missing name exits non-zero" "1" "$rc"
check "missing name says so" "1" \
  "$(echo "$out" | grep -c "name: '' does not match directory 'dx-noname'")"

# --- 7. reasoning-echo instructions are an ERROR (TODO #239) ------------------
reset_fixture
write_skill "dx-echo" <<'SKILL'
---
name: dx-echo
description: A short description.
---

Before answering, think step by step and show your reasoning to the user.
SKILL
out=$(run_validator); rc=$?
check "reasoning-echo in a skill body exits non-zero" "1" "$rc"
check "reasoning-echo names file and line" "1" \
  "$(echo "$out" | grep -c 'plugins/dx-test/skills/dx-echo/SKILL.md:6 — reasoning-echo')"

# references/ are loaded too, so they are checked too
reset_fixture
make_skill "dx-refs" "A short description." 3
mkdir -p "$FIXTURE_ROOT/plugins/dx-test/skills/dx-refs/references"
echo "Explain your reasoning in the final report." \
  > "$FIXTURE_ROOT/plugins/dx-test/skills/dx-refs/references/notes.md"
out=$(run_validator); rc=$?
check "reasoning-echo in references/ exits non-zero" "1" "$rc"
check "reasoning-echo in references/ is located" "1" \
  "$(echo "$out" | grep -c 'dx-refs/references/notes.md:1 — reasoning-echo')"

# agents are prompts too
reset_fixture
make_skill "dx-ok" "A short description." 3
mkdir -p "$FIXTURE_ROOT/plugins/dx-test/agents"
printf -- '---\nname: dx-a\n---\nUse chain-of-thought and print your reasoning.\n' \
  > "$FIXTURE_ROOT/plugins/dx-test/agents/dx-a.md"
out=$(run_validator); rc=$?
check "reasoning-echo in an agent exits non-zero" "1" "$rc"
check "one error per offending line" "1" \
  "$(echo "$out" | grep -c 'agents/dx-a.md:4 — reasoning-echo')"

# plain mention of reasoning is fine — the check targets instructions to print it
reset_fixture
write_skill "dx-plain" <<'SKILL'
---
name: dx-plain
description: A short description.
---

Record the reasoning behind each decision in decisions.yaml.
SKILL
out=$(run_validator); rc=$?
check "ordinary use of the word 'reasoning' passes" "0" "$rc"

# --- 8. inline-chain budget (TODO #241) --------------------------------------
# chain_skill <name> <fork:0|1> <invocation line> — ~400 chars of padding each
chain_skill() {
  local fork_line=""
  [ "$2" = "1" ] && fork_line="context: fork"
  {
    echo "---"; echo "name: $1"; echo "description: A short description."
    [ -n "$fork_line" ] && echo "$fork_line"
    echo "---"; echo
    echo "$3"
    for ((i = 0; i < 20; i++)); do echo "padding line $i for size"; done
  } | write_skill "$1"
}
chain_warns() { echo "$1" | grep -c "^WARN: $2 — .*unforked"; }

# A -> B inline: both bodies land in A's context
reset_fixture
chain_skill dx-coord 0 'Invoke `/dx-worker` with the id.'
chain_skill dx-worker 0 'Do the work.'
out=$(CHAIN_MAX_TOK=150 CHAIN_OVER_BASELINE=1 run_validator); rc=$?
check "inline chain over budget warns" "1" "$(chain_warns "$out" dx-coord)"
check "a single warning at the baseline does not fail" "0" "$rc"
out=$(CHAIN_MAX_TOK=150 CHAIN_OVER_BASELINE=0 run_validator); rc=$?
check "inline-chain ratchet fails above the baseline" "1" "$rc"
check "inline-chain ratchet says to fork" "1" "$(echo "$out" | grep -c 'fork the worker')"

# the same chain with a forked worker costs the coordinator nothing
reset_fixture
chain_skill dx-coord 0 'Skill(/dx-worker) then report.'
chain_skill dx-worker 1 'Do the work.'
out=$(CHAIN_MAX_TOK=150 CHAIN_OVER_BASELINE=0 run_validator); rc=$?
check "forked worker is not counted" "0" "$(chain_warns "$out" dx-coord)"
check "forked worker passes the ratchet" "0" "$rc"

# transitive: A -> B -> C, all inline; C's body counts toward A
reset_fixture
chain_skill dx-a 0 'Invoke the `/dx-b` skill.'
chain_skill dx-b 0 'Invoke /dx-c next.'
chain_skill dx-c 0 'Leaf.'
out=$(CHAIN_MAX_TOK=400 CHAIN_OVER_BASELINE=9 run_validator)
check "transitive chain is summed (A over, B under)" "1:0" \
  "$(chain_warns "$out" dx-a):$(chain_warns "$out" dx-b)"

# a cycle must terminate and count each skill once
reset_fixture
chain_skill dx-p 0 'Invoke /dx-q first.'
chain_skill dx-q 0 'Invoke /dx-p back.'
out=$(CHAIN_MAX_TOK=100000 timeout 20 bash -c "REPO_ROOT='$FIXTURE_ROOT' bash '$VALIDATOR'" 2>&1); rc=$?
check "a cycle terminates" "0" "$rc"

# a hint to the human is not an invocation
reset_fixture
chain_skill dx-coord 0 'If it fails, run /dx-worker manually to debug.'
chain_skill dx-worker 0 'Do the work.'
out=$(CHAIN_MAX_TOK=150 CHAIN_OVER_BASELINE=0 run_validator); rc=$?
check "human 'run /x' hint is not counted" "0" "$rc"

# --- 9. the real tree is still green ------------------------------------------
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

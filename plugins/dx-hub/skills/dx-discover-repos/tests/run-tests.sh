#!/usr/bin/env bash
# Smoke tests for the dx-discover-repos skill helpers. Run from repo root.
# Each test prints PASS/FAIL and the script exits non-zero on any failure.
#
# Covers the deterministic tiers of the discovery cascade:
#   tier-0  parse-explicit-repos.sh   ("repos: a, b" after the @kai-<agent> tag)
#   tier-1  route-targets.sh          (```simple``` block -> platform/brand/scope routing)
#   tier-2  parse-crossrepo-table.sh  (## Cross-Repo Scope markdown table)
# tier-3 (LLM) is covered by the dx-automation eval fixtures, not here.
#
# NOTE: -e is intentionally omitted — the run()/expect_exit() helpers capture
# exit codes; with -e a failing test would abort the runner instead of being
# counted as a FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURES="$SCRIPT_DIR/fixtures"
SCRIPTS="$SCRIPT_DIR/../scripts"
TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

PASS=0
FAIL=0

run() {
  local name="$1"; shift
  if "$@" >"$TMP/out" 2>"$TMP/err"; then
    echo "PASS: $name"
    PASS=$((PASS+1))
  else
    echo "FAIL: $name"
    echo "  stdout: $(cat $TMP/out)"
    echo "  stderr: $(cat $TMP/err)"
    FAIL=$((FAIL+1))
  fi
}

expect_exit() {
  local name="$1" expected="$2"; shift 2
  "$@" >"$TMP/out" 2>"$TMP/err"
  local actual=$?
  if [[ "$actual" == "$expected" ]]; then
    echo "PASS: $name (exit=$actual)"
    PASS=$((PASS+1))
  else
    echo "FAIL: $name (expected exit=$expected, got=$actual)"
    echo "  stderr: $(cat $TMP/err)"
    FAIL=$((FAIL+1))
  fi
}

# ===== tier-0: parse-explicit-repos =====
EXPLICIT="$SCRIPTS/parse-explicit-repos.sh"
REG="$FIXTURES/repos-registry.json"

run "tier0: explicit 'repos: a, b' -> 2 known entries" \
  bash -c "$EXPLICIT $FIXTURES/comment-explicit.txt $REG | jq -e 'map(.alias) == [\"brand-one\",\"platform-core\"]'"

run "tier0: explicit branch comes from registry defaultBranch" \
  bash -c "$EXPLICIT $FIXTURES/comment-explicit.txt $REG | jq -e '.[1].branch==\"main\" and .[0].branch==\"development\"'"

run "tier0: no repos directive -> empty array" \
  bash -c "$EXPLICIT $FIXTURES/comment-no-repos.txt $REG | jq -e 'length==0'"

# ===== tier-2: parse-crossrepo-table =====
TABLE="$SCRIPTS/parse-crossrepo-table.sh"

run "tier2: cross-repo table -> only known aliases (unknown skipped)" \
  bash -c "$TABLE $FIXTURES/research-crossrepo.md $REG | jq -e 'map(.alias)==[\"platform-core\"]'"

run "tier2: missing markdown file -> empty array" \
  bash -c "$TABLE /nonexistent/research.md $REG | jq -e 'length==0'"

# ===== tier-1: route-targets (moved from dx-simple) =====
ROUTE="$SCRIPTS/route-targets.sh"
CFG_MULTI="$FIXTURES/config-multi-platform.yaml"
CFG_SINGLE="$FIXTURES/config-single-platform.yaml"
# map: every reachable repo -> a fake pipeline id
MAP='{"AlphaFullstack":"101","BetaBackend":"102","BetaBrandX":"103","BetaBrandY":"104"}'

# Multi-platform, platform omitted -> exit 3 (ambiguous, must declare)
printf '%s\n' "page-url: http://x" "scope: fe" > "$TMP/r1.yaml"
expect_exit "route: multi-platform missing platform -> 3" 3 \
  "$ROUTE" "$TMP/r1.yaml" "$CFG_MULTI" "$MAP"

# platform=beta, brand=brandx, scope=both -> dispatch BetaBackend + BetaBrandX
printf '%s\n' "page-url: http://x" "platform: beta" "brand: brandx" "scope: both" > "$TMP/r2.yaml"
run "route: beta/both dispatches BE + brandX FE" \
  bash -c "$ROUTE $TMP/r2.yaml $CFG_MULTI '$MAP' | jq -e 'map(.repo) | (index(\"BetaBackend\") != null) and (index(\"BetaBrandX\") != null) and (index(\"BetaBrandY\") == null)'"

# scope=be -> only BetaBackend
printf '%s\n' "page-url: http://x" "platform: beta" "scope: be" > "$TMP/r3.yaml"
run "route: beta/be dispatches only BE" \
  bash -c "$ROUTE $TMP/r3.yaml $CFG_MULTI '$MAP' | jq -e 'length==1 and .[0].repo==\"BetaBackend\"'"

# single-platform config has NO repos[] block -> a solo repo fans out to nothing.
printf '%s\n' "page-url: http://x" "scope: fe" > "$TMP/r4.yaml"
SMAP='{"AlphaFullstack":"101"}'
run "route: single-platform (no repos[]) fans out to empty" \
  bash -c "$ROUTE $TMP/r4.yaml $CFG_SINGLE '$SMAP' | jq -e 'length==0'"

# platform inference: MAP reachable repos span only ONE platform -> platform field optional
printf '%s\n' "page-url: http://x" "scope: be" > "$TMP/r8.yaml"
run "route: infers platform when only one reachable" \
  bash -c "$ROUTE $TMP/r8.yaml $CFG_MULTI '{\"BetaBackend\":\"102\"}' | jq -e 'length==1 and .[0].repo==\"BetaBackend\"'"

# fullstack single-platform repo: platform=alpha scope=both -> dispatches AlphaFullstack
printf '%s\n' "page-url: http://x" "platform: alpha" "scope: both" > "$TMP/r5.yaml"
run "route: alpha/both dispatches the fullstack repo" \
  bash -c "$ROUTE $TMP/r5.yaml $CFG_MULTI '$MAP' | jq -e 'length==1 and .[0].repo==\"AlphaFullstack\" and .[0].authoring==true'"

# fullstack also serves scope=be
printf '%s\n' "page-url: http://x" "platform: alpha" "scope: be" > "$TMP/r6.yaml"
run "route: alpha/be dispatches the fullstack repo" \
  bash -c "$ROUTE $TMP/r6.yaml $CFG_MULTI '$MAP' | jq -e 'length==1 and .[0].repo==\"AlphaFullstack\"'"

# branded ticket targeting a fullstack repo (no brand on repo) must still dispatch it
printf '%s\n' "page-url: http://x" "platform: alpha" "brand: brandx" "scope: both" > "$TMP/r7.yaml"
run "route: branded ticket still dispatches brandless fullstack repo" \
  bash -c "$ROUTE $TMP/r7.yaml $CFG_MULTI '$MAP' | jq -e 'length==1 and .[0].repo==\"AlphaFullstack\"'"

# Summary
echo "---"
echo "Total: $((PASS+FAIL)), Pass: $PASS, Fail: $FAIL"
[[ "$FAIL" == "0" ]] || exit 1

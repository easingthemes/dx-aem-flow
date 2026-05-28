#!/usr/bin/env bash
# Smoke tests for dx-simple helper scripts. Run from repo root.
# Each test prints PASS/FAIL and the script exits non-zero on any failure.
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

# ===== parse-simple-block tests =====
run "parse: valid block exits 0" \
  "$SCRIPTS/parse-simple-block.sh" "$FIXTURES/raw-story-valid.md" "$TMP/parsed.yaml"

run "parse: yaml contains page-url" \
  bash -c "grep -q '^page-url:' $TMP/parsed.yaml"

expect_exit "parse: missing block exits 2" 2 \
  "$SCRIPTS/parse-simple-block.sh" "$FIXTURES/raw-story-missing-block.md" "$TMP/missing.yaml"

expect_exit "parse: missing file exits 2" 2 \
  "$SCRIPTS/parse-simple-block.sh" "/nonexistent/file.md" "$TMP/missing.yaml"

# Build a fixture with no change-value field for the missing-field test.
cat > "$TMP/raw-no-change-value.md" <<'EOF'
---
ticket: 9999996
---

```simple
page-url: https://qa-author.example.com/editor.html/content/site/en/home.html
component-locator: heading-text="Get started today"
change-type: aria-label
brand: site
```
EOF
expect_exit "parse: missing change-value field exits 3" 3 \
  "$SCRIPTS/parse-simple-block.sh" "$TMP/raw-no-change-value.md" "$TMP/no-change-value.yaml"

# Build a fixture with an invalid change-type enum value.
cat > "$TMP/raw-bad-enum.md" <<'EOF'
---
ticket: 9999995
---

```simple
page-url: https://qa-author.example.com/editor.html/content/site/en/home.html
component-locator: heading-text="Get started today"
change-type: not-a-real-type
change-value: "anything"
brand: site
EOF
# Close fence on its own line to avoid heredoc indentation issues.
echo '```' >> "$TMP/raw-bad-enum.md"
expect_exit "parse: invalid change-type exits 3" 3 \
  "$SCRIPTS/parse-simple-block.sh" "$TMP/raw-bad-enum.md" "$TMP/bad-enum.yaml"

# Hex-color fixture: parse must succeed AND output must retain literal `#FF0000`
# (proves inline `#` inside a quoted value is preserved — C1 fix).
run "parse: hex color in change-value preserved" \
  bash -c "$SCRIPTS/parse-simple-block.sh $FIXTURES/raw-story-hex-color.md $TMP/hex.yaml && grep -q '#FF0000' $TMP/hex.yaml"

# CRLF fixture: parser must succeed on Windows-style line endings.
run "parse: CRLF line endings work" \
  "$SCRIPTS/parse-simple-block.sh" "$FIXTURES/raw-story-crlf.md" "$TMP/crlf.yaml"

# ===== scope-check tests =====
run "scope: mixed plan passes (1 code, 1 auth)" \
  "$SCRIPTS/scope-check.sh" "$FIXTURES/work-plan-mixed.json"

# Generate an oversize fixture in-place
python3 -c "
import json
data = {'authoring': [], 'code': [{'file': f'f{i}.html', 'match-context': 'x'} for i in range(6)]}
print(json.dumps(data))
" > "$TMP/over.json"

expect_exit "scope: 6 files exits 4" 4 \
  "$SCRIPTS/scope-check.sh" "$TMP/over.json"

# ===== update-progress tests =====
TMPSPEC="$TMP/9999999-test"
run "progress: first append creates file" \
  "$SCRIPTS/update-progress.sh" "$TMPSPEC" "Phase 1" "pending"

run "progress: file exists with header" \
  bash -c "test -f $TMPSPEC/simple-progress.md && grep -q '#9999999' $TMPSPEC/simple-progress.md"

run "progress: second call updates same row" \
  "$SCRIPTS/update-progress.sh" "$TMPSPEC" "Phase 1" "done" "ok"

run "progress: row reflects 'done' status" \
  bash -c "grep -q '| Phase 1 | done' $TMPSPEC/simple-progress.md"

run "progress: third call appends new row" \
  "$SCRIPTS/update-progress.sh" "$TMPSPEC" "Phase 2" "in_progress"

run "progress: file now has 2 phase rows" \
  bash -c "test \$(grep -cE '^\| Phase [0-9]+ \|' $TMPSPEC/simple-progress.md) -eq 2"


# ===== scope-check + progress edge cases =====

# C3: malformed JSON exits 4 (was 5)
echo 'not json' > "$TMP/bad.json"
expect_exit "scope: invalid JSON exits 4" 4 \
  "$SCRIPTS/scope-check.sh" "$TMP/bad.json"

# C3: empty {} object exits 0 (treats missing keys as empty arrays)
echo '{}' > "$TMP/empty.json"
run "scope: empty object passes (defaults to empty arrays)" \
  "$SCRIPTS/scope-check.sh" "$TMP/empty.json"

# C3: missing .code key still works
echo '{"authoring":[]}' > "$TMP/noCode.json"
run "scope: missing .code key defaults to empty" \
  "$SCRIPTS/scope-check.sh" "$TMP/noCode.json"

# C1: phase name with regex metachars (parens, dot) is treated literally
TMPSPEC2="$TMP/8888888-edge"
run "progress: phase 'Phase(A.1)' creates row" \
  "$SCRIPTS/update-progress.sh" "$TMPSPEC2" "Phase(A.1)" "pending"
run "progress: same phase updates same row (no duplicate)" \
  "$SCRIPTS/update-progress.sh" "$TMPSPEC2" "Phase(A.1)" "done"
run "progress: file has exactly 1 row for 'Phase(A.1)'" \
  bash -c "test \$(grep -cF '| Phase(A.1) |' $TMPSPEC2/simple-progress.md) -eq 1"

# C2: note with pipe and hash is sanitized, doesn't break table
TMPSPEC3="$TMP/7777777-special"
run "progress: note with pipe and hash chars" \
  "$SCRIPTS/update-progress.sh" "$TMPSPEC3" "Phase 1" "done" "color #FF0000 | reverted"
run "progress: file has clean row (no sed error, no extra | columns)" \
  bash -c "grep -q '| Phase 1 | done |' $TMPSPEC3/simple-progress.md"

# ===== rollback-authoring + aem-revert tests (offline — no actual HTTP) =====
expect_exit "rollback: missing file exits 5" 5 \
  "$SCRIPTS/rollback-authoring.sh" "/nonexistent/diff.json"

# aem-revert.js without env vars must exit 2 immediately (fail-fast on missing creds)
expect_exit "aem-revert: missing env exits 2" 2 \
  bash -c "unset AEM_QA_URL AEM_QA_USER AEM_QA_PASSWORD; node \"$(cd $SCRIPTS/.. && pwd)/../../data/lib/aem-revert.js\" $FIXTURES/authoring-diff-sample.json"

# ===== visual-diff tests =====
run "visual-diff: identical files = 100% overall" \
  bash -c "$SCRIPTS/visual-diff.sh $FIXTURES/before-blue.png $FIXTURES/before-blue.png | grep -q '\"overall\": 100'"

run "visual-diff: all-different (blue vs red) = 0% overall" \
  bash -c "$SCRIPTS/visual-diff.sh $FIXTURES/before-blue.png $FIXTURES/before-red.png | grep -q '\"overall\": 0'"

run "visual-diff: bbox region reports region-diff" \
  bash -c "$SCRIPTS/visual-diff.sh $FIXTURES/before-blue.png $FIXTURES/before-red.png 0,0,32,32 | grep -q 'region-diff'"

# ===== visual-diff filter reversal tests (G5/G6 correctness) =====
# Generate identical Sub-filtered PNGs at test time, then diff
run "visual-diff: Sub-filtered PNG vs itself = 100%" \
  bash -c "$SCRIPTS/visual-diff.sh $FIXTURES/sub-filtered.png $FIXTURES/sub-filtered.png | grep -q '\"overall\": 100'"

# Verify the parsed pixel data is correct by ensuring px-total matches expectation (8*8=64)
run "visual-diff: Sub-filtered PNG reports correct px-total" \
  bash -c "$SCRIPTS/visual-diff.sh $FIXTURES/sub-filtered.png $FIXTURES/sub-filtered.png | grep -q '\"px-total\": 64'"

# ===== preflight tests =====
# Create temp project with minimal config
TMPPROJ="$TMP/proj1"
mkdir -p "$TMPPROJ/.ai/lib"
touch "$TMPPROJ/.ai/lib/dx-common.sh"
cat > "$TMPPROJ/.ai/config.yaml" <<EOF
dx-simple:
  allowed-resource-types:
    - mysite/components/hero
build:
  compile: "mvn compile"
EOF

run "preflight: valid config passes" \
  bash -c "cd $TMPPROJ && $SCRIPTS/preflight.sh"

# Missing dx-simple section
TMPPROJ2="$TMP/proj2"
mkdir -p "$TMPPROJ2/.ai/lib"
touch "$TMPPROJ2/.ai/lib/dx-common.sh"
echo "build: {compile: mvn compile}" > "$TMPPROJ2/.ai/config.yaml"

expect_exit "preflight: missing dx-simple block exits 6" 6 \
  bash -c "cd $TMPPROJ2 && $SCRIPTS/preflight.sh"

# Pipeline mode without AEM vars
expect_exit "preflight: pipeline mode without AEM_QA_* exits 7" 7 \
  bash -c "cd $TMPPROJ && unset AEM_QA_URL AEM_QA_USER AEM_QA_PASSWORD; DX_PIPELINE_MODE=true $SCRIPTS/preflight.sh"

# ===== classify-work tests (chained: parse → classify) =====
run "classify: parse first then classify (high confidence)" \
  bash -c "$SCRIPTS/parse-simple-block.sh $FIXTURES/raw-story-valid.md $TMP/parsed1.yaml && $SCRIPTS/classify-work.sh $TMP/parsed1.yaml $FIXTURES/dialog-map.json $FIXTURES/file-list.json $TMP/plan1.json && jq -e '.confidence.\"G3-classification\" == \"high\"' $TMP/plan1.json"

run "classify: authoring item has ariaLabel property" \
  bash -c "jq -e '.authoring[0].property == \"ariaLabel\"' $TMP/plan1.json"

run "classify: code list is empty (authoring wins)" \
  bash -c "jq -e '.code | length == 0' $TMP/plan1.json"

# ===== classify fixes verification =====
# Fix #1: ticket field populated from frontmatter
run "classify: ticket field populated (was empty bug)" \
  bash -c "$SCRIPTS/parse-simple-block.sh $FIXTURES/raw-story-valid.md $TMP/parsed2.yaml && $SCRIPTS/classify-work.sh $TMP/parsed2.yaml $FIXTURES/dialog-map.json $FIXTURES/file-list.json $TMP/plan2.json && jq -e '.ticket == \"9999999\"' $TMP/plan2.json"

# Fix #2: field-type comes from dialog (textfield in this case, but verifies the wire-through)
run "classify: field-type wired through from dialog" \
  bash -c "jq -e '.authoring[0][\"field-type\"] == \"textfield\"' $TMP/plan2.json"

# Fix #3: classify works without bc (proxy: install a poisoned `bc` shim that fails if invoked,
# then run classify-work.sh — success proves the script never calls bc)
mkdir -p "$TMP/nobc"
cat > "$TMP/nobc/bc" <<'EOF'
#!/bin/sh
echo "bc was invoked but should not have been" >&2
exit 1
EOF
chmod +x "$TMP/nobc/bc"
run "classify: still works without bc dependency" \
  bash -c "PATH=$TMP/nobc:\$PATH $SCRIPTS/classify-work.sh $TMP/parsed2.yaml $FIXTURES/dialog-map.json $FIXTURES/file-list.json $TMP/plan3.json"

# ===== block-mvn-deploy hook tests =====
HOOK="$SCRIPT_DIR/../hooks/block-mvn-deploy.sh"

expect_exit "hook: blocks autoInstallPackage in pipeline mode" 2 \
  bash -c "echo '{\"input\":{\"command\":\"mvn clean install -PautoInstallPackage\"}}' | DX_PIPELINE_MODE=true $HOOK"

run "hook: allows mvn compile in pipeline mode" \
  bash -c "echo '{\"input\":{\"command\":\"mvn compile -pl core\"}}' | DX_PIPELINE_MODE=true $HOOK"

run "hook: allows autoInstallPackage when not in pipeline mode" \
  bash -c "echo '{\"input\":{\"command\":\"mvn clean install -PautoInstallPackage\"}}' | $HOOK"

# Regression for PR #147 review (medium): `mvn clean install -DskipTests`
# must NOT be blocked — it builds locally without deploying to AEM.
run "hook: allows 'mvn clean install -DskipTests' in pipeline mode" \
  bash -c "echo '{\"input\":{\"command\":\"mvn clean install -DskipTests\"}}' | DX_PIPELINE_MODE=true $HOOK"

run "hook: allows 'mvn clean install -pl core -am' in pipeline mode" \
  bash -c "echo '{\"input\":{\"command\":\"mvn clean install -pl core -am\"}}' | DX_PIPELINE_MODE=true $HOOK"

expect_exit "hook: blocks sling:install in pipeline mode" 2 \
  bash -c "echo '{\"input\":{\"command\":\"mvn sling:install -Dsling.url=http://localhost:4502\"}}' | DX_PIPELINE_MODE=true $HOOK"

# ===== scope-check line counter regression (PR #147 medium) =====
# A 2-file plan with multi-line replacements (15 + 20 = 35 lines) must be
# counted as 35 lines, not 2. Budget MAX_LINES=50 → still passes.
python3 -c "
import json
data = {
  'authoring': [],
  'code': [
    {'file': 'a.html', 'match-context': 'foo', 'replacement': '\n'.join(['x'] * 15)},
    {'file': 'b.html', 'match-context': 'bar', 'replacement': '\n'.join(['y'] * 20)}
  ]
}
print(json.dumps(data))
" > "$TMP/multiline.json"
run "scope: 2 files × 15+20 lines passes (35 ≤ 50)" \
  "$SCRIPTS/scope-check.sh" "$TMP/multiline.json"
run "scope: reports the actual 35 lines, not '2'" \
  bash -c "$SCRIPTS/scope-check.sh $TMP/multiline.json 2>&1 | grep -q 'lines=35'"

# A 2-file plan with 30 + 30 lines = 60 → must FAIL the 50-line budget
python3 -c "
import json
data = {
  'authoring': [],
  'code': [
    {'file': 'a.html', 'match-context': 'foo', 'replacement': '\n'.join(['x'] * 30)},
    {'file': 'b.html', 'match-context': 'bar', 'replacement': '\n'.join(['y'] * 30)}
  ]
}
print(json.dumps(data))
" > "$TMP/over-lines.json"
expect_exit "scope: 2 files × 30+30 lines exits 4 (60 > 50)" 4 \
  "$SCRIPTS/scope-check.sh" "$TMP/over-lines.json"

# ===== aem-revert URL safety regression (PR #147 high) =====
# A diff with a jcr-path containing "://" must be REJECTED (no HTTP attempt).
# We need fake AEM_QA_* env so the script reaches revertOne(); we expect
# it to print "INVALID jcr-path" and exit 1 (1+ failures).
cat > "$TMP/diff-bad-path.json" <<'EOF'
{
  "writes": [
    {"applied": true, "jcr-path": "https://attacker.example.com/foo", "property": "p", "before": "old"}
  ]
}
EOF
REVERTER="$(cd $SCRIPTS/.. && pwd)/../../data/lib/aem-revert.js"
expect_exit "aem-revert: rejects jcr-path with scheme (URL injection guard)" 1 \
  bash -c "AEM_QA_URL=http://localhost:4502 AEM_QA_USER=u AEM_QA_PASSWORD=p node $REVERTER $TMP/diff-bad-path.json"
run "aem-revert: prints INVALID for url-like jcr-path" \
  bash -c "AEM_QA_URL=http://localhost:4502 AEM_QA_USER=u AEM_QA_PASSWORD=p node $REVERTER $TMP/diff-bad-path.json 2>&1 | grep -q 'INVALID jcr-path'"

# Summary
echo "---"
echo "Total: $((PASS+FAIL)), Pass: $PASS, Fail: $FAIL"
[[ "$FAIL" == "0" ]] || exit 1

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

# Summary
echo "---"
echo "Total: $((PASS+FAIL)), Pass: $PASS, Fail: $FAIL"
[[ "$FAIL" == "0" ]] || exit 1

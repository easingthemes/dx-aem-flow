#!/usr/bin/env bash
# sync-ai-rules.test.sh — /dx-sync must keep the AEM sections of pr-review.md.
#
# aem-init appends "## AEM/Sling Patterns" (+ "## Frontend Patterns") to
# .ai/rules/pr-review.md and pr-answer.md. sync-consumers.sh step 7 used to cp
# the dx template over the whole file and delete them. Runs the script's own
# sync functions (extracted, not the whole script — it syncs real repos).
# Hermetic: temp files only, no git, no network.

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/sync-consumers.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0; FAIL=0
check() { # check <label> <want> <got>
  if [ "$2" = "$3" ]; then echo "PASS $1"; PASS=$((PASS + 1)); else echo "FAIL $1 (want $2, got $3)"; FAIL=$((FAIL + 1)); fi
}

# Pull the needed function definitions out of the script.
for fn in log log_warn log_info log_dry sync_file sync_template sync_rule_keep_aem; do
  awk -v fn="$fn" '
    $0 ~ "^"fn"\\(\\) *\\{.*\\}[[:space:]]*;?[[:space:]]*$" { print; next }   # one-liner
    $0 ~ "^"fn"\\(\\) *\\{" { f = 1 }
    f { print }
    f && /^}/ { f = 0 }' "$SCRIPT"
done > "$TMP/fns.sh"
DRY_RUN=false
# shellcheck disable=SC1091
source "$TMP/fns.sh" 2>/dev/null
type sync_rule_keep_aem >/dev/null 2>&1 || { echo "FAIL sync_rule_keep_aem not found in $SCRIPT"; exit 1; }

printf '# PR review\n\nnew dx rules\n' > "$TMP/template"
AEM_TAIL=$'## AEM/Sling Patterns\n- Verify Sling Model annotations\n\n## Frontend Patterns\n- project-specific line'

# 1. Old dx portion + AEM sections → new dx portion, AEM sections kept.
printf '# PR review\n\nold dx rules\n\n%s\n' "$AEM_TAIL" > "$TMP/pr-review.md"
sync_rule_keep_aem "$TMP/template" "$TMP/pr-review.md" >/dev/null
check "dx portion updated" yes "$(grep -q 'new dx rules' "$TMP/pr-review.md" && ! grep -q 'old dx rules' "$TMP/pr-review.md" && echo yes || echo no)"
check "AEM sections kept" yes "$(grep -q '^## AEM/Sling Patterns' "$TMP/pr-review.md" && grep -q 'project-specific line' "$TMP/pr-review.md" && echo yes || echo no)"

# 2. Idempotent: a second sync changes nothing.
cp "$TMP/pr-review.md" "$TMP/first"
sync_rule_keep_aem "$TMP/template" "$TMP/pr-review.md" >/dev/null
check "second sync is a no-op" same "$(cmp -s "$TMP/first" "$TMP/pr-review.md" && echo same || echo changed)"

# 3. A file without AEM sections becomes exactly the template.
printf '# PR review\n\nold dx rules\n' > "$TMP/plain.md"
sync_rule_keep_aem "$TMP/template" "$TMP/plain.md" >/dev/null
check "no AEM sections → plain template" same "$(cmp -s "$TMP/template" "$TMP/plain.md" && echo same || echo changed)"

# 4. Same layout aem-init produces (template + blank line + sections) is left untouched.
{ cat "$TMP/template"; printf '\n%s\n' "$AEM_TAIL"; } > "$TMP/fresh.md"; cp "$TMP/fresh.md" "$TMP/fresh.orig"
sync_rule_keep_aem "$TMP/template" "$TMP/fresh.md" >/dev/null
check "fresh aem-init layout unchanged" same "$(cmp -s "$TMP/fresh.orig" "$TMP/fresh.md" && echo same || echo changed)"

# 5. Step 7 routes pr-review.md / pr-answer.md through it.
check "step 7 uses sync_rule_keep_aem" yes "$(awk '/^step_7_ai_rules\(\)/,/^}/' "$SCRIPT" | grep -q 'pr-review.md|pr-answer.md) sync_rule_keep_aem' && echo yes || echo no)"

echo "sync-ai-rules: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]

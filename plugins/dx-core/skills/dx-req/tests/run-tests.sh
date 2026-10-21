#!/usr/bin/env bash
# Tests for the config lookups /dx-req runs before fetch-raw-story.js.
# Run from anywhere. Prints PASS/FAIL per test; exits non-zero on any failure.
#
# Regression guard: SKILL.md read `yaml-val project`, and the dx-init config
# has a top-level `project:` section ahead of `scm.project`, so the ADO
# project came back empty and the ADO MCP fell into form elicitation. The
# lines under test are taken from SKILL.md itself, not copied, so a revert
# to a bare key fails here.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL="$SCRIPT_DIR/../SKILL.md"
PLUGIN="$SCRIPT_DIR/../../.."
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0
check() {  # check <name> <expected> <actual>
  if [ "$2" = "$3" ]; then echo "PASS: $1"; PASS=$((PASS+1))
  else echo "FAIL: $1"; echo "  expected [$2], got [$3]"; FAIL=$((FAIL+1)); fi
}

# Consumer layout: .ai/lib/dx-common.sh + a config rendered from the dx-init template.
mkdir -p "$TMP/.ai/lib"
cp "$PLUGIN/data/lib/dx-common.sh" "$TMP/.ai/lib/"
sed -e 's/{{PROJECT_NAME}}/quit-zone/' -e 's/{{SCM_ORG}}/batdigital/' \
    -e 's/{{SCM_PROJECT}}/Consumer Platforms/' -e 's/{{[A-Z_]*}}/x/g' \
    "$PLUGIN/templates/config.yaml.template" > "$TMP/.ai/config.yaml"

LOOKUPS=$(grep -E '^(ORG|PROJ)=\$\(bash \.ai/lib/dx-common\.sh yaml-val ' "$SKILL")
check "SKILL.md has the ORG and PROJ lookups" "2" "$(printf '%s\n' "$LOOKUPS" | grep -c .)"

OUT=$(cd "$TMP" && eval "$LOOKUPS" && printf '%s|%s' "$ORG" "$PROJ")
check "fetch step resolves org"     "batdigital"         "${OUT%%|*}"
check "fetch step resolves project" "Consumer Platforms" "${OUT#*|}"

echo "---"
echo "Total: $((PASS+FAIL)), Pass: $PASS, Fail: $FAIL"
[ "$FAIL" -eq 0 ]

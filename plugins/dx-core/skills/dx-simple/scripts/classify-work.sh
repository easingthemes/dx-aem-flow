#!/usr/bin/env bash
# Deterministic part of Phase 2: takes simple-block.yaml + dialog-map.json
# (produced by the dialog-inspector subagent) and a file-list.json (from
# file-resolver subagent), produces work-plan.json with authoring/code split
# and confidence per item.
#
# Field-match heuristic:
#   change-type            preferred dialog field names (regex on name+label)
#   aria-label             aria.*label, accessibility.*label, screenreader
#   color-token            (color|bg|background).*(picker|field)?, fill
#   spacing                (spacing|margin|padding).*select
#   copy                   (text|heading|title|body|copy)
#   icon                   icon, (logo|image).*ref
#   css-class              n/a (always code)
#
# Usage: classify-work.sh <simple-block.yaml> <dialog-map.json> <file-list.json> <output: work-plan.json>
# Exit codes:
#   0 — classified, work-plan.json written
#   8 — change-type couldn't be classified with high or medium confidence

set -euo pipefail

BLOCK="${1:?simple-block.yaml required}"
DIALOG="${2:?dialog-map.json required}"
FILES="${3:?file-list.json required}"
OUT="${4:?output work-plan.json path required}"

[[ -f "$BLOCK" ]]  || { echo "ERROR: $BLOCK missing" >&2; exit 8; }
[[ -f "$DIALOG" ]] || { echo "ERROR: $DIALOG missing" >&2; exit 8; }
[[ -f "$FILES" ]]  || { echo "ERROR: $FILES missing" >&2; exit 8; }
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq required" >&2; exit 8; }

CHANGE_TYPE=$(grep -E '^change-type:' "$BLOCK" | head -1 | sed -E 's/^change-type:[[:space:]]*//; s/[[:space:]]+$//')
CHANGE_VALUE=$(grep -E '^change-value:' "$BLOCK" | head -1 | sed -E 's/^change-value:[[:space:]]*//; s/[[:space:]]+$//' | sed -E 's/^"//;s/"$//')
JCR_PATH=$(jq -r '.["jcr-path"] // empty' "$DIALOG")
RESOURCE_TYPE=$(jq -r '.["resource-type"] // empty' "$DIALOG")

declare -A PATTERNS=(
  ["aria-label"]='aria.*label|accessibility.*label|screen.?reader'
  ["color-token"]='color|bg|background|fill'
  ["spacing"]='spacing|margin|padding'
  ["copy"]='text|heading|title|body|copy'
  ["icon"]='icon|(logo|image).?(ref|path)'
)

PATTERN="${PATTERNS[$CHANGE_TYPE]:-}"
AUTH_FIELD=""
AUTH_TYPE=""
AUTH_CONF=0
ALTERNATIVES=()
ALT_TYPES=()

if [[ -n "$PATTERN" && "$CHANGE_TYPE" != "css-class" ]]; then
  while IFS=$'\t' read -r FIELD TYPE; do
    if echo "$FIELD" | grep -qiE "$PATTERN"; then
      ALTERNATIVES+=("$FIELD")
      ALT_TYPES+=("$TYPE")
    fi
  done < <(jq -r '.fields | to_entries[] | "\(.key)\t\(.value)"' "$DIALOG")

  case "${#ALTERNATIVES[@]}" in
    0) AUTH_CONF=0; AUTH_TYPE="" ;;
    1) AUTH_FIELD="${ALTERNATIVES[0]}"; AUTH_TYPE="${ALT_TYPES[0]}"; AUTH_CONF=92 ;;
    *) AUTH_FIELD="${ALTERNATIVES[0]}"; AUTH_TYPE="${ALT_TYPES[0]}"; AUTH_CONF=75 ;;  # medium: ambiguous
  esac
fi

# Build authoring item (if confidence >= 75)
AUTHORING="[]"
if [[ "$AUTH_CONF" -ge 75 ]]; then
  BEFORE=$(jq -r --arg p "$AUTH_FIELD" '.values[$p] // ""' "$DIALOG")
  AUTHORING=$(jq -n \
    --arg path "$JCR_PATH" \
    --arg prop "$AUTH_FIELD" \
    --arg before "$BEFORE" \
    --arg after "$CHANGE_VALUE" \
    --arg ftype "${AUTH_TYPE:-textfield}" \
    --argjson conf "$(jq -n --argjson n "$AUTH_CONF" '$n / 100')" \
    '[{
      "jcr-path": $path,
      "property": $prop,
      "before": $before,
      "after": $after,
      "field-type": $ftype,
      "confidence": $conf
    }]')
fi

# Build code item(s) — only when authoring confidence < 75 OR change-type is css-class
CODE="[]"
if [[ "$AUTH_CONF" -lt 75 || "$CHANGE_TYPE" == "css-class" ]]; then
  CODE=$(jq '[.files[] | {
    "file": .path,
    "match-line": 0,
    "match-context": "",
    "replacement": "",
    "rationale": "deferred: LLM identifies match in Phase 3b",
    "confidence": 0
  }]' "$FILES")
fi

# G3 level
LEVEL="low"
[[ "$AUTH_CONF" -ge 90 ]] && LEVEL="high"
[[ "$AUTH_CONF" -ge 75 && "$AUTH_CONF" -lt 90 ]] && LEVEL="medium"

# Emit work-plan.json
jq -n \
  --arg ticket "$(grep -E '^ticket:' "$BLOCK" | head -1 | sed -E 's/^ticket:[[:space:]]*//; s/[[:space:]]+$//')" \
  --arg path "$JCR_PATH" \
  --arg rtype "$RESOURCE_TYPE" \
  --arg page "$(grep -E '^page-url:' "$BLOCK" | head -1 | sed -E 's/^page-url:[[:space:]]*//; s/[[:space:]]+$//')" \
  --argjson auth "$AUTHORING" \
  --argjson code "$CODE" \
  --arg level "$LEVEL" \
  --arg alts "${ALTERNATIVES[*]:-none}" \
  '{
    ticket: $ticket,
    component: { "jcr-path": $path, "resource-type": $rtype, "page-url": $page },
    authoring: $auth,
    code: $code,
    confidence: { "G3-classification": $level, rationale: ("alternatives: " + $alts) }
  }' > "$OUT"

if [[ "$LEVEL" == "low" ]]; then
  echo "LOW-CONFIDENCE: no dialog field matched — falling back to code-only path" >&2
fi

echo "OK: work-plan written to $OUT (G3=$LEVEL, authoring=$(echo "$AUTHORING" | jq 'length'), code=$(echo "$CODE" | jq 'length'))" >&2

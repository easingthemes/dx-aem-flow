#!/usr/bin/env bash
# Deterministic part of Phase 2: takes simple-block.yaml + dialog-map.json
# (produced by the dialog-inspector subagent) and a file-list.json (from the
# file-resolver subagent), produces work-plan.json with an authoring/code
# split and confidence per item.
#
# How the classifier decides authoring-vs-code:
#   1. Read the natural-language `change-value` from the simple block.
#   2. Scan it for keyword clusters that map to dialog-field name patterns.
#   3. If exactly one dialog field matches the strongest cluster, propose
#      an authoring write (high confidence).
#   4. If multiple match, propose the best by name heuristic (medium).
#   5. If none match — or the change-value reads as a behavioral change
#      (focus trap, keyboard handler, click listener, CSS class toggle,
#      etc.) — fall through to the code path.
#
# Keyword clusters (case-insensitive substring on change-value):
#   aria-label : aria, accessibility, screen reader
#   color      : color, background, fill, bg, hue, palette, theme
#   spacing    : spacing, margin, padding, gap
#   copy       : rename, label, heading, title, copy, text, wording, message
#   icon       : icon, logo, image src, image path
#   behavior   : focus, trap, keyboard, tab key, escape, click handler,
#                listener, modal open, dialog open
#   css-class  : class, hidden class, visible class, modifier class
#
# behavior + css-class are always routed to code path (no dialog field).
#
# Usage: classify-work.sh <simple-block.yaml> <dialog-map.json> <file-list.json> <output: work-plan.json>
# Exit codes:
#   0 — classified, work-plan.json written
#   8 — inputs missing / unreadable

set -euo pipefail

BLOCK="${1:?simple-block.yaml required}"
DIALOG="${2:?dialog-map.json required}"
FILES="${3:?file-list.json required}"
OUT="${4:?output work-plan.json path required}"

[[ -f "$BLOCK" ]]  || { echo "ERROR: $BLOCK missing" >&2; exit 8; }
[[ -f "$DIALOG" ]] || { echo "ERROR: $DIALOG missing" >&2; exit 8; }
[[ -f "$FILES" ]]  || { echo "ERROR: $FILES missing" >&2; exit 8; }
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq required" >&2; exit 8; }

CHANGE_VALUE=$(grep -E '^change-value:' "$BLOCK" | head -1 | sed -E 's/^change-value:[[:space:]]*//; s/[[:space:]]+$//' | sed -E 's/^"//;s/"$//' || true)
JCR_PATH=$(jq -r '.["jcr-path"] // empty' "$DIALOG")
RESOURCE_TYPE=$(jq -r '.["resource-type"] // empty' "$DIALOG")

# Lowercase change-value for keyword matching.
CV_LC=$(echo "$CHANGE_VALUE" | tr '[:upper:]' '[:lower:]')

# Detect behavioral / css-class signals first — they short-circuit to code.
BEHAVIOR_HIT=0
if echo "$CV_LC" | grep -qE 'focus|trap|keyboard|tab[[:space:]]*key|escape[[:space:]]*key|click[[:space:]]+handler|event[[:space:]]+listener|onclick|onkey|modal[[:space:]]+open|dialog[[:space:]]+open'; then
  BEHAVIOR_HIT=1
fi
CSS_CLASS_HIT=0
if echo "$CV_LC" | grep -qE 'css[[:space:]]+class|class[[:space:]]+name|add[[:space:]]+class|remove[[:space:]]+class|toggle[[:space:]]+class|hidden[[:space:]]+class|modifier[[:space:]]+class'; then
  CSS_CLASS_HIT=1
fi

# Field-name regex per cluster (matched against dialog field NAMES, not change-value).
declare -A PATTERNS=(
  ["aria-label"]='aria.*label|accessibility.*label|screen.?reader'
  ["color-token"]='color|bg|background|fill'
  ["spacing"]='spacing|margin|padding'
  ["copy"]='text|heading|title|body|copy'
  ["icon"]='icon|(logo|image).?(ref|path)'
)

# Decide which cluster best fits the change-value text.
# (Order matters when the description uses overlapping words — aria > copy.)
CLUSTER=""
if echo "$CV_LC" | grep -qE 'aria|accessibility|screen[[:space:]]*reader'; then
  CLUSTER="aria-label"
elif echo "$CV_LC" | grep -qE 'color|background|bg[[:space:]]|hue|palette|theme|fill'; then
  CLUSTER="color-token"
elif echo "$CV_LC" | grep -qE 'spacing|margin|padding|gap'; then
  CLUSTER="spacing"
elif echo "$CV_LC" | grep -qE 'icon|logo|image[[:space:]]+(src|path|ref)'; then
  CLUSTER="icon"
elif echo "$CV_LC" | grep -qE 'rename|label|heading|title|copy|text|wording|message|caption'; then
  CLUSTER="copy"
fi

PATTERN=""
[[ -n "$CLUSTER" ]] && PATTERN="${PATTERNS[$CLUSTER]:-}"

AUTH_FIELD=""
AUTH_TYPE=""
AUTH_CONF=0
ALTERNATIVES=()
ALT_TYPES=()

if [[ -n "$PATTERN" && "$BEHAVIOR_HIT" -eq 0 && "$CSS_CLASS_HIT" -eq 0 ]]; then
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

# Build code item(s) when authoring confidence < 75 OR the change-value
# describes a behavioral / css-class change.
CODE="[]"
if [[ "$AUTH_CONF" -lt 75 || "$BEHAVIOR_HIT" -eq 1 || "$CSS_CLASS_HIT" -eq 1 ]]; then
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
  --arg cluster "${CLUSTER:-none}" \
  --arg alts "${ALTERNATIVES[*]:-none}" \
  '{
    ticket: $ticket,
    component: { "jcr-path": $path, "resource-type": $rtype, "page-url": $page },
    authoring: $auth,
    code: $code,
    confidence: {
      "G3-classification": $level,
      "cluster": $cluster,
      "rationale": ("cluster=" + $cluster + " alternatives=" + $alts)
    }
  }' > "$OUT"

if [[ "$LEVEL" == "low" ]]; then
  echo "LOW-CONFIDENCE: no dialog field matched cluster '$CLUSTER' — falling back to code-only path" >&2
fi

echo "OK: work-plan written to $OUT (G3=$LEVEL, cluster=${CLUSTER:-none}, authoring=$(echo "$AUTHORING" | jq 'length'), code=$(echo "$CODE" | jq 'length'))" >&2

#!/usr/bin/env bash
# Enforces dx-simple budgets: ≤5 code files, ≤50 code lines (predicted),
# ≤10 JCR writes. Reads work-plan.json. Prints actuals on failure.
#
# Usage: scope-check.sh <work-plan.json>
# Exit codes:
#   0  — within budget
#   4  — over budget (stderr lists which limits + actuals)

set -euo pipefail

PLAN="${1:?work-plan.json path required}"
[[ -f "$PLAN" ]] || { echo "ERROR: $PLAN not found" >&2; exit 4; }

MAX_FILES=5
MAX_LINES=50
MAX_JCR_WRITES=10

# Use jq when available, else fall back to grep counts (less accurate but functional)
if command -v jq >/dev/null 2>&1; then
  # Validate JSON before reading individual keys so malformed input fails
  # with our documented exit code 4 instead of leaking jq's exit code 5.
  if ! jq empty "$PLAN" 2>/dev/null; then
    echo "ERROR: invalid JSON in $PLAN" >&2
    exit 4
  fi
  # Default missing .code / .authoring keys to [] so an empty {} or partial
  # object is treated as "no items" rather than a jq null-iteration error.
  FILES=$(jq '(.code // []) | length' "$PLAN")
  JCR_WRITES=$(jq '(.authoring // []) | length' "$PLAN")
  # Sum estimated lines per code item (rough: 1 line per replacement)
  LINES=$(jq '[(.code // [])[] | if ((.["match-context"] // "") | length) > 0 then 1 else 0 end] | add // 0' "$PLAN")
else
  FILES=$(grep -c '"file":' "$PLAN" || true)
  JCR_WRITES=$(grep -c '"property":' "$PLAN" || true)
  LINES="$FILES"  # rough fallback
fi

ERRORS=()
[[ "$FILES" -le "$MAX_FILES" ]] || ERRORS+=("code files: $FILES > $MAX_FILES")
[[ "$LINES" -le "$MAX_LINES" ]] || ERRORS+=("predicted lines: $LINES > $MAX_LINES")
[[ "$JCR_WRITES" -le "$MAX_JCR_WRITES" ]] || ERRORS+=("JCR writes: $JCR_WRITES > $MAX_JCR_WRITES")

if [[ "${#ERRORS[@]}" -gt 0 ]]; then
  echo "SCOPE-EXCEEDED:" >&2
  printf '  - %s\n' "${ERRORS[@]}" >&2
  exit 4
fi

echo "OK: scope check passed (files=$FILES, lines=$LINES, jcr=$JCR_WRITES)" >&2

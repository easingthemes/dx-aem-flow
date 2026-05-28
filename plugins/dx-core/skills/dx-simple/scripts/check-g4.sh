#!/usr/bin/env bash
# G4 gate enforcement: verify every item in work-plan.json's .code[] has
#   - confidence  >= MIN_CONF (default 0.85)
#   - match-context non-empty (agent populated it)
#   - replacement  non-empty (agent populated it)
#
# This script is invoked AFTER the agent rewrites work-plan.json with the
# per-item match data it identified in Phase 3b. classify-work.sh emits
# code items with confidence:0 / empty contexts on purpose (deferred).
#
# Usage: check-g4.sh <work-plan.json> [min-confidence]
# Exit codes:
#   0 — every code item passes
#   4 — at least one code item fails (stderr lists which)
#   8 — invalid input (file missing or not JSON)

set -uo pipefail

PLAN="${1:?work-plan.json path required}"
MIN_CONF="${2:-0.85}"

[[ -f "$PLAN" ]] || { echo "ERROR: $PLAN not found" >&2; exit 8; }
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq required" >&2; exit 8; }
jq empty "$PLAN" 2>/dev/null || { echo "ERROR: $PLAN is not valid JSON" >&2; exit 8; }

# No code items -> trivially pass (authoring-only run).
COUNT=$(jq '(.code // []) | length' "$PLAN")
if [[ "$COUNT" -eq 0 ]]; then
  echo "OK: G4 skipped (no code items)" >&2
  exit 0
fi

FAILED=$(jq -r --arg min "$MIN_CONF" '
  [(.code // [])[] |
    select(
      ((.confidence // 0) | tonumber) < ($min | tonumber)
      or ((.["match-context"] // "") | length) == 0
      or ((.replacement // "") | length) == 0
    )
    | "\(.file // "<no file>"): conf=\(.confidence // 0), ctx=\((.["match-context"] // "") | length)c, repl=\((.replacement // "") | length)c"
  ] | .[]
' "$PLAN")

if [[ -n "$FAILED" ]]; then
  echo "G4-FAILED (min-confidence=$MIN_CONF):" >&2
  echo "$FAILED" | sed 's/^/  - /' >&2
  echo "" >&2
  echo "Hint: the agent must rewrite work-plan.json with populated match-context, replacement, and confidence per code item BEFORE check-g4.sh." >&2
  exit 4
fi

echo "OK: G4 passed ($COUNT code items >= $MIN_CONF confidence)" >&2

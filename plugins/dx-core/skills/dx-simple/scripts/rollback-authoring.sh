#!/usr/bin/env bash
# Replays authoring-diff.json in REVERSE: writes the .before value back to
# each JCR path that was previously written. Delegates the actual JCR write
# to aem-revert.js (which uses the AEM MCP HTTP API via env vars).
#
# Usage: rollback-authoring.sh <authoring-diff.json>
# Exit codes:
#   0  — all reverts succeeded
#   5  — partial: some reverts failed (stderr lists which)

set -uo pipefail

DIFF="${1:?authoring-diff.json path required}"
[[ -f "$DIFF" ]] || { echo "ERROR: $DIFF not found" >&2; exit 5; }

REVERTER="$(dirname "${BASH_SOURCE[0]}")/../../../data/lib/aem-revert.js"
[[ -f "$REVERTER" ]] || { echo "ERROR: aem-revert.js not found at $REVERTER" >&2; exit 5; }

echo "Reverting authoring writes from $DIFF" >&2
node "$REVERTER" "$DIFF"
RC=$?

if [[ "$RC" -ne 0 ]]; then
  echo "PARTIAL-ROLLBACK: see stderr above for which writes failed" >&2
  exit 5
fi

echo "OK: all authoring writes rolled back" >&2

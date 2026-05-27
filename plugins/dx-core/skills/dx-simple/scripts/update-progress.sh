#!/usr/bin/env bash
# Appends/updates a row in simple-progress.md. Initializes the file from
# the template if it doesn't exist yet.
#
# Usage: update-progress.sh <spec-dir> <phase-name> <status> [note]
#   status: pending | in_progress | done | failed | skipped

set -euo pipefail

SPEC_DIR="${1:?spec dir required}"
PHASE="${2:?phase name required}"
STATUS="${3:?status required}"
NOTE="${4:-—}"

PROGRESS="$SPEC_DIR/simple-progress.md"
TEMPLATE="$(dirname "${BASH_SOURCE[0]}")/../templates/progress.md.tmpl"

mkdir -p "$SPEC_DIR"

# Resolve ticket id from spec dir name (e.g., 9999999-foo-bar -> 9999999)
TICKET=$(basename "$SPEC_DIR" | grep -oE '^[0-9]+' || echo "unknown")

# Initialize file from template if missing
if [[ ! -f "$PROGRESS" ]]; then
  sed "s/{TICKET}/$TICKET/g" "$TEMPLATE" > "$PROGRESS"
fi

# If the phase row already exists, update it; otherwise append
if grep -qE "^\| ${PHASE} \|" "$PROGRESS"; then
  # Use '#' as the sed delimiter to avoid collisions with the literal '|'
  # characters in the markdown table rows. Portable across BSD and GNU sed.
  if sed --version >/dev/null 2>&1; then
    sed -i "s#^\(| ${PHASE} | \).*#\\1${STATUS} | ${NOTE} |#" "$PROGRESS"
  else
    sed -i '' "s#^\(| ${PHASE} | \).*#\\1${STATUS} | ${NOTE} |#" "$PROGRESS"
  fi
else
  echo "| ${PHASE} | ${STATUS} | ${NOTE} |" >> "$PROGRESS"
fi

echo "OK: progress updated for ${PHASE} → ${STATUS}" >&2

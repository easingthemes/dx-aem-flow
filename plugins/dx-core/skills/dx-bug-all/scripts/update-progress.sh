#!/usr/bin/env bash
# Appends/updates a row in bug-progress.md. Initializes the file from the
# template if it doesn't exist yet. (/dx-bug-all variant of dx-simple's
# update-progress.sh — same logic, bug-specific file + template.)
#
# Usage: update-progress.sh <spec-dir> <step-name> <status> [note]
#   status: pending | in_progress | done | failed | skipped | blocked

set -euo pipefail

SPEC_DIR="${1:?spec dir required}"
STEP="${2:?step name required}"
STATUS="${3:?status required}"
NOTE="${4:-—}"

PROGRESS="$SPEC_DIR/bug-progress.md"
TEMPLATE="$(dirname "${BASH_SOURCE[0]}")/../templates/progress.md.tmpl"

mkdir -p "$SPEC_DIR"

# Resolve ticket id from spec dir name (e.g., 2453532-foo-bar -> 2453532)
TICKET=$(basename "$SPEC_DIR" | grep -oE '^[0-9]+' || echo "unknown")

# Escape regex metachars in STEP so step names are matched literally.
STEP_REGEX=$(printf '%s' "$STEP" | sed 's/[][\.*^$/(){}?+|]/\\&/g')

# Sanitize values used in sed replacements and table cells:
#   - escape sed replacement metachars: & \ #
#   - replace '|' with U+2223 (DIVIDES) so the table column count stays intact
sanitize() {
  printf '%s' "$1" | sed -e 's/[&\\#]/\\&/g' -e 's/|/∣/g'
}
STATUS_S=$(sanitize "$STATUS")
NOTE_S=$(sanitize "$NOTE")

# Initialize file from template if missing
if [[ ! -f "$PROGRESS" ]]; then
  sed "s/{TICKET}/$TICKET/g" "$TEMPLATE" > "$PROGRESS"
fi

# If the step row already exists, update it; otherwise append
if grep -qE "^\| ${STEP_REGEX} \|" "$PROGRESS"; then
  if sed --version >/dev/null 2>&1; then
    sed -i "s#^\(| ${STEP_REGEX} | \).*#\\1${STATUS_S} | ${NOTE_S} |#" "$PROGRESS"
  else
    sed -i '' "s#^\(| ${STEP_REGEX} | \).*#\\1${STATUS_S} | ${NOTE_S} |#" "$PROGRESS"
  fi
else
  printf '| %s | %s | %s |\n' "$STEP" "$STATUS_S" "$NOTE_S" >> "$PROGRESS"
fi

echo "OK: progress updated for ${STEP} → ${STATUS}" >&2

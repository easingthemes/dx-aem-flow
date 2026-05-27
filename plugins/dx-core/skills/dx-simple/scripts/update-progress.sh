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

# Escape regex metachars in PHASE so phase names like "Phase(A.1)" or
# "Build|Deploy" are matched literally in grep/sed patterns (C1).
PHASE_REGEX=$(printf '%s' "$PHASE" | sed 's/[][\.*^$/(){}?+|]/\\&/g')

# Sanitize values used in sed replacements and table cells (C2):
#   - escape sed replacement metachars: & \ #
#   - replace '|' with U+2223 (DIVIDES) so the markdown table column count
#     stays intact even when notes/statuses contain a literal pipe
sanitize() {
  printf '%s' "$1" | sed -e 's/[&\\#]/\\&/g' -e 's/|/∣/g'
}
STATUS_S=$(sanitize "$STATUS")
NOTE_S=$(sanitize "$NOTE")

# Initialize file from template if missing
if [[ ! -f "$PROGRESS" ]]; then
  sed "s/{TICKET}/$TICKET/g" "$TEMPLATE" > "$PROGRESS"
fi

# If the phase row already exists, update it; otherwise append
if grep -qE "^\| ${PHASE_REGEX} \|" "$PROGRESS"; then
  # Use '#' as the sed delimiter to avoid collisions with the literal '|'
  # characters in the markdown table rows. Portable across BSD and GNU sed.
  if sed --version >/dev/null 2>&1; then
    sed -i "s#^\(| ${PHASE_REGEX} | \).*#\\1${STATUS_S} | ${NOTE_S} |#" "$PROGRESS"
  else
    sed -i '' "s#^\(| ${PHASE_REGEX} | \).*#\\1${STATUS_S} | ${NOTE_S} |#" "$PROGRESS"
  fi
else
  # Append literal phase name (not the regex-escaped form) but use sanitized
  # status/note so a stray '|' in the note can't break the table layout.
  printf '| %s | %s | %s |\n' "$PHASE" "$STATUS_S" "$NOTE_S" >> "$PROGRESS"
fi

echo "OK: progress updated for ${PHASE} → ${STATUS}" >&2

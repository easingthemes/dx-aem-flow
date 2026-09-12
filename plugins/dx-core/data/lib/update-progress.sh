#!/usr/bin/env bash
# update-progress.sh — Append/update one row in a spec-dir progress file.
#
# The progress FILE is the source of truth for run progress across every dx
# coordinator. Task-tracking tools (TaskCreate/TaskUpdate/TaskList) are an
# optional display layer on top — see rules/task-progress.md. Claude Code
# stopped offering those tools by default on Opus 4.8 / Sonnet 5 / Fable 5 /
# Mythos 5 and newer (v2.1.233+), and they never existed on Copilot CLI,
# Codex or Gemini, so nothing may depend on them.
#
# Usage: update-progress.sh <spec-dir> <phase-name> <status> [note]
#   status: pending | in_progress | done | failed | skipped | blocked
#
# Environment:
#   DX_PROGRESS_FILE   output filename inside <spec-dir>  (default: progress.md)
#   DX_PROGRESS_TITLE  heading text, "<title> — #<ticket>" (default: Progress)
#   DX_PROGRESS_LABEL  first column header                (default: Phase)
#
# Exit codes: 0 — row written. Non-zero only on unusable arguments.

set -euo pipefail

SPEC_DIR="${1:?spec dir required}"
PHASE="${2:?phase name required}"
STATUS="${3:?status required}"
NOTE="${4:-—}"

PROGRESS_FILE="${DX_PROGRESS_FILE:-progress.md}"
PROGRESS_TITLE="${DX_PROGRESS_TITLE:-Progress}"
PROGRESS_LABEL="${DX_PROGRESS_LABEL:-Phase}"

PROGRESS="$SPEC_DIR/$PROGRESS_FILE"

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

# Initialize the file on first write. The header is generated here rather than
# read from a template so a coordinator needs no per-skill template file.
if [[ ! -f "$PROGRESS" ]]; then
  {
    printf '# %s — #%s\n\n' "$PROGRESS_TITLE" "$TICKET"
    printf '| %s | Status | Note |\n' "$PROGRESS_LABEL"
    printf '|---|---|---|\n'
  } > "$PROGRESS"
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

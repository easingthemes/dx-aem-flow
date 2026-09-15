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

# A literal '|' in any value would add a markdown column, so swap it for
# U+2223 (DIVIDES). This is the ONLY transform applied to a value — the row is
# matched and rewritten with literal string comparison (awk `index`), never a
# regex or a sed replacement, so phase names like "Phase(A.1)", "Build|Deploy"
# or notes like "color #FF0000 & more" need no further escaping.
cell() { printf '%s' "$1" | sed 's/|/∣/g'; }

PHASE_CELL=$(cell "$PHASE")
ROW="| $PHASE_CELL | $(cell "$STATUS") | $(cell "$NOTE") |"

# Initialize the file on first write. The header is generated here rather than
# read from a template so a coordinator needs no per-skill template file.
if [[ ! -f "$PROGRESS" ]]; then
  {
    printf '# %s — #%s\n\n' "$PROGRESS_TITLE" "$TICKET"
    printf '| %s | Status | Note |\n' "$PROGRESS_LABEL"
    printf '|---|---|---|\n'
  } > "$PROGRESS"
fi

# Rewrite the row in place if the phase is already listed, else append it.
# Values reach awk through the environment rather than `-v`, because `-v`
# interprets backslash escapes in the value and a phase name may contain one.
TMP=$(mktemp "${TMPDIR:-/tmp}/dx-progress.XXXXXX")
trap 'rm -f "$TMP"' EXIT

DX_ROW_KEY="| $PHASE_CELL | " DX_ROW="$ROW" awk '
  index($0, ENVIRON["DX_ROW_KEY"]) == 1 {
    # One row per phase: rewrite the first match, drop any duplicate.
    if (!seen) { print ENVIRON["DX_ROW"]; seen = 1 }
    next
  }
  { print }
  END { if (!seen) print ENVIRON["DX_ROW"] }
' "$PROGRESS" > "$TMP"

cat "$TMP" > "$PROGRESS"

echo "OK: progress updated for ${PHASE} → ${STATUS}" >&2

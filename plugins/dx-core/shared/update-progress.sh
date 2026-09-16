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

# Serialize concurrent writers. Subagents and forked skills write this same file
# (see rules/task-progress.md), so the init + read-merge-write below must not
# interleave — two writers reading the same starting content would make the
# later write drop the earlier row.
#
# The mutex is a directory, because `mkdir` is the one atomic test-and-set that
# exists everywhere: flock(1) is not installed on stock macOS, which is where
# most runs happen, so anything built on it silently does nothing there.
#
# The wait is bounded. A progress file is a report, not a transaction — a writer
# that was killed mid-update must never wedge a pipeline. So a lock older than a
# minute is treated as abandoned and reclaimed, and after ~10s we give up and
# write anyway, saying so on stderr. The atomic rename below means even an
# unlocked write can't be seen half-finished. Worst case, a lock leaked by a
# SIGKILLed writer costs each later writer 10s until it ages past the minute
# and is reclaimed — slow, never stuck, never wrong.
LOCK="$PROGRESS.lock"
LOCKED=""
cleanup() {
  [ -n "${TMP:-}" ] && rm -f "$TMP"
  # Release only a lock still stamped with our PID. Removing by path alone is the
  # same class of bug as the -mmin -1 reclaim below, one threshold up: if our hold
  # ever outlives the staleness window (a suspended laptop mid-critical-section is
  # the realistic way), another writer reclaims the path and creates its own lock,
  # and an unconditional rmdir here would delete a live one. Lock dirs would always
  # be empty, so that rmdir would always succeed.
  if [ -n "$LOCKED" ] && [ "$(cat "$LOCK/owner" 2>/dev/null)" = "$$" ]; then
    rm -rf "$LOCK"
  fi
  return 0
}
trap cleanup EXIT

for _ in $(seq 1 200); do
  # Stamp the lock on acquire so the release above can tell ours from a successor's.
  if mkdir "$LOCK" 2>/dev/null; then echo $$ > "$LOCK/owner"; LOCKED=1; break; fi
  # Reclaim an abandoned lock, but only on positive evidence of age: -mmin +1
  # prints the path only once the lock is over a minute old, and prints nothing
  # for a lock that is fresh OR that just vanished as its owner released it.
  # Testing the other way round (-z of -mmin -1) conflates those two cases, and
  # a writer that reads "gone" as "stale" goes on to rmdir whichever lock the
  # NEXT writer has meanwhile created — deleting a live lock it does not own.
  # The rename makes the removal single-winner: only one process can move a
  # given directory to its own uniquely-named target.
  if [ -n "$(find "$LOCK" -maxdepth 0 -mmin +1 2>/dev/null)" ]; then
    mv "$LOCK" "$LOCK.stale.$$" 2>/dev/null && rm -rf "$LOCK.stale.$$"
  fi
  sleep 0.05
done
[ -n "$LOCKED" ] || echo "warn: update-progress: lock wait timed out, writing unlocked" >&2

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
# mktemp inside the spec dir so the rename below stays on one filesystem.
TMP=$(mktemp "$SPEC_DIR/.dx-progress.XXXXXX")

DX_ROW_KEY="| $PHASE_CELL | " DX_ROW="$ROW" awk '
  index($0, ENVIRON["DX_ROW_KEY"]) == 1 {
    # One row per phase: rewrite the first match, drop any duplicate.
    if (!seen) { print ENVIRON["DX_ROW"]; seen = 1 }
    next
  }
  { print }
  END { if (!seen) print ENVIRON["DX_ROW"] }
' "$PROGRESS" > "$TMP"

mv -f "$TMP" "$PROGRESS"          # atomic: a reader never sees a partial file

echo "OK: progress updated for ${PHASE} → ${STATUS}" >&2

#!/usr/bin/env bash
# save-state.sh — Checkpoint /dx-simple recovery state to the per-ticket branch.
#
# The per-ticket git branch is the durable state store for resumable recovery
# (TODO #141). Every checkpoint stages the *text* recovery set under the spec
# dir, commits it, and pushes — so a crashed/blocked run leaves committed state
# the next run can resume from. PNGs are intentionally NOT checkpointed (large,
# not needed to resume the decision; Phase 6 commits them with the code change).
#
# Usage: save-state.sh <spec-dir> <phase>
#   <spec-dir>  e.g. .ai/specs/9999999-simple
#   <phase>     e.g. "Phase 1" | "Phase 3a" | "G4" — recorded as last-completed-phase
#
# Behavior:
#   1. Bumps resume-state.json's last-completed-phase to <phase> (status/blocker
#      are owned by the caller — ABORT sets them via jq BEFORE calling this).
#   2. Stages only the named text files that exist (no `git add .`/`-A`).
#   3. Commits `chore(dx-simple): checkpoint <phase> [#<id>]` (decision #4 —
#      checkpoint commits on the branch are accepted; not squashed).
#   4. Rebase-before-push (H2): `git pull --rebase origin <branch>` then push
#      with exponential backoff. On an un-rebasable non-fast-forward, BAILS
#      (exit 3) with a clear "branch advanced under another run" message rather
#      than force-pushing — this is the only dedup layer on the comment path
#      (the Lambda's body.id dedup does not apply here).
#
# Exit codes:
#   0  — checkpoint committed (and pushed if a remote is configured), or nothing
#        to commit
#   3  — branch advanced under another run (concurrent @<keyword> resume) —
#        un-rebasable non-fast-forward; caller should bail, NOT retry
#   4  — push failed after retries for a non-rebase reason
#   5  — usage / not a git repo

set -uo pipefail

SPEC_DIR="${1:?Usage: save-state.sh <spec-dir> <phase>}"
SPEC_DIR="${SPEC_DIR%/}"
PHASE="${2:?Usage: save-state.sh <spec-dir> <phase>}"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "ERROR: save-state.sh must run inside a git work tree" >&2
  exit 5
}

BRANCH=$(git branch --show-current 2>/dev/null || echo "")
[[ -z "$BRANCH" ]] && { echo "ERROR: detached HEAD — cannot checkpoint" >&2; exit 5; }

# Ticket id = leading digits of the spec dir basename.
TICKET_ID=$(basename "$SPEC_DIR" | grep -oE '^[0-9]+' || echo "")

STATE="$SPEC_DIR/resume-state.json"

# 1. Bump last-completed-phase (only — status/blocker are the caller's to set).
if [[ -f "$STATE" ]] && command -v jq >/dev/null 2>&1; then
  tmp=$(mktemp)
  if jq --arg p "$PHASE" '.["last-completed-phase"] = $p' "$STATE" > "$tmp" 2>/dev/null; then
    mv "$tmp" "$STATE"
  else
    rm -f "$tmp"
  fi
fi

# 2. Stage only the recovery text set that exists. NEVER `git add .`/`-A`
#    (git-rules.md). PNGs deliberately excluded from checkpoints.
RECOVERY_FILES=(
  resume-state.json
  simple-block.yaml
  work-plan.json
  dialog-map.json
  file-list.json
  confidence.json
  authoring-diff.json
  locator-bbox.json
  simple-progress.md
  report.md
  raw-story.md
)
staged=0
for f in "${RECOVERY_FILES[@]}"; do
  if [[ -f "$SPEC_DIR/$f" ]]; then
    git add -- "$SPEC_DIR/$f" 2>/dev/null && staged=1
  fi
done

if [[ "$staged" -eq 0 ]] || git diff --cached --quiet 2>/dev/null; then
  echo "OK: nothing to checkpoint at $PHASE (no staged changes)" >&2
  exit 0
fi

# 3. Commit. Decision #4: checkpoint commits are accepted (not squashed).
git commit --quiet -m "$(cat <<EOF
chore(dx-simple): checkpoint ${PHASE} [#${TICKET_ID}]
EOF
)" || { echo "ERROR: checkpoint commit failed" >&2; exit 4; }

# No remote? Local-dev resume still works off the committed branch.
if ! git remote get-url origin >/dev/null 2>&1; then
  echo "OK: checkpoint committed at $PHASE (no origin remote — local only)" >&2
  exit 0
fi

# 4. Rebase-before-push (H2). The branch has no uncommitted code edits at
#    checkpoint time (code edits are ephemeral, never committed — decision #3),
#    so a rebase is safe. If the remote advanced under a concurrent resume and
#    the rebase can't replay cleanly, BAIL — do not force-push.
git fetch --quiet origin "$BRANCH" 2>/dev/null || true
if git rev-parse --verify --quiet "refs/remotes/origin/$BRANCH" >/dev/null 2>&1; then
  if ! git pull --rebase --quiet origin "$BRANCH" 2>/dev/null; then
    git rebase --abort 2>/dev/null || true
    echo "BRANCH-ADVANCED: '$BRANCH' advanced under another run — a concurrent @<keyword> resume is in flight. Bailing rather than force-pushing." >&2
    exit 3
  fi
fi

# Push with exponential backoff (2s/4s/8s/16s) per git-rules.md push policy.
for delay in 0 2 4 8 16; do
  [[ "$delay" -gt 0 ]] && sleep "$delay"
  if git push --quiet -u origin "$BRANCH" 2>/dev/null; then
    echo "OK: checkpoint committed + pushed at $PHASE (branch $BRANCH)" >&2
    exit 0
  fi
  # A non-fast-forward that appeared between rebase and push → re-check by
  # bailing (concurrent run); other failures get retried by the loop.
  if git rev-parse --verify --quiet "refs/remotes/origin/$BRANCH" >/dev/null 2>&1; then
    git fetch --quiet origin "$BRANCH" 2>/dev/null || true
    if ! git merge-base --is-ancestor "refs/remotes/origin/$BRANCH" HEAD 2>/dev/null; then
      echo "BRANCH-ADVANCED: '$BRANCH' advanced under another run during push. Bailing." >&2
      exit 3
    fi
  fi
done

echo "ERROR: push failed after retries for branch $BRANCH" >&2
exit 4

#!/usr/bin/env bash
# save-state.sh — Checkpoint /dx-bug-all recovery state to the per-ticket branch.
#
# The per-ticket git branch (bugfix/<id>-<slug>) is the durable state store for
# resumable recovery. Every checkpoint stages the *text* recovery set under the
# spec dir, commits it, and PUSHES — so a crashed/blocked run leaves committed
# state on origin that the next pipeline container can resume from. Screenshots
# (PNGs) are intentionally NOT checkpointed (large, not needed to resume the
# decision).
#
# Unlike dx-simple (whose code edits are never committed), /dx-bug-fix commits its
# fix and opens a PR. That code lands on the same branch via /dx-pr-commit; this
# checkpoint only ever stages the named SPEC text files, so it never fights the
# fix commit — it just adds a small `chore(dx-bug-all): checkpoint` commit on top.
#
# Usage: save-state.sh <spec-dir> <step>
#   <spec-dir>  e.g. .ai/specs/2453532-preview-image-persists
#   <step>      "triage" | "verify" | "fix" | "finalize" — recorded as last-completed-step
#
# Exit codes:
#   0  — checkpoint committed (and pushed if a remote is configured), or nothing
#        to commit
#   3  — branch advanced under another run (concurrent @<token> resume) —
#        un-rebasable non-fast-forward; caller should bail, NOT retry
#   4  — push failed after retries for a non-rebase reason
#   5  — usage / not a git repo

set -uo pipefail

SPEC_DIR="${1:?Usage: save-state.sh <spec-dir> <step>}"
SPEC_DIR="${SPEC_DIR%/}"
STEP="${2:?Usage: save-state.sh <spec-dir> <step>}"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "ERROR: save-state.sh must run inside a git work tree" >&2
  exit 5
}

BRANCH=$(git branch --show-current 2>/dev/null || echo "")
[[ -z "$BRANCH" ]] && { echo "ERROR: detached HEAD — cannot checkpoint" >&2; exit 5; }

# Ticket id = leading digits of the spec dir basename.
TICKET_ID=$(basename "$SPEC_DIR" | grep -oE '^[0-9]+' || echo "")

STATE="$SPEC_DIR/resume-state.json"

# 1. Bump last-completed-step (only — status/blocker are the caller's to set).
if [[ -f "$STATE" ]] && command -v jq >/dev/null 2>&1; then
  tmp=$(mktemp)
  if jq --arg s "$STEP" '.["last-completed-step"] = $s' "$STATE" > "$tmp" 2>/dev/null; then
    mv "$tmp" "$STATE"
  else
    rm -f "$tmp"
  fi
fi

# 2. Stage only the recovery text set that exists. NEVER `git add .`/`-A`
#    (git-rules.md). PNGs/screenshots deliberately excluded from checkpoints.
RECOVERY_FILES=(
  resume-state.json
  raw-bug.md
  triage.md
  verification.md
  verification-local.md
  implement.md
  followup.md
  bug-progress.md
  report.md
  .branch
)
staged=0
for f in "${RECOVERY_FILES[@]}"; do
  if [[ -f "$SPEC_DIR/$f" ]]; then
    git add -- "$SPEC_DIR/$f" 2>/dev/null && staged=1
  fi
done

if [[ "$staged" -eq 0 ]] || git diff --cached --quiet 2>/dev/null; then
  echo "OK: nothing to checkpoint at $STEP (no staged changes)" >&2
  exit 0
fi

# 3. Commit. Checkpoint commits on the branch are accepted (not squashed).
git commit --quiet -m "$(cat <<EOF
chore(dx-bug-all): checkpoint ${STEP} [#${TICKET_ID}]
EOF
)" || { echo "ERROR: checkpoint commit failed" >&2; exit 4; }

# No remote? Local-dev resume still works off the committed branch.
if ! git remote get-url origin >/dev/null 2>&1; then
  echo "OK: checkpoint committed at $STEP (no origin remote — local only)" >&2
  exit 0
fi

# 4. Rebase-before-push (H2). If the remote advanced under a concurrent resume
#    and the rebase can't replay cleanly, BAIL — do not force-push.
git fetch --quiet origin "$BRANCH" 2>/dev/null || true
if git rev-parse --verify --quiet "refs/remotes/origin/$BRANCH" >/dev/null 2>&1; then
  if ! git pull --rebase --quiet origin "$BRANCH" 2>/dev/null; then
    git rebase --abort 2>/dev/null || true
    echo "BRANCH-ADVANCED: '$BRANCH' advanced under another run — a concurrent @<token> resume is in flight. Bailing rather than force-pushing." >&2
    exit 3
  fi
fi

# Push with exponential backoff (2s/4s/8s/16s) per git-rules.md push policy.
for delay in 0 2 4 8 16; do
  [[ "$delay" -gt 0 ]] && sleep "$delay"
  if git push --quiet -u origin "$BRANCH" 2>/dev/null; then
    echo "OK: checkpoint committed + pushed at $STEP (branch $BRANCH)" >&2
    exit 0
  fi
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

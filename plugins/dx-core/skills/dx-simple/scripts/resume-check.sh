#!/usr/bin/env bash
# resume-check.sh — Phase 0 of /dx-simple resumable recovery (TODO #141).
#
# A fresh pipeline container can't recompute run 1's title-derived slug, so
# resume keys on the TICKET ID with an ANCHORED prefix match — never a bare
# substring (`123` must NOT match `feature/1234-x`). This script owns:
#   - anchored discovery of the ticket's branch (feature/<id>-* | bugfix/<id>-*)
#   - the 0 / 1 / >1 branch decision (>1 → ambiguous-branch BLOCKER, not "pick any")
#   - the reverse branch -> spec-dir mapping (the inverse of ensure-feature-branch.sh,
#     which is why this is a NEW script, not an extension of the shared helper — M2)
#   - reading resume-state.json and emitting the Phase 0 DISPATCH
#
# It is READ-ONLY w.r.t. resume-state.json (it never increments answer-attempts —
# a crash resume must not burn the needs-input cap, M4). The create-fresh path is
# the ONLY thing delegated to shared/ensure-feature-branch.sh (contract unchanged).
#
# Usage: resume-check.sh <ticket-id> [spec-root]
#   <ticket-id>  numeric ADO work item id
#   [spec-root]  default .ai/specs
#
# Output: key=value lines to stdout. Always emits DISPATCH and BRANCH (when known).
#   DISPATCH=fresh | resume-forward | resume-blocked-input | resume-blocked-hard
#            | done | ambiguous-branch
#   BRANCH=<branch>                       (absent for ambiguous-branch)
#   SPEC_DIR=<spec-dir>                   (when resolvable)
#   STATUS=<resume-state status>          (resume-* dispatches)
#   LAST_COMPLETED_PHASE=<phase>
#   BLOCKED_AT_PHASE=<phase>
#   RE_ENTER_PHASE=<phase>                (the phase the skill should re-enter)
#   REPLAY_CODE_EDITS=true|false          (true => replay code edits from work-plan
#                                          before re-entering — past Phase 3b, C2)
#   ANSWER_ATTEMPTS=<n>
#   COMMENT_CURSOR=<id>                   (last follow-up comment consumed; the
#                                          SKILL uses this to decide done→reopen)
#   MAX_ATTEMPTS=<n>
#   MATCHES=<branch1,branch2,...>         (only for ambiguous-branch)
#
# Exit codes:
#   0  — dispatch resolved (read DISPATCH from stdout)
#   2  — bad usage (missing/non-numeric ticket id)

set -uo pipefail

TICKET_ID="${1:-}"
SPEC_ROOT="${2:-.ai/specs}"

if ! [[ "$TICKET_ID" =~ ^[0-9]+$ ]]; then
  echo "ERROR: resume-check.sh requires a numeric ticket id (got '${TICKET_ID}')" >&2
  exit 2
fi

# --- max-attempts from config (M7), default 3 ----------------------------------
MAX_ATTEMPTS=3
if [[ -f .ai/config.yaml ]]; then
  _ma=$(grep -E '^\s*(dx-simple\.recovery\.max-attempts|max-attempts):' .ai/config.yaml 2>/dev/null \
        | head -1 | sed 's/^[^:]*:\s*//' | tr -dc '0-9')
  [[ -n "${_ma:-}" ]] && MAX_ATTEMPTS="$_ma"
fi

# --- phase ordering (single source of truth for forward-resume + past-3b) ------
ALL_ORDER=( "Phase 0" "Phase 1" "G1" "Phase 2" "G3" "Phase 3a" "Phase 3b" \
            "G4" "Phase 4" "Phase 5" "G5" "G6" "Phase 5.5" "G7" "Phase 6" "Phase 7" )

_index_of() {  # $1 = label; prints index or -1
  local target="$1" i
  for i in "${!ALL_ORDER[@]}"; do
    [[ "${ALL_ORDER[$i]}" == "$target" ]] && { echo "$i"; return; }
  done
  echo "-1"
}

# Next actionable Phase node after a (possibly gate) label.
_next_actionable_phase() {
  local last="$1" idx i lbl
  # Phase 6 is checkpointed BEFORE its irreversible PR-create (M5), so a crash
  # at Phase 6 re-enters Phase 6 (idempotent update-mode), not Phase 7.
  [[ "$last" == "Phase 6" ]] && { echo "Phase 6"; return; }
  idx=$(_index_of "$last")
  [[ "$idx" -lt 0 ]] && { echo "Phase 1"; return; }
  for (( i = idx + 1; i < ${#ALL_ORDER[@]}; i++ )); do
    lbl="${ALL_ORDER[$i]}"
    [[ "$lbl" == Phase* ]] && { echo "$lbl"; return; }
  done
  echo "Phase 7"
}

# True if re-entering <phase> requires replaying ephemeral code edits first (C2):
# any phase strictly AFTER Phase 3b. Phase 3b itself re-applies the work-plan, so
# re-entering 3b does NOT need a separate replay.
_replay_for() {
  local phase="$1" idx3b idx
  idx3b=$(_index_of "Phase 3b")
  idx=$(_index_of "$phase")
  if [[ "$idx" -gt "$idx3b" ]]; then echo "true"; else echo "false"; fi
}

# Jump target for a needs-input blocker (resume jump table).
_jump_target() {
  case "$1" in
    G1)  echo "Phase 1" ;;   # re-locate
    G3)  echo "Phase 2" ;;   # re-classify
    G4)  echo "Phase 3b" ;;  # re-fill + re-apply work-plan
    G7)  echo "Phase 3b" ;;  # re-edit
    *)   echo "$1" ;;
  esac
}

# --- anchored branch discovery -------------------------------------------------
git fetch origin --quiet 2>/dev/null || true

# Anchored regex: feature|bugfix / <id> - …  (the trailing hyphen is the anchor,
# so 123 cannot match feature/1234-x). Collect remote + local, dedupe.
ANCHOR="^(feature|bugfix)/${TICKET_ID}-"
declare -a MATCHES=()
while IFS= read -r ref; do
  [[ -z "$ref" ]] && continue
  [[ "$ref" =~ $ANCHOR ]] && MATCHES+=("$ref")
done < <(
  { git ls-remote --heads origin 2>/dev/null | sed 's#.*refs/heads/##'
    git for-each-ref --format='%(refname:short)' refs/heads 2>/dev/null
  } | sort -u
)

NMATCH="${#MATCHES[@]}"

# --- 0 matches → create fresh (delegate ONLY this path to the shared helper) ---
if [[ "$NMATCH" -eq 0 ]]; then
  SPEC_DIR="${SPEC_ROOT%/}/${TICKET_ID}-simple"
  mkdir -p "$SPEC_DIR"
  ENSURE="${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/shared/ensure-feature-branch.sh}"
  if [[ -z "$ENSURE" || ! -f "$ENSURE" ]]; then
    ENSURE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../shared" 2>/dev/null && pwd)/ensure-feature-branch.sh"
  fi
  BRANCH="feature/${TICKET_ID}-simple"
  if [[ -f "$ENSURE" ]]; then
    # ensure-feature-branch.sh prints BRANCH=… ; capture it.
    eval "$(bash "$ENSURE" "$SPEC_DIR" 2>/dev/null | grep '^BRANCH=')" || true
  else
    git checkout -b "$BRANCH" --quiet 2>/dev/null || git checkout "$BRANCH" --quiet 2>/dev/null || true
  fi
  echo "DISPATCH=fresh"
  echo "BRANCH=${BRANCH}"
  echo "SPEC_DIR=${SPEC_DIR}"
  echo "MAX_ATTEMPTS=${MAX_ATTEMPTS}"
  exit 0
fi

# --- >1 matches → ambiguous-branch BLOCKER (do NOT pick any, M1) ---------------
if [[ "$NMATCH" -gt 1 ]]; then
  echo "DISPATCH=ambiguous-branch"
  echo "MATCHES=$(IFS=,; echo "${MATCHES[*]}")"
  echo "MAX_ATTEMPTS=${MAX_ATTEMPTS}"
  exit 0
fi

# --- exactly 1 match → check it out and resume ---------------------------------
BRANCH="${MATCHES[0]}"
if git show-ref --verify --quiet "refs/heads/${BRANCH}" 2>/dev/null; then
  git checkout "${BRANCH}" --quiet 2>/dev/null || true
elif git rev-parse --verify --quiet "refs/remotes/origin/${BRANCH}" >/dev/null 2>&1; then
  git checkout -b "${BRANCH}" "origin/${BRANCH}" --quiet 2>/dev/null || true
fi

# Reverse map branch -> committed spec dir: the only <id>-* spec dir carrying a
# resume-state.json. (The fresh path always names it <id>-simple, but a human
# rename is tolerated by globbing on the id.)
SPEC_DIR=""
STATE=""
for d in "${SPEC_ROOT%/}/${TICKET_ID}-"*; do
  [[ -f "$d/resume-state.json" ]] || continue
  SPEC_DIR="$d"; STATE="$d/resume-state.json"; break
done

# Branch exists but no committed state (created out-of-band) → start fresh on it.
if [[ -z "$STATE" ]]; then
  SPEC_DIR="${SPEC_ROOT%/}/${TICKET_ID}-simple"
  mkdir -p "$SPEC_DIR"
  echo "DISPATCH=fresh"
  echo "BRANCH=${BRANCH}"
  echo "SPEC_DIR=${SPEC_DIR}"
  echo "MAX_ATTEMPTS=${MAX_ATTEMPTS}"
  exit 0
fi

# Read state (read-only — never mutate; a crash resume must not bump attempts).
_jq() { jq -r "$1" "$STATE" 2>/dev/null; }
STATUS=$(_jq '.status // "in-progress"')
LAST=$(_jq '.["last-completed-phase"] // "Phase 0"')
BLOCKED_AT=$(_jq '.["blocked-at-phase"] // ""')
ATTEMPTS=$(_jq '.["answer-attempts"] // 0')
[[ "$ATTEMPTS" =~ ^[0-9]+$ ]] || ATTEMPTS=0
# comment-cursor (last follow-up comment consumed). Emitted so the SKILL — which
# DOES have ADO access — can decide `done` → reopen vs no-op (this script can't
# reach ADO). Empty string means "nothing consumed yet"; the SKILL treats it as 0.
CURSOR=$(_jq '.["comment-cursor"] // ""')

emit_common() {
  echo "BRANCH=${BRANCH}"
  echo "SPEC_DIR=${SPEC_DIR}"
  echo "STATUS=${STATUS}"
  echo "LAST_COMPLETED_PHASE=${LAST}"
  echo "BLOCKED_AT_PHASE=${BLOCKED_AT}"
  echo "ANSWER_ATTEMPTS=${ATTEMPTS}"
  echo "COMMENT_CURSOR=${CURSOR}"
  echo "MAX_ATTEMPTS=${MAX_ATTEMPTS}"
}

case "$STATUS" in
  done)
    echo "DISPATCH=done"; emit_common ;;

  blocked-hard)
    echo "DISPATCH=resume-blocked-hard"; emit_common ;;

  blocked-needs-input)
    # Cap reached (M4) → downgrade to hard, recommend DevAgent. The cap counts
    # only human-answer cycles; crashes never reach here with a bumped count.
    if [[ "$ATTEMPTS" -ge "$MAX_ATTEMPTS" ]]; then
      echo "DISPATCH=resume-blocked-hard"; emit_common
    else
      RE=$(_jump_target "$BLOCKED_AT")
      echo "DISPATCH=resume-blocked-input"
      echo "RE_ENTER_PHASE=${RE}"
      echo "REPLAY_CODE_EDITS=$(_replay_for "$RE")"
      emit_common
    fi ;;

  *)  # in-progress (or unknown) → prior run crashed; resume forward.
    RE=$(_next_actionable_phase "$LAST")
    echo "DISPATCH=resume-forward"
    echo "RE_ENTER_PHASE=${RE}"
    echo "REPLAY_CODE_EDITS=$(_replay_for "$RE")"
    emit_common ;;
esac

exit 0

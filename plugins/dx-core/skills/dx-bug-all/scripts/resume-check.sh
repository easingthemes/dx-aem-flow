#!/usr/bin/env bash
# resume-check.sh — Phase 0 of /dx-bug-all resumable recovery.
#
# Mirrors dx-simple's recovery model (TODO #141) but over the THREE coarse steps
# of the bug pipeline (triage → verify → fix) instead of dx-simple's 8 phases. A
# fresh pipeline container can't recompute run 1's title-derived slug, so resume
# keys on the TICKET ID with an ANCHORED prefix match — never a bare substring
# (`123` must NOT match `bugfix/1234-x`). This script owns:
#   - anchored discovery of the ticket's branch (bugfix/<id>-* | feature/<id>-*)
#   - the 0 / 1 / >1 branch decision (>1 → ambiguous-branch BLOCKER, not "pick any")
#   - the reverse branch -> spec-dir mapping (the dir carrying resume-state.json)
#   - reading resume-state.json and emitting the Phase 0 DISPATCH
#
# UNLIKE dx-simple's resume-check it does NOT create a fresh branch: on a fresh
# run /dx-bug-triage (Step 1) creates `bugfix/<id>-<slug>` itself, preserving the
# bug skills' existing local behavior. This script only DISCOVERS an already-pushed
# branch for resume. It is READ-ONLY w.r.t. resume-state.json (never bumps
# answer-attempts — a crash resume must not burn the needs-input cap).
#
# Usage: resume-check.sh <ticket-id> [spec-root]
#   <ticket-id>  numeric ADO work item id
#   [spec-root]  default .ai/specs
#
# Output: key=value lines to stdout. Always emits DISPATCH.
#   DISPATCH=fresh | resume-forward | resume-blocked-input | resume-blocked-hard
#            | done | ambiguous-branch
#   BRANCH=<branch>                       (absent for fresh-with-no-branch + ambiguous)
#   SPEC_DIR=<spec-dir>                   (when resolvable)
#   STATUS=<resume-state status>          (resume-* dispatches)
#   LAST_COMPLETED_STEP=<step>
#   BLOCKED_AT_STEP=<step>
#   RE_ENTER_STEP=<step>                  (the step the skill should re-enter)
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

# --- max-attempts from config, default 3 ---------------------------------------
# Scope the read to the `dx-bug-all:` block so a bare `max-attempts:` in another
# section (e.g. dx-simple.recovery) can't leak in. Handles the nested form
# (dx-bug-all: → recovery: → max-attempts:) and the flattened dotted key.
MAX_ATTEMPTS=3
if [[ -f .ai/config.yaml ]]; then
  _ma=$(awk '
    /^dx-bug-all:[[:space:]]*$/ { inb=1; next }
    inb && /^[^[:space:]#]/ { inb=0 }
    inb && /^[[:space:]]+max-attempts:/ {
      sub(/^[[:space:]]+max-attempts:[[:space:]]*/, ""); sub(/[[:space:]]*#.*$/, ""); print; exit
    }
    /^[[:space:]]*dx-bug-all\.recovery\.max-attempts:/ {
      sub(/^[^:]*:[[:space:]]*/, ""); sub(/[[:space:]]*#.*$/, ""); print; exit
    }
  ' .ai/config.yaml 2>/dev/null | head -1 | tr -dc '0-9')
  [[ -n "${_ma:-}" ]] && MAX_ATTEMPTS="$_ma"
fi

# --- coarse step ordering (single source of truth for forward-resume) ----------
# "Step 0" = nothing done yet; "finalize" = post-PR ADO comment + done checkpoint.
ALL_ORDER=( "Step 0" "triage" "verify" "fix" "finalize" )

_index_of() {  # $1 = label; prints index or -1
  local target="$1" i
  for i in "${!ALL_ORDER[@]}"; do
    [[ "${ALL_ORDER[$i]}" == "$target" ]] && { echo "$i"; return; }
  done
  echo "-1"
}

# Next actionable step after a given last-completed label.
_next_actionable_step() {
  local last="$1" idx
  idx=$(_index_of "$last")
  [[ "$idx" -lt 0 ]] && { echo "triage"; return; }
  local nxt=$(( idx + 1 ))
  if [[ "$nxt" -ge ${#ALL_ORDER[@]} ]]; then echo "done"; else echo "${ALL_ORDER[$nxt]}"; fi
}

# --- anchored branch discovery -------------------------------------------------
git fetch origin --quiet 2>/dev/null || true

# Anchored regex: bugfix|feature / <id> - …  (the trailing hyphen is the anchor,
# so 123 cannot match bugfix/1234-x). Collect remote + local, dedupe.
ANCHOR="^(bugfix|feature)/${TICKET_ID}-"
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

# --- 0 matches → fresh run (triage will create the branch — we do NOT) ---------
if [[ "$NMATCH" -eq 0 ]]; then
  echo "DISPATCH=fresh"
  echo "MAX_ATTEMPTS=${MAX_ATTEMPTS}"
  exit 0
fi

# --- >1 matches → ambiguous-branch BLOCKER (do NOT pick any) --------------------
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
# resume-state.json (tolerates a human-renamed slug by globbing on the id).
SPEC_DIR=""
STATE=""
for d in "${SPEC_ROOT%/}/${TICKET_ID}-"*; do
  [[ -f "$d/resume-state.json" ]] || continue
  SPEC_DIR="$d"; STATE="$d/resume-state.json"; break
done

# Branch exists but no committed state (triage crashed before the first
# checkpoint, or the branch was created out-of-band) → start fresh on it. triage
# is idempotent (skips re-fetch when raw-bug.md is current), so re-running is safe.
if [[ -z "$STATE" ]]; then
  echo "DISPATCH=fresh"
  echo "BRANCH=${BRANCH}"
  echo "MAX_ATTEMPTS=${MAX_ATTEMPTS}"
  exit 0
fi

# Read state (read-only — never mutate; a crash resume must not bump attempts).
_jq() { jq -r "$1" "$STATE" 2>/dev/null; }
STATUS=$(_jq '.status // "in-progress"')
LAST=$(_jq '.["last-completed-step"] // "Step 0"')
BLOCKED_AT=$(_jq '.["blocked-at-step"] // ""')
ATTEMPTS=$(_jq '.["answer-attempts"] // 0')
[[ "$ATTEMPTS" =~ ^[0-9]+$ ]] || ATTEMPTS=0
CURSOR=$(_jq '.["comment-cursor"] // ""')

emit_common() {
  echo "BRANCH=${BRANCH}"
  echo "SPEC_DIR=${SPEC_DIR}"
  echo "STATUS=${STATUS}"
  echo "LAST_COMPLETED_STEP=${LAST}"
  echo "BLOCKED_AT_STEP=${BLOCKED_AT}"
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
    # Cap reached → downgrade to hard, recommend re-tag/DevAgent. The cap counts
    # only human-answer cycles; crashes never reach here with a bumped count.
    if [[ "$ATTEMPTS" -ge "$MAX_ATTEMPTS" ]]; then
      echo "DISPATCH=resume-blocked-hard"; emit_common
    else
      # needs-input re-enters the step that blocked (triage/verify/fix).
      RE="${BLOCKED_AT:-triage}"
      echo "DISPATCH=resume-blocked-input"
      echo "RE_ENTER_STEP=${RE}"
      emit_common
    fi ;;

  *)  # in-progress (or unknown) → prior run crashed; resume forward.
    RE=$(_next_actionable_step "$LAST")
    echo "DISPATCH=resume-forward"
    echo "RE_ENTER_STEP=${RE}"
    emit_common ;;
esac

exit 0

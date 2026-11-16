#!/usr/bin/env bash
# stop-guard.sh — Anti-rationalization Stop hook
#
# Checks for skipped processes before allowing Claude to exit:
# 1. Secrets in changed files
# 2. Abandoned plan steps in the active ticket's implement.md (in-progress, or
#    blocked with no reason written)
# 3. Uncommitted code changes without explanation
#
# Exit: 0 with JSON {"decision":"block","reason":"..."} to block
# Exit: 0 with no output to allow stop

set -euo pipefail

INPUT=$(cat)


# Prevent infinite loops — if we already blocked once, let the agent stop.
# Claude Code and Copilot CLI (agentStop, verified v1.0.109 interactive) both send
# stop_hook_active=true on the call after a block. The repeat check in the Report
# section below is a backup for a host that omits the field: the same findings
# never block twice in a row.
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null || echo false)
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  exit 0
fi

CWD=$(echo "$INPUT" | jq -r '.cwd // "."' 2>/dev/null || echo .)
cd "$CWD" || exit 0

# Only check if we're in a git repo
GIT_DIR=$(git rev-parse --absolute-git-dir 2>/dev/null) || exit 0
# Last block: "<checksum of reason> <epoch>". Lives in the git dir, never tracked.
STATE_FILE="$GIT_DIR/dx-stop-guard.last"
REPEAT_WINDOW=600

ISSUES=()

# --- Check 1: Secrets in staged or modified files ---
CHANGED_FILES=$(git diff --name-only HEAD 2>/dev/null || true)
STAGED_FILES=$(git diff --cached --name-only 2>/dev/null || true)
ALL_CHANGED="$CHANGED_FILES"$'\n'"$STAGED_FILES"

if [ -n "$ALL_CHANGED" ]; then
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    [ ! -f "$file" ] && continue
    # Skip binary files and known safe patterns
    case "$file" in
      *.png|*.jpg|*.gif|*.jar|*.zip|*.class|*.woff*|*.ttf|*.eot) continue ;;
    esac
    # Skip files that legitimately reference secret patterns (detection, redaction, docs, scanning)
    case "$file" in
      */redact.js|*/redact.test.*|*/aws-sig.js) continue ;;
      */stop-guard.sh|*/pre-review-checks.sh) continue ;;
      */runbook.md|*/pipeline-policy.yaml) continue ;;
      */auto-init/SKILL.md|*/auto-status/SKILL.md|*/auto-lambda-env/SKILL.md) continue ;;
    esac
    # Check for common secret patterns
    if grep -qEi '(aws_secret_access_key|aws_access_key_id|PRIVATE.KEY|password\s*=\s*["\x27][^"\x27]+|api[_-]?key\s*=\s*["\x27][^"\x27]+|secret\s*=\s*["\x27][^"\x27]+|token\s*=\s*["\x27][a-zA-Z0-9]{20,})' "$file" 2>/dev/null; then
      ISSUES+=("Secret pattern detected in $file")
    fi
  done <<< "$ALL_CHANGED"
fi

# --- Check 2: Abandoned plan steps (active ticket only) ---
# Only the plan of the ticket being worked on counts — another story's plan in
# .ai/specs/ is not this session's business. The active plan is the one for the
# ticket in the branch name (feature/<id>-*, bugfix/<id>-*); off a ticket branch,
# the one implement.md changed in the working tree, if exactly one is.
IMPL_FILE=""
BRANCH=$(git branch --show-current 2>/dev/null || true)
TICKET=$(printf '%s' "$BRANCH" | sed -nE 's#^(feature|bugfix)/([0-9]+)([-_/].*)?$#\2#p')
if [ -n "$TICKET" ]; then
  for f in .ai/specs/"$TICKET"-*/implement.md; do [ -f "$f" ] && { IMPL_FILE="$f"; break; }; done
else
  CHANGED_IMPL=$(git status --porcelain -- '.ai/specs/*/implement.md' 2>/dev/null | awk '{print $NF}' || true)
  if [ -n "$CHANGED_IMPL" ] && [ "$(printf '%s\n' "$CHANGED_IMPL" | wc -l | tr -d ' ')" -eq 1 ]; then
    IMPL_FILE="$CHANGED_IMPL"
  fi
fi
if [ -n "$IMPL_FILE" ] && [ -f "$IMPL_FILE" ]; then
  # Per step: in-progress always counts; blocked counts only when no reason is
  # written in the step (**Blocked:** or **Reason:** with text) — a documented
  # block is known, not abandoned.
  read -r IN_PROGRESS BLOCKED < <(awk '
    function flush() { if (st == "in-progress") ip++; if (st == "blocked" && !why) bl++ }
    /^##+ Step / { flush(); st = ""; why = 0; next }
    /\*\*Status:\*\*/ { v = $0; sub(/.*\*\*Status:\*\*[ \t]*/, "", v); split(v, w, /[ \t]/); st = w[1] }
    /\*\*(Blocked|Reason):\*\*[ \t]*[^ \t]/ { why = 1 }
    END { flush(); print ip + 0, bl + 0 }' "$IMPL_FILE" 2>/dev/null || echo "0 0")
  PLAN="$(basename "$(dirname "$IMPL_FILE")")/implement.md"
  if [ "${IN_PROGRESS:-0}" -gt 0 ]; then
    ISSUES+=("$IN_PROGRESS step(s) still in-progress in $PLAN")
  fi
  if [ "${BLOCKED:-0}" -gt 0 ]; then
    ISSUES+=("$BLOCKED step(s) blocked in $PLAN with no reason written — fix them, or add a **Blocked:** note saying why")
  fi
fi

# --- Check 3: Uncommitted changes to source files ---
DIRTY_SOURCE=$(git diff --name-only -- '*.java' '*.js' '*.scss' '*.html' '*.xml' 2>/dev/null | wc -l | tr -d ' ')
if [ "$DIRTY_SOURCE" -gt 0 ]; then
  ISSUES+=("$DIRTY_SOURCE source file(s) have uncommitted changes")
fi

# --- Check 4: Merge conflict markers ---
# Real markers start the line followed by a space ("<<<<<<< HEAD"). Anchoring keeps
# this file — whose own pattern contains the marker text — from flagging itself.
CONFLICT_FILES=$(git diff --name-only 2>/dev/null | xargs grep -lE '^(<{7}|>{7}) ' 2>/dev/null || true)
if [ -n "$CONFLICT_FILES" ]; then
  ISSUES+=("Unresolved merge conflicts in: $CONFLICT_FILES")
fi

# --- Check 5: Uncommitted config changes ---
if git diff --name-only 2>/dev/null | grep -q '.ai/config.yaml'; then
  ISSUES+=("Uncommitted changes to .ai/config.yaml — commit or revert before stopping")
fi

# --- Report ---
if [ ${#ISSUES[@]} -gt 0 ]; then
  REASON="Anti-rationalization check before stopping:\\n"
  for issue in "${ISSUES[@]}"; do
    REASON+="- $issue\\n"
  done
  REASON+="\\nAddress these items or explain why they can be skipped."

  # Same findings already blocked recently → the agent has seen them; let it stop.
  SIG=$(printf '%s' "$REASON" | cksum | cut -d' ' -f1)
  NOW=$(date +%s)
  if [ -f "$STATE_FILE" ]; then
    read -r LAST_SIG LAST_TS < "$STATE_FILE" || true
    if [ "${LAST_SIG:-}" = "$SIG" ] && [ $((NOW - ${LAST_TS:-0})) -lt "$REPEAT_WINDOW" ]; then
      rm -f "$STATE_FILE"
      exit 0
    fi
  fi
  echo "$SIG $NOW" > "$STATE_FILE" 2>/dev/null || true

  cat <<EOF
{
  "decision": "block",
  "reason": "$(echo -e "$REASON" | jq -Rs .| sed 's/^"//;s/"$//')"
}
EOF
  exit 0
fi

# All clear
rm -f "$STATE_FILE"
# Copilot CLI shows hook status from this stdout line (it has no statusMessage)
# and keeps it in the transcript, so say what happened, after the fact. Only on
# a pass: a block shows its own message. COPILOT_HOOK_DIR is set only by Copilot.
[ -n "${COPILOT_HOOK_DIR:-}" ] && printf '{"type":"progress","message":"Completion checks passed","temporary":true}\n'
exit 0

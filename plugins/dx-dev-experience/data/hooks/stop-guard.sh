#!/usr/bin/env bash
# stop-guard.sh — Anti-rationalization Stop hook
#
# Checks for skipped processes before allowing Claude to exit:
# 1. Secrets in changed files
# 2. Abandoned plan steps (pending/blocked in implement.md)
# 3. Uncommitted code changes without explanation
#
# Exit: 0 with JSON {"decision":"block","reason":"..."} to block
# Exit: 0 with no output to allow stop

set -euo pipefail

INPUT=$(cat)

# Prevent infinite loops — if we already blocked once, let Claude stop
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  exit 0
fi

CWD=$(echo "$INPUT" | jq -r '.cwd // "."')
cd "$CWD" || exit 0

# Only check if we're in a git repo
git rev-parse --git-dir > /dev/null 2>&1 || exit 0

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
      */eval/cost-report.js|*/eval/process-dlq.js|*/eval/rate-limit-report.js) continue ;;
    esac
    # Check for common secret patterns
    if grep -qEi '(aws_secret_access_key|aws_access_key_id|PRIVATE.KEY|password\s*=\s*["\x27][^"\x27]+|api[_-]?key\s*=\s*["\x27][^"\x27]+|secret\s*=\s*["\x27][^"\x27]+|token\s*=\s*["\x27][a-zA-Z0-9]{20,})' "$file" 2>/dev/null; then
      ISSUES+=("Secret pattern detected in $file")
    fi
  done <<< "$ALL_CHANGED"
fi

# --- Check 2: Abandoned plan steps ---
# Find the most recent implement.md
IMPL_FILE=$(ls -t .ai/specs/*/implement.md 2>/dev/null | head -1 || true)
if [ -n "$IMPL_FILE" ] && [ -f "$IMPL_FILE" ]; then
  PENDING=$(grep -c '\*\*Status:\*\* pending' "$IMPL_FILE" 2>/dev/null) || PENDING=0
  BLOCKED=$(grep -c '\*\*Status:\*\* blocked' "$IMPL_FILE" 2>/dev/null) || BLOCKED=0
  IN_PROGRESS=$(grep -c '\*\*Status:\*\* in-progress' "$IMPL_FILE" 2>/dev/null) || IN_PROGRESS=0

  if [ "$IN_PROGRESS" -gt 0 ]; then
    ISSUES+=("$IN_PROGRESS step(s) still in-progress in $(basename "$(dirname "$IMPL_FILE")")/implement.md")
  fi
  if [ "$BLOCKED" -gt 0 ]; then
    ISSUES+=("$BLOCKED step(s) blocked in $(basename "$(dirname "$IMPL_FILE")")/implement.md — were they intentionally skipped?")
  fi
fi

# --- Check 3: Uncommitted changes to source files ---
DIRTY_SOURCE=$(git diff --name-only -- '*.java' '*.js' '*.scss' '*.html' '*.xml' 2>/dev/null | wc -l | tr -d ' ')
if [ "$DIRTY_SOURCE" -gt 0 ]; then
  ISSUES+=("$DIRTY_SOURCE source file(s) have uncommitted changes")
fi

# --- Check 4: Merge conflict markers ---
CONFLICT_FILES=$(git diff --name-only 2>/dev/null | xargs grep -l '<<<<<<<' 2>/dev/null || true)
if [ -n "$CONFLICT_FILES" ]; then
  ISSUES+=("Unresolved merge conflicts in: $CONFLICT_FILES")
fi

# --- Check 5: Uncommitted config changes ---
if git diff --name-only 2>/dev/null | grep -q '.ai/config.yaml'; then
  ISSUES+=("Uncommitted changes to .ai/config.yaml — commit or revert before stopping")
fi

# --- Check 6: Steps still in-progress ---
LATEST_IMPL=$(find .ai/specs -name 'implement.md' -maxdepth 3 2>/dev/null | head -1)
if [ -n "$LATEST_IMPL" ]; then
  IN_PROGRESS=$(grep -c '\*\*Status:\*\* in-progress' "$LATEST_IMPL" 2>/dev/null || echo 0)
  if [ "$IN_PROGRESS" -gt 0 ]; then
    ISSUES+=("$IN_PROGRESS steps still marked in-progress in $LATEST_IMPL — should be done or blocked")
  fi
fi

# --- Report ---
if [ ${#ISSUES[@]} -gt 0 ]; then
  REASON="Anti-rationalization check before stopping:\\n"
  for issue in "${ISSUES[@]}"; do
    REASON+="- $issue\\n"
  done
  REASON+="\\nAddress these items or explain why they can be skipped."

  cat <<EOF
{
  "decision": "block",
  "reason": "$(echo -e "$REASON" | jq -Rs .| sed 's/^"//;s/"$//')"
}
EOF
  exit 0
fi

# All clear
exit 0

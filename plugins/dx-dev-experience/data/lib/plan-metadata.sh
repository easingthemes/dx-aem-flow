#!/usr/bin/env bash
# plan-metadata.sh — Extract step metadata from implement.md
#
# Outputs a compact summary for orchestrators (exe-all, dev-all)
# instead of loading the full implement.md (saves ~90% tokens).
#
# Usage: plan-metadata.sh <spec-dir>
#
# Output format:
#   Steps: 8 total, 5 pending, 2 done, 1 blocked
#   1. [done] Configure model interface
#   2. [done] Implement model class
#   3. [pending] Add template
#   4. [pending] Create config
#   ...

set -euo pipefail

SPEC_DIR="${1:-.}"
IMPL_FILE="$SPEC_DIR/implement.md"

if [ ! -f "$IMPL_FILE" ]; then
  echo "ERROR: implement.md not found in $SPEC_DIR"
  exit 1
fi

# Extract step headers and statuses
TOTAL=0
PENDING=0
DONE=0
BLOCKED=0
IN_PROGRESS=0

STEPS=()

while IFS= read -r line; do
  # Match step headers: ### Step N: Title  or  ### Step Nh: Title  or  ### Step R1: Title
  if [[ "$line" =~ ^###[[:space:]]+Step[[:space:]]+([^:]+):[[:space:]]+(.*) ]]; then
    STEP_NUM="${BASH_REMATCH[1]}"
    STEP_TITLE="${BASH_REMATCH[2]}"
    TOTAL=$((TOTAL + 1))
    CURRENT_STEP="$STEP_NUM"
    CURRENT_TITLE="$STEP_TITLE"
  fi

  # Match status lines: **Status:** pending/done/blocked/in-progress
  if [[ "$line" =~ \*\*Status:\*\*[[:space:]]+(pending|done|blocked|in-progress) ]]; then
    STATUS="${BASH_REMATCH[1]}"
    case "$STATUS" in
      pending) PENDING=$((PENDING + 1)) ;;
      done) DONE=$((DONE + 1)) ;;
      blocked) BLOCKED=$((BLOCKED + 1)) ;;
      in-progress) IN_PROGRESS=$((IN_PROGRESS + 1)) ;;
    esac
    STEPS+=("$CURRENT_STEP. [$STATUS] $CURRENT_TITLE")
  fi
done < "$IMPL_FILE"

# Output summary
echo "Steps: $TOTAL total, $PENDING pending, $DONE done, $BLOCKED blocked, $IN_PROGRESS in-progress"
echo ""
for step in "${STEPS[@]}"; do
  echo "  $step"
done

#!/usr/bin/env bash
# context-loader.sh — Auto-load spec context from git branch on session start
# Detects ticket ID from branch name (e.g., feature/ABC-123-description)
# and loads the matching .ai/specs/<id>-*/ directory as session context.
#
# Supports common branch patterns:
#   feature/ABC-123-slug, bugfix/ABC-123, ABC-123-description, users/name/ABC-123

# Profile gate — informational hook, skip in minimal mode
source "$(dirname "$0")/hook-profile.sh"
require_profile "standard" || exit 0

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
SPEC_BASE="$PROJECT_DIR/.ai/specs"

# Only run in dx-initialized projects with specs
[ ! -d "$SPEC_BASE" ] && exit 0

BRANCH=$(git -C "$PROJECT_DIR" branch --show-current 2>/dev/null)
[ -z "$BRANCH" ] && exit 0

# Extract ticket ID from branch name
# Matches patterns like: ABC-123, PROJ-4567 (uppercase letters + dash + digits)
TICKET_ID=$(echo "$BRANCH" | grep -oE '[A-Z]+-[0-9]+' | head -1)
[ -z "$TICKET_ID" ] && exit 0

# Find matching spec directory (case-insensitive prefix match)
TICKET_LOWER=$(echo "$TICKET_ID" | tr '[:upper:]' '[:lower:]')
SPEC_DIR=""
for dir in "$SPEC_BASE"/*/; do
  [ ! -d "$dir" ] && continue
  dirname=$(basename "$dir")
  dirname_lower=$(echo "$dirname" | tr '[:upper:]' '[:lower:]')
  if echo "$dirname_lower" | grep -q "^${TICKET_LOWER}"; then
    SPEC_DIR="$dir"
    break
  fi
done

[ -z "$SPEC_DIR" ] && exit 0

SLUG=$(basename "$SPEC_DIR")

# Build context summary
CONTEXT="📋 Active ticket: **$TICKET_ID** (branch: \`$BRANCH\`)\n"
CONTEXT="${CONTEXT}📁 Spec directory: \`.ai/specs/$SLUG/\`\n"

# List available spec files
FILES=""
for f in "$SPEC_DIR"/*.md; do
  [ -f "$f" ] && FILES="$FILES $(basename "$f")"
done

if [ -n "$FILES" ]; then
  CONTEXT="${CONTEXT}📄 Available:$FILES\n"
fi

# Determine workflow state (same logic as next-step.sh but output as context)
if [ -f "$SPEC_DIR/implement.md" ] && grep -q '^\- \[ \]' "$SPEC_DIR/implement.md" 2>/dev/null; then
  CONTEXT="${CONTEXT}⏭ Resume with: \`/dx-step-all $SLUG\`"
elif [ -f "$SPEC_DIR/implement.md" ] && ! grep -q '^\- \[ \]' "$SPEC_DIR/implement.md" 2>/dev/null; then
  CONTEXT="${CONTEXT}✅ All steps done. Ready for: \`/dx-pr $SLUG\`"
elif [ -f "$SPEC_DIR/explain.md" ] && [ ! -f "$SPEC_DIR/implement.md" ]; then
  CONTEXT="${CONTEXT}⏭ Requirements ready. Next: \`/dx-plan $SLUG\`"
elif [ -f "$SPEC_DIR/raw-story.md" ] && [ ! -f "$SPEC_DIR/explain.md" ]; then
  CONTEXT="${CONTEXT}⏭ Story fetched. Next: \`/dx-req $SLUG\`"
fi

echo -e "$CONTEXT" | jq -Rs '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: .}}'

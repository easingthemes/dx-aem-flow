#!/bin/bash
# SessionStart hook: suggest next skill based on spec directory state
# Reads most recent spec dir, checks which files exist, suggests next step

SPEC_BASE=".ai/specs"
if [ ! -d "$SPEC_BASE" ]; then exit 0; fi

# Find most recent spec directory
LATEST=$(ls -td "$SPEC_BASE"/*/ 2>/dev/null | head -1)
if [ -z "$LATEST" ]; then exit 0; fi

SLUG=$(basename "$LATEST")

if [ -f "$LATEST/raw-story.md" ] && [ ! -f "$LATEST/explain.md" ]; then
  echo "💡 Story fetched but not processed. Continue with: /dx-req $SLUG"
elif [ -f "$LATEST/explain.md" ] && [ ! -f "$LATEST/implement.md" ]; then
  echo "💡 Requirements ready. Next: /dx-plan $SLUG"
elif [ -f "$LATEST/implement.md" ] && grep -q "^\- \[ \]" "$LATEST/implement.md" 2>/dev/null; then
  echo "💡 Plan has pending steps. Continue with: /dx-step-all $SLUG"
elif [ -f "$LATEST/implement.md" ] && ! grep -q "^\- \[ \]" "$LATEST/implement.md" 2>/dev/null; then
  echo "💡 All steps done. Ready for: /dx-pr $SLUG"
fi

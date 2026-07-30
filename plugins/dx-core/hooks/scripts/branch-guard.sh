#!/usr/bin/env bash
# branch-guard.sh — Block commits on protected branches.
# This script is called by PreToolUse matcher: Bash(git commit*).

BRANCH=$(git branch --show-current 2>/dev/null)
if [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ] || [ "$BRANCH" = "development" ] || [ "$BRANCH" = "develop" ]; then
  echo "BLOCKED: Do not commit on $BRANCH. Create a feature/* or bugfix/* branch first." >&2
  exit 2
fi

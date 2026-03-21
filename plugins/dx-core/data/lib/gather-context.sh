#!/usr/bin/env bash
# gather-context.sh — Collect git context for commit skill
#
# Usage: gather-context.sh
# Output: key=value pairs to stdout
#   CURRENT_BRANCH=<branch name>
#   BASE_BRANCH=<base branch name>
#   GITIGNORE_STRATEGY=<matching lines or "none">

set -euo pipefail

# 1. Current branch
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "detached")
echo "CURRENT_BRANCH=${CURRENT_BRANCH}"

# 2. Base branch discovery (from git-rules.md)
git remote set-head origin --auto >/dev/null 2>&1 || true
BASE_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||' || true)

if [[ -z "$BASE_BRANCH" ]]; then
    # Probe for development/develop
    BASE_BRANCH=$(git branch -r 2>/dev/null | grep -oE 'origin/(development|develop)$' | head -1 | sed 's|origin/||' || true)
fi

if [[ -z "$BASE_BRANCH" ]]; then
    BASE_BRANCH="unknown"
fi
echo "BASE_BRANCH=${BASE_BRANCH}"

# 3. Gitignore rules for .ai/ and strategy patterns
GITIGNORE_HITS=""
if [[ -f .gitignore ]]; then
    STRATEGY=$(grep -i 'strateg' .gitignore 2>/dev/null || true)
    AI_RULES=$(grep '.ai/' .gitignore 2>/dev/null | head -10 || true)
    if [[ -n "$STRATEGY" || -n "$AI_RULES" ]]; then
        GITIGNORE_HITS="${STRATEGY}${STRATEGY:+$'\n'}${AI_RULES}"
    fi
fi
echo "GITIGNORE_RULES=${GITIGNORE_HITS:-none}"

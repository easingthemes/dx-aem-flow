#!/usr/bin/env bash
# ensure-feature-branch.sh — Ensure we are on the correct feature branch before code changes
#
# Usage: ensure-feature-branch.sh <spec-dir> [prefix]
#   e.g.: ensure-feature-branch.sh .ai/specs/2416553-enhance-starter-kid-component
#   e.g.: ensure-feature-branch.sh .ai/specs/2453532-preview-image-persists bugfix
#
# Behavior:
#   1. Protected branches (development, develop, main, master, release/*) → always create/switch
#   2. Already on feature/bugfix branch that MATCHES the ticket ID → no-op
#   3. Already on feature/bugfix branch that does NOT match → warn and create/switch
#   4. Any other branch → create/switch
#   - Saves branch name to <spec-dir>/.branch for downstream skills
#
# Output: key=value pairs to stdout
#   BRANCH=feature/<id>-<slug>
#   BRANCH_ACTION=created|existing|switched|switched-from-mismatch

set -euo pipefail

SPEC_DIR="${1:?Usage: ensure-feature-branch.sh <spec-dir>}"
SPEC_DIR="${SPEC_DIR%/}"  # strip trailing slash

PREFIX="${2:-feature}"
DIR_NAME=$(basename "$SPEC_DIR")
BRANCH="${PREFIX}/${DIR_NAME}"

CURRENT=$(git branch --show-current 2>/dev/null || echo "detached")

# Extract ticket ID from spec dir name (leading digits)
TICKET_ID=$(echo "$DIR_NAME" | grep -oE '^[0-9]+' || echo "")

# --- Gate 1: Never stay on protected branches ---
if [[ "$CURRENT" =~ ^(development|develop|main|master)$ ]] || [[ "$CURRENT" =~ ^release/ ]]; then
    # Must leave this branch — fall through to create/switch logic below
    :

# --- Gate 2: On a feature/bugfix branch — check if it matches the ticket ---
elif [[ "$CURRENT" =~ ^(feature|bugfix)/ ]]; then
    if [[ -n "$TICKET_ID" ]] && [[ "$CURRENT" == *"$TICKET_ID"* ]]; then
        # Branch contains the ticket ID — correct branch, stay here
        echo "$CURRENT" > "${SPEC_DIR}/.branch"
        echo "BRANCH=${CURRENT}"
        echo "BRANCH_ACTION=existing"
        exit 0
    fi

    # Branch does NOT contain the ticket ID — wrong branch for this ticket
    echo "WARN: Current branch '${CURRENT}' does not match ticket ${TICKET_ID}. Switching to '${BRANCH}'." >&2
    # Fall through to create/switch logic below
fi

# --- Create or switch to the correct branch ---

# Check if the target branch already exists locally — switch to it
if git show-ref --verify --quiet "refs/heads/${BRANCH}" 2>/dev/null; then
    git checkout "${BRANCH}" --quiet 2>/dev/null
    echo "$BRANCH" > "${SPEC_DIR}/.branch"
    echo "BRANCH=${BRANCH}"
    if [[ "$CURRENT" =~ ^(feature|bugfix)/ ]]; then
        echo "BRANCH_ACTION=switched-from-mismatch"
    else
        echo "BRANCH_ACTION=switched"
    fi
    exit 0
fi

# Check if it exists on the remote — create local tracking branch
if git ls-remote --heads origin "${BRANCH}" 2>/dev/null | grep -q "${BRANCH}"; then
    git checkout -b "${BRANCH}" "origin/${BRANCH}" --quiet 2>/dev/null
    echo "$BRANCH" > "${SPEC_DIR}/.branch"
    echo "BRANCH=${BRANCH}"
    echo "BRANCH_ACTION=switched"
    exit 0
fi

# Create the feature branch from current position
git checkout -b "${BRANCH}" --quiet 2>/dev/null
echo "$BRANCH" > "${SPEC_DIR}/.branch"
echo "BRANCH=${BRANCH}"
echo "BRANCH_ACTION=created"

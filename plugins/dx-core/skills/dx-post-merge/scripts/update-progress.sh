#!/usr/bin/env bash
# update-progress.sh — /dx-post-merge wrapper around shared/update-progress.sh.
# Keeps the post-merge-progress.md filename and heading; all logic lives in the
# shared script so every coordinator writes the same table shape.
#
# Usage: update-progress.sh <spec-dir> <step-name> <status> [note]
#   status: pending | in_progress | done | failed | skipped | blocked

set -euo pipefail

exec env \
  DX_PROGRESS_FILE="post-merge-progress.md" \
  DX_PROGRESS_TITLE="/dx-post-merge Progress" \
  DX_PROGRESS_LABEL="Step" \
  bash "$(dirname "${BASH_SOURCE[0]}")/../../../shared/update-progress.sh" "$@"

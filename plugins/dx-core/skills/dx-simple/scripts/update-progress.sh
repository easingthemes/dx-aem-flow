#!/usr/bin/env bash
# update-progress.sh — /dx-simple wrapper around shared/update-progress.sh.
# Keeps the simple-progress.md filename and heading; all logic lives in the
# shared script so every coordinator writes the same table shape.
#
# Usage: update-progress.sh <spec-dir> <phase-name> <status> [note]
#   status: pending | in_progress | done | failed | skipped

set -euo pipefail

exec env \
  DX_PROGRESS_FILE="simple-progress.md" \
  DX_PROGRESS_TITLE="/dx-simple Progress" \
  DX_PROGRESS_LABEL="Phase" \
  bash "$(dirname "${BASH_SOURCE[0]}")/../../../shared/update-progress.sh" "$@"

#!/usr/bin/env bash
# check-existing-reports.sh — Check which PR reports already exist locally.
#
# Usage:
#   ./check-existing-reports.sh [pr-id ...]
#
# With arguments: checks specific PR IDs
# Without arguments: lists all existing report files
#
# Output: JSON array of { "prId": N, "exists": true/false, "path": "..." }

set -euo pipefail

REPORT_DIR=".ai/pr-reviews/reports"

if [[ $# -eq 0 ]]; then
  # List all existing reports
  if [[ -d "$REPORT_DIR" ]]; then
    for f in "$REPORT_DIR"/pr-*-report.md; do
      [[ -f "$f" ]] || continue
      pr_id=$(basename "$f" | sed 's/pr-\(.*\)-report\.md/\1/')
      echo "$pr_id $f"
    done
  fi
else
  # Check specific PR IDs — output JSON
  echo "["
  first=true
  for pr_id in "$@"; do
    path="$REPORT_DIR/pr-${pr_id}-report.md"
    exists=false
    [[ -f "$path" ]] && exists=true
    $first || echo ","
    first=false
    printf '  {"prId": %s, "exists": %s, "path": "%s"}' "$pr_id" "$exists" "$path"
  done
  echo ""
  echo "]"
fi

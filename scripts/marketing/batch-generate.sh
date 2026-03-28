#!/bin/bash
# batch-generate.sh — Generate posts for all pending items in content-queue.json
# Usage: ./batch-generate.sh [--limit N]
#
# Processes pending items from docs/marketing/content-queue.json
# Generates drafts and marks items as "drafted" in the queue

set -euo pipefail

QUEUE_FILE="docs/marketing/content-queue.json"
LIMIT="${2:-5}"  # Default: process 5 items

if [ ! -f "$QUEUE_FILE" ]; then
  echo "Error: Queue file not found: $QUEUE_FILE"
  exit 1
fi

# Get pending items
PENDING=$(jq -r '.queue[] | select(.status=="pending") | .file' "$QUEUE_FILE" | head -"$LIMIT")

if [ -z "$PENDING" ]; then
  echo "No pending items in queue."
  exit 0
fi

COUNT=0
while IFS= read -r TIP_FILE; do
  COUNT=$((COUNT + 1))
  echo ""
  echo "=== [$COUNT] Processing: $TIP_FILE ==="
  bash scripts/marketing/generate-posts.sh "$TIP_FILE"

  # Mark as drafted in queue
  SLUG=$(basename "$TIP_FILE" .md)
  jq --arg file "$TIP_FILE" \
    '(.queue[] | select(.file == $file)).status = "drafted"' \
    "$QUEUE_FILE" > "${QUEUE_FILE}.tmp" && mv "${QUEUE_FILE}.tmp" "$QUEUE_FILE"

  echo "  ✓ Marked as drafted"

  # Rate limit: 1 second between API calls
  sleep 1
done <<< "$PENDING"

echo ""
echo "=== Done: $COUNT items processed ==="
echo "Review drafts in docs/marketing/drafts/"
echo "When approved, change status to 'approved' in $QUEUE_FILE"

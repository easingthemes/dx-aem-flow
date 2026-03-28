#!/bin/bash
# post-to-devto.sh — Publish a drafted article to Dev.to
# Usage: ./post-to-devto.sh <draft-slug> [--publish]
#
# Requires: DEVTO_API_KEY environment variable
# Without --publish flag, creates as draft (published: false)

set -euo pipefail

SLUG="${1:?Usage: post-to-devto.sh <draft-slug> [--publish]}"
PUBLISH="${2:-}"

if [ -z "${DEVTO_API_KEY:-}" ]; then
  echo "Error: DEVTO_API_KEY not set"
  exit 1
fi

DRAFT_FILE="docs/marketing/drafts/$SLUG/devto.md"
if [ ! -f "$DRAFT_FILE" ]; then
  echo "Error: Draft not found: $DRAFT_FILE"
  exit 1
fi

BODY=$(cat "$DRAFT_FILE")
TITLE=$(echo "$BODY" | grep '^title:' | head -1 | sed 's/^title: *//')
TAGS=$(echo "$BODY" | grep '^tags:' | head -1 | sed 's/^tags: *//')

PUBLISHED="false"
if [ "$PUBLISH" = "--publish" ]; then
  PUBLISHED="true"
  echo "Publishing to Dev.to: $TITLE"
else
  echo "Creating DRAFT on Dev.to: $TITLE"
fi

RESPONSE=$(curl -s -X POST https://dev.to/api/articles \
  -H "api-key: $DEVTO_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$(jq -n \
    --arg title "$TITLE" \
    --arg body "$BODY" \
    --argjson published "$PUBLISHED" \
    '{article: {title: $title, body_markdown: $body, published: $published, tags: ["ai","devops","opensource","productivity"]}}')")

URL=$(echo "$RESPONSE" | jq -r '.url // empty')
ERROR=$(echo "$RESPONSE" | jq -r '.error // empty')

if [ -n "$URL" ]; then
  echo "Success: $URL"
  echo "(published: $PUBLISHED)"
elif [ -n "$ERROR" ]; then
  echo "Error: $ERROR"
  echo "$RESPONSE" | jq .
  exit 1
else
  echo "Unexpected response:"
  echo "$RESPONSE" | jq .
  exit 1
fi

#!/bin/bash
# generate-posts.sh — Generate platform-specific social media posts from a tip/doc file
# Usage: ./generate-posts.sh <tip-file-path> [--post-devto]
#
# Requires: ANTHROPIC_API_KEY environment variable
# Optional:  DEVTO_API_KEY for --post-devto flag
#
# Output: docs/marketing/drafts/<slug>/linkedin.md, twitter.md, devto.md

set -euo pipefail

TIP_FILE="${1:?Usage: generate-posts.sh <tip-file-path>}"
POST_DEVTO="${2:-}"

if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
  echo "Error: ANTHROPIC_API_KEY not set"
  exit 1
fi

if [ ! -f "$TIP_FILE" ]; then
  echo "Error: File not found: $TIP_FILE"
  exit 1
fi

# Extract slug from filename
SLUG=$(basename "$TIP_FILE" .md)
DRAFT_DIR="docs/marketing/drafts/$SLUG"
mkdir -p "$DRAFT_DIR"

TIP_CONTENT=$(cat "$TIP_FILE")

# Read positioning context (first 80 lines of marketing plan)
POSITIONING=""
if [ -f "docs/marketing/MARKETING-PLAN.md" ]; then
  POSITIONING=$(head -80 docs/marketing/MARKETING-PLAN.md)
fi

# Claude API call helper
call_claude() {
  local prompt="$1"
  curl -s https://api.anthropic.com/v1/messages \
    -H "x-api-key: $ANTHROPIC_API_KEY" \
    -H "anthropic-version: 2023-06-01" \
    -H "content-type: application/json" \
    -d "$(jq -n \
      --arg model "claude-haiku-4-5-20251001" \
      --arg prompt "$prompt" \
      '{
        model: $model,
        max_tokens: 1500,
        messages: [{role: "user", content: $prompt}]
      }')" | jq -r '.content[0].text // "Error: no content returned"'
}

echo "Generating posts for: $SLUG"
echo "---"

# LinkedIn post
echo "  → LinkedIn..."
LINKEDIN_PROMPT="You are a solo developer sharing your open-source work on LinkedIn. Write a professional but authentic post (150-200 words) based on this technical content. Position it around structured enterprise-quality AI output — not raw code generation. Include a call to engagement at the end (question or opinion ask). No emojis. No hashtags in the body — add 3-5 hashtags at the very end.

Source content:
$TIP_CONTENT

Positioning context:
$POSITIONING"
call_claude "$LINKEDIN_PROMPT" > "$DRAFT_DIR/linkedin.md"

# Twitter thread
echo "  → Twitter thread..."
TWITTER_PROMPT="You are a developer sharing insights on Twitter/X. Write a thread of 5 tweets based on this technical content. Each tweet must be under 280 characters. First tweet is the hook — make it compelling. Last tweet has a soft CTA (star the repo or check docs). No emojis. Use 1-2 hashtags only on the last tweet.

Source content:
$TIP_CONTENT

Positioning context:
$POSITIONING"
call_claude "$TWITTER_PROMPT" > "$DRAFT_DIR/twitter.md"

# Dev.to article
echo "  → Dev.to article..."
DEVTO_PROMPT="You are a developer writing a technical article for Dev.to. Write a 400-600 word article based on this content. Include a brief intro, the core concept with code examples or diagrams if relevant, and a conclusion pointing to the open-source project. Use markdown formatting. Technical but accessible tone. No fluff.

Source content:
$TIP_CONTENT

Positioning context:
$POSITIONING

Output format — start with YAML frontmatter:
---
title: <article title>
published: false
tags: ai, devops, opensource, productivity
---"
call_claude "$DEVTO_PROMPT" > "$DRAFT_DIR/devto.md"

echo "---"
echo "Drafts saved to $DRAFT_DIR/"
ls -la "$DRAFT_DIR/"

# Optional: post to Dev.to as draft
if [ "$POST_DEVTO" = "--post-devto" ]; then
  if [ -z "${DEVTO_API_KEY:-}" ]; then
    echo "Warning: DEVTO_API_KEY not set, skipping Dev.to post"
  else
    echo ""
    echo "Posting to Dev.to as DRAFT..."
    DEVTO_BODY=$(cat "$DRAFT_DIR/devto.md")
    # Extract title from frontmatter
    DEVTO_TITLE=$(echo "$DEVTO_BODY" | grep '^title:' | head -1 | sed 's/^title: //')

    RESPONSE=$(curl -s -X POST https://dev.to/api/articles \
      -H "api-key: $DEVTO_API_KEY" \
      -H "Content-Type: application/json" \
      -d "$(jq -n \
        --arg title "$DEVTO_TITLE" \
        --arg body "$DEVTO_BODY" \
        '{article: {title: $title, body_markdown: $body, published: false, tags: ["ai","devops","opensource"]}}')")

    DEVTO_URL=$(echo "$RESPONSE" | jq -r '.url // "Error"')
    echo "  Dev.to draft: $DEVTO_URL"
  fi
fi

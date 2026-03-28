# Marketing Automation Strategy

**Goal:** Automate content creation and posting using AI agents, Claude Code, and free APIs.
**Budget:** ~€1/month (Claude API Haiku calls + free platform APIs + free GitHub Actions)

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                  CONTENT PIPELINE                        │
│                                                         │
│  Content Sources          AI Generation      Platforms  │
│  ┌──────────────┐    ┌──────────────────┐              │
│  │ TLDR Tips    │───→│                  │──→ LinkedIn   │
│  │ (50+ .md)    │    │  Claude API      │──→ Twitter/X  │
│  │              │    │  (Haiku ~$0.01)  │──→ Dev.to     │
│  │ Blog docs    │───→│                  │──→ Hashnode   │
│  │ (website/)   │    │  Platform-aware  │──→ Reddit     │
│  │              │    │  prompt per      │              │
│  │ Changelog    │───→│  channel         │              │
│  │ (releases)   │    └──────────────────┘              │
│  └──────────────┘            │                         │
│                              ▼                         │
│                     ┌──────────────────┐              │
│                     │ Review Queue     │              │
│                     │ (GitHub PR or    │              │
│                     │  local draft)    │              │
│                     └──────────────────┘              │
│                                                         │
│  Scheduler: GitHub Actions cron / Claude Code /schedule │
└─────────────────────────────────────────────────────────┘
```

---

## What Can Be Automated vs What Needs a Human

| Task | Automate? | How |
|------|-----------|-----|
| **Generate post drafts from docs/tips** | Yes — fully | Claude API reads tip .md → generates platform-specific post |
| **Adapt content per platform** | Yes — fully | Different prompts per platform (LinkedIn=professional, Twitter=punchy, Dev.to=technical) |
| **Post to Dev.to** | Yes — fully | Dev.to API is open, free, no approval needed |
| **Post to Twitter/X** | Yes — fully | X API free tier allows 1,500 posts/month |
| **Post to LinkedIn** | Partially | API requires OAuth app approval; manual posting may be more authentic |
| **Post to Reddit** | No — manual | Reddit aggressively detects automated posting. Stay manual. |
| **Review before posting** | Recommended | Generate as draft → human approves → auto-post |
| **Directory submissions** | One-time manual | No APIs; fill forms once |
| **Engagement (comments, replies)** | No — manual | Authentic engagement can't be automated without looking spammy |

---

## Three Automation Levels (Pick One)

### Level 1: Claude Code Interactive (€0 — Already Available)

Use Claude Code as a content generation assistant. No automation infrastructure needed.

**Workflow:**
```bash
# Generate a week's worth of posts from your TLDR tips
claude "Read the tip file at website/src/content/tips/what-is-a-skill.md
and generate: 1) a LinkedIn post (professional, 150 words),
2) a Twitter thread (5 tweets), 3) a Dev.to article intro (300 words).
Use the positioning from docs/marketing/MARKETING-PLAN.md —
structured enterprise output, not raw AI suggestions."

# Or use /cowork for batch generation
claude "/cowork Generate social media posts for all 10 priority tips
listed in docs/marketing/website-content-assets.md. Save each to
docs/marketing/drafts/<tip-name>/<platform>.md"
```

**When to use:** Right now. Zero setup. You run it when you have 15 minutes, review the output, copy-paste to platforms.

**Pro:** Full control, authentic voice, zero cost beyond your Claude subscription.
**Con:** Manual effort every time.

---

### Level 2: Scripts + Claude API (€0.50/month)

Shell scripts that call the Claude API to generate content, save drafts for review, and optionally post to platforms with APIs.

**Setup:**

```
scripts/marketing/
├── generate-posts.sh       # Reads tips → calls Claude API → saves drafts
├── post-to-devto.sh        # Publishes draft to Dev.to via API
├── post-to-twitter.sh      # Posts thread to X via API
├── post-to-linkedin.sh     # Posts to LinkedIn (if API approved)
├── config.env.example      # API keys template (NEVER commit actual keys)
└── content-queue.json      # Queue of topics/tips to process
```

**generate-posts.sh concept:**
```bash
#!/bin/bash
# Generate platform-specific posts from a TLDR tip file
TIP_FILE="$1"
TIP_CONTENT=$(cat "$TIP_FILE")
POSITIONING=$(cat docs/marketing/MARKETING-PLAN.md | head -80)

# Call Claude API (Haiku — cheapest, ~$0.01/call)
generate_post() {
  local platform="$1"
  local style="$2"

  curl -s https://api.anthropic.com/v1/messages \
    -H "x-api-key: $ANTHROPIC_API_KEY" \
    -H "anthropic-version: 2023-06-01" \
    -H "content-type: application/json" \
    -d "{
      \"model\": \"claude-haiku-4-5-20251001\",
      \"max_tokens\": 1024,
      \"messages\": [{
        \"role\": \"user\",
        \"content\": \"You are a developer sharing open-source work. Platform: ${platform}. Style: ${style}. Generate a post based on this content:\\n\\n${TIP_CONTENT}\\n\\nPositioning context:\\n${POSITIONING}\"
      }]
    }" | jq -r '.content[0].text'
}

SLUG=$(basename "$TIP_FILE" .md)
mkdir -p docs/marketing/drafts/"$SLUG"

generate_post "LinkedIn" "professional, thought-leadership, 150 words max" \
  > docs/marketing/drafts/"$SLUG"/linkedin.md

generate_post "Twitter" "punchy thread of 5 tweets, each under 280 chars" \
  > docs/marketing/drafts/"$SLUG"/twitter.md

generate_post "Dev.to" "technical blog intro, 300 words, include code examples" \
  > docs/marketing/drafts/"$SLUG"/devto.md

echo "Drafts saved to docs/marketing/drafts/$SLUG/"
```

**post-to-devto.sh concept:**
```bash
#!/bin/bash
# Publish a draft article to Dev.to
TITLE="$1"
BODY=$(cat "$2")
TAGS="$3"  # comma-separated: "ai,devops,opensource"

curl -s -X POST https://dev.to/api/articles \
  -H "api-key: $DEVTO_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"article\": {
      \"title\": \"${TITLE}\",
      \"body_markdown\": $(echo "$BODY" | jq -Rs .),
      \"published\": false,
      \"tags\": [$(echo "$TAGS" | sed 's/,/","/g' | sed 's/^/"/' | sed 's/$/"/')],
      \"canonical_url\": \"https://your-docs-site.com/tips/${SLUG}\"
    }
  }"
```

**When to use:** When you want to batch-generate a week of content in 2 minutes, review it, then post with one command.

**Pro:** Fast batch generation, repeatable, version-controlled drafts.
**Con:** Requires API key setup (~30 min one-time).

---

### Level 3: GitHub Actions Scheduled Pipeline (€0.50/month)

Fully automated: generates content on a schedule, creates a PR for review, and posts after approval.

**`.github/workflows/marketing-content.yml`:**
```yaml
name: Generate Marketing Content
on:
  schedule:
    - cron: '0 8 * * 1'  # Every Monday at 8am UTC
  workflow_dispatch:
    inputs:
      tip_file:
        description: 'Specific tip file to process (optional)'
        required: false

jobs:
  generate-drafts:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Pick next topic from queue
        id: topic
        run: |
          # Read next unprocessed tip from content queue
          NEXT=$(jq -r '.queue[] | select(.status=="pending") | .file' \
            docs/marketing/content-queue.json | head -1)
          echo "tip_file=$NEXT" >> $GITHUB_OUTPUT

      - name: Generate posts with Claude API
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
        run: |
          bash scripts/marketing/generate-posts.sh \
            "${{ steps.topic.outputs.tip_file }}"

      - name: Create PR with drafts for review
        uses: peter-evans/create-pull-request@v6
        with:
          title: "content: weekly social media drafts"
          body: |
            Auto-generated from: `${{ steps.topic.outputs.tip_file }}`

            Review the drafts in `docs/marketing/drafts/` and approve to trigger posting.
          branch: marketing/weekly-content
          commit-message: "content: generate weekly social media drafts"

  post-approved:
    # Separate workflow triggered when the draft PR is merged
    # Posts to Dev.to, Twitter/X, etc.
    if: github.event_name == 'pull_request' && github.event.action == 'closed' && github.event.pull_request.merged
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Post to Dev.to
        env:
          DEVTO_API_KEY: ${{ secrets.DEVTO_API_KEY }}
        run: bash scripts/marketing/post-to-devto.sh
      - name: Post to Twitter/X
        env:
          X_BEARER_TOKEN: ${{ secrets.X_BEARER_TOKEN }}
        run: bash scripts/marketing/post-to-twitter.sh
```

**When to use:** When you want a "set and forget" system. Content appears as PRs every Monday, you review/merge, it auto-posts.

**Pro:** Truly automated, human-in-the-loop review via PRs, full audit trail.
**Con:** More setup (~2 hours), requires platform API keys.

---

## Claude Code Native Automation (Level 4)

Claude Code itself has powerful automation features that go beyond shell scripts. These are smarter — they understand your codebase, use your CLAUDE.md context, and can chain complex multi-step tasks.

### Option A: `/loop` Command (Session-Scoped Recurring Tasks)

The `/loop` command runs a prompt on a recurring interval within your Claude Code session.

```bash
# Generate content briefs every day at your work session start
/loop 1d Read the next pending item from docs/marketing/content-queue.json, \
generate LinkedIn + Twitter + Dev.to posts, save to docs/marketing/drafts/. \
Commit to a marketing branch.

# Check content performance weekly
/loop 7d Summarize this week's marketing activity: \
what was posted, engagement metrics if available, next week's queue items.
```

**How it works:** Uses `CronCreate`/`CronDelete`/`CronList` tools internally. Each task gets a unique ID.

**Limitations:**
- Tasks die when you exit the session (session-scoped)
- Auto-expire after 3 days
- Max 50 concurrent tasks
- Disable with `CLAUDE_CODE_DISABLE_CRON=1`

**Best for:** Daily content generation during active work sessions.

### Option B: `claude -p` Headless Mode (Scriptable, Cron-Ready)

The `-p` / `--print` flag runs Claude Code non-interactively — perfect for cron jobs and CI/CD.

```bash
# One-shot content generation from crontab or GitHub Actions
claude -p "Read the next pending topic from docs/marketing/content-queue.json. \
Generate a LinkedIn post (150 words, professional), a Twitter thread (5 tweets), \
and a Dev.to article (500 words) based on the tip file. \
Save drafts to docs/marketing/drafts/<slug>/. \
Update the queue status to 'drafted'." \
  --allowedTools Read,Write,Glob,Bash \
  --output-format json \
  --bare

# In crontab (every Monday 9am):
# 0 9 * * 1 cd /path/to/dx-aem-flow && ANTHROPIC_API_KEY=sk-... claude -p "..." --bare
```

**Key flags:**

| Flag | Purpose |
|------|---------|
| `-p "prompt"` | Non-interactive mode — run, print result, exit |
| `--bare` | Skip OAuth, keychain, skill walks (recommended for scripts) |
| `--allowedTools "Read,Write,Bash"` | Whitelist tools (no permission prompts) |
| `--output-format json` | Machine-readable output for piping |
| `--max-turns 5` | Limit conversation rounds |
| `--continue` / `--resume <id>` | Multi-turn sessions (24h persistence) |
| `--append-system-prompt` | Add instructions while keeping defaults |

**Auth:** Must use `ANTHROPIC_API_KEY` env var (OAuth disabled in headless mode).

**Why this is better than raw API calls:** Claude Code in headless mode understands your entire repo — CLAUDE.md, marketing plan positioning, TLDR tips structure. Raw `curl` to the API doesn't.

### Option C: Claude Code `/schedule` (Persistent Remote Agents)

```bash
# Schedule a weekly content generation remote agent
/schedule "Every Monday at 9am, read the next pending topic from
docs/marketing/content-queue.json, generate LinkedIn + Twitter + Dev.to
posts using the TLDR tip file, and save drafts to docs/marketing/drafts/.
Commit and push to a marketing/weekly-content branch."
```

**Pro:** Persistent — survives session restarts. Smarter than scripts.
**Con:** Requires Claude Code subscription with remote agent support; consumes API credits.

### Option D: Cowork (Desktop — Non-Technical Content Work)

If using Claude Desktop with Cowork:
- **Scheduled tasks** that survive app restarts
- **38+ connectors** (Slack, Google Drive, etc.) for cross-posting
- **Computer Use** — Claude can literally open your browser, navigate to LinkedIn, and paste the post
- **Sub-agent coordination** — break "generate a week of content" into parallel tasks

```
Schedule: Every Monday at 9am
Task: "Read the content queue in my dx-aem-flow repo. Generate this week's
social media posts. Save to drafts folder. Summarize what was generated."
```

### Option E: Agent SDK (Custom Content Pipeline)

For maximum control, build a custom agent using the Claude Agent SDK:

```javascript
// scripts/marketing/content-agent.js
import { Agent } from '@anthropic-ai/claude-agent-sdk';

const agent = new Agent({
  allowedTools: ['Read', 'Write', 'Glob', 'Bash'],
  systemPrompt: `You are a content marketing assistant for dx-aem-flow.
    Read the positioning from docs/marketing/MARKETING-PLAN.md.
    Generate structured, enterprise-quality messaging — not hype.
    Output platform-specific posts to docs/marketing/drafts/.`
});

for await (const event of agent.run(
  'Process the next 3 pending items from docs/marketing/content-queue.json'
)) {
  console.log(event);
}
```

**Pro:** Full programmatic control, can integrate MCP servers, run from CI/CD.
**Con:** Most setup effort. Best for when you outgrow shell scripts.

### Option F: Agent Teams (Experimental — Parallel Research)

Multiple Claude Code sessions coordinating together:

```bash
# Enable experimental feature
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1

# One agent researches trending topics, another generates posts,
# a third reviews for brand voice consistency
```

One session acts as team lead, assigns tasks, synthesizes results. Strong for generating content across multiple topics simultaneously.

---

## Comparison: Which Automation Level to Use

| Level | Tool | Setup | Persistence | Intelligence | Cost |
|-------|------|-------|-------------|-------------|------|
| **1** | Claude Code interactive | 0 min | None (manual) | Full codebase context | €0 (subscription) |
| **2** | Shell scripts + Claude API | 30 min | Cron/manual | Prompt-only, no repo context | ~€0.15/mo |
| **3** | GitHub Actions + scripts | 2 hours | Persistent (weekly cron) | Prompt-only | ~€0.15/mo |
| **4a** | `/loop` command | 1 min | Session-scoped (3 days) | Full codebase context | €0 (subscription) |
| **4b** | `claude -p` in cron | 15 min | Persistent (system cron) | Full codebase context | Subscription or API |
| **4c** | `/schedule` remote agents | 5 min | Persistent | Full codebase context | Subscription |
| **4d** | Cowork scheduled tasks | 10 min | Persistent (Desktop) | Full context + connectors | Subscription |
| **4e** | Agent SDK | 2+ hours | Persistent (custom) | Full programmatic control | API tokens |

**Recommendation:** Start with **4a** (`/loop`) for daily use, graduate to **4b** (`claude -p` in cron) or **4c** (`/schedule`) for persistent automation. Use **Level 3** (GitHub Actions) as the production backbone for the team-visible PR-based workflow.

---

## Platform API Setup Guide

### Dev.to (5 minutes — Start Here)
1. Go to dev.to/settings/extensions
2. Generate an API key
3. Store as `DEVTO_API_KEY` in GitHub Secrets or `.env`
4. Test: `curl -H "api-key: YOUR_KEY" https://dev.to/api/articles/me`

### Twitter/X (15 minutes)
1. Go to developer.x.com, create a project + app
2. Free tier: allows posting (1,500/month)
3. Generate OAuth 1.0a keys (consumer key/secret + access token/secret)
4. Store all 4 values in GitHub Secrets
5. Use `tweepy` (Python) or `twurl` (Ruby) for OAuth-signed requests

### LinkedIn (30 minutes — May Need Approval Wait)
1. Go to linkedin.com/developers, create an app
2. Request `w_member_social` scope (posting to your profile)
3. Get OAuth 2.0 access token (expires in 60 days — needs refresh logic)
4. API is more complex than Dev.to/X; consider using Buffer free tier as a proxy instead

### Buffer as LinkedIn/X Proxy (10 minutes — Easiest Multi-Platform)
1. Free tier: 3 channels, 10 scheduled posts/month
2. Connect LinkedIn + Twitter/X accounts
3. Use Buffer API to schedule posts: `POST https://api.bufferapp.com/1/updates/create.json`
4. One API call posts to multiple platforms

---

## Content Queue System

Keep a simple JSON file tracking what to post and when:

```json
{
  "queue": [
    {
      "file": "website/src/content/tips/what-is-a-skill.md",
      "angle": "AI skills > AI prompts. Here's why.",
      "status": "pending",
      "scheduled_week": "2026-W14"
    },
    {
      "file": "website/src/content/tips/the-coordinator-pattern.md",
      "angle": "The pattern that chains AI agents like microservices",
      "status": "pending",
      "scheduled_week": "2026-W15"
    },
    {
      "file": "website/src/content/tips/agent-model-tiering-cost-vs-quality.md",
      "angle": "How to cut AI token costs 60% with model tiering",
      "status": "posted",
      "scheduled_week": "2026-W13",
      "posted_platforms": ["devto", "twitter", "linkedin"]
    }
  ]
}
```

With 50+ TLDR tips, this gives you **a year of weekly content** without repeating.

---

## Recommended Path

| Week | Action | Level |
|------|--------|-------|
| **Now** | Use Claude Code to generate first batch of posts interactively | 1 |
| **Now** | Try `/loop 1d generate content...` in your daily session | 4a |
| **Week 2** | Set up Dev.to API key, post first article with `post-to-devto.sh` | 2 |
| **Week 2** | Set up `claude -p` in a cron job for weekly content generation | 4b |
| **Week 3** | Set up X API free tier for automated tweet posting | 2 |
| **Week 4** | Set up GitHub Actions workflow as the production pipeline | 3 |
| **Month 2** | Try `/schedule` for persistent remote content agents | 4c |
| **Month 2+** | Run on autopilot — weekly PR with drafts, merge to auto-post | 3+4b |
| **When needed** | Build custom Agent SDK pipeline for advanced workflows | 4e |

---

## Cost Breakdown

| Component | Monthly Cost |
|-----------|-------------|
| Claude API (Haiku, ~12 calls/month) | ~€0.15 |
| Claude Code subscription (if using Level 4) | €0 (already paying for dev work) |
| GitHub Actions (free tier) | €0 |
| Dev.to API | €0 |
| X/Twitter API (free tier) | €0 |
| LinkedIn API | €0 |
| Buffer free tier (optional) | €0 |
| **Total** | **~€0.15/month** (or €0 if using Claude Code subscription for Level 4) |

Even at full automation, this costs less than a coffee per year. If you already have a Claude Code subscription (Max plan), Level 4 options cost nothing additional.

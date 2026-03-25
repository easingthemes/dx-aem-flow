---
title: "The Spec Directory Convention"
category: "Plugins — Full Package"
focus: "Claude Code"
tags: ["Specs","Convention","Pipeline"]
overview: "Every skill pipeline writes to .ai/specs/<ticket-id>-<slug>/. This directory is the handoff point between skills. It's inspectable (just read the files), resumable (re-run any step), and debuggable (if step 3 fails, check step 2's output). Convention over configuration at its best."
screenshot: null
week: 8
weekLabel: "Skills — Advanced"
order: 40
slackOneLiner: "🤖 Tip #40 — Every skill writes to `.ai/specs/<id>-<slug>/`. Inspectable, resumable, debuggable — file convention over data passing at its best."
keyPointsTitle: "How Specs Work"
actionItemsTitle: "Explore and Debug"
keyPoints:
  - "**The convention** — Every skill in the pipeline writes to `.ai/specs/<ticket-id>-<slug>/`. The directory grows as you progress: raw-story.md, explain.md, research.md, implement.md, share-plan.md, figma-extract.md."
  - "**Inspectable** — Want to see what the AI extracted from the ticket? Read `raw-story.md`. No log diving, no API calls. Every intermediate result is a plain text file you can read."
  - "**Resumable** — Step 3 failed? Fix the issue and re-run just step 3. It reads step 2's file, which is already there. No need to repeat the entire pipeline."
actionItems:
  - "**Debuggable** — If the plan looks wrong, check `explain.md` — maybe the requirements were misunderstood. Trace backwards through the files to find where things went off track."
  - |
    Know what each file represents
    - `raw-story.md` — fetched ticket from ADO/Jira
    - `explain.md` — dev-focused requirements
    - `research.md` — affected files and codebase analysis
    - `implement.md` — step-by-step implementation plan
    - `share-plan.md` — team-shareable summary
    - `dod.md` — definition of done checklist
  - "**Shareable** — Copy `share-plan.md` to Teams or Slack. It's a human-readable summary, not a log dump. Stakeholders can review AI output without touching dev tools."
---

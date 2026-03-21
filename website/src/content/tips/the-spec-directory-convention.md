---
title: "The Spec Directory Convention"
category: "Plugins — Full Package"
focus: "Claude Code"
tags: ["Specs","Convention","Pipeline"]
overview: "Every skill pipeline writes to .ai/specs/<ticket-id>-<slug>/. This directory is the handoff point between skills. It's inspectable (just read the files), resumable (re-run any step), and debuggable (if step 3 fails, check step 2's output). Convention over configuration at its best."
codeLabel: "Complete spec directory"
screenshot: null
week: 8
weekLabel: "Skills — Advanced"
order: 40
slackText: |
  🤖 Agentic AI Tip #40 — The Spec Directory Convention
  
  This is the architectural decision I'm most proud of: *file convention over data passing*.
  
  Every skill in our pipeline writes to:
  `.ai/specs/<ticket-id>-<slug>/`
  
  The directory grows as you progress:
  ```
  .ai/specs/12345-login-bug/
  ├── raw-story.md       ← fetched ticket
  ├── explain.md         ← dev requirements
  ├── research.md        ← affected files
  ├── implement.md       ← step-by-step plan
  ├── share-plan.md      ← team summary
  └── figma-extract.md   ← design specs
  ```
  
  *Why this works so well:*
  
  *Inspectable:* Want to see what the AI extracted from the ticket? Read `raw-story.md`. No log diving, no API calls.
  
  *Resumable:* Step 3 failed? Fix the issue and re-run just step 3. It reads step 2's file, which is already there.
  
  *Debuggable:* If the plan looks wrong, check `explain.md` — maybe the requirements were misunderstood.
  
  *Shareable:* Copy the `share-plan.md` to Teams/Slack. It's a human-readable summary, not a log dump.
  
  💡 Try it: Run a few skills on a ticket and then explore the `.ai/specs/` directory. Read each file. You'll understand the entire pipeline.
  
  #AgenticAI #Day40
---

```
.ai/specs/12345-login-bug/
├── raw-story.md       # /dx-req-fetch
├── explain.md         # /dx-req-explain
├── research.md        # /dx-req-research
├── implement.md       # /dx-plan
├── share-plan.md      # /dx-req-share
├── dod.md             # /dx-req-dod
├── figma-extract.md   # /dx-figma-extract
└── prototype/         # /dx-figma-prototype
    ├── index.html
    └── screenshot.png
```

---
title: "Bug Triage: Ticket to Root Cause"
category: "Real-World Workflows"
focus: "Claude Code"
tags: ["Bug","Triage","Visual Verification"]
overview: "Our bug flow: /dx-bug-triage fetches the bug ticket and finds the affected component in code. /dx-bug-verify opens Chrome, follows repro steps, and takes screenshots to confirm the bug. /dx-bug-fix implements the fix and verifies it works. Three skills, zero tab-switching."
screenshot: null
week: 9
weekLabel: "Agents — AI Personas"
order: 45
slackOneLiner: "🤖 Tip #45 — Bug fixing is 80% investigation — let AI triage the ticket, visually verify the bug in Chrome, then fix and re-verify."
keyPointsTitle: "The Three-Step Bug Flow"
actionItemsTitle: "When to Use Each Step"
keyPoints:
  - "**Step 1 — Triage** (/dx-bug-triage) — Fetches the bug ticket from ADO, reads repro steps and expected vs actual behavior, searches the codebase for affected components, and saves a root cause hypothesis to triage.md."
  - "**Step 2 — Verify** (/dx-bug-verify) — Opens Chrome DevTools MCP, navigates to the repro URL, follows repro steps (click, fill, navigate), takes screenshots at each step, and confirms whether the bug reproduces."
  - "**Step 3 — Fix** (/dx-bug-fix) — Reads the triage findings, implements the fix, re-runs verification in Chrome, screenshots the fixed state, and produces a before/after comparison."
  - "**Visual verification matters** — 'The hero component overlaps the nav on mobile' can't be verified by reading code. Chrome DevTools MCP makes the AI see what the user sees."
actionItems:
  - |
    **Pick the right skill for your situation**
    - /dx-bug-triage — investigation only, safe to run anytime
    - /dx-bug-verify — confirms reproduction, still read-only
    - /dx-bug-fix — implements changes, use on a feature branch
  - "**Even partial use saves time** — Pick a UI bug, run /dx-bug-triage <id>, and read the investigation output. Even if you fix it manually, the automated triage saves significant investigation time."
  - |
    **Prerequisites**
    - Chrome DevTools MCP must be configured for the visual verify and fix steps
    - Bug ticket needs repro steps and expected vs actual behavior for best results
    - Run on a feature branch when using /dx-bug-fix
---

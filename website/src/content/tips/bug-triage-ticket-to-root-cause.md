---
title: "Bug Triage: Ticket to Root Cause"
category: "Real-World Workflows"
focus: "Claude Code"
tags: ["Bug","Triage","Visual Verification"]
overview: "Our bug flow: /dx-bug-triage fetches the bug ticket and finds the affected component in code. /dx-bug-verify opens Chrome, follows repro steps, and takes screenshots to confirm the bug. /dx-bug-fix implements the fix and verifies it works. Three skills, zero tab-switching."
codeLabel: "Bug triage pipeline"
screenshot: null
week: 9
weekLabel: "Agents — AI Personas"
order: 45
slackText: |
  🤖 Agentic AI Tip #45 — Bug Triage: Ticket to Root Cause
  
  Bug fixing is 80% investigation, 20% coding. AI excels at the investigation part.
  
  *Step 1: Triage (/dx-bug-triage)*
  • Fetches the bug ticket from ADO
  • Reads repro steps, expected vs actual behavior
  • Searches codebase for affected components
  • Saves root cause hypothesis to `triage.md`
  
  *Step 2: Verify (/dx-bug-verify)*
  • Opens Chrome DevTools MCP
  • Navigates to the repro URL
  • Follows the repro steps (click, fill, navigate)
  • Takes screenshots at each step
  • Confirms: "Yes, the bug reproduces" or "Cannot reproduce"
  
  *Step 3: Fix (/dx-bug-fix)*
  • Reads the triage findings
  • Implements the fix
  • Re-runs verification in Chrome
  • Screenshots the fixed state
  • Before/after comparison
  
  *Why visual verification matters:*
  "The hero component overlaps the nav on mobile" — you can't verify this by reading code. You need to see it. Chrome DevTools MCP makes the AI see what the user sees.
  
  💡 Try it: Pick a UI bug from your backlog. Run `/dx-bug-triage <id>` and read the triage output. Even if you fix it manually, the investigation saves time.
  
  #AgenticAI #Day45
---

```
# Bug workflow:
/dx-bug-triage 54321
# → Fetches bug from ADO
# → Finds affected component
# → Saves root cause hypothesis

/dx-bug-verify
# → Opens Chrome DevTools
# → Follows repro steps
# → Screenshots the bug

/dx-bug-fix
# → Implements the fix
# → Re-verifies in Chrome
# → Screenshots the fixed state
```

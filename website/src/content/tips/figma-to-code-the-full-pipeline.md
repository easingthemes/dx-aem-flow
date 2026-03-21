---
title: "Figma-to-Code: The Full Pipeline"
category: "Real-World Workflows"
focus: "Claude Code"
tags: ["Figma","Design-to-Code","Pipeline"]
overview: "Our Figma pipeline goes: Extract (read design, capture screenshot, extract tokens) → Prototype (generate standalone HTML/CSS) → Verify (screenshot prototype, compare against Figma reference). Three skills, three agents, zero manual copying of hex values."
codeLabel: "Design-to-code"
screenshot: null
week: 9
weekLabel: "Agents — AI Personas"
order: 43
slackText: |
  🤖 Agentic AI Tip #43 — Figma-to-Code: The Full Pipeline
  
  Manually translating Figma designs into code is tedious and error-prone. Here's how we automated it.
  
  *Three-step pipeline:*
  
  *Step 1: Extract (/dx-figma-extract)*
  • Reads the Figma design via MCP
  • Captures a reference screenshot
  • Extracts design tokens (colors, spacing, typography)
  • Saves everything to `figma-extract.md`
  
  *Step 2: Prototype (/dx-figma-prototype)*
  • Reads the extraction data
  • Discovers project CSS conventions (variables, breakpoints)
  • Generates standalone HTML/CSS prototype
  • Maps Figma tokens to existing project variables (not raw hex!)
  
  *Step 3: Verify (/dx-figma-verify)*
  • Opens the prototype in Chrome (via DevTools MCP)
  • Takes a screenshot
  • Compares against the Figma reference using vision
  • Identifies visual differences
  • Fixes them automatically and re-verifies
  
  *Key insight:* The prototype maps to your *project's* design tokens, not generic CSS. If Figma says `#36C0CF`, the prototype uses `var(--color-secondary)`. This makes the output actually usable.
  
  💡 Try it: If you have a Figma design URL, run `/dx-figma-extract <url>` and inspect the output in `.ai/specs/`.
  
  #AgenticAI #Day43
---

```
# Full Figma pipeline:
/dx-figma-extract <figma-url>
# → Reads design, extracts tokens
# → Saves figma-extract.md + screenshot

/dx-figma-prototype
# → Generates HTML/CSS prototype
# → Maps tokens to project variables

/dx-figma-verify
# → Screenshots the prototype
# → Compares against Figma reference
# → Fixes visual differences
```

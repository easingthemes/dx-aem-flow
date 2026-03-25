---
title: "Figma-to-Code: The Full Pipeline"
category: "Real-World Workflows"
focus: "Claude Code"
tags: ["Figma","Design-to-Code","Pipeline"]
overview: "Our Figma pipeline goes: Extract (read design, capture screenshot, extract tokens) → Prototype (generate standalone HTML/CSS) → Verify (screenshot prototype, compare against Figma reference). Three skills, three agents, zero manual copying of hex values."
screenshot: null
week: 9
weekLabel: "Agents — AI Personas"
order: 43
slackOneLiner: "🤖 Tip #43 — Three-step Figma pipeline: extract tokens, generate a prototype mapped to project variables, then visually verify against the original."
keyPointsTitle: "The Three-Step Pipeline"
actionItemsTitle: "Why It Works"
keyPoints:
  - "**Step 1 — Extract** (/dx-figma-extract) — Reads the Figma design via MCP, captures a reference screenshot, extracts design tokens (colors, spacing, typography), and saves everything to figma-extract.md."
  - "**Step 2 — Prototype** (/dx-figma-prototype) — Reads the extraction data, discovers project CSS conventions (variables, breakpoints), generates standalone HTML/CSS, and maps Figma tokens to existing project variables (not raw hex values)."
  - "**Step 3 — Verify** (/dx-figma-verify) — Opens the prototype in Chrome via DevTools MCP, takes a screenshot, compares against the Figma reference using vision, identifies visual differences, fixes them automatically, and re-verifies."
actionItems:
  - "**Token mapping is the key insight** — The prototype maps to your project's design tokens, not generic CSS. If Figma says #36C0CF, the prototype uses var(--color-secondary). This makes the output actually usable in production code."
  - |
    **Zero manual copying** — Three skills, three agents, no tab-switching between Figma and code
    - The entire pipeline runs from the terminal
    - Each step's output feeds the next automatically
  - |
    **Getting started**
    - Run /dx-figma-extract <figma-url> with a real Figma design URL and inspect the output in .ai/specs/
    - Ensure Chrome DevTools MCP is configured — the verify step needs it to screenshot and compare
    - Check your project's CSS variable conventions before running the prototype step — missing variable mappings fall back to raw values
---

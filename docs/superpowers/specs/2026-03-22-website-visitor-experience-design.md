---
status: approved
date: 2026-03-22
topic: Website Visitor Experience Restructure
---

# Website Visitor Experience Restructure

## Problem

The website home page dumps architecture details, 14 engineering cards, and autonomous agent grids before telling a visitor what to do. A first-time visitor has no idea how to get started. Setup and usage are split across redundant platform-specific pages. "Workflows" is a confusing nav label for what is really "how to use the system."

## Design

### 1. Home Page — Sell Then Guide

Slim down from ~467 lines to ~200-250. Structure:

1. **Hero** — One-liner: what is KAI, who is it for
2. **Value props** — 3-4 cards: problems it solves (not architecture)
3. **Get Started block** — Two prominent linked cards:
   - "Set Up Your Project" → `/setup/`
   - "Try Your First Workflow" → `/usage/` (the quickstart)
4. **Sprint lifecycle pipeline** — Keep existing "Every Phase Covered" 6-card grid
5. **Plugins overview** — Keep existing 4-plugin cards
6. **What Makes This Different** — 4-5 strongest engineering cards (teaser) + "See all →" link to Architecture
7. **Dive deeper** — Slim link grid to other sections

**Remove from home page (moved/already exists elsewhere):**
- Three-Layer Architecture diagram → already in demo page
- Autonomous Agents grid → already in architecture/automation.mdx
- Safety Controls → already in automation.mdx + costs.mdx
- Before/After table → already in demo page
- MCP Integrations detail → already in learn/mcps.mdx
- Full 14 engineering cards → move to architecture/overview.mdx
- "Beyond Anthropic's guide" → move to architecture/overview.mdx

### 2. Navigation Rename

```
Home → Setup → Usage → Reference → Architecture → Learn → Demo → Costs → Contributing
```

Rename "Workflows" → "Usage" in:
- BaseLayout.astro nav
- SidebarLayout.astro sidebar
- All internal links referencing `/workflows/`

**URL change:** `/workflows/*` → `/usage/*` (move all files from `pages/workflows/` to `pages/usage/`)

### 3. Usage Section (renamed from Workflows)

**New landing page** (`/usage/index.mdx`):

**Quickstart: Figma-to-Prototype** — top of page, the first thing users see:
- Uses the free "Flights - Free App UI Kit" Figma community file (already used in demo)
- Steps: install plugins → open Figma file → run `/dx-figma-extract` → `/dx-figma-prototype` → `/dx-figma-verify`
- Visual, no ADO/Jira ticket needed, impressive results
- Include link to the Figma community file
- Include the prototype screenshot comparison (Figma source vs generated) from demo page

**"Full Story Flow"** — below quickstart:
- For users with ADO/Jira access
- `/dx-req <id>` → `/dx-plan` → `/dx-step-all` → `/dx-pr`
- Link to detailed local workflow page

**Sidebar:** Usage (landing) + existing workflow pages (Local, ADO, AEM, Bug Flow, Figma, DoR/DoD, Accessibility)

### 4. Architecture Page — Absorb Engineering Cards

Add to `architecture/overview.mdx`:

**"Design Decisions" section** — all 14 engineering cards from home page:
- Templates for Predictive Outcome
- Hooks to Offload LLM Usage
- Subagents to Protect Context
- Direct Skill Invocation
- Explicit Tool Allowlists
- Convention-Based Discovery
- .ai/ Folder
- Config-Driven
- Three-Layer Override System
- Memory via Markdown
- Subagent Memory Isolation
- Cross-Repo Intelligence
- Model Tier Strategy
- Dual-IDE Support
- The Human Behind the Machine card
- "Beyond Anthropic's guide" comparison

### 5. Home Page — Strongest 4-5 Cards

Keep at the bottom of home page as "What Makes This Different" teaser:
1. **Config-Driven, Never Hardcoded** — most universal differentiator
2. **Memory via Markdown** — unique approach, easy to understand
3. **Direct Skill Invocation** — the architectural innovation from the recent refactor
4. **Dual-IDE Support** — practical selling point (Claude Code + Copilot CLI)
5. **Model Tier Strategy** — cost-conscious, enterprise appeal

Link: "See all design decisions → Architecture"

## Files Changed

### Moved
- `pages/workflows/*.mdx` → `pages/usage/*.mdx` (7 files)

### New
- `pages/usage/index.mdx` — Usage landing with Figma quickstart

### Modified
- `pages/index.mdx` — Slim home page
- `pages/architecture/overview.mdx` — Add design decisions section
- `layouts/BaseLayout.astro` — Nav rename + reorder
- `layouts/SidebarLayout.astro` — Sidebar rename

### Cross-references
- All internal links from `/workflows/` to `/usage/` across all pages

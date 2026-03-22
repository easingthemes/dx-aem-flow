# Website Visitor Experience Restructure — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure the website so a first-time visitor understands what KAI is, how to set it up, and can try it within 5 minutes — with a Figma quickstart that needs no ADO/Jira ticket.

**Architecture:** Move workflow pages to `/usage/`, create a usage landing page with Figma quickstart, slim the home page to sell+guide, move engineering cards to architecture.

**Tech Stack:** Astro MDX pages, Tailwind components. No build changes.

---

### Task 1: Rename workflows → usage (move files + update all references)

**Files:**
- Move: `website/src/pages/workflows/*.mdx` (7 files) → `website/src/pages/usage/*.mdx`
- Modify: `website/src/layouts/BaseLayout.astro` (nav: Workflows → Usage, path → /usage/)
- Modify: `website/src/layouts/SidebarLayout.astro` (sidebar key + all paths)
- Modify: `website/src/pages/index.mdx` (4 links from /workflows/ to /usage/)
- Modify: Each moved .mdx file (sidebar: workflows → sidebar: usage)

- [ ] **Step 1: Move the directory**

```bash
mv website/src/pages/workflows website/src/pages/usage
```

- [ ] **Step 2: Update sidebar frontmatter in all 7 moved files**

In each `.mdx` file under `website/src/pages/usage/`, change `sidebar: workflows` to `sidebar: usage`.

Files: `accessibility.mdx`, `ado.mdx`, `aem.mdx`, `bug-flow.mdx`, `dor-dod.mdx`, `figma.mdx`, `local.mdx`

- [ ] **Step 3: Update SidebarLayout.astro**

Change the sidebar key from `workflows` to `usage` and update all paths from `/workflows/` to `/usage/`:

```javascript
  usage: [
    { label: 'Getting Started', path: '/usage/' },
    { label: 'Local Workflow', path: '/usage/local/' },
    { label: 'Figma Pipeline', path: '/usage/figma/' },
    { label: 'Bug Flow', path: '/usage/bug-flow/' },
    { label: 'AEM Verification', path: '/usage/aem/' },
    { label: 'ADO Integration', path: '/usage/ado/' },
    { label: 'Accessibility', path: '/usage/accessibility/' },
    { label: 'DoR & DoD', path: '/usage/dor-dod/' },
  ],
```

- [ ] **Step 4: Update BaseLayout.astro nav**

Change `{ label: 'Workflows', path: '/workflows/local/' }` to `{ label: 'Usage', path: '/usage/' }`.

- [ ] **Step 5: Update index.mdx links**

Replace all `/workflows/` references with `/usage/` (4 occurrences: figma link ×2, local link, bug-flow link).

- [ ] **Step 6: Search for any other /workflows/ references across the entire website**

```bash
grep -rn "/workflows/" website/src/ --include="*.mdx" --include="*.astro" --include="*.ts"
```

Update any remaining references.

- [ ] **Step 7: Commit**

```bash
git add -A website/src/
git commit -m "refactor(website): rename workflows to usage, update all paths"
```

---

### Task 2: Create Usage landing page with Figma quickstart

**Files:**
- Create: `website/src/pages/usage/index.mdx`

- [ ] **Step 1: Create the usage landing page**

The page has two sections:

**Section 1: Quickstart — Figma to Prototype (no ticket needed)**

Content:
- Title: "Try It Now — Figma to Prototype in 5 Minutes"
- Explain: uses the free "Flights - Free App UI Kit" Figma community file
- Link to the community file on Figma
- Prerequisites: plugins installed, Figma desktop app open, Chrome installed
- Steps (as CommandBlock components):
  1. `/dx-figma-extract <figma-url>` — pulls design tokens and screenshots
  2. `/dx-figma-prototype` — generates HTML/CSS using project conventions
  3. `/dx-figma-verify` — opens Chrome, screenshots, compares against Figma
- Include the side-by-side screenshot comparison (Figma source vs generated prototype) — reuse the images already at `/images/figma-demo/air-tours-reference.png` and `/images/figma-demo/prototype-screenshot.png`
- HighlightBox: "Or run all three in one command: `/dx-figma-all <url>`"

**Section 2: Full Story Flow (with ADO/Jira)**

Content:
- Title: "Full Development Flow — From Ticket to PR"
- Explain: requires ADO or Jira ticket access
- Steps as a PipelineBlock:
  1. `/dx-req <id>` — fetch story, validate DoR, research codebase
  2. `/dx-plan` — generate implementation plan
  3. `/dx-step-all` — execute all steps with self-healing
  4. `/dx-pr` — create pull request
- Link to detailed local workflow page: "See the full local workflow guide →" → `/usage/local/`

**Section 3: All Workflows**

Grid of links to the other usage pages (Local, Figma, Bug Flow, AEM, ADO, Accessibility, DoR/DoD) using ContentCard components.

Use `sidebar: usage` in frontmatter. Import same components as other pages (PageHero, Section, SectionHeading, ContentCard, HighlightBox, CommandBlock, PipelineBlock).

- [ ] **Step 2: Commit**

```bash
git add website/src/pages/usage/index.mdx
git commit -m "feat(website): add usage landing page with Figma quickstart"
```

---

### Task 3: Move engineering cards to Architecture, keep 5 on home page

**Files:**
- Modify: `website/src/pages/architecture/overview.mdx` (add Design Decisions section)
- Modify: `website/src/pages/index.mdx` (slim down)

- [ ] **Step 1: Read architecture/overview.mdx to find the right insertion point**

Read the file and find the end — the new "Design Decisions" section goes at the bottom, before any closing tags.

- [ ] **Step 2: Add "Design Decisions" section to architecture/overview.mdx**

Add a new section with all 14 engineering cards from the home page (lines 361-435 of current index.mdx):
- SectionHeading with badge "Design Decisions", title "What Makes This Different"
- All 14 ContentCard components (Templates, Hooks, Subagents, Direct Skill Invocation, Tool Allowlists, Convention-Based Discovery, .ai/ Folder, Config-Driven, Override System, Memory via Markdown, Memory Isolation, Cross-Repo, Model Tier, Dual-IDE)
- The "Human Behind the Machine" card
- The "Beyond Anthropic's guide" HighlightBox
- The 3 closing cards (Generic by Design, Future-Proof, Enterprise-Ready)

- [ ] **Step 3: Slim down index.mdx**

Remove from home page:
- Three-Layer Architecture section (lines 45-66) — already in demo
- "Real-World Example: From Story to Tasks" section (lines 132-150) — move to usage/ado or keep as part of sprint lifecycle
- "Real-World Example: Autonomous PR Review" section (lines 152-170) — already in architecture/automation
- "Two Modes" section (lines 193-228) — verbose, the plugin cards already show this
- "For Teams: Autonomous Agents" full grid (lines 230-271) — already in architecture/automation
- Safety Controls (lines 273-295) — already in automation + costs
- Before/After table (lines 297-325) — already in demo
- MCP Integrations detail (lines 327-352) — already in learn/mcps
- Full 14 engineering cards (lines 354-435) — moved to architecture

Replace with:
- Keep: Hero, stat counters, Figma pipeline, Sprint Lifecycle cards, Plugin overview
- Add: **"Get Started" block** — two prominent cards linking to Setup and Usage
- Add: **"What Makes This Different"** — 5 strongest cards + "See all → Architecture"
- Keep: "Dive Deeper" link grid (update links from /workflows/ to /usage/)

- [ ] **Step 4: Commit**

```bash
git add website/src/pages/index.mdx website/src/pages/architecture/overview.mdx
git commit -m "refactor(website): slim home page, move engineering cards to architecture"
```

---

### Task 4: Verify and fix all cross-references

**Files:**
- Any files with stale `/workflows/` links outside of what was caught in Task 1

- [ ] **Step 1: Full search for stale references**

```bash
grep -rn "/workflows/" website/src/ --include="*.mdx" --include="*.astro" --include="*.ts" --include="*.md"
```

Should return zero results. Fix any remaining.

- [ ] **Step 2: Check for broken sidebar references**

Verify that `sidebar: usage` works by checking that `SidebarLayout.astro` has a `usage` key.
Verify that `sidebar: workflows` appears in zero files.

```bash
grep -rn "sidebar: workflows" website/src/ --include="*.mdx"
```

Should return zero.

- [ ] **Step 3: Test the Figma community file URL**

Verify the Figma URL used in the quickstart is valid and accessible (it's a public community file).

- [ ] **Step 4: Commit any fixes**

```bash
git add -A website/src/
git commit -m "fix(website): clean up remaining stale references after restructure"
```

---

### Task 5: Push and create PR

- [ ] **Step 1: Push branch**

```bash
git push -u origin fix/setup-restructure
```

- [ ] **Step 2: Create PR**

Title: "refactor(website): restructure visitor experience — usage landing, slim home page"

Body should summarize: workflows→usage rename, Figma quickstart landing page, slimmed home page, engineering cards moved to architecture.

---

## Validation Checklist (Run After All Tasks)

- [ ] `/usage/` loads with Figma quickstart
- [ ] `/usage/local/`, `/usage/figma/`, etc. all load correctly
- [ ] `/workflows/` paths return 404 (or redirect if Astro supports it)
- [ ] Home page is noticeably shorter and has Get Started + What Makes This Different sections
- [ ] Architecture page has the full Design Decisions section
- [ ] Nav shows "Usage" not "Workflows"
- [ ] No remaining `/workflows/` references: `grep -rn "/workflows/" website/src/`
- [ ] No remaining `sidebar: workflows`: `grep -rn "sidebar: workflows" website/src/`

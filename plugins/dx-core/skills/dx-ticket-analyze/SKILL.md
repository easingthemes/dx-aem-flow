---
name: dx-ticket-analyze
description: Research an Azure DevOps/Jira ticket and find all relevant source files and assets. Use when a developer pastes an ADO URL or Jira issue key and wants to know what files are involved.
argument-hint: "[ADO URL, Jira URL, work item ID, or issue key]"
model: haiku
allowed-tools: ["read", "edit", "search", "write", "agent", "ado/*", "atlassian/*"]
---

## Defaults

Read `shared/provider-config.md` for provider detection and tool mapping.

Read `.ai/config.yaml`:
- `tracker.provider` (or `scm.provider` for backward compat) — `ado` (default) or `jira`

**If provider = ado:**
- **Organization:** `scm.org`
- **Project:** `scm.project`

**If provider = jira:**
- **Jira URL:** `jira.url`
- **Project Key:** `jira.project-key`

You receive an ADO ticket URL/ID or Jira issue key, extract all relevant info, and produce a structured developer reference showing every file and asset they need.

## 1. Parse Input

Accept any of these formats:
- Full ADO URL: `https://{org}.visualstudio.com/{project}/_workitems/edit/{id}`
- Full ADO URL: `https://dev.azure.com/{org}/{project}/_workitems/edit/{id}`
- Full Jira URL: `https://{host}/browse/{KEY-123}`
- Jira issue key: `KEY-123` (matches `/^[A-Z]+-\d+$/`)
- Short numeric: `{id}`

Extract:
- **Work Item ID** — numeric ID from ADO URL
- **Issue Key** — from Jira URL or key format
- **Project** — from URL path if present. Default: read from `.ai/config.yaml` `scm.project` (ADO) or `jira.project-key` (Jira)

If the argument is purely numeric, check `tracker.provider` to determine if it's an ADO ID or a Jira issue number (prepend project key).

If no argument provided, ask the user for the ADO URL, Jira URL, or ticket ID.

## 2. Fetch Ticket

Use ADO MCP to get the work item:

```
mcp__ado__wit_get_work_item
  project: <extracted project>
  id: <work item ID>
  expand: "relations"
```

### If provider = jira

```
mcp__atlassian__jira_get_issue
  issue_key: "<issue key>"
```

Map Jira fields (see `shared/provider-config.md` Field Mapping):
- **Title** — `fields.summary`
- **State** — `fields.status.name`
- **Assigned To** — `fields.assignee.displayName`
- **Iteration Path** — `fields.sprint.name`
- **Tags** — `fields.labels[]`
- **Parent** — `fields.parent.key` and `fields.parent.fields.summary`
- **Children** — fetch via `mcp__atlassian__jira_search` with JQL `parent = <issue_key>`
- **Issue links** — from the response's `fields.issuelinks[]` (replaces ADO relations)

Extract:
- **Title** and **State**
- **Scope tags** from title — `[FE]`, `[BE]`, `[Authoring]`
- **Component names** — from title and description
- **Design links** — from description fields (e.g., Figma URLs)
- **Parent work item** — from relations (ADO) or `fields.parent` (Jira), fetch title only
- **Child work items** — from relations (ADO) or JQL search (Jira), fetch titles only
- **Assigned To**, **Iteration Path**, **Tags**

## 3. Identify Components & Detect Market Scope

From the ticket title, description, and acceptance criteria, identify:
- Component names referenced
- Related components mentioned

### Market Scope Detection (conditional — if `.ai/project/project.yaml` exists)

Detect market scope using 4 signals:
1. **Iteration Path** — extract team/market from ADO path
2. **Area Path** — extract brand/market from area
3. **Tags** — look for market codes or brand names
4. **Component resource type prefix** — read `platforms[].resource-type-prefix` from project.yaml to detect platform

Parse AEM paths in acceptance criteria (e.g., `/content/mybrand/ca/`) to detect brand and market.

Resolve detected signals against `project.yaml` → `brands[].markets[]` to get canonical market codes.

Fallback: if market cannot be determined, proceed using `aem.active-markets` from config.yaml and note uncertainty.

## 4. Search Local Docs First (MANDATORY)

Before any MCP search, check local project docs for each component:

1. Search `.ai/project/component-index.md` (or `.ai/component-index.md`) — confirms platform, availability
2. Search `.ai/project/component-index-project.md` — enriched catalog with FE, source links, dialog fields
3. Search `.ai/project/features.md` (or `.ai/features.md`) — feature context
4. Search `.ai/project/architecture.md` (or `.ai/reference.md`) — architecture patterns

Use a `dx-doc-searcher` agent for this step (if available), otherwise search inline with Grep/Glob.

## 5. Resolve Source Files

For each component identified, search the codebase for all source files:
- Backend files (models, services, controllers, tests)
- Frontend files (templates, styles, scripts)
- Configuration files (dialogs, XML definitions)

### With project.yaml — Parallel AEM Agent Dispatch

If `.ai/project/project.yaml` exists, dispatch 3 agents simultaneously via parallel Agent/Task tool calls:

1. **dx-doc-searcher** — search component-index, component-index-project, features.md. Return: platform, FE availability, Source Links, feature context excerpts
2. **aem-file-resolver** — resolve source files across repos. Return: file paths with ADO URLs, per-platform
3. **aem-page-finder** — find AEM pages with market-scoped paths, `primary_language_only: true`. Return: pages with QA author URLs

### Without project.yaml

If multiple components found, spawn search agents in parallel using Explore agents.

## 6. Present Results

```markdown
## Ticket: #<id> — <title>

**State:** <state> | **Assigned:** <name> | **Sprint:** <iteration>
**Tags:** <tags>
**Scope:** <FE/BE tags>
**Parent:** [#<parent-id>] <parent-title>

---

### Components Found

#### <component-name>

**Source Files**
| File | Path |
|------|------|
| Template | `path/to/template` |
| Style | `path/to/style` |
| Logic | `path/to/logic` |
| Model | `path/to/model` |
| Test | `path/to/test` |

<repeat for each component>

---

### Project Context

#### Market Scope
**Platform:** <Legacy|DXN|both>
**Markets:** <market codes>
**Brand:** <brand>

#### Source Files
| File | Repo | Purpose | Link |
|------|------|---------|------|
<from aem-file-resolver — per-platform, with ADO URLs>

#### AEM Pages
| Page | Market | Author URL |
|------|--------|-----------|
<from aem-page-finder — grouped by market>

#### Knowledge Base
<component-index excerpts>
<feature context excerpts if relevant>

---

### Design Assets
- Figma: [link](url) (or "None found in ticket")

### Acceptance Criteria (from ticket)
<bullet list of AC items, converted from HTML to markdown>

---

**Files:** <N> files across <M> repos | **Pages:** <P> AEM pages found

**Save results to a file?** (suggested: `.ai/specs/<id>-<slug>/ticket-research.md`)
```

**If no project.yaml:** Omit the Project Context section entirely. Present only the basic Components Found section.

## 7. Save (if user confirms)

If the user says yes:
1. Create directory `.ai/specs/<id>-<slug>/` if it doesn't exist
2. Write the results to `.ai/specs/<id>-<slug>/ticket-research.md`
3. Confirm with pipeline hint

If the user says no, do nothing.

After saving, check if pipeline spec artifacts already exist in that directory (`explain.md`, `research.md`, etc.):

If pipeline artifacts exist:
> Note: This spec dir already has pipeline artifacts. `/dx-req` will pick up your ticket-research.md and use the discovered file paths to accelerate its search.

If no pipeline artifacts:
> Tip: Run `/dx-req <id>` to generate the full spec pipeline. The research skill will use your ticket-research.md to skip redundant searches.

## Examples

1. `/dx-ticket-analyze 2416553` — Fetches the ADO work item, identifies the "starterkit" component from the title, searches the component index and codebase for all source files (JS, SCSS, HBS, dialog XML), finds 8 AEM pages using the component, and presents a structured reference with clickable author URLs.

2. `/dx-ticket-analyze https://dev.azure.com/myorg/MyProject/_workitems/edit/2416553` — Extracts the ID from the full URL, detects the project from the URL path, and runs the same analysis. Offers to save results to `.ai/specs/2416553-starterkit-pods/ticket-research.md`.

3. `/dx-ticket-analyze 2435084` (with project.yaml) — Detects market scope from the iteration path ("DE Team"), resolves files across 2 repos via aem-file-resolver, finds 12 pages via aem-page-finder scoped to the German market, and includes platform-specific source links.

## Troubleshooting

- **"Component not found in component index"**
  **Cause:** The component mentioned in the ticket is not indexed, or the ticket uses a different name than the component folder.
  **Fix:** Try alternative names (e.g., "product listing" vs "productlisting"). Run `/aem-refresh` to update the component index if it's stale.

- **No source files found for a component**
  **Cause:** The component exists only in a sibling repo (e.g., backend in a separate AEM repo, frontend in the current repo).
  **Fix:** Check the "Cross-Repo Scope" section. If project.yaml is configured with multiple repos, the skill searches across all of them.

- **Market scope detection is wrong**
  **Cause:** The ticket's iteration path or tags don't clearly indicate the market, or the project.yaml brand/market mapping is incomplete.
  **Fix:** The skill falls back to `aem.active-markets` from config.yaml and notes the uncertainty. Verify the market manually and pass it as context to downstream skills.

## Rules

- **Docs first, MCP second** — always search local docs before ADO code search
- **Parallel agents** — spawn file search agents in parallel for speed
- **No implementation advice** — this skill finds files, it doesn't plan changes
- **Ask to save** — always ask before writing files
- **Handle missing data gracefully** — if a component has no implementation found, say so
- **Extract project from URL** — parse the project from the URL when available. When given a bare ID, read from `.ai/config.yaml`
- **Pipeline compatible** — ticket-research.md is designed to feed into downstream research skills. Use consistent structured headings for components, source files, design assets, and acceptance criteria so downstream skills can parse the data reliably.
- **Project Context is conditional** — only add the Project Context section when `.ai/project/project.yaml` exists. Without it, Steps 3-5 AEM enrichment is skipped entirely.
- **Every seed data file is optional** — missing files = reduced coverage, not an error

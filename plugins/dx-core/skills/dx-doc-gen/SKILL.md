---
name: dx-doc-gen
description: "Generate the story's wiki page — what changed, screenshots, QA URLs, how to test, demo script — and post it to ADO Wiki or Confluence. Works from spec files, or retroactively from the story and its PRs. Step 2 of /dx-post-merge."
argument-hint: "[ADO Work Item ID (optional — uses most recent if omitted)]"
allowed-tools: ["read", "edit", "search", "write", "agent", "ado/*", "atlassian/*"]
---

You generate the story's wiki page: what was built and why, the demo page and screenshots, how to test it, and how to present it in the demo call. In pipeline/wiki mode, it posts to the correct sprint subfolder in the ADO wiki or Confluence (depending on `tracker.provider`).

Inputs are optional and read only if present. The demo page and screenshots come from `/aem-demo-page` (`demo/demo-page.md`); without it the page has no QA/Authoring sections. Nothing written after this skill (`qa-handoff.md`) is read here.

## 1. Locate the Spec Directory

Accept a numeric ID or a work item URL (`…/_workitems/edit/<id>`).

```bash
SPEC_DIR=$(bash .ai/lib/dx-common.sh find-spec-dir <work-item-id-if-provided>)
```

If the script exits with error and an ID was given → **retro mode** (section 2r). With no ID at all, ask the user for it.

As soon as the ID is known (given, or taken from the spec dir name), start the run (see [Run Result](#run-result)):

```bash
bash "${CLAUDE_PLUGIN_ROOT}/data/lib/run-result.sh" --start --skill dx-doc-gen --id <id>
```

Read `.ai/config.yaml` for:
- `tracker.provider` — `ado` (default) or `jira`
- `scm.org` — ADO org URL
- `scm.project` — ADO project name
- `scm.wiki-id` — ADO wiki identifier (if configured)
- `scm.wiki-project` — project that owns the wiki (may differ from `scm.project`)
- `scm.wiki-doc-root` — root wiki path for technical documentation
- `confluence.space-key` — Confluence space key (if provider = jira)
- `confluence.doc-root` — parent page title for generated docs (if provider = jira)

## 2. Read Source Files

Read these files from `$SPEC_DIR` (all optional — generate from what's available):

- `raw-story.md` — original story for title, ID, acceptance criteria, iteration path
- `explain.md` — distilled developer requirements
- `share-plan.md` — non-technical summary
- `implement.md` — step-by-step plan with status
- `research.md` — codebase context and patterns found
- `.sprint` — sprint name (e.g., `Sprint 41`) saved by `/dx-req` (Phase 1)
- `.branch` — feature branch name
- `.pr` — PR number and URL (if PR was created)
- `demo/demo-page.md` — demo page, configured field values, screenshots with attachment URLs (produced by `/aem-demo-page`)
- `figma-extract.md` — Figma design data (produced by `/dx-figma-extract`)
- `aem-fe-verify.md` — FE verification verdict (produced by `/aem-fe-verify`)

If none of the story files exist (`raw-story.md`, `explain.md`, `share-plan.md`, `implement.md`, `research.md`), switch to **retro mode** (section 2r).

## 2r. Retro mode — no spec files

For a story finished without dx spec files. Discover the content from the work item and its PRs, then continue at section 3 with the same templates.

1. **Fetch the work item** — `mcp__ado__wit_work_item` (`action: "get"`, `expand: "Relations"`); Jira: `mcp__atlassian__jira_get_issue`. Take title, type, state, description, acceptance criteria, iteration path (sprint = last segment, `Sprint41` → `Sprint 41`). Not found → print the error, write the run result (`--status failed --next "/dx-doc-gen <id>" --metric fail_at=fetch`) and STOP.
2. **Linked PRs** — relations with `vstfs:///Git/PullRequestId/{projectId}%2F{repoId}%2F{prId}`. Fetch each with `mcp__ado__repo_pull_request` (`action: "get"`). Keep only `completed` PRs in `scm.repo-id` (or a repo in `repos:`). Collect title, description, source/target branch, merge commit. None → warn `No linked PRs found — documentation is based on the story only.`
3. **Changed files** — `git show --name-only --format= -m --first-parent <merge-commit>` when the commit is local; else keywords from the title and PR descriptions with Grep/Glob; else file paths named in the PR descriptions. Group by area (FE/BE/Config).
4. **Spec dir** — `DIR_NAME=$(bash .ai/lib/dx-common.sh slugify <id> "<title>")`, `mkdir -p ".ai/specs/$DIR_NAME/docs"`, write the sprint to `.sprint` and the first PR to `.pr`.

In retro mode, write only what the story and PRs show: no Architecture Decisions or API Changes unless a PR description states them.

## 3. Determine Sprint

Read `$SPEC_DIR/.sprint` for the sprint name. If the file doesn't exist, try to extract it from the Iteration Path in `raw-story.md`. If still unknown, set sprint to `Unknown` and warn the user.

## 4. Check Existing Output

1. Check if `docs/wiki-page.md` exists in the spec directory
2. If it exists, read its content
3. Check staleness: does the ADO ID match? Has `implement.md` or `demo/demo-page.md` changed since generation?
4. If current → print `docs/wiki-page.md already up to date — skipping`, write the run result (`--status done --summary "wiki-page.md already up to date — nothing to do"`, `--wiki` from `.wiki-url` if present) and STOP
5. If outdated → print `docs/wiki-page.md exists but is outdated — regenerating`
6. If not found → continue normally

## 5. Generate wiki-page.md

Create `$SPEC_DIR/docs/` directory if it doesn't exist.

### 5a. Template — AEM demo walkthrough

Use `.ai/templates/wiki/wiki-page-aem.md.template` when `demo/demo-page.md` exists, or this is an AEM project (`aem.author-url-qa` configured) in retro mode. The template is a **demo walkthrough** — sections follow the order of a demo call (story → design → what changed → QA pages → authoring → frontend → how to test → demo script).

**Which environment:** use `environments.qa` from `demo-page.md`. If only `environments.local` exists, use it for page paths and field values (the JCR path is the same on QA), build the QA URLs from `aem.author-url-qa`, and add under QA Verification: `⚠️ QA demo page not set up yet — run /aem-demo-page <id> after the QA deploy.`

**Authoring section is the core of the demo page.** Every action MUST have a clickable link — the AEM Author Edit URL, the real component name, and a field table. Field values come from `demo-page.md` (`components[].fields`). Field labels and what each field does come from the component's dialog in the repo (`<component>/_cq_dialog/.content.xml`: `fieldLabel`, `fieldDescription`, show/hide wiring) — written for an author, no JCR property names or code paths. Only NEW or CHANGED fields when the dialog changed; the fields to set for the demo otherwise.

**Screenshots — attachment URLs:** use the `url` of each `environments.qa.screenshots[]` entry (work-item attachments uploaded by `/aem-demo-page`): `kind: dialog` under Authoring, `kind: preview` under Frontend Preview. A screenshot without a `url` (local only, or upload failed) is not linked — write `Screenshot not uploaded — re-run /aem-demo-page <id>.` instead. Figma reference images and `aem-fe-verify` screenshots are local files: in Design Reference link the Figma URL from `figma-extract.md`, and in Figma Comparison give the `aem-fe-verify.md` verdict as text — no local image paths.

**Conditional sections:** The template contains sections guarded by comments (e.g., "ONLY if figma-extract.md exists"). Check for each source file and OMIT the entire section (heading included) if the source data is not available. Specifically:
- **Design Reference** — only if `figma-extract.md` or `prototype/` dir exists
- **Figma Comparison** — only if BOTH Figma reference AND rendered screenshot exist

**QA Verification (MANDATORY for AEM projects):** AEM pages are the deliverable — this is what the customer wants to see. Every AEM wiki page MUST include QA page URLs. Read QA URLs from `.ai/config.yaml` (`aem.author-url-qa`, `aem.publish-url-qa`).

Two views are required per page:
- **Author Edit:** `<author-url-qa>/editor.html<page>.html` — dialog/config view for authors
- **Author Preview:** `<author-url-qa><page>.html?wcmmode=disabled` — FE rendering without editor chrome, for demo

**Page selection rule:** New demo pages are ONLY for new components. For updates to existing components (enhancements, a11y fixes), the page should be the best representative existing page that already has the component — not a newly created demo page.

Take the demo page path from `demo/demo-page.md` (`environments.qa.pages`, else `environments.local.pages`). Without `demo-page.md` (retro mode, or `/aem-demo-page` not run), name the affected components and flag: `⚠️ No demo page yet — run /aem-demo-page <id>.`

**Multi-component coverage:** If several components are affected, determine whether they can all be demoed on one page or need separate pages. Provide a QA URL table for each page needed. If a new component was created but not yet on a QA page, flag: `⚠️ Component <name> needs to be added to a QA page and configured for demo.`

### 5-test. How to test and Demo script (both templates)

**How to test** — numbered steps a tester can follow without reading code. Derive one or more steps per acceptance criterion (from `raw-story.md` / `explain.md`, or the work item in retro mode). Each step: where to go (QA Preview or Author Edit URL from `demo-page.md` when there is one), what to do, expected result.

```markdown
## How to test

| # | Open | Do | Expected |
|---|------|----|----------|
| 1 | [Preview](<author-preview>) | Scroll to the hero | Dark variant: white text on dark background |
| 2 | [Edit](<author-edit>) | Open the hero dialog, set Variant = Light | Preview shows dark text on light background |
```

**Demo script** (AEM template only, when `demo-page.md` exists) — the click order for presenting the story in the demo call, 4–8 short steps: open the Edit URL → open the dialog (point at the new/changed fields) → change the listed fields → open Preview → point out the change (compare with Figma if there is a design reference). Use the real component name and the values from `demo-page.md`.

Neither section repeats the acceptance criteria text — the linked ticket has it.

### 5-dev. Planned vs Built (both templates)

If `implement.md` has any `**Deviation:**` lines (written by `/dx-step` when the implementation departed from the plan), add a `## Planned vs Built` section before `## Related`:

```markdown
## Planned vs Built

| Step | Planned | Built instead — why |
|------|---------|---------------------|
| 2 — <step title> | <one-line summary of the step's **What**> | <the Deviation line> |
```

OMIT the section when there are no deviations. If `docs/plan-wiki.md` exists (plan prepared with `/dx-prep`), add one line under the table: `Prepared plan: <URL from .plan-wiki-url>` (omit when the file is missing).

### 5b. Template — Standard (non-AEM)

Otherwise, read `.ai/templates/wiki/wiki-page.md.template` and follow that structure exactly. This standard template has a `## Usage` section instead of Authoring/Frontend, and the How to test section from 5-test.

## 6. Wiki Mode — Post to Wiki

If the environment variable `PIPELINE_MODE` is set to `true`, OR if the user explicitly asks to post to wiki:

Read `tracker.provider` from `.ai/config.yaml` (default: `ado`).
- If `ado` → follow **Section 6a** (ADO Wiki posting).
- If `jira` → follow **Section 6b** (Confluence posting).

### 6a. ADO Wiki Mode

1. Read `scm.wiki-id`, `scm.wiki-project`, and `scm.wiki-doc-root` from `.ai/config.yaml`
2. If `scm.wiki-id` is not configured, print: `Wiki ID not configured — wiki page saved locally only.` and STOP wiki posting.
3. **Find the story page** — follow `../../shared/wiki-story-page.md` (ADO section) with `WIKI_ROOT = <scm.wiki-doc-root>`, `SPRINT = <sprint name from .sprint>` (`Unsorted` when unknown) and the spec dir's `<id>`/`<slug>`. It reuses the story's existing page whatever its name format (`<id>-<slug>`, `<id> <title>`, `<id>: <title>`, several ids), looks in other sprint folders for a carried-over story, and only falls back to `${WIKI_ROOT}/${SPRINT}/<id>-<slug>`. Set `WIKI_PATH` to the resulting `STORY_PATH`.

4. **Merge, don't overwrite.** The story page may be hand-written by the team. Get its current content (`mcp__ado__wiki` `action: "get_page_content"`, keep the version/ETag) and build the new content:
   - Page is new, empty, or the `/dx-prep` placeholder (contains `Technical documentation follows after implementation`) → the generated doc, wrapped in the markers below.
   - Page contains the markers → replace only the text between them.
   - Otherwise (team content, no markers) → keep the existing content and append `---` plus the generated doc wrapped in the markers.
   ```
   <!-- dx-doc-gen:start -->
   <contents of docs/wiki-page.md>
   <!-- dx-doc-gen:end -->
   ```
   ADO wiki Markdown hides HTML comments, so the markers are invisible on the page.

5. **Create or update the wiki page:**

```
mcp__ado__wiki_upsert_page
  wikiIdentifier: <scm.wiki-id>
  project: <scm.wiki-project>
  path: "${WIKI_PATH}"
  content: <merged content from step 4>
  etag: <version from step 4, when the page existed>
```

6. Write the page URL to `$SPEC_DIR/.wiki-url` (`<scm.org>/<scm.wiki-project>/_wiki/wikis/<scm.wiki-id>?pagePath=<url-encoded WIKI_PATH>`) — `/dx-qa-handoff` links it.
7. Print: `Wiki page created/updated at ${WIKI_PATH}` (add `— story page carried over from <sprint>` when the resolver returned `SCOPE=other-sprint`).

If the sprint is `Unknown` and no page matched anywhere, the new page lands under `${WIKI_ROOT}/Unsorted/` — warn: `Sprint unknown — page placed under Unsorted. Move it manually after confirming the sprint.`

### 6b. Confluence Mode

1. Read `confluence.space-key` and `confluence.doc-root` from `.ai/config.yaml`.
2. If `confluence.space-key` is not configured, print: `Confluence space key not configured — wiki page saved locally only.` and STOP wiki posting.

3. **Find the doc root parent page:**

```
mcp__atlassian__confluence_search
  cql: "title = '<confluence.doc-root>' AND space = '<confluence.space-key>'"
```

Extract `page_id` from results → `DOC_ROOT_ID`. If not found, print: `Doc root page "<confluence.doc-root>" not found in space <space-key> — create it in Confluence first.`, write the run result (`--status blocked --next "create the doc root page, then /dx-doc-gen <id>" --metric fail_at=wiki`) and STOP.

4. **Find or create the sprint subfolder page:**

```
SPRINT = <sprint name from .sprint>   # e.g., Sprint 42

mcp__atlassian__confluence_search
  cql: "title = '<SPRINT>' AND ancestor = '<DOC_ROOT_ID>' AND space = '<confluence.space-key>'"
```

If not found, create it:

```
mcp__atlassian__confluence_create_page
  space_key: "<confluence.space-key>"
  title: "<SPRINT>"
  body: "<h1><SPRINT></h1><p>Technical documentation for stories in <SPRINT>.</p>"
  parent_id: "<DOC_ROOT_ID>"
```

Save the sprint page ID → `SPRINT_PAGE_ID`.

5. **Find the doc page** — follow `../../shared/wiki-story-page.md` (Confluence section): it reuses the story's existing page whatever its title format, including one under another sprint page (carried over), and only falls back to creating `<id>-<slug>` under `SPRINT_PAGE_ID`. `PAGE_TITLE` = the matched page's title (unchanged), or `<id>-<slug>` for a new page. For an existing page apply the same **merge, don't overwrite** rule as ADO step 4 — Confluence shows HTML comments, so the boundary is a heading instead of markers: `<h2>Generated documentation (dx-doc-gen)</h2>`. Replace from that heading to the end of the page; if it is missing, append it and the generated doc after the existing content. A new page or the `/dx-prep` placeholder is replaced whole.

6. **Content format conversion (CRITICAL):**

Skills generate markdown (same as for ADO wiki). Before posting to Confluence, test if the MCP server accepts markdown directly by making a test call. If the page renders correctly with raw markdown, use markdown. If it renders as raw text, convert markdown to basic Confluence storage format (XHTML):
- `# Heading` → `<h1>Heading</h1>`
- `**bold**` → `<strong>bold</strong>`
- `*italic*` → `<em>italic</em>`
- `- item` → `<ul><li>item</li></ul>`
- `1. item` → `<ol><li>item</li></ol>`
- `` `code` `` → `<code>code</code>`
- Code blocks → `<ac:structured-macro ac:name="code"><ac:plain-text-body><![CDATA[...]]></ac:plain-text-body></ac:structured-macro>`
- Tables → `<table><tr><th>...</th></tr><tr><td>...</td></tr></table>`
- Links `[text](url)` → `<a href="url">text</a>`
- Paragraphs → `<p>...</p>`

7a. **If page doesn't exist — create:**

```
mcp__atlassian__confluence_create_page
  space_key: "<confluence.space-key>"
  title: "<PAGE_TITLE>"
  body: "<converted content>"
  parent_id: "<SPRINT_PAGE_ID>"
```

7b. **If page exists — update:**

```
mcp__atlassian__confluence_update_page
  page_id: "<existing page ID>"
  title: "<PAGE_TITLE>"
  body: "<converted content>"
  version_number: <current version + 1>
```

8. Write the page URL (from the create/update result) to `$SPEC_DIR/.wiki-url`.
9. Print: `Wiki page created/updated in Confluence: <confluence.space-key> > <SPRINT> > <PAGE_TITLE>`

If the sprint is `Unknown`, create the page under `DOC_ROOT_ID` directly with an "Unsorted" parent page (create if needed), and warn: `Sprint unknown — page placed under Unsorted. Move it manually after confirming the sprint.`

## 7. Present Summary

```markdown
## dx-doc-gen complete

**<Title>** (ADO #<id>)
- Sprint: <sprint name>
- Output: `<spec-dir>/docs/wiki-page.md`
- Sections: <list of included sections>
- Source: spec files / retro (story + <N> PRs)
- Template: AEM (demo walkthrough) / Standard (technical doc)
- Screenshots: <count> linked (attachments) / <count> not uploaded
- QA URLs: Yes (from demo-page.md) / local page only / No demo page
- Word count: <N> words
- Mode: Local / Wiki (posted to <wiki path>)
```

Then write the run result as the last action (see [Run Result](#run-result)).

## Run Result

Machine-readable outcome for a tool that started this skill (dashboard, script, hub), per `../../shared/run-result.md`. Never fail the run because of it.

**Start** — once, as soon as the ID is known (section 1). **End** — last action of **every** exit, after the final message:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/data/lib/run-result.sh" --skill dx-doc-gen --id <id> --status <done|blocked|failed> \
  --wiki "<page URL from .wiki-url, if posted>" --next "<next step or none>" \
  --summary "<one line, e.g. wiki page posted (AEM template, retro)>" \
  --metric screenshots=<n linked> --metric posted=<true|false> --metric retro=<true|false> [--metric fail_at=<step>]
```

| Exit | `--status` | `--next` |
|------|------------|----------|
| Page generated (posted, or local only — say which in `--summary`, e.g. `saved locally only (wiki id not configured)`) | `done` | `/dx-qa-handoff <id>`, or `none` |
| `docs/wiki-page.md` already up to date — nothing to do | `done` | `none` |
| Confluence doc root page missing | `blocked` | `create the doc root page, then /dx-doc-gen <id>` |
| Work item not found (retro), wiki/Confluence write failed | `failed` | `/dx-doc-gen <id>` |

Under `/dx-post-merge` or `/dx-req-dod` this is its own file (`dx-doc-gen-<id>.json`).

## Examples

1. `/dx-doc-gen 2416553` — Reads spec files, generates `docs/wiki-page.md` with Summary, What Changed and Why, Usage, Files Changed. Standard template.

2. `/dx-doc-gen 2416553` after `/aem-demo-page 2416553` — reads `demo/demo-page.md`. AEM template: Summary → Design Reference → What Changed and Why → QA Verification → Authoring (Edit URL + component + field table + dialog screenshot) → Frontend Preview → How to test → Demo script → Files Changed. Screenshots are the work-item attachment URLs.

3. `/dx-doc-gen 2416553` (pipeline mode) — `PIPELINE_MODE=true` triggers wiki posting. Creates the sprint subfolder (`Sprint 42`) if needed, posts the page, writes `.wiki-url`.

4. `/dx-doc-gen 2357516` for a story done without dx — no spec dir → retro mode: fetches the story and its completed PRs, creates the spec dir, writes the page from what they show.

## Troubleshooting

- **"No spec files found — nothing to generate from"**
  **Cause:** The spec directory exists but contains no recognized files (explain.md, implement.md, etc.).
  **Fix:** Pass the work item ID — with an ID and no story files the skill switches to retro mode and reads the work item and its PRs.

- **"docs/wiki-page.md already up to date — skipping"**
  **Cause:** The wiki page was already generated and the source files haven't changed.
  **Fix:** Delete the existing `docs/wiki-page.md` and re-run, or modify one of the source spec files to trigger regeneration.

- **Wiki posting fails with "Wiki ID not configured"**
  **Cause:** `scm.wiki-id` is not set in `.ai/config.yaml`.
  **Fix:** Add `scm.wiki-id`, `scm.wiki-project`, and `scm.wiki-doc-root` to your config. These can be found in ADO under Project Settings > Wiki.

## Rules

- **Read config, never hardcode** — ADO URLs, project names, wiki paths from config.yaml
- **Skip empty sections** — never write "N/A" or "None" filler. Omit the section entirely.
- **Tech lead audience** — more detailed than share-plan.md, less raw than explain.md. Include actual techniques and patterns used.
- **No acceptance criteria** — the linked ADO ticket has the full AC. The wiki page links to the ticket, no need to duplicate.
- **Idempotent** — check existing output before regenerating
- **Read forward only** — inputs come from earlier steps (`demo/demo-page.md`); never read `qa-handoff.md`, which is written after this skill
- **Degrade gracefully** — generate from whatever spec files are available. More files = richer output, but even raw-story.md alone is enough for a basic page.
- **Sprint from .sprint file** — do NOT hardcode sprint numbers. Always read from the file or fall back to iteration path parsing.
- **Wiki path encoding** — ADO wiki uses spaces in paths. Do NOT URL-encode the path when passing to MCP tools.
- **No time estimates** — never include estimates or durations
- **demo-page.md drives template** — if `demo/demo-page.md` exists (or AEM retro mode), use the AEM demo walkthrough template; otherwise the standard template with Usage section
- **Attachment URLs for screenshots** — link only the work-item attachment URLs from `demo-page.md`; never repo-relative paths (the wiki is a different repo and cannot resolve them)
- **Omit empty conditional sections** — Design Reference, Figma Comparison are conditional. If source data is missing, omit the entire section including heading. Never write "N/A" placeholders.
- **QA pages are mandatory** — for AEM projects, QA Author Edit + Preview URLs are required. This is the deliverable. Preview uses `wcmmode=disabled` for FE demo.
- **Multi-component = multi-page** — if several components are affected and need different pages, provide QA URL tables for each page
- **Don't list every file** — group by area (FE/BE/Config) with short descriptions. The PR has the diff; the wiki explains what and why.
- **Demo walkthrough order** — AEM template sections follow a demo presentation flow: story → design → implementation → QA → authoring (page URL + component + fields + dialog screenshot) → frontend → Figma comparison → how to test → demo script → files
- **Authoring = presenter runbook** — every action in the Authoring section MUST have a clickable AEM Author Edit URL and the real component name. The presenter should never have to search for anything — all links, component names, and field values are explicit.

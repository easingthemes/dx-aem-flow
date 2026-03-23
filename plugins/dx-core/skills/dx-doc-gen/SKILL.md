---
name: dx-doc-gen
description: Generate wiki documentation from completed spec files — architecture decisions, usage guide, API changes. Posts to ADO Wiki or Confluence depending on provider config. Use as the final step after implementation is done. Invoked automatically by /dx-agent-all Phase 7 and /dx-req-dod.
argument-hint: "[ADO Work Item ID (optional — uses most recent if omitted)]"
allowed-tools: ["read", "edit", "search", "write", "agent", "ado/*", "atlassian/*"]
---

You generate wiki-style documentation from completed spec files. The output captures what was built, why, and how to use it. In pipeline/wiki mode, it posts to the correct sprint subfolder in the ADO wiki or Confluence (depending on `tracker.provider`).

## 1. Locate the Spec Directory

```bash
SPEC_DIR=$(bash .ai/lib/dx-common.sh find-spec-dir <work-item-id-if-provided>)
```

If the script exits with error, ask the user for the work item ID.

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
- `demo/authoring-guide.md` — AEM authoring guide with screenshots (produced by `/aem-doc-gen`)
- `figma-extract.md` — Figma design data (produced by `/dx-figma-extract`)
- `aem-fe-verify.md` — FE verification verdict (produced by `/aem-fe-verify`)
- `aem-after.md` — post-deployment component state (produced by `/aem-verify`)
- `qa-handoff.md` — QA testing steps with page URLs (produced by `/aem-qa-handoff`)

If none exist (excluding authoring-guide.md), print "No spec files found — nothing to generate from" and STOP.

## 3. Determine Sprint

Read `$SPEC_DIR/.sprint` for the sprint name. If the file doesn't exist, try to extract it from the Iteration Path in `raw-story.md`. If still unknown, set sprint to `Unknown` and warn the user.

## 4. Check Existing Output

1. Check if `docs/wiki-page.md` exists in the spec directory
2. If it exists, read its content
3. Check staleness: does the ADO ID match? Has implement.md changed since generation?
4. If current → print `docs/wiki-page.md already up to date — skipping` and STOP
5. If outdated → print `docs/wiki-page.md exists but is outdated — regenerating`
6. If not found → continue normally

## 5. Generate wiki-page.md

Create `$SPEC_DIR/docs/` directory if it doesn't exist.

### 5a. Template — With Authoring Guide (AEM projects)

If `demo/authoring-guide.md` exists, read `.ai/templates/wiki/wiki-page-aem.md.template` and follow that structure exactly. The template is structured as a **demo walkthrough** — sections are ordered to match a typical demo presentation flow (story → design → implementation → QA page → dialog → frontend → Figma comparison → authoring guide).

**Screenshot references — repo-relative paths:** ADO wiki does not support binary upload via current MCP tools. All screenshot references MUST use repo-relative paths so they can be committed and linked from the ADO wiki.

Compute `<repo-relative-path>` = `.ai/specs/<id>-<slug>` (relative to repo root). Use this for all image references in the generated wiki page:
- `<repo-relative-path>/demo/dialog-<component>.png`
- `<repo-relative-path>/demo/rendered-<component>.png`
- `<repo-relative-path>/prototype/figma-reference.png`
- `<repo-relative-path>/screenshots/component-rendered.png`

**Conditional sections:** The template contains sections guarded by comments (e.g., "ONLY if figma-extract.md exists"). Check for each source file and OMIT the entire section (heading included) if the source data is not available. Specifically:
- **Design Reference** — only if `figma-extract.md` or `prototype/` dir exists
- **Figma Comparison** — only if BOTH Figma reference AND rendered screenshot exist

**QA Verification (MANDATORY for AEM projects):** AEM pages are the deliverable — this is what the customer wants to see. Every AEM wiki page MUST include QA page URLs. Read QA URLs from `.ai/config.yaml` (`aem.author-url-qa`, `aem.publish-url-qa`).

Two views are required per page:
- **Author Edit:** `<author-url-qa>/editor.html<page>.html` — dialog/config view for authors
- **Author Preview:** `<author-url-qa><page>.html?wcmmode=disabled` — FE rendering without editor chrome, for demo

Extract demo page path from (in priority order):
1. `qa-handoff.md` — QA-specific URLs
2. `demo/authoring-guide.md` — Author URL, Publisher URL
3. `aem-after.md` — Test/Demo page path

**Multi-component coverage:** If several components are affected, determine whether they can all be demoed on one page or need separate pages. Provide a QA URL table for each page needed. If a new component was created but not yet on a QA page, flag: `⚠️ Component <name> needs to be added to a QA page and configured for demo.`

### 5b. Template — Without Authoring Guide (non-AEM or authoring-guide missing)

If `demo/authoring-guide.md` does NOT exist, read `.ai/templates/wiki/wiki-page.md.template` and follow that structure exactly. This standard template includes a `## Usage` section instead of Authoring/Website.

## 6. Wiki Mode — Post to Wiki

If the environment variable `PIPELINE_MODE` is set to `true`, OR if the user explicitly asks to post to wiki:

Read `tracker.provider` from `.ai/config.yaml` (default: `ado`).
- If `ado` → follow **Section 6a** (ADO Wiki posting).
- If `jira` → follow **Section 6b** (Confluence posting).

### 6a. ADO Wiki Mode

1. Read `scm.wiki-id`, `scm.wiki-project`, and `scm.wiki-doc-root` from `.ai/config.yaml`
2. If `scm.wiki-id` is not configured, print: `Wiki ID not configured — wiki page saved locally only.` and STOP wiki posting.
3. Determine the sprint subfolder path:

```
WIKI_ROOT = <scm.wiki-doc-root>        # e.g., /My-Wiki/Technical-Documentation/Sprint-wise
SPRINT = <sprint name from .sprint>     # e.g., Sprint 42
PAGE_TITLE = <id>-<slug-from-title>     # e.g., 2357516-Enhance-PLP-Filter-Sticky
WIKI_PATH = "${WIKI_ROOT}/${SPRINT}/${PAGE_TITLE}"
```

4. **Check if the sprint subfolder exists.** Try to get the sprint page:

```
mcp__ado__wiki_get_page
  wikiIdentifier: <scm.wiki-id>
  project: <scm.wiki-project>
  path: "${WIKI_ROOT}/${SPRINT}"
```

5. **If the sprint subfolder does NOT exist** (404), create it first:

```
mcp__ado__wiki_create_or_update_page
  wikiIdentifier: <scm.wiki-id>
  project: <scm.wiki-project>
  path: "${WIKI_ROOT}/${SPRINT}"
  content: "# ${SPRINT}\n\nTechnical documentation for stories in ${SPRINT}."
```

6. **Create or update the wiki page:**

```
mcp__ado__wiki_create_or_update_page
  wikiIdentifier: <scm.wiki-id>
  project: <scm.wiki-project>
  path: "${WIKI_PATH}"
  content: <contents of docs/wiki-page.md>
```

7. Print: `Wiki page created/updated at ${WIKI_PATH}`

If the sprint is `Unknown`, post under `${WIKI_ROOT}/Unsorted/${PAGE_TITLE}` instead and warn: `Sprint unknown — page placed under Unsorted. Move it manually after confirming the sprint.`

### 6b. Confluence Mode

1. Read `confluence.space-key` and `confluence.doc-root` from `.ai/config.yaml`.
2. If `confluence.space-key` is not configured, print: `Confluence space key not configured — wiki page saved locally only.` and STOP wiki posting.

3. **Find the doc root parent page:**

```
mcp__atlassian__confluence_search
  cql: "title = '<confluence.doc-root>' AND space = '<confluence.space-key>'"
```

Extract `page_id` from results → `DOC_ROOT_ID`. If not found, print: `Doc root page "<confluence.doc-root>" not found in space <space-key> — create it in Confluence first.` and STOP.

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

5. **Check if the doc page already exists:**

```
PAGE_TITLE = <id>-<slug-from-title>   # e.g., 2357516-Enhance-PLP-Filter-Sticky

mcp__atlassian__confluence_search
  cql: "title = '<PAGE_TITLE>' AND ancestor = '<SPRINT_PAGE_ID>' AND space = '<confluence.space-key>'"
```

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

8. Print: `Wiki page created/updated in Confluence: <confluence.space-key> > <SPRINT> > <PAGE_TITLE>`

If the sprint is `Unknown`, create the page under `DOC_ROOT_ID` directly with an "Unsorted" parent page (create if needed), and warn: `Sprint unknown — page placed under Unsorted. Move it manually after confirming the sprint.`

## 7. Present Summary

```markdown
## dx-doc-gen complete

**<Title>** (ADO #<id>)
- Sprint: <sprint name>
- Output: `<spec-dir>/docs/wiki-page.md`
- Sections: <list of included sections>
- Template: AEM (demo walkthrough) / Standard (technical doc)
- Screenshots: <count> referenced (<list of screenshot files found>)
- Committable screenshots: `git add <spec-dir>/demo/*.png <spec-dir>/prototype/*.png <spec-dir>/screenshots/*.png`
- Figma: Yes / No
- QA URLs: Yes / No
- Word count: <N> words
- Mode: Local / Wiki (posted to <wiki path>)
```

## Examples

1. `/dx-doc-gen 2416553` — Reads spec files, generates `docs/wiki-page.md` with Summary, What Changed and Why, Usage, Files Changed. Standard template.

2. `/dx-doc-gen 2416553` (AEM project with authoring guide) — Detects `demo/authoring-guide.md`. Uses AEM template: Summary → Design Reference → What Changed and Why → QA Verification → Dialog Changes → Frontend Preview → Figma Comparison → Authoring Guide → Files Changed. Screenshots use repo-relative paths.

3. `/dx-doc-gen 2416553` (pipeline mode) — `PIPELINE_MODE=true` triggers wiki posting. Creates the sprint subfolder (`Sprint 42`) in the ADO wiki if it doesn't exist, then creates the wiki page at the configured doc root path. Summary includes `git add` command for committing screenshots.

## Troubleshooting

- **"No spec files found — nothing to generate from"**
  **Cause:** The spec directory exists but contains no recognized files (explain.md, implement.md, etc.).
  **Fix:** Run the requirements and planning pipeline first (`/dx-req <id>` or `/dx-plan <id>`). Even `raw-story.md` alone is enough for a basic page.

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
- **Degrade gracefully** — generate from whatever spec files are available. More files = richer output, but even raw-story.md alone is enough for a basic page.
- **Sprint from .sprint file** — do NOT hardcode sprint numbers. Always read from the file or fall back to iteration path parsing.
- **Wiki path encoding** — ADO wiki uses spaces in paths. Do NOT URL-encode the path when passing to MCP tools.
- **No time estimates** — never include estimates or durations
- **Authoring-guide drives template** — if `demo/authoring-guide.md` exists, use the AEM demo walkthrough template; otherwise use the standard template with Usage section
- **Repo-relative screenshot paths** — all image references use `.ai/specs/<id>-<slug>/...` paths so screenshots can be committed to the repo and linked from ADO wiki
- **Omit empty conditional sections** — Design Reference, Figma Comparison are conditional. If source data is missing, omit the entire section including heading. Never write "N/A" placeholders.
- **QA pages are mandatory** — for AEM projects, QA Author Edit + Preview URLs are required. This is the deliverable. Preview uses `wcmmode=disabled` for FE demo.
- **Multi-component = multi-page** — if several components are affected and need different pages, provide QA URL tables for each page
- **Don't list every file** — group by area (FE/BE/Config) with short descriptions. The PR has the diff; the wiki explains what and why.
- **Demo walkthrough order** — AEM template sections follow a demo presentation flow: story → design → implementation → QA → dialog → frontend → Figma comparison → authoring guide → files

---
name: dx-doc-retro
description: Generate technical documentation retroactively for completed stories — fetches ADO story, finds linked PRs, searches codebase, and produces wiki-ready docs without needing spec files. Posts to ADO Wiki or Confluence depending on provider config. Use when documentation was never generated during development.
argument-hint: "[ADO Work Item ID or URL]"
allowed-tools: ["read", "edit", "search", "write", "agent", "ado/*", "atlassian/*"]
---

You generate technical documentation for stories that are already implemented. Unlike `/dx-doc-gen` (which reads spec files produced during development), this skill discovers everything from the ADO work item and linked PRs. Posts to ADO Wiki or Confluence depending on `tracker.provider`.

## 1. Parse Input

Extract the numeric work item ID from the argument. Accept:
- Numeric ID: `2357516`
- Full URL: `https://dev.azure.com/{org}/{project}/_workitems/edit/2357516`
- Short URL: `https://<org>.visualstudio.com/.../_workitems/edit/2357516`

If no argument, ask the user for it.

Read `.ai/config.yaml` for:
- `tracker.provider` — `ado` (default) or `jira`
- `scm.org`, `scm.project`, `scm.repo-id`
- `scm.wiki-id`, `scm.wiki-project`, `scm.wiki-doc-root`
- `confluence.space-key`, `confluence.doc-root` (if provider = jira)

## 2. Fetch Work Item

```
mcp__ado__wit_get_work_item
  project: <scm.project>
  id: <work item ID>
  expand: "relations"
```

Extract:
- **Title**, **ID**, **State**, **Type**
- **Iteration Path** → sprint name (last segment, normalize `Sprint41` → `Sprint 41`)
- **Description** → markdown
- **Acceptance Criteria** → markdown
- **Relations** → find PR links (artifact links with `vstfs:///Git/PullRequestId/` URLs)

Save sprint to memory for step 6.

If the work item is not found or is not a User Story/Bug, print the error and STOP.

## 3. Find Linked PRs

From the relations, extract Pull Request artifact links. The URL format is:
```
vstfs:///Git/PullRequestId/{projectId}%2F{repoId}%2F{pullRequestId}
```

For each PR link, extract the `pullRequestId` and fetch:

```
mcp__ado__repo_get_pull_request_by_id
  repositoryId: <scm.repo-id>
  pullRequestId: <extracted PR ID>
```

**Filter:** Only keep PRs whose `status` is `completed` (discard `abandoned`, `active`, and all other non-completed statuses) and whose repository matches `scm.repo-id` (or any repo in `repos:` config). Discard PRs to unrelated repos.

For each relevant PR, collect:
- PR title, ID, source branch, target branch
- PR description (often contains implementation notes)
- Merge commit or last merge source commit

If no PRs are linked, warn: `No linked PRs found — documentation will be based on story content only.` Continue with what's available.

## 4. Search Codebase

Use the PR data and story content to search the codebase for changed files and patterns.

**Strategy A — PR branch exists locally:**
```bash
git log --oneline --name-only <target-branch>..<source-branch> 2>/dev/null
```

**Strategy B — PR branch doesn't exist (most common for completed PRs):**
Extract keywords from the story title and PR descriptions. Search using:

```
Grep for component names, class names, or feature keywords from the title
Glob for file patterns if component names are identified
```

Focus on:
- Component JS files (`src/core/components/`, `src/brand/components/`)
- SCSS files (`src/core/themes/`, `src/brand/themes/`)
- HBS templates (`src/*/handlebars/`)
- Backend/config files if story references them

**Strategy C — Cross-reference PR description:**
PR descriptions often list files or describe the approach. Parse the PR description for:
- File paths mentioned
- Component or class names
- Technical approach described

Collect a deduplicated list of relevant files grouped by area.

## 5. Generate Documentation

Create the spec directory if it doesn't exist:
```bash
DIR_NAME=$(bash .ai/lib/dx-common.sh find-spec-dir <work-item-id> 2>/dev/null || echo "")
if [ -z "$DIR_NAME" ]; then
  # Create new spec dir using slugify from dx-req
  DIR_NAME=$(bash .ai/lib/dx-common.sh slugify <id> "<title>")
  mkdir -p ".ai/specs/${DIR_NAME}/docs"
fi
```

Save the sprint name to `$SPEC_DIR/.sprint`.

Read `.ai/templates/wiki/wiki-page.md.template` and follow that structure, adapted for retroactive documentation (PR links instead of branch, synthesize from PR descriptions instead of spec files).

**Key difference from `/dx-doc-gen`:** No Architecture Decisions, API Changes, or Usage sections unless the PR descriptions explicitly contain that information. Keep it focused on what can be reliably discovered.

## 6. Post to Wiki (optional)

If the user asks to post to wiki, OR if `PIPELINE_MODE=true`:

Read `tracker.provider` from `.ai/config.yaml` (default: `ado`).
- If `ado` → follow **Section 6a** (ADO Wiki posting).
- If `jira` → follow **Section 6b** (Confluence posting).

### 6a. ADO Wiki Mode

Follow the same wiki posting logic as `/dx-doc-gen` (step 6a):
1. Read wiki config (`scm.wiki-id`, `scm.wiki-project`, `scm.wiki-doc-root`)
2. Build path: `<wiki-doc-root>/<Sprint XX>/<id>-<slug>`
3. Create sprint subfolder if needed
4. Create or update the page via `mcp__ado__wiki_create_or_update_page`

If `scm.wiki-id` is not configured, save locally only.

### 6b. Confluence Mode

Follow the same Confluence posting logic as `/dx-doc-gen` (step 6b):

1. Read `confluence.space-key` and `confluence.doc-root` from `.ai/config.yaml`.
2. If `confluence.space-key` is not configured, print: `Confluence space key not configured — wiki page saved locally only.` and STOP wiki posting.

3. **Find the doc root parent page:**

```
mcp__atlassian__confluence_search
  cql: "title = '<confluence.doc-root>' AND space = '<confluence.space-key>'"
```

Extract `page_id` → `DOC_ROOT_ID`. If not found, print error and STOP.

4. **Find or create the sprint subfolder page:**

```
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

5. **Check if the doc page already exists** under the sprint page.

6. **Content format conversion (CRITICAL):**

Skills generate markdown (same as for ADO wiki). Before posting to Confluence, test if the MCP server accepts markdown directly by making a test call. If the page renders correctly with raw markdown, use markdown. If it renders as raw text, convert markdown to basic Confluence storage format (XHTML):
- `# Heading` → `<h1>Heading</h1>`
- `**bold**` → `<strong>bold</strong>`
- `*italic*` → `<em>italic</em>`
- `- item` → `<ul><li>item</li></ul>`
- Code blocks → `<ac:structured-macro ac:name="code"><ac:plain-text-body><![CDATA[...]]></ac:plain-text-body></ac:structured-macro>`
- Tables → `<table><tr><th>...</th></tr><tr><td>...</td></tr></table>`
- Links `[text](url)` → `<a href="url">text</a>`

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

8. Print: `Wiki page created/updated in Confluence: <space-key> > <SPRINT> > <PAGE_TITLE>`

## 7. Present Summary

```markdown
## dx-doc-retro complete

**<Title>** (ADO #<id>)
- Sprint: <sprint name>
- PRs found: <count> (<pr-ids>)
- Files discovered: <count>
- Output: `<spec-dir>/docs/wiki-page.md`
- Mode: Local / Wiki (posted to <wiki path>)

### Discovery quality:
- Story content: <available/missing>
- PR descriptions: <rich/minimal/none>
- Codebase files: <N files found>
```

## Examples

1. `/dx-doc-retro 2357516` — Fetches the completed story from ADO, finds 2 linked completed PRs, extracts implementation details from PR descriptions, searches the codebase for changed component files, and generates `docs/wiki-page.md` with discovered context.

2. `/dx-doc-retro https://dev.azure.com/myorg/MyProject/_workitems/edit/2357516` — Extracts the ID from the URL, follows the same flow. Discovers 15 relevant files grouped by Frontend/Styles/Templates/Config. Offers to save and optionally post to the ADO wiki.

3. `/dx-doc-retro 2400000` (no linked PRs) — Fetches the story but finds no PR links in relations. Warns about reduced quality, generates documentation from story content + codebase search only, with a note about the limitation.

## Troubleshooting

- **"No linked PRs found — documentation will be based on story content only"**
  **Cause:** The story has no PR artifact links in ADO, or PRs were linked to a different work item.
  **Fix:** The skill continues with reduced context. For better results, manually link completed PRs to the story in ADO and re-run.

- **PR branch not found locally**
  **Cause:** The PR is completed and the source branch was deleted (common after merge). This is the normal case for retroactive documentation.
  **Fix:** The skill falls back to Strategy B (keyword search from story title and PR descriptions) and Strategy C (parsing PR descriptions for file paths). No action needed.

- **Files discovered don't match the actual changes**
  **Cause:** The codebase search uses keywords from the story/PR, which may match unrelated files with similar names.
  **Fix:** Review the generated `docs/wiki-page.md` and remove any incorrectly included files. The skill prioritizes PR descriptions as the most reliable source.

## Rules

- **Discovery-based** — this skill does NOT require spec files. It discovers everything from ADO + PRs + codebase search.
- **PR descriptions are gold** — they often contain the best implementation summary. Prioritize them over story descriptions.
- **Don't fabricate** — if you can't determine a technique or pattern, say what was changed without guessing how.
- **Read config, never hardcode** — ADO URLs, wiki paths from config.yaml
- **Skip empty sections** — never write "N/A" filler
- **Sprint from Iteration Path** — extract from the work item's iteration path field
- **Multi-PR support** — stories can have multiple PRs (e.g., one FE, one BE). Include all relevant ones.
- **Idempotent** — check existing docs/wiki-page.md before regenerating
- **Works without PRs** — if no PRs are linked, still generate docs from story content + codebase search. Warn about reduced quality.

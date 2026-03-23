---
name: aem-qa-handoff
description: Post QA handoff comment to ADO with QA page URLs, prerequisites, and wiki link. Reuses test page from /aem-doc-gen if available, otherwise creates its own on QA AEM. Use after /aem-doc-gen and /dx-doc-gen.
argument-hint: "<component-name> <work-item-id> (e.g., hero 2416553)"
context: fork
agent: aem-inspector
compatibility: "Full mode requires AEM MCP (QA instance) and Chrome DevTools MCP. Lightweight mode needs only ADO MCP."
metadata:
  mcp-server: AEM, chrome-devtools-mcp
  category: aem-verification
allowed-tools: ["read", "edit", "search", "write", "agent", "ado/*", "AEM/*", "chrome-devtools-mcp/*"]
---

**Platform note:** This skill uses `context: fork` + `agent: aem-inspector` for isolated execution. If subagent dispatch is unavailable (e.g., VS Code Chat), you may run inline but AEM MCP tools (`AEM/*`, `chrome-devtools-mcp/*`) must be available for full mode.

You are the **QA Handoff Agent**. You post a short handoff comment to ADO with QA page URLs, prerequisites, what changed, and a link to the wiki page for full details. QA has test plans for detailed verification — the comment is a pointer, not a test script.

**Two modes:**

- **Lightweight (recommended):** Reads existing test page and context from `/aem-doc-gen` + `/dx-doc-gen` output. No AEM MCP needed.
- **Full (fallback):** Creates test page on QA AEM if no doc-gen output exists. Requires AEM MCP.

**Recommended flow:**
```
/aem-doc-gen hero 2416553       -> creates QA page, screenshots, authoring guide
/dx-doc-gen 2416553             -> creates wiki page
/aem-qa-handoff hero 2416553    -> posts short handoff comment to ADO with wiki link
```

## Flow

```dot
digraph aem_qa_handoff {
    "Load config and parse arguments" [shape=box];
    "Config valid?" [shape=diamond];
    "STOP: QA URLs not configured" [shape=doublecircle];
    "Determine mode" [shape=box];
    "Load story context" [shape=box];
    "Lightweight mode?" [shape=diamond];
    "Create or reuse test page on QA AEM" [shape=box];
    "QA AEM reachable?" [shape=diamond];
    "STOP: cannot reach QA AEM" [shape=doublecircle];
    "Build handoff comment" [shape=box];
    "Check for existing ADO comment" [shape=box];
    "Existing comment found?" [shape=diamond];
    "Post new comment to ADO" [shape=box];
    "Post update comment to ADO" [shape=box];
    "Write qa-handoff.md and present summary" [shape=doublecircle];

    "Load config and parse arguments" -> "Config valid?";
    "Config valid?" -> "STOP: QA URLs not configured" [label="no"];
    "Config valid?" -> "Determine mode" [label="yes"];
    "Determine mode" -> "Load story context";
    "Load story context" -> "Lightweight mode?";
    "Lightweight mode?" -> "Build handoff comment" [label="yes, skip page creation"];
    "Lightweight mode?" -> "Create or reuse test page on QA AEM" [label="no, full mode"];
    "Create or reuse test page on QA AEM" -> "QA AEM reachable?";
    "QA AEM reachable?" -> "STOP: cannot reach QA AEM" [label="no"];
    "QA AEM reachable?" -> "Build handoff comment" [label="yes"];
    "Build handoff comment" -> "Check for existing ADO comment";
    "Check for existing ADO comment" -> "Existing comment found?";
    "Existing comment found?" -> "Post update comment to ADO" [label="yes"];
    "Existing comment found?" -> "Post new comment to ADO" [label="no"];
    "Post new comment to ADO" -> "Write qa-handoff.md and present summary";
    "Post update comment to ADO" -> "Write qa-handoff.md and present summary";
}
```

## Node Details

### Load config and parse arguments

**Read configuration** from `.ai/config.yaml`:
- `aem.author-url-qa` — QA author URL
- `aem.publish-url-qa` — QA publisher URL
- `aem.demo-parent-path` — where test pages live
- `scm.project`, `scm.org` — for ADO operations
- `scm.wiki-id`, `scm.wiki-doc-root` — for wiki page link

**Parse arguments:** Extract `<component-name>` and `<work-item-id>` from `$ARGUMENTS`.
- If no component name: infer from `implement.md` or `aem-after.md`. If unclear, STOP and ask.
- If no work item ID: use most recent spec dir. If unclear, STOP and ask.

### Config valid?

If `aem.author-url-qa` or `aem.publish-url-qa` is not configured, take the "no" path.

### STOP: QA URLs not configured

```
BLOCKED: QA URLs not configured. Set `aem.author-url-qa` and `aem.publish-url-qa` in `.ai/config.yaml`.
```

### Determine mode

Check for `/aem-doc-gen` output in `<spec-dir>`:

1. `demo/authoring-guide.md` exists?
2. `demo/*.png` screenshots exist?

**If `demo/authoring-guide.md` exists:** Lightweight mode.
**If not:** Full mode. Print tip to run `/aem-doc-gen` first.

### Load story context

Read from spec dir (all optional):
- `explain.md` — what was done (for "What Changed" bullets)
- `implement.md` — implementation details
- `aem-after.md` — test page path, dialog fields
- `demo/authoring-guide.md` — QA page URLs
- `docs/wiki-page.md` — wiki page exists? (for wiki link)
- `.sprint` — sprint name (for wiki path)
- `.pr` — PR number

Also fetch ADO work item for title and PR link:
```
mcp__ado__wit_get_work_item
  id: <work-item-id>
```

**Build wiki URL:** If `scm.wiki-id` and `scm.wiki-doc-root` are configured and `.sprint` exists:
```
WIKI_URL = <scm.org>/<scm.wiki-project>/_wiki/wikis/<scm.wiki-id>/<wiki-doc-root>/<sprint>/<id>-<slug>
```
If wiki page doesn't exist yet, note it in the comment.

### Lightweight mode?

If lightweight, skip page creation. If full, create/reuse test page.

### Create or reuse test page on QA AEM

Same as before — all AEM MCP calls use `instance: "qa"`. Resolve QA basic auth. Check for existing page from `aem-after.md`. Create if needed.

### QA AEM reachable?

If AEM MCP call succeeded, continue. If not, STOP.

### STOP: cannot reach QA AEM

```
BLOCKED: Cannot reach QA AEM instance.
```

### Build handoff comment

Read the template from `.ai/templates/ado-comments/qa-handoff.md.template`.

Fill in:
- `<story-title>` — from ADO work item
- `<pr-url>` — from `.pr` file or ADO work item relations
- `<branch-name>` — from `.branch` file or `git branch --show-current`
- `<wiki-url>` — computed wiki URL (or "Wiki page not yet generated — run /dx-doc-gen")
- `<qa-author-url>`, `<qa-publish-url>` — from config
- `<test-page-path>` — from doc-gen or self-created page
- Prerequisites — only hard blockers (dependency PRs, deployments)
- What Changed — 3-5 bullets from `explain.md`, same as wiki Summary
- `<ISO timestamp>` — current time

**The comment is SHORT.** No test scripts, no step-by-step verification, no DOM inspection commands. QA has test plans. The wiki page has screenshots, dialog details, and authoring guide.

### Check for existing ADO comment

Search comments for `[QAHandoff]` signature:
```
mcp__ado__wit_list_work_item_comments
  workItemId: <work-item-id>
```

### Existing comment found?

If found, take "yes" path. If not, "no".

### Post new comment to ADO

```
mcp__ado__wit_add_work_item_comment
  workItemId: <work-item-id>
  text: "<filled-template>"
  format: "markdown"
```

### Post update comment to ADO

Post a short update (ADO MCP doesn't support comment editing):

```markdown
### [QAHandoff] Updated

**Previous:** <previous timestamp>
**Changes:** <what changed — new page, updated URLs, etc.>

---
_[QAHandoff] Update | <ISO timestamp>_
```

### Write qa-handoff.md and present summary

Write `<spec-dir>/qa-handoff.md` with the same content as the ADO comment.

Print:
```markdown
## QA Handoff Complete: #<work-item-id>

**Mode:** <lightweight | full>
**Test Page:** <qa-publisher-url>
**Wiki:** <wiki-url or "not yet generated">
**ADO Comment:** posted [QAHandoff]
```

## Examples

1. `/aem-qa-handoff hero 2416553` (after doc-gen + doc-gen) — Lightweight mode. Reads existing test page URL and wiki link. Posts short ADO comment: QA URLs, PR link, 4 bullets on what changed, wiki link. Done in seconds.

2. `/aem-qa-handoff hero 2416553` (no prior doc-gen) — Full mode. Creates test page on QA AEM, posts handoff comment. Warns that wiki page is missing.

## Troubleshooting

- **"QA URLs not configured"** — Add `aem.author-url-qa` and `aem.publish-url-qa` to `.ai/config.yaml`.
- **"Cannot reach QA AEM"** — Run `/aem-doc-gen` first (handles page creation), then re-run in lightweight mode.
- **Wiki link says "not yet generated"** — Run `/dx-doc-gen <id>` first to create the wiki page.

## Rules

- **Short comment** — the ADO comment is a pointer, not a document. QA has test plans for detailed verification. The wiki page has full details.
- **Lightweight first** — if `/aem-doc-gen` output exists, use it. Don't duplicate AEM MCP work.
- **Remote QA only** — all AEM MCP calls use `instance: "qa"`. Never target localhost.
- **Idempotent** — reuses existing test pages, checks for existing ADO comments
- **Wiki link required** — always include wiki link. If wiki page doesn't exist, note it and suggest `/dx-doc-gen`.

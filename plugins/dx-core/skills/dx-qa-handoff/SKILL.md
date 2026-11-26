---
name: dx-qa-handoff
description: "Post the QA handoff comment on the story — links the PR, wiki page, QA demo pages and screenshots. Use after /dx-doc-gen, or for 'hand off to QA'. Step 3 of /dx-post-merge."
argument-hint: "[work-item-id]"
allowed-tools: ["read", "edit", "search", "write", "ado/*", "atlassian/*"]
---

You post one short `[QAHandoff]` comment on the work item: where to test (QA demo pages), what changed, and links to the PR, the wiki page and the screenshots. QA has test plans and the wiki page has the details — the comment is a pointer, not a test script.

You never touch AEM. Everything comes from files earlier steps wrote; each is optional:

| File | Written by | Gives |
|------|-----------|-------|
| `demo/demo-page.md` | `/aem-demo-page` | QA pages (Edit / Preview / Publisher), screenshot attachment URLs |
| `.wiki-url` | `/dx-doc-gen` | wiki page link |
| `.pr`, `.branch` | `/dx-pr`, `/dx-req` | PR link, branch |
| `explain.md`, `share-plan.md` | `/dx-req` | "What changed" bullets |

## 1. Load config and spec dir

```bash
SPEC_DIR=$(bash .ai/lib/dx-common.sh find-spec-dir <work-item-id-if-given>)
```

No spec dir → ask for the ID (interactive) or STOP with `No spec dir for <id> — run /dx-doc-gen <id> first.` (non-interactive, `../../shared/interaction-mode.md`).

Read `.ai/config.yaml`: `tracker.provider` (default `ado`), `scm.org`, `scm.project`. Provider rules: `../../shared/provider-config.md`.

## 2. Load context

Fetch the work item for title and PR relations (ADO `mcp__ado__wit_work_item` `action: "get"`, `expand: "Relations"`; Jira `mcp__atlassian__jira_get_issue`).

- **PR:** `.pr`, else a PR relation on the work item. None → omit the PR line.
- **Wiki:** `.wiki-url`. Missing → `Wiki page not generated yet — run /dx-doc-gen <id>.`
- **QA pages and screenshots:** `environments.qa` of `demo/demo-page.md`. Only a `local` entry → `QA demo page not set up yet — run /aem-demo-page <id>.` No file → omit the QA Pages and Screenshots sections (non-AEM story).
- **What changed:** 3–5 bullets from `explain.md` / `share-plan.md`, else from the work item description. Same wording as the wiki Summary when `docs/wiki-page.md` exists.
- **Prerequisites:** only hard blockers — a dependency PR or deployment that must be live first (from `explain.md` "Repos Required" / cross-repo notes). Omit when none.

## 3. Build the comment

Read `.ai/templates/ado-comments/qa-handoff.md.template` and fill it. Its `<!-- … -->` lines are instructions — leave them out of the posted text (ADO shows them literally). Leave out every section whose data is missing; never write "N/A".

## 4. Post (idempotent)

List the work item's comments (ADO `mcp__ado__wit_work_item` `action: "list_comments"`; Jira: issue comments) and look for one starting with `### [QAHandoff]`.

- **None** → post the filled template (ADO `mcp__ado__wit_work_item_comment_write` `action: "add"`, `format: "Markdown"`; Jira `mcp__atlassian__jira_add_comment`).
- **Found** → post a short update instead of a second full comment:
  ```markdown
  ### [QAHandoff] Updated

  **Changed since <previous timestamp>:** <new QA page, new screenshots, wiki link added, …>

  ---
  _[QAHandoff] Update | <ISO timestamp>_
  ```
  Nothing changed since the last one → post nothing and say so.

**Dry run** (`dry run` in the arguments) → do not post; print the comment.

## 5. Save and report

Write `$SPEC_DIR/qa-handoff.md` with the posted text (or the dry-run text).

```markdown
## QA handoff — #<id>

**Comment:** posted / update posted / unchanged / dry run
**QA pages:** <N> (from demo-page.md) / not set up / n/a
**Wiki:** <url> / not generated
**Screenshots:** <N> linked
```

## Examples

1. `/dx-qa-handoff 12345` after `/aem-demo-page` and `/dx-doc-gen` — comment with PR, wiki link, one QA page (Edit / Preview / Publisher), dialog and preview screenshot links, four "what changed" bullets.
2. `/dx-qa-handoff 12345` on a non-AEM story — no `demo-page.md`: PR, wiki link, what changed.
3. Re-run after `/aem-demo-page` re-captured on QA — posts `[QAHandoff] Updated` naming the new screenshots.

## Rules

- **Short** — a pointer, not a test script. No repro steps, no DOM checks; "How to test" lives on the wiki page.
- **No AEM access** — read `demo-page.md`; never create or look up pages.
- **One comment per story** — later runs post a short update, never a second full comment.
- **Read config for every URL** — never hardcode hosts or projects.

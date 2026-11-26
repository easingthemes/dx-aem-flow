---
name: dx-prep
description: "Prepare a story for hand-off before the sprint — requirements, plan, plan wiki page, [DevPlan] comment with next step, specs pushed. Use for 'prepare this story', 'architect prep'. Implementation continues later with /dx-agent-all."
argument-hint: "<ADO Work Item ID or URL> [autonomous] [--force]"
allowed-tools: ["read", "edit", "search", "write", "agent", "ado/*", "atlassian/*"]
---

You prepare a ticket so that someone else — a developer, or `/dx-agent-all` in a pipeline — can implement it later without redoing the analysis. You coordinate existing skills via the Skill tool and publish their result; you do no new research and write no code.

Outputs:
- Spec files in `.ai/specs/<id>-<slug>/` (from `/dx-req` and `/dx-plan`), committed and pushed on the feature branch
- `docs/plan-wiki.md` in the spec dir + a wiki page titled `dx-prep.wiki-page-title` (default **Development Plan**) under the story's doc page. Teams that had a pre-development "Solution Review" / tech-lead sign-off step use this page for it — set the title to make that visible, e.g. `Development Plan (Solution Review)`.
- The `[DevPlan]` comment on the work item, with the wiki link, what is prepared, and the next command

Re-running is safe: every step is idempotent, the wiki page is upserted and the comment edited in place.

## Flow

```dot
digraph dx_prep {
    "Parse argument" [shape=box];
    "Requirements (dx-req)" [shape=box];
    "Planning (dx-plan + validate)" [shape=box];
    "Plan valid?" [shape=diamond];
    "STOP: plan validation failed" [shape=doublecircle];
    "Write plan-wiki.md" [shape=box];
    "Wiki configured?" [shape=diamond];
    "Publish wiki page" [shape=box];
    "Post hand-off DevPlan comment" [shape=box];
    "Specs tracked in git?" [shape=diamond];
    "Commit and push specs" [shape=box];
    "Summary" [shape=doublecircle];

    "Parse argument" -> "Requirements (dx-req)";
    "Requirements (dx-req)" -> "Planning (dx-plan + validate)";
    "Planning (dx-plan + validate)" -> "Plan valid?";
    "Plan valid?" -> "STOP: plan validation failed" [label="fail after resolve"];
    "Plan valid?" -> "Write plan-wiki.md" [label="pass / warn"];
    "Write plan-wiki.md" -> "Wiki configured?";
    "Wiki configured?" -> "Publish wiki page" [label="yes"];
    "Wiki configured?" -> "Post hand-off DevPlan comment" [label="no (local copy only)"];
    "Publish wiki page" -> "Post hand-off DevPlan comment";
    "Post hand-off DevPlan comment" -> "Specs tracked in git?";
    "Specs tracked in git?" -> "Commit and push specs" [label="yes"];
    "Specs tracked in git?" -> "Summary" [label="no (warn)"];
    "Commit and push specs" -> "Summary";
}
```

## Node Details

### Parse argument

Extract the numeric work item ID (or Jira key) from the argument; ask if missing. `autonomous` → no confirmation prompts. `--force` → passed to `/dx-plan` to regenerate an existing plan.

### Requirements (dx-req)

Invoke `Skill(/dx-req <id>)`. It fetches the story (with linked items, release check and comment images), runs DoR, explain, research, creates the feature branch and posts the pre-plan `[DevPlan]` comment. Then:

```bash
SPEC_DIR=$(bash .ai/lib/dx-common.sh find-spec-dir <id>)
```

### Planning (dx-plan + validate)

Invoke `Skill(/dx-plan <id>)` (add `--force` if given), then `Skill(/dx-plan-validate <id>)`. On `verdict: fail`, invoke `Skill(/dx-plan-resolve <id>)` once and validate again. Interactive mode: on `warn`, offer `/dx-plan-resolve`; autonomous: continue.

### Plan valid?

`pass` or `warn` → continue. `fail` after one resolve → STOP.

### STOP: plan validation failed

Print `Plan validation failed — see $SPEC_DIR/validation-report.md. Fix the plan or the story, then re-run /dx-prep <id>.` Nothing is published. Write the run result (see **Run result**) with `--status blocked --verdict fail --next "/dx-prep <id>"`.

### Write plan-wiki.md

Read `.ai/templates/wiki/plan-wiki.md.template` and fill it **only from spec files** — `raw-story.md`, `explain.md`, `research.md`, `dor-report.md`, `implement.md`, `plan-thinking.md`, `.sprint`, `.branch`. No new code search: if a section has no source, omit it. Write `$SPEC_DIR/docs/plan-wiki.md`.

**Title:** `PLAN_TITLE=$(bash .ai/lib/dx-common.sh yaml-val dx-prep.wiki-page-title)`, default `Development Plan`. It is the page heading (`# <PLAN_TITLE> — <Title> (ADO #<id>)`).

**Status line:** read `dx-prep.review-tag` from config.
- Set, and `raw-story.md` `**Tags:**` contains it → `Reviewed (tag <tag>)`
- Set, tag missing → `Draft — not reviewed (add tag <tag> after review)`
- Not set → `Draft — set dx-prep.review-tag to track review`

Idempotent: if `docs/plan-wiki.md` exists and the new content is the same apart from the `Prepared:` date, keep the file and print `plan-wiki.md already up to date`.

### Wiki configured?

ADO: `scm.wiki-id` and `scm.wiki-doc-root` set. Jira: `confluence.space-key` and `confluence.doc-root` set. If not, print `Wiki not configured — plan saved locally at docs/plan-wiki.md` and continue.

### Publish wiki page

The plan is a **child page** of the story's doc page, so `/dx-doc-gen` can keep updating the story page after implementation without touching the plan.

**Story page:** follow `../../shared/wiki-story-page.md` to find it. It reuses the story's existing page whatever its name format (`<id>-<slug>`, `<id> <title>`, `<id>: <title>`, several ids), also in other sprint folders (carried-over stories), and only falls back to `<id>-<slug>` in the current sprint (`Unsorted` when the sprint is unknown). Never create a second story page next to an existing one.

**ADO:**

1. Resolve `STORY_PATH` (shared procedure above; it creates the sprint folder only when a new story page is needed).
2. Story page does not exist yet → create a placeholder: `# <Title> (ADO #<id>)` + `Technical documentation follows after implementation. The prepared plan is in the child page **<PLAN_TITLE>**.` (`/dx-doc-gen` replaces it later). An existing story page is **never** written by `/dx-prep`.
3. Upsert the plan: `mcp__ado__wiki_upsert_page` with `wikiIdentifier: <scm.wiki-id>`, `project: <scm.wiki-project>`, `path: "${STORY_PATH}/${PLAN_TITLE}"`, `content: <docs/plan-wiki.md>`. Pass the page's current version as `etag` when it exists; on a version conflict, get the page again and retry once.
4. Write the page URL to `$SPEC_DIR/.plan-wiki-url` (one line). Use the URL the tool returns (`remoteUrl`); if none, build `<scm.org>/<wiki-project>/_wiki/wikis/<wiki-id>?pagePath=<page path url-encoded>`.

If `PLAN_TITLE` was changed since the last run, the page under the old title stays — print `Plan page title changed — the old page "<old>" is still there; delete or rename it by hand` when `.plan-wiki-url` points at a different title.

**Confluence:** resolve the story page with the shared procedure (create the same placeholder only when no page matched). Create or update its child page titled `<id> <PLAN_TITLE>` (Confluence titles are unique per space) with the converted content. Write its URL to `.plan-wiki-url`.

If publishing fails, print a warning and continue — the local `docs/plan-wiki.md` and the comment still help.

### Post hand-off DevPlan comment

Regenerate `share-plan.md` in **post-plan mode** and post it per `../dx-req/references/share-template.md`, including its **Hand-off Block** (wiki link from `.plan-wiki-url`, prepared phases, branch, `Next: /dx-agent-all <id>`). The existing `[DevPlan]` comment from `/dx-req` is edited in place (`dx-req.devplan-update`), so the ticket keeps one DevPlan comment.

### Specs tracked in git?

```bash
git check-ignore -q "$SPEC_DIR/implement.md" && echo ignored || echo tracked
```

`ignored` → print `⚠ .ai/specs/ is gitignored — the prepared plan stays on this machine. Replace the .ai/specs/ line in .gitignore with .ai/specs/**/images/ (see /dx-doctor), then re-run /dx-prep <id>.` and go to Summary.

### Commit and push specs

Stage **only the spec dir** — never code or other files:

```bash
BRANCH=$(cat "$SPEC_DIR/.branch" 2>/dev/null || git branch --show-current)
git add -- "$SPEC_DIR"
git diff --cached --quiet && echo "NOTHING_TO_COMMIT"
```

If there is something to commit, commit with message `#<id> Prepare development plan` (format from `../../shared/git-rules.md`). Interactive mode: show `git diff --cached --stat` and ask before pushing. Push: `git push -u origin "$BRANCH"`. A push failure is a warning, not a stop — print the command to run by hand.

### Summary

```markdown
## /dx-prep complete: #<id> <title>

- Specs: `<spec-dir>` — requirements, DoR, research, plan (<n> steps)
- Wiki: <"<STORY_PATH>/<PLAN_TITLE>" or "local only: docs/plan-wiki.md"> <"— story page carried over from <sprint>" when SCOPE=other-sprint>
- ADO: [DevPlan] comment <posted | updated | unchanged>
- Branch: `<branch>` <pushed | not pushed — reason>
- Review: <"add tag <review-tag> to the work item after reading the wiki page" | "reviewed" | "not tracked — set dx-prep.review-tag">

**Next:** `/dx-agent-all <id>` — skips the prepared phases and starts from implementation.
```

Then write the run result.

### Run result

**Start marker** — right after the id is parsed (Parse argument), before any long work:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/data/lib/run-result.sh" --start --skill dx-prep --id <id> --progress-file req-progress.md
```

**Progress** — `req-progress.md` is shared with `/dx-req` (it adds its own phase rows there). Add one row per dx-prep step, each `in_progress` before it starts: `Prep: requirements` (the nested `/dx-req` call; on a first run the spec dir does not exist yet — write this row as soon as `/dx-req` returns) → `Prep: planning` (`/dx-plan` + validate) → `Prep: plan wiki` (`skipped` when no wiki is configured) → `Prep: DevPlan comment` → `Prep: commit specs` (`skipped` when specs are not tracked). Rules: `../../shared/run-result.md` § 2.

```bash
DX_PROGRESS_FILE="req-progress.md" DX_PROGRESS_TITLE="/dx-req Progress" \
  bash "${CLAUDE_PLUGIN_ROOT}/shared/update-progress.sh" "$SPEC_DIR" "<step>" "<status>" "<note>"
```

Last action of every run — Summary, the validation STOP, and any failure that ends the run early (`/dx-req` failing, no plan produced → `--status failed`) — per `../../shared/run-result.md`:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/data/lib/run-result.sh" --skill dx-prep --id <id> --status <done|blocked|failed> \
  --verdict "<plan-validate verdict>" --next "/dx-agent-all <id>" \
  --wiki "<.plan-wiki-url, if published>" --work-item "<work item url>" --summary "<one line>" \
  --mode <interactive|automation> --mode-reason <args|no-ask|flag|none> \
  --metric plan_steps=<steps in implement.md> --metric resolve_rounds=<0|1> \
  --metric fail_at="<node that stopped the run, omit if none>"
```

See `../../shared/run-result.md` § Metrics.

From Summary: `done` (a skipped wiki publish or an unpushed branch is still `done` — say so in `--summary`).

## Rules

- **No duplicate work** — every section of the wiki page comes from a spec file; never re-research.
- **One comment** — edit `[DevPlan]` in place; never post a second full plan.
- **Specs only** — the commit contains the spec dir, nothing else.
- **Plain hand-off** — the plan is a default for the implementer, not a contract (`/dx-step` records deviations).

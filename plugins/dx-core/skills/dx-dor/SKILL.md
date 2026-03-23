---
name: dx-dor
description: Validate Definition of Ready — fetch wiki checklist, evaluate story, post ADO comment. Use standalone at sprint start, in batch, or as part of /dx-req.
argument-hint: "<Work Item ID(s) — space-separated for batch>"
model: sonnet
allowed-tools: ["read", "edit", "search", "write", "agent", "ado/*", "atlassian/*"]
---

Validate one or more work items against the project's Definition of Ready checklist. Fetches the DoR wiki page, evaluates each criterion against the story content, generates a scorecard, and posts an interactive ADO/Jira comment with checkboxes for BA collaboration. Supports three modes: first post (Mode A), update after changes (Mode B), and reuse when nothing changed (Mode C).

## Flow

```dot
digraph dx_dor {
    "Parse argument(s)" [shape=box];
    "Single or batch?" [shape=diamond];
    "Fetch story" [shape=box];
    "Fetch DoR wiki" [shape=box];
    "Existing [DoRAgent] comment?" [shape=diamond];
    "Read checkbox state" [shape=box];
    "BA updated checkboxes?" [shape=diamond];
    "Re-fetch story + re-validate" [shape=box];
    "Materialize comment → dor-report.md (Mode C)" [shape=box];
    "Parse wiki → build criteria" [shape=box];
    "Evaluate story against criteria" [shape=box];
    "Generate dor-report.md" [shape=box];
    "Post ADO comment" [shape=box];
    "Done" [shape=doublecircle];
    "Spawn parallel subagents" [shape=box];

    "Parse argument(s)" -> "Single or batch?";
    "Single or batch?" -> "Fetch story" [label="single"];
    "Single or batch?" -> "Spawn parallel subagents" [label="multiple IDs"];
    "Spawn parallel subagents" -> "Done";
    "Fetch story" -> "Fetch DoR wiki";
    "Fetch DoR wiki" -> "Existing [DoRAgent] comment?";
    "Existing [DoRAgent] comment?" -> "Read checkbox state" [label="yes"];
    "Existing [DoRAgent] comment?" -> "Parse wiki → build criteria" [label="no"];
    "Read checkbox state" -> "BA updated checkboxes?";
    "BA updated checkboxes?" -> "Re-fetch story + re-validate" [label="yes"];
    "BA updated checkboxes?" -> "Materialize comment → dor-report.md (Mode C)" [label="no"];
    "Re-fetch story + re-validate" -> "Generate dor-report.md";
    "Materialize comment → dor-report.md (Mode C)" -> "Done";
    "Parse wiki → build criteria" -> "Evaluate story against criteria";
    "Evaluate story against criteria" -> "Generate dor-report.md";
    "Generate dor-report.md" -> "Post ADO comment";
    "Post ADO comment" -> "Done";
}
```

## Node Details

### Parse argument(s)

- Read shared config: `shared/provider-config.md`, `shared/external-content-safety.md`
- Read `.ai/config.yaml` for provider, project, repo
- Parse argument: split on whitespace to produce a list of IDs
- If no argument provided, check for an active spec dir and extract the ID from its directory name

### Single or batch?

- If 1 ID: continue to "Fetch story"
- If 2+ IDs: continue to "Spawn parallel subagents"

### Spawn parallel subagents

- For each ID, use the Agent tool to dispatch a subagent with prompt: `Run /dx-dor <id>`
- Run all agents in parallel
- Collect results and present a summary table

### Fetch story

- If `.ai/specs/<id>-*/` exists, reuse it as `$SPEC_DIR`. Otherwise fetch title via MCP, slugify, create `mkdir -p .ai/specs/<id>-<slug>/`
- Fetch work item via MCP (ADO: `mcp__ado__wit_get_work_item`, Jira: `mcp__atlassian__jira_get_issue`)
- Fetch comments (ADO: `mcp__ado__wit_list_work_item_comments`, Jira: comments included in issue response)
- If `raw-story.md` doesn't exist, convert HTML to markdown per `shared/external-content-safety.md` and write it. If it exists and is current, reuse.

### Fetch DoR wiki

- Read `references/wiki-parsing.md` for the full parsing and fallback chain logic
- Fetch the wiki page using the URL from config (`scm.wiki-dor-url`) or Confluence (`confluence.dor-page-title`)

### Existing [DoRAgent] comment?

- Scan fetched comments for text containing `[DoRAgent] Definition of Ready Check`
- If found: continue to "Read checkbox state"
- If not found: continue to "Parse wiki -> build criteria"

### Read checkbox state

- Parse `- [x]` and `- [ ]` lines from the existing comment
- Compare against the original post state to detect changes

### BA updated checkboxes?

- If any checkbox changed from `[ ]` to `[x]` since original post: **yes** -> continue to "Re-fetch story + re-validate"
- If no checkboxes changed: **no** -> continue to "Materialize comment -> dor-report.md (Mode C)"

### Re-fetch story + re-validate

- Print: `BA checked <N> items: <list>. Re-fetching story to validate...`
- Re-fetch work item via MCP to get updated content
- Re-run evaluation against wiki criteria

### Materialize comment -> dor-report.md (Mode C)

- Parse the existing ADO comment back into dor-report.md format
- Write to `$SPEC_DIR/dor-report.md`
- Print: `DoR comment already posted to ADO #<id> — no changes — reusing.`

### Parse wiki -> build criteria

- Parse the wiki content per `references/wiki-parsing.md`
- Build structured list of sections with criteria and skip triggers

### Evaluate story against criteria

- For each section: check skip trigger against change type
- For each criterion: evaluate against raw-story.md content
  - `required`: Pass or Fail
  - `recommended`: Pass or Warn
  - `human`: Warn always (needs human judgment)
- Extract structured BA data (component, dialog, design, scope) per `references/wiki-parsing.md`
- Generate open questions per pragmatism rules (read `rules/pragmatism.md`)

### Generate dor-report.md

- Compute score from applicable `required` criteria
- Apply scoring thresholds from wiki `## Scoring` section
- Write `$SPEC_DIR/dor-report.md` per output format in `references/wiki-parsing.md`

### Post ADO comment

- Read `references/comment-format.md` for Mode A/B posting logic
- Mode A (first post): full checklist with interactive checkboxes
- Mode B (update): short delta comment with resolved/remaining items

### Done

- Print verdict: `DoR: <verdict> (<score>/<total>)`

## Examples

### Single work item
```
/dx-dor 2416553
```
Fetches story #2416553, evaluates against DoR checklist, writes `dor-report.md`, posts ADO comment.

### Batch validation at sprint start
```
/dx-dor 2416553 2416554 2416555
```
Spawns parallel subagents, each validating one item. Prints summary table at the end.

### Re-run after BA updates
```
/dx-dor 2416553
```
Detects existing `[DoRAgent]` comment, finds BA checked 3 items, re-fetches story, re-validates, posts Mode B update.

## Rules

- **Config-driven** — never hardcode wiki URLs, project names, or org details. Read everything from `.ai/config.yaml`.
- **Idempotent** — safe to re-run. Detects existing comments and adapts (Mode A/B/C).
- **Pragmatic questions** — self-discover answers before asking. Target 2-5 open questions, not an interrogation.
- **Interactive checkboxes** — ADO comments use `- [ ]` checkboxes so BAs can mark items resolved directly in ADO.
- **Always use `[DoRAgent]` text signature** — never use HTML comments like `<!-- ai:role:dor-agent -->` for detection.

## Platform Compatibility

This skill uses `Agent()` for batch mode and MCP tools for ADO/Jira, which work on both Claude Code and Copilot CLI.

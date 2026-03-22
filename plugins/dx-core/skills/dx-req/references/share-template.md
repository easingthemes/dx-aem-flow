# Share Summary — Detailed Rules

This file contains the detailed share-plan generation and posting logic used by Phase 5 of `/dx-req`.

## Persona (optional)

If `.ai/me.md` exists, read it. Use it to shape the voice of the share-plan summary — the persona overrides "Preserve the developer's voice" with the actual developer's voice. Writing constraints (25-line limit, no jargon for BAs, no time estimates) still apply. If `.ai/me.md` doesn't exist, use defaults.

## Two Modes

- **Pre-plan mode** (no `implement.md`) — generates a high-level implementation approach from `explain.md` + `research.md` + `dor-report.md`. This is a developer's initial take: "here's how I plan to tackle this in general."
- **Post-plan mode** (`implement.md` exists) — translates the detailed plan into plain language. More specific, but same format.

**Do NOT warn about missing `implement.md`** — pre-plan mode (without it) is the primary flow.

## share-plan.md Output Format

```markdown
# Development Plan: <Title>
**ADO:** [#<id>]({scm.org}/{scm.project_url_encoded}/_workitems/edit/<id>) | **Branch:** `feature/<id>-<slug>`

## Summary
<2 sentences max: what the story asks for, in plain language.
No code references, no file names. User/author experience only.>

## Implementation Approach

### What I'm Planning to Do
<3-5 bullets max. One sentence each. Plain language only — no file
names, class names, or technical jargon.

**Pre-plan mode** (no implement.md): Derive approach from explain.md requirements
+ research.md findings. Focus on the general strategy — what areas of the system
will be touched, what the author/user experience will be after the change.
Example: "Add a new checkbox to the footer component dialog that lets authors
provide screen-reader-only text for social media links."

**Post-plan mode** (implement.md exists): Translate the detailed plan steps into
plain language. More specific, same tone.>

### What Won't Change
<2-3 reassurance bullets. OMIT if change is clearly additive.>

## Scope & Blockers
<Scope: Small/Medium/Large — one sentence justification.
Blockers: list or "None — ready to start."
Be pragmatic — missing minor design details (pixel values, colors, exact spacing)
that have sensible defaults are NOT blockers. Say "FE will use defaults and adjust
when final values arrive." Only list true blockers: missing APIs, unresolved
dependencies, access issues, or ambiguous core requirements.>

## Multi-Repo
<If research.md or explain.md has a "Cross-Repo Scope" or "Repos Required"
section, mention it here in plain language.

OMIT if all work is in a single repo.>

## Assumptions
<If dor-report.md exists and has an "Assumptions" section under Open Questions,
list them here in plain language. These are things the developer assumed to be true
based on the story content — the team should confirm or correct them.
One line each, plain language, no jargon.
OMIT this section entirely if dor-report.md doesn't exist or has no assumptions.>

## Open Questions
<Top 3 questions max from dor-report.md (Open Questions section) — ONLY [req], [design], or [process] tagged questions.
Falls back to checklist.md if dor-report.md doesn't exist.
These are questions a developer asks the BA about unclear requirements.
NEVER include implementation-level concerns.
One line each, plain language, no technical jargon.
If none: "Requirements are clear.">
```

Where `{scm.org}` and `{scm.project_url_encoded}` are read from `.ai/config.yaml`.

## Writing Principles

- **Hard limit: ~25 lines of content** — this is a Teams-pasteable summary, not a document. If it takes more than 60 seconds to read, it's too long.
- **Audience is non-developers** — no file paths, class names, property names, or technical jargon unless the story itself uses those terms
- **Short enough to paste into Teams** — the entire document should be readable in under 1 minute
- **"What Won't Change" is proactive** — stakeholders often worry about regressions. Address it before they ask. Keep to 2-3 bullets.
- **Scope is qualitative** — never give time estimates. Small/Medium/Large with one sentence justification in business terms ("adding fields to existing component", "new component from scratch", "changes across multiple pages"). Never justify scope with implementation details ("one config file", "no Java code", "just XML changes").
- **Open Questions are for the BA, not for yourself** — only include questions about unclear *requirements*, missing *design* specs, or *process* gaps. Never include implementation-level concerns (widget compatibility, script behavior, API version issues) — those are your problem to solve, not the BA's. Pull only from `dor-report.md` Open Questions (or `checklist.md` if dor-report.md doesn't exist) with tags `[req]`, `[design]`, `[process]`. Top 3 max, one line each.
- **Two modes, same quality** — pre-plan mode derives approach from `explain.md` + `research.md` (general strategy). Post-plan mode translates `implement.md` into plain language (more specific). Both produce a useful summary. Never warn about missing `implement.md`.

## ADO/Jira Comment Posting (idempotent)

Post the share-plan as a comment on the work item. Extract the work item ID or issue key from `raw-story.md`.

Before posting, check for an existing comment to avoid duplicates:

1. Fetch existing comments:
   ```
   mcp__ado__wit_list_work_item_comments
     project: "<ADO project from config>"
     workItemId: <id>
   ```

   ### If provider = jira

   Comments are included in the `jira_get_issue` response. Fetch the issue and search `fields.comment.comments[].body` for the signature `[DevPlan] Development Plan`:
   ```
   mcp__atlassian__jira_get_issue
     issue_key: "<issue key>"
   ```

2. Search for a comment containing the signature `[DevPlan] Development Plan`.

3. If found:
   - Compare key content: scope, assumption count, open question count, change bullets
   - If unchanged → print `ADO comment already up to date — skipping` and skip
   - If changed → post a **minimal update comment** (not a full repeat):
     ```
     ### [DevPlan] Plan Updated
     **Scope:** <scope>
     **Changes:** <1-2 bullet summary of what changed, e.g. "2 assumptions resolved after DoR update">
     ```

4. If not found → post full comment using template.

**Post:**
```
mcp__ado__wit_add_work_item_comment
  project: "<ADO project from config>"
  workItemId: <id>
  format: "markdown"
  comment: "<condensed share-plan>"
```

### If provider = jira

```
mcp__atlassian__jira_add_comment
  issue_key: "<issue key>"
  comment: "<condensed share-plan>"
```

Comments support wiki markup on Jira Server/DC. No `format` parameter needed.

Read `.ai/templates/ado-comments/share-plan.md.template` and follow that structure. Fill in from the generated `share-plan.md`.

If posting fails, print a warning but do NOT fail — the local `share-plan.md` is the primary output.

## Rules

- **Zero technical jargon** — if you find yourself writing a class name, file path, or framework-specific term, rephrase it. Exception: terms the BA used in the original story.
- **Honest scope assessment** — don't minimize to look fast or maximize to look busy. Base it on evidence.
- **No time estimates** — never. Not even "should be quick" or "this will take a while."
- **Preserve the developer's voice** — this reads as "here's what I plan to do" not a formal specification. First person is fine.
- **Idempotent posting** — always check for existing `[DevPlan]` comment before posting. Never create duplicate comments.

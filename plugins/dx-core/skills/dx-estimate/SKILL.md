---
name: dx-estimate
description: Analyze an Azure DevOps/Jira User Story and produce a structured estimation — understanding, implementation plan, recommended hours/SP, AEM pages affected, and open questions. Posts result as an ADO/Jira comment. Batch mode: space-separated IDs for parallel estimation. Use when you want an AI-generated estimation for a story.
argument-hint: "<Work Item ID(s) — space-separated for batch>"
disable-model-invocation: true
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

You are a coordinator. You do NOT implement anything yourself. You delegate each analysis step to a subagent via the Agent tool, then synthesize results and post an estimation comment.

## Argument

The argument is one or more ADO work item IDs — numeric values (e.g., `2435084`) or Jira issue keys, space-separated for batch mode.

If the user provides a full ADO URL like `https://dev.azure.com/{org}/{project}/_workitems/edit/{id}`, extract the numeric ID.

If no argument is provided, ask the user for the work item ID(s).

Parse the argument: split on whitespace to produce a list of IDs.

### Single or batch?

- If 1 ID: continue to "Execution Order" below
- If 2+ IDs: continue to "Batch Mode"

### Batch Mode

For each ID, use the Agent tool to dispatch a subagent with prompt: `Run /dx-estimate <id>`

Run all agents **in parallel**. Each subagent runs the full estimation flow independently (fetch → explain → research → synthesize → post ADO comment). Each produces its own spec files and ADO comment — identical output to running `/dx-estimate <id>` individually.

After all agents complete, print a summary table:

```markdown
## Batch Estimation Summary

| ID | Title | BE | FE | Auth | Total | SP | Questions | Status |
|----|-------|----|----|------|-------|----|-----------|--------|
| <id> | <title> | Xh | Xh | Xh | Xh | X | X | Posted |
| ... | ... | ... | ... | ... | ... | ... | ... | ... |
```

Then STOP — do not continue to the single-ticket flow below.

## Execution Order

```
Step 1: fetch     → raw-story.md
Step 2: explain   → explain.md
Step 3: research  → research.md
Step 4: synthesize estimation + post ADO comment
```

**Idempotent by default:** Steps 1-3 check if output files already exist and are still valid before regenerating. Step 4 checks for an existing estimation comment (by signature) and updates it instead of duplicating.

## Instructions

### 1. Dispatch steps 1–3 sequentially

For each step, use the Skill tool to invoke the skill in a fork. Wait for each to return before starting the next.

**Step 1 — Fetch:**
```
Invoke /dx-req <id> (Phase 1 only — fetch)
```
Print: `Step 1/4 done —` followed by the summary.

**Step 2 — Explain:**
```
Invoke /dx-req <id> (Phase 3 only — explain)
```
Print: `Step 2/4 done —` followed by the summary.

**Step 3 — Research:**
```
Invoke /dx-req <id> (Phase 4 only — research)
```
Print: `Step 3/4 done —` followed by the summary.

### 2. Synthesize estimation (step 4)

Find the spec directory (`.ai/specs/<id>-*/`). Read:
- `raw-story.md` — original story content, title, acceptance criteria
- `explain.md` — distilled requirements, areas of change, repos required
- `research.md` — files to modify, existing components, cross-repo scope

From these, build the estimation:

#### 2a. Understanding

Write 2-3 sentences describing what needs to be done in plain language. Mention which layers are affected (backend, frontend, authoring, cross-repo).

#### 2b. Implementation Plan

Write a short bullet list of concrete changes needed. Group by layer:
- **Backend** — models, exporters, services, OSGi config
- **Frontend** — JS components, SCSS, HBS templates
- **Authoring** — dialog fields, content policies, page templates
- **Cross-repo** — if `research.md` indicates cross-repo scope

Each bullet should be 1 line: `<Layer> — <what changes>`.

#### 2c. AEM Pages Affected

If `research.md` or `explain.md` mentions specific AEM components being modified:
1. Search the codebase for the component name to identify it
2. Use the `aem-component` skill pattern — search `.ai/project/component-index-project.md` or `.ai/project/component-index.md` for the component name to find which pages use it
3. List the pages (max 10). If more than 10, say "X+ pages — broad impact"

If no component changes are identified, write: "N/A — no component changes identified"

#### 2d. Estimation Heuristics

Apply these guidelines to estimate hours per group. These are guidelines, not rigid formulas — use judgment based on the specific requirements:

| Complexity | Hours | SP | When |
|------------|-------|----|------|
| Config/dialog only | 4-8h | 1-2 | OSGi config, dialog field toggle, content policy |
| Single variation | 12-20h | 3-5 | New component variation, multi-file in one layer |
| New component | 32-52h | 8-13 | Cross-layer, new models + JS + SCSS + dialog |
| Large feature | 52-80h | 13-21 | Multi-component, new services, complex logic |

**Adjustments:**
- Cross-repo scope: +30% overhead (coordination, separate PRs, deployment order)
- Authoring changes: +4h base (dialog updates, content migration, author testing)
- Existing similar component to copy from: -20% (pattern is established)
- Unclear/ambiguous requirements: +20% risk buffer

Break down hours by group:
- **Backend (BE):** Sling Models, exporters, services, OSGi config
- **Frontend (FE):** JS component, SCSS, HBS template, icons
- **Authoring:** Dialog XML, content policies, page template, content updates

Total SP = round to nearest Fibonacci (1, 2, 3, 5, 8, 13, 21).

#### 2e. Open Questions

List specific ambiguities from `explain.md` and `research.md` that could change the estimate:
- Missing design specs or Figma links
- Unclear acceptance criteria
- Dependency on backend API not yet available
- Multi-market scope unclear (which markets need this?)

### 3. Post ADO Comment

Read `.ai/config.yaml` to get the ADO project name (`ado.project` or `scm.ado-project`).

**Check for existing estimation comment:**

Use `mcp__ado__wit_list_work_item_comments` to list existing comments on the work item. Search for one containing the signature `<!-- ai:role:estimation-agent -->`.

### If provider = jira

Comments are included in the `jira_get_issue` response. Fetch the issue and search `fields.comment.comments[].body` for `<!-- ai:role:estimation-agent -->`:
```
mcp__atlassian__jira_get_issue
  issue_key: "<issue key>"
```

- If found: use `mcp__ado__wit_update_work_item_comment` (or post a new comment — whichever the MCP supports) to update it. For Jira, use `mcp__atlassian__jira_edit_comment` if updating.
- If not found: post a new comment

**Dry run check:** If the user's prompt includes "dry run" (case-insensitive), print the estimation to stdout and do NOT post to ADO. Print: `(Dry run — estimation not posted to ADO)`

**Comment format:**

```markdown
## Estimation: <Title> (#<id>)

### Understanding
<2-3 sentences>

### Implementation Plan
- <Layer> — <description>
- ...

### Recommended Estimation

| Group | Hours | Rationale |
|-------|-------|-----------|
| Backend | Xh | <reason> |
| Frontend | Xh | <reason> |
| Authoring | Xh | <reason> |
| **Total** | **Xh** | Suggested SP: **X** |

### AEM Pages Affected
<list or N/A>

### Open Questions
1. <question>
...

---
*AI-generated estimate based on codebase analysis. Validate with the team.*

<!-- ai:role:estimation-agent -->
```

Post the comment:
```
mcp__ado__wit_add_work_item_comment
  project: "<ADO project>"
  workItemId: <id>
  text: "<comment markdown>"
  format: "markdown"
```

### If provider = jira

```
mcp__atlassian__jira_add_comment
  issue_key: "<issue key>"
  comment: "<comment markdown>"
```

### 4. Final Summary

Print to the user:

```markdown
## Estimation Posted — ADO #<id>

**<Title>**
**Suggested SP:** <X> (~<Y>h total)
**Directory:** `.ai/specs/<id>-<slug>/`

| Group | Hours |
|-------|-------|
| Backend | Xh |
| Frontend | Xh |
| Authoring | Xh |

**Open questions:** <count>
**AEM pages affected:** <count or N/A>

### Next Steps
1. Review estimation comment on the ADO work item
2. Discuss open questions with BA/PO
3. Set Story Points on the work item
4. `/dx-req-tasks <id>` — break down into child tasks with hour estimates
```

### 5. Log Run

After the final summary, log this run for project learning.

**5a. Ensure directory:**
```bash
mkdir -p .ai/learning/raw
```

**5b. Append run record:**

Append one JSONL line to `.ai/learning/raw/runs.jsonl`:
```json
{"timestamp":"<ISO-8601>","ticket":"<id>","flow":"estimation","steps":{"raw-story":"<created|updated|skipped>","explain":"<created|updated|skipped>","research":"<created|updated|skipped>","estimation":"posted"},"failed":false}
```

Use Bash to append — `echo '<json>' >> .ai/learning/raw/runs.jsonl`

## Examples

1. `/dx-estimate 2416553` — Fetches the story, distills requirements, researches the codebase, then synthesizes an estimation: BE 16h + FE 12h + Authoring 4h = 32h total, suggested SP: 8 (Fibonacci). Posts the estimation as an ADO comment with the `<!-- ai:role:estimation-agent -->` signature.

2. `/dx-estimate 2416553 2416554 2416555` — Batch mode. Spawns parallel subagents, each running the full estimation flow. Each story gets its own spec files, ADO comment, and estimation. Prints a summary table at the end.

3. `/dx-estimate 2416553 dry run` — Runs the same analysis but prints the estimation to stdout without posting to ADO. Useful for reviewing the estimate before committing it to the work item.

4. `/dx-estimate 2435084` (re-run) — Finds existing spec files (raw-story.md, explain.md, research.md) from a previous run, skips regeneration, and updates the existing estimation comment (detected by signature) instead of creating a duplicate.

## Troubleshooting

- **Estimation seems too high or too low**
  **Cause:** The heuristics are guidelines, not exact formulas. Complex cross-repo stories or simple config changes can skew estimates.
  **Fix:** The estimate is advisory. Discuss open questions with the team and adjust Story Points based on team velocity and domain knowledge.

- **ADO comment posting fails**
  **Cause:** ADO PAT lacks "Work Items: Read & Write" permission, or the work item is in a closed state that doesn't accept comments.
  **Fix:** The skill prints the estimation to stdout so you can copy-paste it manually. Check PAT permissions and work item state.

- **"No spec files found" after research step**
  **Cause:** The fetch or explain step failed silently, leaving the spec directory empty.
  **Fix:** Check the step-by-step output for error messages. Run `/dx-req <id>` manually to diagnose.

## Error Handling

If any agent returns `FAIL`:

1. Print the failure with the agent's error message
2. Retry the failed step **once** with the same agent
3. If still failing:
   - Print which step failed and the error
   - Print which steps succeeded and their outputs
   - Suggest running the individual skill manually: "Run `/dx-<skill>` to retry this step"
   - **Do NOT continue past a failed step** if subsequent steps depend on its output (steps 1→2→3→4 are strictly sequential)

If the ADO comment posting fails:
- Print the estimation to stdout so the user can copy-paste it manually
- Print: `Failed to post comment to ADO. Copy the estimation above and paste it manually.`

## Rules

- **You are coordinator only** — all analysis happens inside the agent's isolated context (steps 1-3)
- **Never implement steps yourself** — always delegate via Agent tool for steps 1-3
- **Step 4 (synthesis) is yours** — you read the spec files and build the estimation
- **Sequential dependencies are strict** — never dispatch step N+1 until step N returns OK
- **Keep main context lean** — you only see compact summaries from steps 1-3, not file contents (until step 4)
- **Progress reporting** — print status after each step so the user can see progress
- **Same quality as individual skills** — running `/dx-estimate` reuses the same fetch/explain/research output as running each skill separately
- **Advisory only** — estimation is a recommendation, not a commitment. Always include the disclaimer.

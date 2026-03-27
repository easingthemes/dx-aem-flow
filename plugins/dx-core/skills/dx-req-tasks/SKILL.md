---
name: dx-req-tasks
description: Create or close child Task work items under an Azure DevOps/Jira User Story. Use to break down a story into FE/BE/Authoring tasks with hour estimates, or use "close" argument to close all child tasks after development is done.
argument-hint: "[Work Item ID] [BE|FE|Authoring] or [Work Item ID] close"
---

You create child Task work items under a parent User Story in Azure DevOps or Jira. You read the story, infer which work groups apply (BE, FE, Authoring), plan tasks with hour estimates that match the Story Points budget, present the plan for user approval, then create the tasks via ADO or Jira MCP.

## Defaults

Read `shared/provider-config.md` for provider detection and field mapping.

1. Read `.ai/config.yaml`
2. Check `tracker.provider` (preferred) or `scm.provider` (legacy fallback):
   - `ado` → Azure DevOps (default if not set)
   - `jira` → Atlassian Jira
3. Set `provider` variable for branching in subsequent steps.

### If provider = ado

- **Organization:** read from `.ai/config.yaml` `scm.org`
- **Project:** read from `.ai/config.yaml` `scm.project`

### If provider = jira

- **Jira URL:** read from `.ai/config.yaml` `jira.url`
- **Project Key:** read from `.ai/config.yaml` `jira.project-key`
- **Child Issue Type:** read from `.ai/config.yaml` `jira.child-issue-type` (default: `Sub-task`)

## 1. Parse Input

The first token of `$ARGUMENTS` is the work item ID (numeric for ADO, `KEY-123` for Jira) or a full URL.

If the user provides a URL, extract the ID/key from it. Supported formats:
- ADO: `https://dev.azure.com/{org}/{project}/_workitems/edit/{id}`
- ADO: `https://{org}.visualstudio.com/{project}/_workitems/edit/{id}`
- Jira: `https://{instance}/browse/{KEY-123}`

Input detection (see `shared/provider-config.md`):
- Matches `/^[A-Z]+-\d+$/` → Jira issue key
- Matches `/^\d+$/` → numeric ID; check `tracker.provider`
- Contains `dev.azure.com` or `visualstudio.com` → ADO
- Contains `/browse/` → Jira

Remaining tokens are optional **group filters**: `BE`, `FE`, `Authoring` (case-insensitive). If provided, only create tasks for those groups.

```
/dx-req-tasks 2416553              → all groups (inferred)
/dx-req-tasks 2416553 BE           → only BE tasks
/dx-req-tasks 2416553 FE BE        → only FE + BE tasks
/dx-req-tasks 2416553 Authoring    → only Authoring tasks
/dx-req-tasks 2416553 close        → close all child tasks
```

If no argument is provided, ask the user for the work item ID.

**If `close` is in the arguments:** Skip steps 2-10. Jump to **Close Mode** (at the end of this skill).

## 2. Load MCP Tools

Before making any ADO calls, load the required tools:

```
ToolSearch("+ado wit")
```

## 3. Fetch Parent Story

```
mcp__ado__wit_get_work_item
  project: "<ADO project from config>"
  id: <work item ID>
  expand: "relations"
```

Extract:
- **Title** — full title string
- **Story Points** — `Microsoft.VSTS.Scheduling.StoryPoints` (number)
- **Area Path** — `System.AreaPath`
- **Iteration Path** — `System.IterationPath`
- **Assigned To** — `System.AssignedTo` (the person assigned to the parent story — used to assign child tasks)
- **Description** — `System.Description` (HTML)
- **Acceptance Criteria** — `Microsoft.VSTS.Common.AcceptanceCriteria` (HTML)
- **State** — `System.State`
- **Existing children** — from relations (`System.LinkTypes.Hierarchy-Forward`)

### If provider = jira

```
mcp__atlassian__jira_get_issue
  issue_key: "<issue key>"
```

Map fields:
- **Story Points** — `fields.story_points` or `fields.<jira.custom-fields.story-points>` (read from config)
- **Components** — `fields.components[].name` (ADO equivalent: Area Path)
- **Sprint** — `fields.sprint.name` (ADO equivalent: Iteration Path)
- **Assigned To** — `fields.assignee.displayName`
- **Existing children** — fetch via JQL: `mcp__atlassian__jira_search` with `parent = <issue_key> AND issuetype = Sub-task`

If Story Points is missing or 0, ask the user: "Story has no Story Points set. How many SP should I use for budget?"

Calculate **total budget hours** = Story Points × 8.

## 4. Fetch Existing Child Tasks

Always check for existing children from the relations extracted in step 3. If child IDs exist, fetch their details:

```
mcp__ado__wit_get_work_items_batch_by_ids
  project: "<ADO project from config>"
  ids: [<child IDs>]
  fields: ["System.Title", "System.WorkItemType", "System.State",
           "Microsoft.VSTS.Scheduling.OriginalEstimate",
           "Microsoft.VSTS.Scheduling.RemainingWork"]
```

Filter to only **Task** type work items (ignore Bugs, Test Cases, etc.).

### If provider = jira

Children are fetched in Step 3 via JQL search. For each child sub-task returned:
- **Key** — issue key (e.g., `PROJ-124`)
- **Title** — `fields.summary`
- **State** — `fields.status.name`
- **Original Estimate** — `fields.timeoriginalestimate` (in seconds — divide by 3600 for hours)
- **Remaining Work** — `fields.timeestimate` (in seconds — divide by 3600 for hours)

For each existing Task, record:
- **ID** — work item number
- **Title** — to detect group (starts with `BE -`, `FE -`, `Authoring -`)
- **State** — New, Active, Closed, etc.
- **Original Estimate** — hours already allocated
- **Remaining Work** — hours remaining

### Estimate missing hours on existing tasks

If an existing Task has no OriginalEstimate (null or 0), infer an estimate based on the task title and parent story content:

| Title pattern | Inferred hours |
|---------------|---------------|
| `BE - PR Review` or `FE - PR Review` | 1 |
| `* - Unit Tests` | 3 |
| `* - Testing` | 2 |
| `* - Planning` | 1 |
| `* - Implement *` or other implementation tasks | 8 |
| `Authoring - *` (any authoring task) | 4 |
| Anything else unclear | 4 (default) |

Mark inferred estimates with `(inferred)` in the display so the user can see which ones were guessed. These inferred values are used for budget calculation and will be proposed for update in the confirmation step.

### Calculate existing budget usage

```
existing_hours = sum of OriginalEstimate (actual or inferred) across all existing Tasks
remaining_budget = (story_points × 8) - existing_hours
```

### Display existing tasks

If existing Tasks are found, print them:

```markdown
### Existing Tasks (<existing_count> tasks, <existing_hours>h allocated)

| ID | Title | Hours | State |
|----|-------|-------|-------|
| #12345 | BE - Implement Sling Model | 8 | Active |
| #12346 | FE - PR Review | 1 (inferred) | New |

**Budget:** <budget>h total, <existing_hours>h allocated, **<remaining_budget>h remaining**
```

Tasks with `(inferred)` hours will have their estimates set in ADO after user confirmation (step 9).

### Determine action

- If `remaining_budget > 0` → plan new tasks for the remaining hours
- If `remaining_budget = 0` → print "Budget fully allocated. No new tasks needed." and stop (unless user requests specific additions)
- If `remaining_budget < 0` → warn: "Existing tasks exceed budget by Xh. Proceed with planning additional tasks anyway?" Wait for confirmation.

### Avoid duplicates

When planning new tasks (step 6), skip any task that already exists by matching title prefix patterns:
- If `BE - PR Review` already exists → don't create another
- If `FE - Testing` already exists → don't create another
- Match on the title pattern, not exact string (e.g., existing `BE - Implement model changes` covers the `BE - Implement` slot)

### Estimate update mode

If **all groups already have tasks** but some tasks have **no estimates** (OriginalEstimate is null/0), switch to **estimate-only mode**:
1. Skip task creation (step 8)
2. Present existing tasks with inferred estimates marked `(inferred)`
3. After user approval, update estimates on existing tasks via `wit_update_work_items_batch` (step 9)
4. Print summary with updated estimates

### Mixed mode (new tasks + missing estimates)

If there are **both** existing tasks without estimates **and** remaining budget for new tasks:
1. Show existing tasks with inferred estimates in the "Existing Tasks" section
2. Show new tasks in the "New Tasks" section
3. After approval, create new tasks (step 8) AND update estimates on existing tasks (step 9) in the same run

## 5. Infer Groups

Reference `.claude/rules/` for domain-specific naming conventions and group signals.

### From title tags

Parse square bracket tags from the title: `[BE]`, `[FE]`, `[Authoring]`.

- `[BE]` → include BE group
- `[FE]` → include FE group
- `[Authoring]` → include Authoring group

### From content (if no tags found)

If the title has no recognizable tags, analyze the Description and Acceptance Criteria:

| Signal | Group |
|--------|-------|
| Mentions model, exporter, Java, service, backend, API, servlet, controller | BE |
| Mentions frontend, rendering, template, CSS, JavaScript, UI, design, component markup | FE |
| Mentions dialog, authoring, content author, configuration, CMS | Authoring |

If nothing is clear from content, default to **all three groups**.

### Apply user filter

If the user passed group filters in the arguments, override the inferred groups. Only create tasks for the specified groups.

### Component lookup (optional)

If the story title or description mentions a specific component name and a component index exists (`.ai/project/component-index.md` or `.ai/component-index.md`), grep it for the component:

```
Grep(".ai/project/component-index.md", "<component-name>")
```

This helps generate more specific implementation task titles (e.g., "BE - Update StarterKitExporter" instead of generic "BE - Implement exporter").

## 6. Plan Tasks

For each active group, generate tasks. Follow these constraints:

| Group | Max Tasks | Permanent Tasks | Nature |
|-------|-----------|-----------------|--------|
| BE | 5 | `BE - PR Review` (1h), `BE - Unit Tests` (2-4h) | Development (models, services) |
| FE | 5 | `FE - PR Review` (1h), `FE - Testing` (1-2h) | Development (templates, CSS, JS) |
| Authoring | 2 | *(none — no PR or testing)* | Content authoring (non-development) |

**Authoring is NOT development.** Authoring tasks are for content authors who configure components — editing dialogs, setting up content, verifying pages. There is no code, no PR, no unit tests. Authoring tasks are purely CMS authoring work.

### Implementation tasks (fill remaining slots)

Based on story content, create implementation tasks. Examples:

**BE:**
- `BE - Implement model` (6-10h)
- `BE - Update exporter` (6-10h)
- `BE - Implement service logic` (6-10h)

**FE:**
- `FE - Implement component rendering` (6-10h)
- `FE - Implement responsive styles` (6-10h)
- `FE - Update component template` (6-10h)

**Authoring:**
- `Authoring - Configure component dialog` (2-4h)
- `Authoring - Verify authored content` (1-2h)

### Optional tasks (add if budget allows)

- `BE - Planning` or `FE - Planning` (1-2h) — only if story is complex (3+ SP)

### Hour distribution rules

1. Total hours across ALL tasks MUST equal Story Points × 8
2. PR Review tasks: always 1h each
3. Testing/Unit Tests: 1-4h depending on complexity
4. Implementation tasks: 6-10h (typically 8h)
5. Planning: 1-2h
6. Distribute remaining hours by adjusting implementation task estimates
7. If budget is tight, reduce implementation task count rather than making tiny tasks
8. Minimum task estimate: 1h

### Distribution algorithm

```
total_budget = story_points × 8
existing_hours = sum of OriginalEstimate from existing child Tasks (step 4)
remaining_budget = total_budget - existing_hours
groups = active groups (1-3), minus groups fully covered by existing tasks

# Split remaining_budget proportionally across groups that need new tasks
if all 3 groups need tasks:
  BE gets ~45%, FE gets ~40%, Authoring gets ~15%
if BE + FE only:
  BE gets ~50%, FE gets ~50%
if single group:
  that group gets 100%

# Within each group:
1. Skip permanent tasks that already exist (matched in step 4)
2. Allocate remaining permanent tasks first (PR Review 1h, Testing/Unit Tests)
3. Fill remaining group budget with implementation tasks
4. Adjust implementation task hours to consume exact remaining_budget
```

## 7. Present Plan for Approval

Print the task breakdown table. If existing tasks were found, show both sections:

```markdown
## Task Breakdown — Story #<id> (<story_points> SP = <budget>h)

**<Story Title>**
**Groups:** BE, FE, Authoring
**Area Path:** <area_path>
**Iteration:** <iteration_path>

### Existing Tasks (already in ADO)

| ID | Group | Title | Hours | State |
|----|-------|-------|-------|-------|
| #12345 | BE | BE - Implement model | 8 | Active |
| #12346 | FE | FE - PR Review | 1 | New |
| | | **Subtotal** | **9** | |

### New Tasks (to be created)

| # | Group | Task Title | Hours |
|---|-------|-----------|-------|
| 1 | BE | BE - Unit Tests | 3 |
| 2 | BE | BE - PR Review | 1 |
| 3 | FE | FE - Implement component rendering | 8 |
| 4 | FE | FE - Testing | 2 |
| 5 | Authoring | Authoring - Configure dialog | 4 |
| 6 | Authoring | Authoring - PR Review | 1 |
| | | **Subtotal** | **19** |

> **Budget:** 28h (3.5 SP × 8h) = 9h existing + 19h new ✓ Balanced

Want to adjust? You can:
- Remove a task: "remove #5"
- Add a task: "add FE - Update styles 4h"
- Change hours: "#4 to 6h"
- Change title: "#1 title BE - Update model"
- Or say **"go"** to create all tasks in ADO
```

If no existing tasks, omit the "Existing Tasks" section and show only "New Tasks".

### Handle adjustments

If the user requests changes:
1. Apply the changes to the plan
2. **Recalculate** total hours
3. If total no longer matches budget, warn: "Total is now Xh but budget is Yh. Adjust other tasks to balance, or proceed anyway?"
4. Re-print the updated table
5. Ask for confirmation again

Repeat until the user says "go", "create", "yes", "looks good", or similar affirmation.

## 8. Create Tasks in ADO

Once approved, create all tasks as children of the parent story:

```
mcp__ado__wit_add_child_work_items
  parentId: <story ID>
  project: "<ADO project from config>"
  workItemType: "Task"
  items: [
    {
      "title": "<task title>",
      "description": "",
      "areaPath": "<from parent>",
      "iterationPath": "<from parent>"
    },
    ...for each task
  ]
```

The response returns the created work item IDs.

### If provider = jira

Create each task as a Sub-task (one at a time — no batch creation with parent linking):

```
mcp__atlassian__jira_create_issue
  project_key: "<jira.project-key>"
  issue_type: "<jira.child-issue-type>"    # default: "Sub-task"
  summary: "<task title>"
  parent_key: "<parent issue key>"
  description: ""
```

Repeat for each task. The response returns the created issue key.

## 9. Set Estimates and Assign

After creation, set Original Estimate, Remaining Work, and Assigned To on **all newly created tasks**. Also set estimates on existing tasks that had missing estimates (marked `(inferred)` in step 4).

**Assignment rule:** All newly created tasks are assigned to the same person as the parent story (`System.AssignedTo`). If the parent has no assignee, leave tasks unassigned.

```
mcp__ado__wit_update_work_items_batch
  updates: [
    {
      "id": <task ID>,
      "path": "/fields/Microsoft.VSTS.Scheduling.OriginalEstimate",
      "value": "<hours>"
    },
    {
      "id": <task ID>,
      "path": "/fields/Microsoft.VSTS.Scheduling.RemainingWork",
      "value": "<hours>"
    },
    {
      "id": <task ID>,
      "path": "/fields/System.AssignedTo",
      "value": "<parent story assignee email or display name>"
    },
    ...for each new task AND each existing task with inferred estimates
  ]
```

**Note:** Only set `System.AssignedTo` on **newly created** tasks. Do NOT reassign existing tasks — they may have been intentionally assigned to someone else.

### If provider = jira

For each created sub-task, set estimates and assignee:

```
mcp__atlassian__jira_update_issue
  issue_key: "<created sub-task key>"
  fields: {
    "timeoriginalestimate": <hours * 3600>,
    "timeestimate": <hours * 3600>,
    "assignee": {"name": "<parent assignee username>"}
  }
```

**Note:** Jira stores time estimates in **seconds**, not hours. Multiply by 3600.

In **estimate-only mode** (no new tasks), this is the only ADO write operation — skip step 8 entirely. Do NOT change assignment on existing tasks in estimate-only mode.

## 10. Print Summary

```markdown
## Created <N> Tasks under Story #<id>

| # | ID | Title | Hours | Link |
|---|-----|-------|-------|------|
| 1 | #<id> | BE - Implement model | 8 | [Open]({scm.org}/{scm.project_url_encoded}/_workitems/edit/<id>) |
| 2 | #<id> | BE - Unit Tests | 3 | [Open](...) |
| ... | | | | |
| | | **Total** | **<budget>h** | |

All tasks linked as children of [#<story_id>]({scm.org}/{scm.project_url_encoded}/_workitems/edit/<story_id>).
```

Where `{scm.org}` and `{scm.project_url_encoded}` are read from `.ai/config.yaml`.

**If provider = jira:**
| # | Key | Title | Hours | Link |
|---|-----|-------|-------|------|
| 1 | PROJ-124 | BE - Implement model | 8 | [Open]({jira.url}/browse/PROJ-124) |

## Close Mode

When the argument contains `close`, this skill closes all open child tasks under the story.

### C1. Load MCP Tools

```
ToolSearch("+ado wit")
```

### C2. Fetch Parent Story + Children

```
mcp__ado__wit_get_work_item
  project: "<ADO project from config>"
  id: <work item ID>
  expand: "relations"
```

Extract child Task IDs from relations (`System.LinkTypes.Hierarchy-Forward`).

If no children found, print "No child tasks found." and STOP.

Fetch child details:
```
mcp__ado__wit_get_work_items_batch_by_ids
  project: "<ADO project from config>"
  ids: [<child IDs>]
  fields: ["System.Title", "System.WorkItemType", "System.State",
           "Microsoft.VSTS.Scheduling.OriginalEstimate",
           "Microsoft.VSTS.Scheduling.RemainingWork",
           "Microsoft.VSTS.Scheduling.CompletedWork"]
```

Filter to **Task** type only.

### C3. Determine Which Tasks to Close

**Closeable:** Tasks in state `New`, `Active`, or `In Progress` (not already `Closed`, `Removed`, or `Resolved`).

If no closeable tasks, print "All tasks already closed." and STOP.

### C4. Verify Development is Done

Check that development is actually complete before closing:

1. Find spec dir: `bash .ai/lib/dx-common.sh find-spec-dir <work-item-id>`
2. If `implement.md` exists, check that all steps are `done`
3. If any steps are NOT `done`, warn:
   ```
   ⚠ implement.md has <N> incomplete steps. Close tasks anyway? (y/n)
   ```
   Wait for confirmation.

If no spec dir or no implement.md, skip this check (user may be closing manually).

### C5. Calculate Time Updates

For each closeable task, compute the time fields:

```
completed_work_new = (existing CompletedWork or 0) + (existing RemainingWork or 0)
remaining_work_new = 0
```

This moves whatever time was remaining into completed work — the task used its full budget.

### C6. Present Close Plan

```markdown
## Close Tasks — Story #<id>

| ID | Title | State | Original | Completed → | Remaining → |
|----|-------|-------|----------|-------------|-------------|
| #12345 | BE - Implement model | Active | 8h | 0 → 8h | 8 → 0h |
| #12346 | FE - PR Review | New | 1h | 0 → 1h | 1 → 0h |
| #12347 | BE - Unit Tests | Closed | 3h | (already closed) | |

**<N> tasks will be closed.** Proceed? (y/n)
```

Wait for user confirmation.

### C7. Close Tasks

For each closeable task, update in this order:
1. Set Completed Work (add remaining to completed)
2. Set Remaining Work to 0
3. Set State to Closed

```
mcp__ado__wit_update_work_items_batch
  updates: [
    {
      "id": <task ID>,
      "path": "/fields/Microsoft.VSTS.Scheduling.CompletedWork",
      "value": <completed_work_new>
    },
    {
      "id": <task ID>,
      "path": "/fields/Microsoft.VSTS.Scheduling.RemainingWork",
      "value": 0
    },
    {
      "id": <task ID>,
      "path": "/fields/System.State",
      "value": "Closed"
    },
    ...for each closeable task
  ]
```

### If provider = jira

```
mcp__atlassian__jira_update_issue
  issue_key: "<sub-task key>"
  fields: {
    "timespent": <completed_work_new * 3600>,
    "timeestimate": 0
  }
  transition: "Done"
```

**Note:** Jira transitions vary by workflow. Use `mcp__atlassian__jira_get_transitions` to find the "Done" transition ID if "Done" doesn't work by name. Jira stores time in **seconds** — multiply hours by 3600.

### C8. Print Summary

```markdown
## Closed <N> Tasks under Story #<id>

| ID | Title | Completed | Previous State |
|----|-------|-----------|---------------|
| #12345 | BE - Implement model | 8h | Active |
| #12346 | FE - PR Review | 1h | New |

**Total completed:** <sum>h
All child tasks closed. Remaining work zeroed, time moved to Completed Work.
```

## Examples

1. `/dx-req-tasks 2416553` — Fetches story #2416553, infers BE+FE+Authoring groups from the title and description, plans tasks with hours totaling Story Points x 8, presents the breakdown for approval, then creates child Tasks in ADO.

2. `/dx-req-tasks 2416553 FE` — Creates only Frontend tasks (FE - Implement component rendering, FE - Testing, FE - PR Review) under the story, skipping BE and Authoring groups.

3. `/dx-req-tasks 2416553` (with existing tasks) — Detects 3 existing child Tasks already consuming 24h of the 40h budget, plans new tasks for the remaining 16h, and fills in missing hour estimates on existing tasks marked `(inferred)`.

4. `/dx-req-tasks 2416553 close` — Fetches child tasks, checks implement.md steps are all done, shows close plan with time updates (Remaining Work → Completed Work), and after confirmation closes all tasks. Sprint burndown and capacity tracking stay accurate.

## Troubleshooting

- **"Story has no Story Points set"**
  **Cause:** The parent story lacks a Story Points value, which is needed to calculate the hour budget.
  **Fix:** Set Story Points on the ADO work item first, or answer the prompt with the SP value to use.

- **Budget exceeds or doesn't match total hours**
  **Cause:** Existing child tasks already exceed the SP x 8 budget, or manual adjustments shifted the total.
  **Fix:** The skill warns about the mismatch. You can say "proceed anyway" or adjust individual task hours in the interactive table before confirming.

- **"MCP tool not found" or ADO call fails**
  **Cause:** ADO MCP tools were not loaded, or the PAT lacks Work Items write permissions.
  **Fix:** Ensure `.mcp.json` has the ADO server configured (run `/dx-init` if not). Verify your ADO PAT has "Work Items: Read & Write" scope.

## Rules

- **Never create tasks without user approval** — always present the plan first (step 7)
- **Budget must balance** — total task hours = Story Points × 8h (warn if not, but allow override)
- **Be pragmatic** — infer groups from title tags and content, only ask if nothing is clear
- **Respect group filters** — if user specifies groups in arguments, only create those
- **Copy parent fields** — always set Area Path, Iteration Path, and Assigned To from the parent story
- **Assign to parent owner** — new tasks are assigned to the same person as the parent story. Never reassign existing tasks.
- **Task descriptions are empty** — only title and estimates matter
- **MCP tools are deferred** — always load via ToolSearch before first use
- **Work item IDs are integers** — pass as numbers to MCP, not strings

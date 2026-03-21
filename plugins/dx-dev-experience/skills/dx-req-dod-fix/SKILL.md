---
name: dx-req-dod-fix
description: Fix failed DoD criteria — auto-fix what's possible (tests, docs, changelog), create Task work items in ADO/Jira for the rest. Run after /dx-req-dod reports failures.
argument-hint: "[ADO Work Item ID, Jira Issue Key, or full URL]"
allowed-tools: ["read", "edit", "search", "write", "agent", "ado/*", "atlassian/*"]
---

You read DoD failures from `dod.md`, attempt to fix what's automatable, and create ADO/Jira Task work items for items requiring human judgment.

## 0. Provider Detection

Read `shared/provider-config.md` for provider detection and field mapping.

1. Read `.ai/config.yaml`
2. Check `tracker.provider` (preferred) or `scm.provider` (legacy fallback):
   - `ado` → Azure DevOps (default if not set)
   - `jira` → Atlassian Jira
3. Set `provider` variable for branching in subsequent steps.

## 1. Locate the Spec Directory

```bash
SPEC_DIR=$(bash .ai/lib/dx-common.sh find-spec-dir <work-item-id-if-provided>)
```

Read `$SPEC_DIR/dod.md`. If it doesn't exist, tell the user to run `/dx-req-dod <id>` first and STOP.

Parse the Results table — extract all FAIL criteria.

If no failures: print "All DoD criteria already pass — nothing to fix" and STOP.

Read `.ai/config.yaml` for project settings.

## 1.5. Cross-Repo Check (pipeline mode only)

If `DX_PIPELINE_MODE` is set:

1. Check if `$SPEC_DIR/research.md` exists and has a `## Cross-Repo Scope` section
2. If found, apply the same delegation logic as dx-bug-all Step 1.5:
   - If current repo (`SOURCE_REPO_NAME`) is NOT the target → write `delegate.json` and **STOP**
   - If current repo IS the target → continue, delegate to other repos after fixes
   - If map missing → warn and continue locally

If `DX_PIPELINE_MODE` is not set: skip (local mode).

Read `shared/repo-discovery.md` for full protocol details.

## 2. Categorize Failures

Classify each failure as auto-fixable or needs-human:

**Auto-fixable** (agent can fix directly):
- Missing documentation (`share-plan.md`) → generate from explain.md
- Missing test stubs → create test file skeletons from implement.md
- Incomplete implement.md steps → mark verified steps as done
- Open PR threads with "agree/will fix" → apply code changes from review comments

**Needs-human** (create Task work items):
- PR not approved → needs human reviewer
- Design decisions unresolved → needs BA/PO input
- Manual testing required → needs QA
- Stakeholder sign-off missing → needs PM

## 3. Auto-Fix Loop

For each auto-fixable failure, attempt the fix:

1. Print: `Fixing: <criterion> — <action>`
2. Execute the fix (write file, generate content, apply patch)
3. Verify the fix resolves the criterion
4. Print: `Fixed: <criterion>` or `Fix failed: <criterion> — <reason>`

Track results in a list: `{criterion, action, result: fixed|failed|skipped}`.

## 4. Create Task Work Items for Remaining Failures

For each needs-human failure, create a child Task work item in ADO via MCP:

- Title: `[DoD] <criterion description>`
- Description: `DoD check for ADO #<parent-id> failed: <failure details>\n\nHow to fix: <actionable instruction>`
- Parent: link to the original work item
- Assigned To: leave unassigned (or assign to the work item's assigned-to if appropriate)

Track created tasks: `{criterion, taskId, title}`.

### If provider = jira

Create fix tasks as Sub-tasks:

```
mcp__atlassian__jira_create_issue
  project_key: "<jira.project-key>"
  issue_type: "<jira.child-issue-type>"
  summary: "[DoD] <criterion description>"
  parent_key: "<parent issue key>"
  description: "DoD check for <parent issue key> failed: <failure details>\n\nHow to fix: <actionable instruction>"
```

Repeat for each needs-human failure. The response returns the created issue key.

## 5. Re-run DoD Check

After all fixes, re-evaluate DoD criteria (same logic as `/dx-req-dod` step 4).

Update `dod.md` with new results. Print the delta:
- Criteria that flipped from FAIL → PASS
- Criteria still failing (with created Task IDs)

## 6. Documentation Generation (optional)

If auto-fixes improved the score (at least some criteria flipped to PASS), invoke documentation generation:

1. Check if `/dx-doc-gen` skill is available
2. If available, invoke it:
   ```
   /dx-doc-gen <work-item-id>
   ```
3. Check if `/aem-doc-gen` skill is available (AEM project)
4. If available, invoke it:
   ```
   /aem-doc-gen <work-item-id>
   ```

**If skills not available:** Print: `Documentation generation skipped (doc-gen skills not installed).`
**If executed:** Print: `Documentation generated — wiki page + demo saved to docs/.`

## 7. Present Summary

```markdown
## DoD Fix: <Title> (ADO #<id>)

### Auto-Fixed
| Criterion | Action | Result |
|-----------|--------|--------|
| <criterion> | <what was done> | ✅ Fixed |

### Tasks Created (needs human)

**If provider = ado:**
| Criterion | Task | Assigned |
|-----------|------|----------|
| <criterion> | ADO #<task-id>: <title> | <assignee or unassigned> |

**If provider = jira:**
| Criterion | Task | Assigned |
|-----------|------|----------|
| <criterion> | [<issue-key>]({jira.url}/browse/<issue-key>): <title> | <assignee or unassigned> |

### Updated Score
**Before:** <N>/<total> → **After:** <M>/<total>
**Remaining failures:** <count>

<If all pass:>
**Verdict: Ready for QA** — all DoD criteria now met.

<If still failing:>
**Verdict: <M/10> passed.** <count> tasks created for remaining items. Assign and resolve them before proceeding.

### Documentation
| Document | Status |
|----------|--------|
| Wiki page | Generated / Skipped (skill not installed) |
| AEM demo | Generated / Skipped (not AEM project) |
```

## Examples

1. `/dx-req-dod-fix 2416553` — Reads `dod.md` for story #2416553, auto-fixes missing documentation and test stubs, creates ADO Task work items for items needing human review (e.g., "PR not approved"), then re-runs the DoD check and prints the updated score.

2. `/dx-req-dod-fix` (no argument) — Finds the most recent spec directory, reads its `dod.md`, and processes all FAIL criteria. Useful after running `/dx-req-dod` and seeing failures.

3. `/dx-req-dod-fix 2416553` (re-run) — Skips already-fixed criteria (idempotent), only processes remaining failures. If all criteria now pass, prints "All DoD criteria already pass."

## Troubleshooting

- **"dod.md not found"**
  **Cause:** The DoD check has not been run yet for this work item.
  **Fix:** Run `/dx-req-dod <id>` first to generate the DoD report, then re-run `/dx-req-dod-fix`.

- **Auto-fix marks a criterion as fixed but DoD re-check still fails**
  **Cause:** The fix was applied but the verification logic requires additional conditions (e.g., tests must actually pass, not just exist).
  **Fix:** Review the generated test stubs or documentation, fill in real content, and re-run `/dx-req-dod`.

- **Task work items created but not linked to parent story**
  **Cause:** ADO MCP call succeeded for creation but the parent link failed (permissions or API issue).
  **Fix:** Manually link the created Tasks to the parent story in ADO, or re-run the skill (it checks for existing tasks before creating duplicates).

## Rules

- **Read dod.md first** — never guess what failed, always read the structured report
- **Conservative auto-fixes** — only fix things the agent can verify. When in doubt, create a task instead
- **Never fake evidence** — don't mark tests as passing without running them, don't mark PR as approved without verifying
- **Idempotent** — if run twice, skip already-fixed criteria
- **Audit trail** — every auto-fix is traceable in the updated dod.md

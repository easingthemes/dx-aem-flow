# Bug Work Item Field Mapping

Maps ADO Bug work item fields to `raw-bug.md` sections. Read this before processing any Bug work item.

## Bug-Specific Fields

| ADO Field | API Name | raw-bug.md Section | Notes |
|-----------|----------|-------------------|-------|
| Steps to Reproduce | `Microsoft.VSTS.TCM.ReproSteps` | `## Steps to Reproduce` | HTML → markdown. Contains numbered steps + embedded URLs. |
| Expected Behavior | `Custom.Whatwasexpected` | `## Expected Behavior` | HTML → markdown. May be empty — omit section if so. |
| Actual Behavior | `Custom.Whatactuallyhappened` | `## Actual Behavior` | HTML → markdown. Often includes impact statement. May be empty. |
| Severity | `Microsoft.VSTS.Common.Severity` | Header line | Values: "1 - Critical", "2 - High", "3 - Medium", "4 - Low" |
| Priority | `Microsoft.VSTS.Common.Priority` | Header line | Values: 1, 2, 3, 4 |

## Shared Fields (same as User Stories)

| ADO Field | API Name | raw-bug.md Location |
|-----------|----------|-------------------|
| Title | `System.Title` | `# <title>` heading |
| State | `System.State` | Header metadata line |
| Assigned To | `System.AssignedTo.displayName` | Header metadata line |
| Area Path | `System.AreaPath` | Header metadata line |
| Iteration Path | `System.IterationPath` | Header metadata line |
| Tags | `System.Tags` | Header metadata line |
| Work Item Type | `System.WorkItemType` | Header metadata line (should be "Bug") |

## URL Extraction Rules

Bug repro steps often contain URLs. Extract them for bug-verify:

1. Parse `<a href="...">` tags from ReproSteps HTML
2. Parse raw URLs matching `https?://[^\s<>"]+` from converted markdown
3. Classify URLs:
   - **QA/Stage:** `qa.*`, `stage.*`, `uat.*` → primary repro target
   - **Production:** `www.*`, no subdomain → note but don't test against prod
   - **Local:** `localhost:*` → needs login handling
4. Store the primary repro URL prominently in raw-bug.md for bug-verify

## Branch Convention

Bug tickets use `bugfix/<id>-<slug>` prefix (not `feature/`).

Call `ensure-feature-branch.sh` with second argument:
```bash
bash shared/ensure-feature-branch.sh "$SPEC_DIR" bugfix
```

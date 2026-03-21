# Cross-Repo Discovery & Pipeline Delegation

Reference document for coordinator skills that need to detect and handle cross-repo work items.

## When This Applies

Code-writing agents (BugFix, DevAgent, DoD-Fix) run in ADO pipelines with `checkout: self` — they only have the repo where the pipeline YAML lives. If a work item requires changes in a different repo, the agent must delegate to that repo's pipeline.

Non-code agents (DoR, PR Review, PR Answer, DoD, QA, DOCAgent) don't need this — they read code but don't write it, or they're already scoped to the correct repo.

## How Cross-Repo Scope Is Detected

The triage/research skills already detect cross-repo scope and document it:

- **BugFix:** `triage.md` → `## Cross-Repo Scope` section
- **DevAgent:** `research.md` → `## Cross-Repo Scope` section
- **DoD-Fix:** `research.md` → `## Cross-Repo Scope` section (if present in spec dir)

The section contains a table:

```markdown
## Cross-Repo Scope

**Current repo:** <current-repo> (this fix covers only this repo)

| Repo | What's needed | Key files |
|------|--------------|-----------|
| <other-repo> | Backend exporter update | src/main/java/... |
```

## Pipeline Mode: Automatic Delegation

**When `DX_PIPELINE_MODE=true` is set** (only in ADO pipeline environments):

1. After triage/research completes, read the cross-repo output file
2. Check for `## Cross-Repo Scope` section
3. If present, parse the repo names from the table
4. For each target repo that is NOT the current repo (`SOURCE_REPO_NAME` env var):
   a. Look up pipeline ID from `CROSS_REPO_PIPELINE_MAP` env var
   b. Write `.ai/run-context/delegate.json` with delegation details
   c. Print delegation summary
   d. **STOP** — do not continue with local implementation

### delegate.json Format

```json
{
  "targetRepo": "<other-repo>",
  "pipelineId": "456",
  "reason": "Backend exporter update needed",
  "templateParameters": {
    "bugId": "12345",
    "eventId": "evt-001"
  }
}
```

The pipeline YAML has a post-Claude step that reads this file and queues the target pipeline via ADO REST API using `System.AccessToken`.

### CROSS_REPO_PIPELINE_MAP

JSON pipeline variable mapping repo names to pipeline IDs of the same agent type:

```json
{"Other-Repo": "789", "Another-Repo": "790"}
```

Each code-writing pipeline has its own map — BugFix maps to BugFix pipelines in other repos, DevAgent maps to DevAgent pipelines, etc.

### What if the current repo also needs changes?

If `## Cross-Repo Scope` lists the current repo AND other repos, **do both**:
1. Continue with local implementation (current repo is a target)
2. After completing local work, write `delegate.json` for the other repos

### What if `CROSS_REPO_PIPELINE_MAP` is empty or missing the repo?

Print a warning and continue with local implementation:
```
⚠ Cross-repo scope detected (<other-repo>) but no pipeline mapped. Set CROSS_REPO_PIPELINE_MAP pipeline variable.
```

## Local Mode: Manual Handoff (unchanged)

**When `DX_PIPELINE_MODE` is NOT set** (local developer usage):

1. Cross-repo scope appears in the final summary (current behavior)
2. The agent prints: `Run /dx-bug-all <id> in <other-repo>`
3. The developer manually switches to the other repo and runs the command

No delegation file is written. No pipeline is queued. The developer controls the workflow.

## Environment Variables

| Variable | Set by | Purpose |
|----------|--------|---------|
| `DX_PIPELINE_MODE` | Pipeline YAML | Enables automatic delegation |
| `SOURCE_REPO_NAME` | Pipeline YAML | Current repo name (from `Build.Repository.Name`) |
| `CROSS_REPO_PIPELINE_MAP` | Pipeline variable | JSON: repo name → pipeline ID |
| `SYSTEM_ACCESSTOKEN` | Pipeline YAML | ADO build token for REST API calls |

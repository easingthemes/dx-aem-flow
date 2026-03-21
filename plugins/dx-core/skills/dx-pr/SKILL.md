---
name: dx-pr
description: Create a pull request after all plan steps are complete. Verifies all steps are done, generates PR description from share-plan.md, pushes branch, and creates PR via ADO MCP tools. Use as the final step in the execution pipeline.
argument-hint: "[Work Item ID or slug (optional — uses most recent if omitted)]"
allowed-tools: ["read", "edit", "search", "write", "agent", "ado/*"]
---

You create a pull request for the completed implementation.

**Before anything else**, read these files:
- `shared/git-rules.md` — all git/ADO conventions (base branch discovery, repo ID discovery, PR creation, rebase)
- `.ai/config.yaml` — project config, SCM settings

Follow every rule in `git-rules.md`. The steps below assume you have read it.

## Hub Mode Check

Read `shared/hub-dispatch.md` for hub detection logic.

If hub mode is active (`hub.enabled: true` AND cwd is `.hub/`):
1. Read `.ai/config.yaml` → `repos:` list
2. Determine which repos have completed work for this ticket:
   - Check `state/<ticket-id>/results/` for repos with `status: completed`
   - Or: check each repo for a feature branch matching the ticket ID
3. For each repo with completed work:
   - If `repos[].no-pr: true` → skip, print: `<repo> — pushed (no PR)`
   - Otherwise: dispatch `claude -p "/dx-pr <ticket-id>" --cwd <repo.path> --output-format json --allowedTools "Bash,Read,Edit,Write,Glob,Grep" --permission-mode trust`
   - Collect PR URLs from results
4. Write state, print summary:
   ```
   PRs created:
     - Repo-A: #38001 (https://...)
     - Repo-B: pushed (no PR)
   ```
5. STOP

If hub mode is not active: continue with normal flow below.

## Persona (optional)

If `.ai/me.md` exists, read it. Use it to shape the PR description text. PR format constraints (summary + changes + test plan) always apply. If `.ai/me.md` doesn't exist, use defaults.

## 1. Locate the Spec Directory

```bash
SPEC_DIR=$(bash .ai/lib/dx-common.sh find-spec-dir $ARGUMENTS)
```

Read `implement.md` from `$SPEC_DIR`.

## 2. Verify All Steps Done

Parse implement.md and check that ALL steps have `**Status:** done`.

If any step is `pending`, `in-progress`, or `blocked`:
- Print which steps are incomplete
- Print: "Not all steps are done. Complete remaining steps with `/dx-step` or `/dx-step-all` first."
- STOP

### Branch Readiness Check

If `superpowers:finishing-a-development-branch` is available, invoke it to verify branch readiness.

**Fallback (if superpowers not installed):** Before pushing:
1. Run the project's test suite — if tests fail, STOP.
2. Check for uncommitted changes — commit or stash.
3. Verify the branch targets the correct base (`development`, not `master`/`main`).

## 3. Setup

1. **Discover base branch** — per git-rules.md
2. **Discover repo ID** — per git-rules.md (use `mcp__ado__repo_get_repo_by_name_or_id`)

## 4. Gather PR Content

Read from `$SPEC_DIR`:
- `share-plan.md` — for PR description (preferred)
- `explain.md` — for requirements summary (fallback)
- `implement.md` — for step list

Extract:
- **ADO ID:** From the directory name (numeric prefix, e.g., `2416553`)
- **Title:** `#<ID> <short description>`. The `#<ID>` prefix is **mandatory**. Description from implement.md header or share-plan.md, kept under 70 characters total.
- **Summary:** From share-plan.md's Summary section, or explain.md's What & Why
- **Changes:** From share-plan.md's Changes section, or from implement.md step titles

## 5. Push Branch

```bash
git push -u origin $(git branch --show-current)
```

If rejected after rebase, use `--force-with-lease` per git-rules.md.

## 6. Create PR via ADO MCP

Use `mcp__ado__repo_create_pull_request` per git-rules.md:

- **repositoryId:** auto-discovered in step 3
- **sourceRefName:** `refs/heads/<current-branch>`
- **targetRefName:** `refs/heads/$BASE_BRANCH` (auto-discovered, never hardcoded)
- **title:** `#<ID> <short description>`
- **description:** Use PR description template from git-rules.md, populated with content from step 4
- **workItems:** `<ADO-ID>` to auto-link the work item

## 7. Present Summary

```markdown
## Pull Request Created

**PR:** <PR URL from ADO response>
**Title:** <title>
**Base:** $BASE_BRANCH ← <branch>
**Steps completed:** <N>/<N>

### Post-PR checklist:
- [ ] Review PR diff in ADO
- [ ] Verify ADO work item is linked
- [ ] Request reviews from team
```

## Examples

### Create PR after all steps done
```
/dx-pr 2435084
```
Verifies all steps in `implement.md` are `done`, generates PR description from `share-plan.md`, pushes branch, creates ADO PR targeting the configured base branch with work item linked.

### With custom persona
```
/dx-pr 2435084
```
If `.ai/me.md` exists, uses the persona to shape the PR description text while maintaining the standard format (summary + changes + test plan).

## Troubleshooting

### "Not all steps are done"
**Cause:** Some steps in `implement.md` are still `pending`, `in-progress`, or `blocked`.
**Fix:** Run `/dx-step-all` to complete remaining steps, or `/dx-step` one at a time.

### Push rejected
**Cause:** Remote branch has diverged (e.g., after a rebase upstream).
**Fix:** The skill uses `--force-with-lease` only after a rebase. If push fails for other reasons, it reports the error for manual resolution.

### PR creation fails with "repository not found"
**Cause:** Repo ID discovery failed — `mcp__ado__repo_get_repo_by_name_or_id` needs the correct ADO project name.
**Fix:** Check `.ai/config.yaml` `scm.project` matches the ADO project where the repo lives. Remember repos need a GUID, not a name.

## Rules

- **Follow git-rules.md** — read `shared/git-rules.md` and follow all conventions.
- **All steps must be done** — never create a PR with incomplete steps
- **ADO MCP only** — use `mcp__ado__repo_create_pull_request`, never `gh` CLI
- **Auto-discover base branch and repo ID** — per git-rules.md, never hardcode
- **Push before PR** — ensure branch is pushed with -u flag
- **Include ADO reference** — link to the work item via the `workItems` parameter
- **Don't force push** — if push fails, report and let the user resolve (unless post-rebase, then `--force-with-lease`)

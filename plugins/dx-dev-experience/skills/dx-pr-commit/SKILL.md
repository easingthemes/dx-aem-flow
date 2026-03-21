---
name: dx-pr-commit
description: Commit changes and optionally create an ADO pull request. Handles staging, commit messages with ADO work item IDs, rebasing onto the base branch, and PR creation via ADO MCP tools. Use when the user says "commit", "create PR", "open PR", "push changes", or any variation. This is the ONLY skill for commits and PRs — always use it instead of gh CLI or manual git workflows.
argument-hint: "[optional: commit message or 'pr' to also create PR]"
allowed-tools: ["read", "edit", "search", "write", "agent", "ado/*"]
---

You handle git commits and Azure DevOps pull requests.

**Before anything else**, read these two files:
- `shared/git-rules.md` — all git/ADO conventions (base branch discovery, repo ID discovery, commit format, staging, rebase, PRs)
- `.ai/config.yaml` — project config, preferences (Auto-Commit, Auto-PR)

Follow every rule in `git-rules.md`. The steps below assume you have read it.

## Persona (optional)

If `.ai/me.md` exists, read it. Use it to shape PR titles and descriptions. Commit message format (`#<ID> <imperative>`) is a structural constraint and always wins. If `.ai/me.md` doesn't exist, use defaults.

## 1. Determine Intent

Parse the user's request and argument:
- **Commit only** — default if no "pr" keyword
- **Commit + PR** — if user says "pr", "pull request", "open pr", etc.
- **PR only** — if changes are already committed and user just wants a PR

## 1. Gather Git Context

Run the context discovery script:

```bash
bash .ai/lib/gather-context.sh
```

This outputs `CURRENT_BRANCH`, `BASE_BRANCH`, and `GITIGNORE_RULES`. Use these values throughout — do NOT re-run discovery commands.

## 2. Setup

1. **Base branch** — already discovered above (use `BASE_BRANCH` value). If `unknown`, fall back to git-rules.md probing.
2. **Discover repo ID** — per git-rules.md
3. **Check branch safety** — must be on `feature/*` or `bugfix/*` (check `CURRENT_BRANCH` above)

## 3. Extract ADO Work Item ID

Find it from (in priority order):
1. **User argument** — if they passed an ID
2. **Branch name** — extract digits from `feature/#2416553-...` or `feature/2416553-...` or `bugfix/2416553-...`
3. **Spec directory** — check `.ai/specs/<id>-*/` for the most recent spec
4. **Recent commits** — parse `git log -5 --oneline` for `#<digits>` pattern

If no ID found, ask the user.

## 4. Rebase (if needed)

Per git-rules.md — fetch, check if behind, rebase. Never merge.

## 5. Stage Changes

Run `git status`. Stage files **specifically** per git-rules.md.

### Identify YOUR changes only

Before staging, determine which files are actually yours vs came from the base branch:

```bash
# Files changed only on this branch (yours)
git diff origin/$BASE_BRANCH...HEAD --name-only

# Compare with git status to spot foreign files
git status --short
```

If `git status` shows files NOT in the `git diff ...HEAD --name-only` output, those came from a merge or rebase — do NOT stage them.

### Stage rules

- Only stage files that appear in YOUR diff
- Files the user explicitly mentioned
- If a spec directory exists, also stage `implement.md` status updates
- **Never** stage files that only exist in `git status` but not in your branch diff

Present the staged files to the user for confirmation before committing.

## 6. Commit

Craft message per git-rules.md format: `#<ADO-ID> <imperative description>`

If the user provided a message in the argument, use it (prepend the `#<ID>` if missing).

Commit and verify with `git log -1 --oneline`.

## 7. Create PR (if requested)

Only if the user asked for a PR.

### 7a. PR Pre-Flight Checks (per git-rules.md)

Run all pre-flight checks from git-rules.md before creating:
1. **Check for existing PR** — if Active, show it and stop. If Abandoned, offer to reactivate.
2. **Check for empty diff** — if no commits vs base branch, stop.
3. **Push branch** — `git push -u origin $(git branch --show-current)`. If rejected after rebase, use `--force-with-lease`.

### 7b. Create PR via ADO MCP

Use `mcp__ado__repo_create_pull_request` per git-rules.md:

- **repositoryId:** auto-discovered
- **sourceRefName:** `refs/heads/<current-branch>`
- **targetRefName:** `refs/heads/$BASE_BRANCH`
- **title:** `#<ID> <short description>` (under 70 chars)
- **description:** Build from available context (share-plan.md, git log, diff stat). Use PR description template from git-rules.md.
- **workItems:** `<ADO-ID>` to auto-link the work item

### 7c. Post-Creation Check

After creating the PR, verify merge status per git-rules.md. If conflicts detected, warn the user to rebase.

### 7d. Set Auto-Complete (optional)

If the user asks, use `mcp__ado__repo_update_pull_request` with `autoComplete: true`.

## Examples

### Simple commit
```
/dx-pr-commit
```
Discovers work item ID from branch name, stages your changes (not base branch files), commits with `#2435084 add language selector component`.

### Commit with message
```
/dx-pr-commit fix null check in hero component
```
Uses your message, prepends `#<ID>`: `#2435084 fix null check in hero component`.

### Commit and create PR
```
/dx-pr-commit pr
```
Commits, pushes, creates ADO PR targeting the configured base branch with work item linked.

## Troubleshooting

### "Not on a feature or bugfix branch"
**Cause:** You're on `development`, `main`, or another protected branch.
**Fix:** Create a feature branch first: `git checkout -b feature/<id>-<slug>`.

### Stages unexpected files from base branch
**Cause:** After rebase, files from the base branch appear in `git status`.
**Fix:** The skill compares `git status` against `git diff origin/<base>...HEAD --name-only` to only stage YOUR changes.

### PR creation fails — "active PR already exists"
**Cause:** An active PR already exists for this branch.
**Fix:** The skill detects this and shows the existing PR URL. Update the existing PR instead.

## 8. Present Summary

After commit:
```markdown
**Committed:** `#<ID> <message>`
**Files:** <count> files
**Hash:** `<short hash>`
**Branch:** <branch name>
```

After PR:
```markdown
**PR #<pr-id>:** `<title>`
**Branch:** <source> → <$BASE_BRANCH>
**URL:** <PR web URL from ADO response>
```

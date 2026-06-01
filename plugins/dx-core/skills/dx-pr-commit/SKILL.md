---
name: dx-pr-commit
description: Commit changes and optionally create an ADO pull request. Handles staging, commit messages with ADO work item IDs, rebasing onto the base branch, and PR creation via ADO MCP tools. Use when the user says "commit", "create PR", "open PR", "push changes", or any variation. This is the ONLY skill for commits and PRs — always use it instead of gh CLI or manual git workflows.
argument-hint: "[optional: commit message or 'pr' to also create PR]"
context: fork
allowed-tools: ["read", "edit", "search", "write", "agent", "ado/*"]
---

You handle git commits and Azure DevOps pull requests.

## Output discipline

You run in a forked context. Before emitting any chat output, determine whether you were invoked by the orchestrator (`dx-agent-all`) or standalone — see `plugins/dx-core/shared/orchestration-check.md`:

```bash
ORCHESTRATED=0
FLAG=".ai/run-context/orchestrating.flag"
if [ -f "$FLAG" ]; then
  AGE=$(( $(date +%s) - $(date -r "$FLAG" +%s) ))
  [ "$AGE" -lt 7200 ] && ORCHESTRATED=1
fi
```

- **If `$ORCHESTRATED == 1`** (orchestrator path): complete the commit (and PR if requested) and emit ONLY the `## Return` block to chat.
- **If `$ORCHESTRATED == 0`** (standalone path): complete the commit (and PR if requested) AND emit the human-friendly summary marked `<!-- standalone-only -->` below, followed by the `## Return` block at the very end.

Per-step progress lines during the run are allowed in both paths.

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

## 6b. Orchestrated PR update (headless)

When `$ORCHESTRATED == 1` (e.g. `/dx-pr-answer` applying fixes to a reviewer's open PR), the branch usually already has an Active PR and the intent is **update it**, not create a new one. After committing, check:

```
mcp__ado__repo_list_pull_requests_by_repo_or_project
  repositoryId: "<repo ID>"
  sourceRefName: "refs/heads/<current-branch>"
  status: "Active"
```

If an **Active PR exists**, push the new commit to update it — no new PR, no prompt:

```bash
git push origin "$(git branch --show-current)" \
  || { git pull --rebase origin "$(git branch --show-current)" && git push origin "$(git branch --show-current)"; }
```

Pushing the source branch updates the existing PR automatically. Do **not** create a new PR and do **not** bare-`--force` (only `--force-with-lease`, and only after an explicit rebase). Capture the PR URL/ID for the caller's `## Return` block, then skip step 7.

If **no Active PR exists**, fall through: create one only if a PR was requested (the `pr` keyword), otherwise this was a commit-only run and you're done.

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

## Present Summary (standalone path only)

<!-- standalone-only — emit only when $ORCHESTRATED == 0 -->

When running standalone, emit:

```markdown
## Commit complete

**<count> files** committed as `<SHA>` on `<branch>`.
<If PR was created:>
**PR:** <title>
**URL:** <PR web URL>

### Next steps:
- Push branch: `git push -u origin <branch>`
- Or run `/dx-pr` to create the PR (if not already created)
```

After commit (detailed form):
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

When orchestrated (`$ORCHESTRATED == 1`), skip this section entirely and emit only the `## Return` block.

## Return

This skill runs in a forked context. It MUST end with a `## Return` block per `plugins/dx-core/shared/skill-return-contract.md`.

Examples:

```markdown
## Return
verdict: pass
summary: Committed 3 files as 26e7cb8 on feature/2490722-microsite; PR not created (auto-pr=false).
artifacts:
  - .ai/specs/2490722-microsite/commit-log.txt
next_action: open PR via printed URL
```

```markdown
## Return
verdict: fail
summary: Commit aborted — pre-commit hook failed: lint-staged eslint no-shadow on token.
artifacts: []
next_action: fix lint error and re-run /dx-pr-commit
```

If a PR was created, include the PR URL in `summary` (truncated if needed) and the full URL in an artifact file.

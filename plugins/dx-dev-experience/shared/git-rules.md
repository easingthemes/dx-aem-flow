# Git & ADO Rules

Single source of truth for all commit and PR skills (commit, step-commit, pr).
Read this file before performing any git commit or PR operation.

## Base Branch Discovery

Auto-discover the base branch — never hardcode a branch name.

```bash
git remote set-head origin --auto 2>/dev/null
BASE_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')
```

If `origin/HEAD` is not set, probe the remote:
```bash
git branch -r | grep -E 'origin/(development|develop)$'
```

Pick the first match: `development` > `develop`.

If neither exists, check whether the branch was forked from `main` or `master`:
```bash
git merge-base --is-ancestor origin/main HEAD 2>/dev/null && echo "main"
git merge-base --is-ancestor origin/master HEAD 2>/dev/null && echo "master"
```

Only use `main`/`master` if the branch genuinely originated from them. Otherwise STOP and ask the user.

Alternatively, if `.ai/config.yaml` has `scm.base-branch` set, use that value directly.

## ADO Project Discovery

Read `.ai/config.yaml` to get the SCM config:
- `scm.org` — ADO organization URL
- `scm.project` — ADO project name
- `scm.repo-id` — repository ID (optional, discover if missing)

ADO URLs follow this pattern:
```
{scm.org}/{scm.project}/_workitems/edit/{id}
{scm.org}/{scm.project}/_git/{REPO}/pullrequest/{id}
```

Never hardcode the ADO org or project name — always read from `.ai/config.yaml`.

## Repo ID Discovery

Use `mcp__ado__repo_get_repo_by_name_or_id` with the repo name and ADO project from config to get the **repository ID**. Never hardcode repo IDs. Cache the result for the session.

## SCM: Azure DevOps Only

- **NEVER** use `gh` CLI or reference GitHub
- All PR operations use ADO MCP tools (`mcp__ado__repo_*`)
- PR creation: `mcp__ado__repo_create_pull_request`
- PR updates: `mcp__ado__repo_update_pull_request`

## Branch Safety

- Must be on `feature/*` or `bugfix/*` before committing
- Never commit directly to the base branch, `master`, or `main`
- If not on a feature/bugfix branch, use `shared/ensure-feature-branch.sh` or STOP
- **Always start from a fresh base branch.** Before any new work, create a new branch from the latest base branch:
  ```bash
  git checkout $BASE_BRANCH && git pull origin $BASE_BRANCH && git checkout -b feature/<name>
  ```
  Never reuse old feature/bugfix branches for new work — stale branches cause rebase conflicts.

## Rebase, Never Merge

- Always `git rebase origin/$BASE_BRANCH` to sync with upstream
- **NEVER** `git merge` — merge commits pollute PRs with foreign commits
- If rebase has conflicts, STOP and tell the user to resolve them

## Staging

- **Never** use `git add -A` or `git add .` — always name specific files
- Never stage `.env`, credentials, secrets, tokens
- Never stage unrelated modified files or generated files in `dist/`

## Commit Message Format

```
#<ADO-ID> <imperative description>
```

- The `#<ID>` prefix is **mandatory** — every commit starts with it
- Description: short imperative sentence
- No conventional commit prefixes (`feat:`, `fix:`, etc.) — the ADO ID replaces them
- Keep under 72 characters
- Use HEREDOC for the message:
  ```bash
  git commit -m "$(cat <<'EOF'
  #<ID> <description>
  EOF
  )"
  ```

## No Attribution

Do not add "Generated with Claude" or any AI attribution to commits or PRs.

## Force Push

- After rebase, use `--force-with-lease` (safe force push)
- **NEVER** use bare `--force`
- If push fails for other reasons, report and let the user resolve

## PR Target

- PRs always target `$BASE_BRANCH` (auto-discovered or from `scm.base-branch`)
- Never target `master` or `main` unless the branch was genuinely forked from them

## PR Pre-Flight Checks

Before creating a PR, run these checks in order:

### 1. Check for existing PR
```
mcp__ado__repo_list_pull_requests_by_repo_or_project(
  repositoryId, sourceRefName: "refs/heads/<branch>",
  targetRefName: "refs/heads/$BASE_BRANCH", status: "All"
)
```
- **Active PR found** → do NOT create a new one. Show the existing PR URL and ask if the user wants to update it.
- **Abandoned PR found** → ask the user: reactivate it or create a new one.
- **Completed PR found** → OK to create a new one (previous work was merged).

### 2. Check for empty diff
```bash
git log origin/$BASE_BRANCH..HEAD --oneline
```
If no commits, STOP: "No commits to include in PR. Commit changes first."

### 3. Check branch is pushed
```bash
git ls-remote origin refs/heads/<branch>
```
If empty, push first.

### 4. After PR creation, check merge status
After creating the PR, verify merge status:
```
mcp__ado__repo_get_pull_request_by_id(repositoryId, pullRequestId)
```
If `mergeStatus` is `conflicts`, warn: "PR has merge conflicts. Rebase onto $BASE_BRANCH to resolve."

## PR Description

No Claude attribution footer. Include:
```markdown
## Summary
- <2-3 bullets describing the changes>

## Changes
- <file-level or step-level changes>

## Test plan
- [ ] Relevant build/test commands
- [ ] Manual verification steps
```

Link the ADO work item via the `workItems` parameter.

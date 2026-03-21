---
name: dx-pr-fix
description: Apply code fixes from agree-will-fix PR review comments. Reads session data from /dx-pr-answer, applies fixes, lints, commits, pushes, and replies to threads. Use after /dx-pr-answer when there are agree-will-fix threads to resolve.
argument-hint: "[PR URL | PR ID | empty (latest session)]"
allowed-tools: ["read", "edit", "search", "write", "agent", "ado/*"]
---

You apply code fixes from structured instructions — typically `agree-will-fix` items from `/dx-pr-answer` sessions. Read the fix instructions, apply each change, lint, then delegate to `/dx-pr-commit` for commit+push, and finally reply to the PR threads.

**Delegates to:**
- `/dx-pr-commit` — for staging, committing, rebasing, and pushing (never handle git operations directly)
- `general-purpose` subagent — for applying code changes (keeps main context clean)

## Persona (optional)

If `.ai/me.md` exists, read it. Use it to shape the tone of "fixed" reply messages and any text in the agent prompt. Skill constraints (short, factual replies) still apply. If `.ai/me.md` doesn't exist, use defaults.

## 1. Parse Input & Find Context

Parse `$ARGUMENTS`:

| Input | Mode | Example |
|-------|------|---------|
| *(empty)* | Latest session file | `/dx-pr-fix` |
| `<PR ID>` | Session by PR ID | `/dx-pr-fix 12345` |
| `<PR URL>` | Session by PR ID from URL | `/dx-pr-fix https://.../_git/.../pullrequest/12345` |

### Extract PR ID

- Contains `/pullrequest/` → extract `pullRequestId`, `project`, `repo` from the URL. URL-decode the project (e.g., `My%20Project` → `My Project`). **The URL-extracted project takes precedence over the config default.**
- Numeric only → use as PR ID
- Empty → latest session mode

### Check for session file

```bash
# Specific PR
cat .ai/pr-answers/pr-<id>.md

# Latest session (empty input only)
ls -t .ai/pr-answers/pr-*.md | head -1
```

### Session found → **session mode**

Read the session file. It contains everything needed:
- **Repo ID** — from `**Repo:** <name> (ID: <id>)` line
- **Project** — from `**Project:** <name>` line
- **Branch** — from `**Branch:** <source> → <target>` line
- **Threads** — with categories, proposed fixes, reviewer comments

**Do NOT re-resolve repo ID or project from config.** The session file is the source of truth. It was written by `/dx-pr-answer` which already resolved these values correctly (including URL-provided projects that may differ from config).

### No session found → **standalone mode**

If no session file exists for the given PR:

1. Load MCP tools:
   ```
   ToolSearch("+ado repo")
   ToolSearch("+ado pull request thread")
   ```

2. Resolve the repo (use project from URL if provided, otherwise from config per `shared/ado-config.md`):
   ```
   mcp__ado__repo_get_repo_by_name_or_id
     project: "<project from URL if provided, otherwise from config>"
     repositoryNameOrId: "<repo name from URL or git remote>"
   ```

3. Fetch the PR:
   ```
   mcp__ado__repo_get_pull_request_by_id
     repositoryId: "<repo ID>"
     pullRequestId: <PR ID>
   ```

4. Fetch active threads and their comments (same as `/dx-pr-answer` steps 5a-5c)

5. Identify `agree-will-fix` candidates — threads where the reviewer points out a clear code issue. Use a `general-purpose` subagent to:
   - Read each commented file
   - Check the diff (`git diff origin/<target>...origin/<source> -- <file>`)
   - Categorize: is the reviewer right? Would a fix be straightforward?
   - For fixable issues, propose a specific fix

6. Save a session file `.ai/pr-answers/pr-<id>.md` with the standard format (including `**Project:**`) before proceeding to Step 2

Print mode summary:

```markdown
## pr-fix — PR #<id>

**Mode:** session (from /dx-pr-answer) | standalone (fetched fresh)
**Repo:** <name> (ID: <id>)
**Project:** <project>
**Branch:** <source> → <target>
```

## 2. Extract Fixable Threads

Read the session file (or freshly created session from standalone mode). Extract all threads where:
- **Category** is `agree-will-fix`
- **Status** is `pending` or `posted` (reply was sent, but code fix not yet applied)

Skip threads that are already `code-fixed`.

If no `agree-will-fix` threads: "No agree-will-fix threads in PR #<id>. Nothing to fix."

### Present Fix Plan

```markdown
## Fix Plan — PR #<id>: <title>

| # | Thread | File | Line(s) | Proposed Fix |
|---|--------|------|---------|--------------|
| 1 | #101 | `component.js` | L42 | Replace custom throttle with `Utils.debounce()` |
| 2 | #205 | `_component.scss` | L15 | Use `$spacing-md` variable instead of hardcoded value |

**<N> fixes to apply.** Proceed?
```

Wait for user confirmation before applying any changes.

## 3. Verify Branch

Ensure you're on the correct branch:

```bash
git branch --show-current
```

Compare with session file's `sourceBranch`. If different:

```
You're on <current> but this PR's source branch is <sourceBranch>.
Switch to <sourceBranch> first? (This will stash any uncommitted changes.)
```

If on the wrong branch and user confirms, switch:

```bash
git stash
git checkout <sourceBranch>
git pull origin <sourceBranch>
```

If already on the correct branch, just pull latest:

```bash
git pull --rebase origin <sourceBranch>
```

## 4. Apply Fixes

Spawn a subagent to apply all fixes:

```
Task(
  subagent_type: "general-purpose",
  description: "Apply PR #<id> fixes",
  prompt: "Apply these code fixes to the codebase. Each fix has a file, location, and description of what to change.

    repoPath: <current working directory>

    ## Fixes to apply

    <for each agree-will-fix thread:>
    ### Fix #<N>
    File: <filePath>
    Line(s): <line range>
    Context: <reviewer comment or fix instruction>
    What to change: <proposed fix description>
    Constraint: <the reply that was posted — this is what was promised, don't exceed it>

    ## Persona

    <If .ai/me.md was found, paste content. Otherwise omit.>

    ## Instructions

    For each fix:
    1. **Read the file** — read the full file (or ±50 lines around the target area)
    2. **Understand the context** — what the code does, what the reviewer wants changed
    3. **Apply the minimal fix** — change ONLY what was agreed to. Don't refactor surrounding code, don't add features, don't 'improve' things that weren't mentioned
    4. **Verify consistency** — if the fix changes a pattern (e.g., renaming a variable), check elsewhere in the file and update those too
    5. **Report what you changed** — for each fix, report the exact file and what was modified

    ## Constraints
    - **Minimal changes** — only fix what was agreed to
    - **Don't break things** — if a fix seems risky (could break other functionality), flag it instead of applying
    - **Follow project conventions** — read .claude/rules/ for the relevant file type
    - **One fix = one logical change**

    ## Output Format

    ### Fix #<N> — <filePath>
    **Thread:** #<threadId>
    **What changed:** <1-line description>
    **Lines modified:** L<start>-L<end>
    **Risk:** low | medium | high
    **Notes:** <any concerns, or 'none'>
    ---

    If a fix could NOT be applied:
    ### Fix #<N> — <filePath>
    **Thread:** #<threadId>
    **Status:** SKIPPED
    **Reason:** <why>
    ---
  "
)
```

## 5. Lint Check

After fixes are applied, run lint on modified files:

1. Read lint commands from `.ai/config.yaml` `build.lint` if available
2. If not configured, check `package.json` scripts for `lint`, `lint:js`, `lint:css`
3. Run lint on the modified file types
4. Check which file(s) failed before attempting auto-fix
5. If lint fails on a file that was just modified — try auto-fix once (e.g., `--fix` flag)
6. Re-run lint to verify
7. If still failing after one fix attempt — report the lint error and let the user decide

## 6. Present Changes

Show the changes for user review:

```bash
git diff --stat
```

Show `git diff` for each modified file so the user can inspect the actual changes.

```markdown
### Changes Applied

| # | File | Fix | Status |
|---|------|-----|--------|
| 1 | `component.js` | Replaced throttle with debounce | ✅ Applied |
| 2 | `_component.scss` | Changed to $spacing-md | ✅ Applied |

**Lint:** PASSED / FAILED (details)
**Files modified:** <N>
```

Wait for explicit approval. Options:
- **Approve all** → proceed to commit
- **Revert some** → `git checkout -- <filePath>` for specific files
- **Cancel** → revert all changes

## 7. Commit & Push via `/dx-pr-commit`

Delegate to the existing `/dx-pr-commit` skill for all git operations:

```
Skill("commit", args: "address PR review feedback")
```

`/dx-pr-commit` handles everything:
- ADO work item ID discovery (from branch name, recent commits, or spec dir)
- Base branch discovery and rebasing
- Specific file staging (not `git add -A`)
- Commit message formatting (`#<ID> address PR review feedback`)
- Pushing to remote

If `/dx-pr-commit` reports an error (merge conflicts, branch safety issue), surface it and stop — don't try to work around it.

After `/dx-pr-commit` completes, capture the commit hash for use in thread replies.

## 8. Reply to Fixed Threads

Load MCP tools and use the **repo ID** and **project** from the session file directly:

```
ToolSearch("+ado repo")
ToolSearch("+ado pull request thread")
```

For each fixed thread, post a short follow-up reply:

```
mcp__ado__repo_reply_to_comment
  repositoryId: "<repo ID from session>"
  pullRequestId: <PR ID>
  threadId: <thread ID>
  content: "Fixed."
```

Reply tone:
- **Ultra-short** — the earlier `/dx-pr-answer` reply already explained the intent, so this is just a status update
- One or two words max. The reviewer can check the diff for details.
- Examples:
  - "Fixed."
  - "Updated."
  - "Done, pushed."

**Never resolve threads** — the user and reviewer handle resolution.

## 9. Update Session File

Update `.ai/pr-answers/pr-<id>.md`:

For each fixed thread, update:
- **Status:** `code-fixed`
- Add line: `- **Commit:** <short hash>`
- Add line: `- **Fix reply posted:** <ISO date>`

Update the top-level `**Status:**` to reflect progress:
- All threads addressed → `complete`
- Some still pending → `partial`

## 10. Print Summary

```markdown
## Fix Summary — PR #<id>

| # | Thread | File | Fix | Commit |
|---|--------|------|-----|--------|
| 1 | #101 | `component.js` | Replaced throttle with Utils.debounce() | abc1234 |
| 2 | #205 | `_component.scss` | Changed to $spacing-md | abc1234 |

**Committed:** `#<ID> address PR review feedback` (`<hash>`)
**Pushed to:** `<sourceBranch>`
**Replies posted:** <N> threads notified

Remaining open threads: <count> (run /dx-pr-answer <id> to check for new comments)
```

## Examples

### Fix from session
```
/dx-pr-fix 12345
```
Reads `.ai/pr-answers/pr-12345.md`, finds `agree-will-fix` threads, presents fix plan, applies changes via subagent, lints, delegates commit to `/dx-pr-commit`, replies "Fixed." to each thread.

### Fix latest session
```
/dx-pr-fix
```
Picks the most recent session file from `.ai/pr-answers/`. Useful right after `/dx-pr-answer`.

### Standalone mode (no session)
```
/dx-pr-fix https://dev.azure.com/myorg/My%20Project/_git/My-Repo/pullrequest/12345
```
No session exists — fetches PR, analyzes threads, creates a session, then applies fixes.

## Troubleshooting

### "No agree-will-fix threads"
**Cause:** All threads are categorized as `question`, `disagree`, or `skip`.
**Fix:** Run `/dx-pr-answer` first to categorize threads. Only `agree-will-fix` threads get code fixes.

### Lint fails after applying fixes
**Cause:** The fix introduced a lint violation.
**Fix:** The skill tries auto-fix once (e.g., `--fix` flag). If still failing, it reports the lint error for manual resolution.

### "You're on the wrong branch"
**Cause:** Current branch doesn't match the PR's source branch.
**Fix:** The skill offers to switch branches (with stash). Confirm to proceed.

## Rules

- **Session first** — always check `.ai/pr-answers/pr-<id>.md` first. Use stored repo ID, project, and branch — never re-resolve from config
- **Standalone fallback** — if no session exists, fetch the PR, analyze threads, create a session, then proceed
- **Only agree-will-fix** — only apply fixes for threads categorized as `agree-will-fix`. Ignore `question`, `disagree`, `skip`
- **Minimal changes** — fix ONLY what was promised in the reply. Don't improve, refactor, or clean up surrounding code
- **Lint before commit** — always lint after applying fixes. Don't push broken code
- **Delegate git to /dx-pr-commit** — never handle staging, committing, rebasing, or pushing directly. Always invoke `/dx-pr-commit`
- **Correct branch** — verify you're on the PR's source branch before applying any changes
- **Confirm before committing** — show the diff and get user approval before invoking `/dx-pr-commit`
- **Reply after push** — only reply to threads AFTER `/dx-pr-commit` completes (so the reviewer can see the fix)
- **Never resolve threads** — post the "fixed" reply but leave thread resolution to the user/reviewer
- **Subagent for fixes** — use a `general-purpose` subagent to apply code changes. Keeps main context clean for git ops and MCP calls
- **Update session** — always update `.ai/pr-answers/pr-<id>.md` after fixing. Mark threads as `code-fixed` with commit hash
- **Handle failures gracefully** — if one fix can't be applied, skip it, apply the rest, and report what was skipped
- **URL project precedence** — if a PR URL was provided, use the project from the URL, not from config
- **MCP tools are deferred** — always load via ToolSearch before first use

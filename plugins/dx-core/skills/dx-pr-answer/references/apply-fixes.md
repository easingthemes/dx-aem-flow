# Apply Fixes — Procedure for agree-will-fix Threads

This reference describes the full procedure for applying code fixes from `agree-will-fix` PR review threads. Called from `/dx-pr-answer` step 9 when the user chooses to apply fixes.

## 1. Extract Fixable Threads

Read the session file `.ai/pr-answers/pr-<id>.md`. Extract all threads where:
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

## 2. Verify Branch

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

## 3. Apply Fixes via Subagent

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
    1. **Read the file** — read the full file (or +/-50 lines around the target area)
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

## 4. Lint Check

After fixes are applied, run lint on modified files:

1. Read lint commands from `.ai/config.yaml` `build.lint` if available
2. If not configured, check `package.json` scripts for `lint`, `lint:js`, `lint:css`
3. Run lint on the modified file types
4. Check which file(s) failed before attempting auto-fix
5. If lint fails on a file that was just modified — try auto-fix once (e.g., `--fix` flag)
6. Re-run lint to verify
7. If still failing after one fix attempt — report the lint error and let the user decide

## 5. Present Changes

Show the changes for user review:

```bash
git diff --stat
```

Show `git diff` for each modified file so the user can inspect the actual changes.

```markdown
### Changes Applied

| # | File | Fix | Status |
|---|------|-----|--------|
| 1 | `component.js` | Replaced throttle with debounce | Applied |
| 2 | `_component.scss` | Changed to $spacing-md | Applied |

**Lint:** PASSED / FAILED (details)
**Files modified:** <N>
```

Wait for explicit approval. Options:
- **Approve all** -> proceed to commit
- **Revert some** -> `git checkout -- <filePath>` for specific files
- **Cancel** -> revert all changes

## 6. Commit & Push

Delegate to `/dx-pr-commit` for all git operations:

```
Skill(/dx-pr-commit, args: "address PR review feedback")
```

`/dx-pr-commit` handles everything:
- ADO work item ID discovery (from branch name, recent commits, or spec dir)
- Base branch discovery and rebasing
- Specific file staging (not `git add -A`)
- Commit message formatting (`#<ID> address PR review feedback`)
- Pushing to remote

If `/dx-pr-commit` reports an error (merge conflicts, branch safety issue), surface it and stop.

After `/dx-pr-commit` completes, capture the commit hash for use in thread replies.

## 7. Reply to Fixed Threads

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
- **Ultra-short** — the earlier reply already explained the intent, so this is just a status update
- One or two words max. The reviewer can check the diff for details.
- Examples: "Fixed.", "Updated.", "Done, pushed."

**Never resolve threads** — the user and reviewer handle resolution.

## 8. Update Session File

Update `.ai/pr-answers/pr-<id>.md`:

For each fixed thread, update:
- **Status:** `code-fixed`
- Add line: `- **Commit:** <short hash>`
- Add line: `- **Fix reply posted:** <ISO date>`

Update the top-level `**Status:**` to reflect progress:
- All threads addressed -> `complete`
- Some still pending -> `partial`

## Rules

- **Session first** — always check `.ai/pr-answers/pr-<id>.md` first. Use stored repo ID, project, and branch
- **Only agree-will-fix** — only apply fixes for threads categorized as `agree-will-fix`
- **Minimal changes** — fix ONLY what was promised in the reply
- **Lint before commit** — always lint after applying fixes
- **Delegate git to /dx-pr-commit** — never handle staging, committing, rebasing, or pushing directly
- **Correct branch** — verify you're on the PR's source branch before applying any changes
- **Confirm before committing** — show the diff and get user approval before invoking `/dx-pr-commit`
- **Reply after push** — only reply to threads AFTER `/dx-pr-commit` completes
- **Never resolve threads** — post the "fixed" reply but leave thread resolution to the user/reviewer
- **Subagent for fixes** — use a `general-purpose` subagent to apply code changes
- **Update session** — always update `.ai/pr-answers/pr-<id>.md` after fixing
- **Handle failures gracefully** — if one fix can't be applied, skip it, apply the rest, report what was skipped

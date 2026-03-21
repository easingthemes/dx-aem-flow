---
name: dx-step-commit
description: Stage and commit changes for a completed plan step. Reads implement.md for the step title and files, stages only relevant files, and commits with a descriptive message. Use after /dx-step-review approves changes.
argument-hint: "[Work Item ID or slug (optional — uses most recent if omitted)]"
allowed-tools: ["read", "edit", "search", "write", "agent"]
---

You create a git commit for the most recently completed step.

**Before anything else**, read `shared/git-rules.md` — all git/SCM conventions. Follow every rule in it.

## 1. Locate the Spec Directory

```bash
SPEC_DIR=$(bash .ai/lib/dx-common.sh find-spec-dir $ARGUMENTS)
```

Read `implement.md` from `$SPEC_DIR`. Find the most recently completed step (last `**Status:** done`).

## 2. Determine Files to Stage

From the step's **Files:** list, identify which files to stage. Also check `git status` for any additional modified files that are clearly part of this step's work.

Stage the files per git-rules.md (always specific, never `git add -A`):
```bash
git add <file1> <file2> ...
```

**Do NOT stage:**
- Unrelated modified files
- .env files, credentials, or secrets

**DO stage:**
- All files listed in the step's **Files:** line
- implement.md (to capture the status update)

## 3. Craft Commit Message

Extract the work item ID from the spec directory name (the numeric prefix, e.g., `2416553` from `.ai/specs/2416553-enhance-component/`).

Per git-rules.md format: `#<ID> <imperative description of what changed>`

Example: `#2416553 add dropdown and second pod fields to dialog`

## 4. Commit

Per git-rules.md — use HEREDOC for the message:
```bash
git commit -m "$(cat <<'EOF'
#<ID> <description>
EOF
)"
```

## 5. Present Summary

```markdown
## Committed: Step <N>

**Message:** `<commit message>`
**Files:** <count> files
**Hash:** `<short hash>`

Run `/dx-step` for the next step, or `/dx-step-all` to continue autonomously.
```

## Success Criteria

- [ ] Git commit created with a valid commit hash
- [ ] Commit message includes the ADO work item ID (`#<id>`)
- [ ] Only files from the completed step are staged — no unrelated files

## Examples

### Commit after step review
```
/dx-step-commit 2435084
```
Finds the last completed step, stages listed files + `implement.md`, commits with message `#2435084 add dropdown field to dialog`.

### Nothing to commit
```
/dx-step-commit 2435084
```
If no files are modified, reports "Nothing to stage — no commit created."

## Troubleshooting

### "Not on a feature branch"
**Cause:** Working on `development`, `main`, or another protected branch.
**Fix:** The skill auto-runs `ensure-feature-branch.sh` to create one. If that fails, manually create: `git checkout -b feature/<id>-<slug>`.

### Commit message missing work item ID
**Cause:** Spec directory name doesn't have a numeric prefix.
**Fix:** The ID is extracted from the directory name (e.g., `2435084` from `.ai/specs/2435084-slug/`). If the directory was created manually without an ID, the commit message format will be wrong.

## Rules

- **Follow git-rules.md** — read `shared/git-rules.md` and follow all conventions.
- **Never commit outside feature/bugfix branches** — before committing, check `git branch --show-current`. If NOT on `feature/*` or `bugfix/*`: run `bash .ai/lib/ensure-feature-branch.sh $SPEC_DIR` to create a feature branch. If that fails, STOP and print: "ERROR: Not on a feature branch. Create one first."
- **Stage specifically** — never `git add -A` or `git add .`. Only stage files from the step.
- **Include implement.md** — always stage the status update so the plan stays in sync with git history
- **Commit message format** — always `#<ID> <description>`. The work item ID prefix is mandatory, no exceptions.
- **No empty commits** — if nothing to stage, report and skip

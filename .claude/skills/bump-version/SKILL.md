---
name: bump-version
description: Bump plugin and marketplace versions following semver. Auto-detects bump level from git history. Trigger on "bump version", "version bump", "release".
argument-hint: "[patch|minor|major|X.Y.Z]"
---

# bump-version

Bump the version across all 4 version files in one step.

## Files to update

1. `plugins/dx-dev-experience/.claude-plugin/plugin.json` → `"version": "<new>"`
2. `plugins/dx-aem/.claude-plugin/plugin.json` → `"version": "<new>"`
3. `plugins/dx-automation/.claude-plugin/plugin.json` → `"version": "<new>"`
4. `.claude-plugin/marketplace.json` → all 3 `"version": "<new>"` entries

## Determine new version

### If an explicit argument is provided

- **`patch`** — increment patch: `1.6.0` → `1.6.1`
- **`minor`** — increment minor, reset patch: `1.6.1` → `1.7.0`
- **`major`** — increment major, reset minor+patch: `1.7.0` → `2.0.0`
- **`X.Y.Z`** (explicit version like `2.0.0`) — use as-is, must be greater than current

### If no argument — auto-detect from git history

1. Read current version from `plugins/dx-dev-experience/.claude-plugin/plugin.json`
2. Find the last version bump commit:
   ```bash
   git log --oneline --all --grep="bump.*version\|bump.*[0-9]\+\.[0-9]\+\.[0-9]\+" -1 --format="%H"
   ```
   If no match, use the last commit that touched any `plugin.json`:
   ```bash
   git log -1 --format="%H" -- "plugins/*/. claude-plugin/plugin.json"
   ```
3. Get all commits since that reference:
   ```bash
   git log <ref>..HEAD --oneline
   ```
4. Analyze the commit messages and changed files to determine bump level:

   **MAJOR** — any of these signals:
   - Commit messages contain `BREAKING CHANGE`, `breaking:`, or `!:` (conventional commits breaking indicator)
   - Skills were **renamed or removed** (skill directory deleted or moved)
   - Config schema changed (fields renamed/removed in config.yaml handling)
   - Output file conventions changed (spec filenames renamed)

   **MINOR** — any of these signals (and no MAJOR signals):
   - New skill directories added (`plugins/*/skills/*/SKILL.md` created)
   - New agent files added (`plugins/*/agents/*.md` created)
   - New config fields introduced
   - Commit messages start with `feat` or `feat(`
   - Significant new functionality in existing skills

   **PATCH** — everything else:
   - Bug fixes (`fix`, `fix(`)
   - Documentation updates (`docs`, `docs(`)
   - Chore/refactor (`chore`, `refactor`)
   - Typo corrections, broken path fixes
   - Internal improvements with no user-facing changes

5. Present the analysis and recommendation:

```
## Version Analysis

Current version: X.Y.Z
Commits since last bump: N

Changes detected:
  - feat(agents): preload skills into step-executor ...
  - docs: fix stale counts ...
  - ...

Recommendation: MINOR (X.Y.Z → X.(Y+1).0)
Reason: New features added (agent preloading, explicit convention loading)
```

6. Apply the recommended bump level automatically. If the user disagrees, they can override with an explicit argument next time.

## Execution

1. Read all 4 files listed above
2. Edit each file: replace old version string with new version
3. For marketplace.json, use `replace_all: true` since all 3 entries share the same version
4. Print summary:

```
Version bumped: <old> → <new>

Updated:
  - plugins/dx-dev-experience/.claude-plugin/plugin.json
  - plugins/dx-aem/.claude-plugin/plugin.json
  - plugins/dx-automation/.claude-plugin/plugin.json
  - .claude-plugin/marketplace.json
```

## Do NOT

- Do not commit — the user decides when to commit
- Do not change any other files
- Do not modify descriptions or other fields in plugin.json/marketplace.json

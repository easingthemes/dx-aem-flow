# v3.0.0 Release & Rollback

**v3.0.0** is the Playwright MCP migration — a BREAKING CHANGE (the AEM browser-automation server moved from `chrome-devtools-mcp` to `@playwright/mcp`, and `dx-perf` was removed). See [the migration research](research/2026-05-31-playwright-mcp-migration.md).

## What v3 changes for consumers

- The browser MCP server in `plugins/dx-aem/.mcp.json` is now **`playwright`** (`@playwright/mcp@0.0.75`), tool prefix `mcp__plugin_dx-aem_playwright__browser_*`.
- **Action required after upgrade:** enable the `playwright` server, and run `npx playwright install chromium` (Playwright drives a real Chromium; chrome-devtools bundled its own).
- New reusable auth: `.ai/lib/aem-playwright-auth.sh` (installed by `/aem-init`) → author login via `storageState`, publisher Basic Auth via opt-in config.
- `dx-perf` removed (see [TODO #147](todo/todo-perf.md)).

## Release mechanics

semantic-release cuts the version from the conventional-commit history on push to `main`. The migration commit carries a `BREAKING CHANGE:` footer → **major bump → 3.0.0**, which `bump-versions.sh` propagates to all manifests. No manual version edits.

## Rollback strategy

The last v2 release (**2.112.0**) is frozen on the **`v2` branch** (created from `main` at the 2.112.0 commit, before v3 landed). This is the rollback anchor. (This repo's base branch is `main`; the `v2` branch plays the "stable channel" role.)

### Option A — consumer-side pin (fastest, no re-release)

A consumer hitting v3 problems pins their marketplace **source** back to v2 — no change to this repo. In their marketplace entry / `extraKnownMarketplaces`:

```jsonc
// pin the source ref to the frozen v2 branch...
{ "source": { "source": "github", "repo": "easingthemes/dx-aem-flow", "ref": "v2" } }
// ...or to the exact v2 release commit for full reproducibility:
{ "source": { "source": "github", "repo": "easingthemes/dx-aem-flow", "sha": "8d1d295" } }
```

Then `/plugin marketplace update` + reinstall. They keep the entire v2 plugin set (chrome-devtools-mcp included). This is the recommended first response — it's per-consumer and reversible.

### Option B — repo-wide revert (if v3 is bad for everyone)

Revert the v3 merge on `main` and let semantic-release cut a new patch/minor that restores v2 behavior:

```bash
git checkout main && git pull
git revert -m 1 <v3-merge-commit-sha>     # revert the merge
git push                                   # semantic-release publishes the revert as a new version
```

`git revert` (not reset) keeps history linear and auditable. The new version supersedes the broken v3 for all consumers on the default channel; v2-pinned consumers are unaffected.

### Option C — hotfix forward (preferred once a specific bug is known)

Fix the specific issue on a branch off `main`, commit `fix:` (or `feat:`), merge → semantic-release cuts v3.0.1+. Prefer this over a full rollback once the problem is diagnosed — rolling back loses every other v3 improvement.

## Decommissioning the v2 branch

Keep `v2` until v3 has run clean for a sprint or two with no rollback. It costs nothing to retain; delete it only when confident (`git push origin --delete v2`). The 2.112.0 git tag remains a permanent anchor regardless.

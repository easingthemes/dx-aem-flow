# TODO: Naming & UX Improvements

## Rename .ai/me.md

**Added:** 2026-03-03
**Problem:** `.ai/me.md` is the developer's personal tone/style file — used by `dx-pr-answer` for persona-matching in PR replies. Currently lives in `.ai/` alongside project config, making it less discoverable. Unclear if it's personal or project-level.
**Scope:** Skills that reference `me.md`:
- `plugins/dx-core/skills/dx-pr-answer/SKILL.md`
- `plugins/dx-core/skills/dx-pr/SKILL.md`
- `plugins/dx-core/skills/dx-init/SKILL.md` (creates it in Phase 5e)
- `plugins/dx-core/shared/pr-review.md`
- `plugins/dx-core/shared/pr-answer.md`
**Done-when:** `grep -rn "me\.md" plugins/*/skills/*/SKILL.md plugins/*/shared/` shows `.me` instead of `.ai/me.md` in all matches, AND `dx-init` creates `.me` at project root.
**Approach:** Move to `.me` at project root (like `.env`). Gitignore by convention. Update all skill references.
**Open questions:** Does `.me` filename conflict with any tools? Decision needed before proceeding.

## Rename /aem-demo

**Added:** 2026-03-03
**Problem:** `/aem-demo` captures dialog screenshots and writes an editor-friendly authoring guide. The name "demo" is misleading — suggests a live demo, not documentation generation.
**Scope:**
- Skill directory: `plugins/dx-aem/skills/aem-demo/`
- Agent: `plugins/dx-aem/agents/aem-demo-capture.md`
- Coordinator reference: `plugins/dx-core/skills/dx-agent-all/SKILL.md` (Phase 6.5)
- Website: `website/src/` pages that mention `/aem-demo`
- Catalog: `docs/reference/skill-catalog.md`
**Done-when:** `ls plugins/dx-aem/skills/aem-demo 2>&1` returns "No such file or directory" AND `ls plugins/dx-aem/skills/aem-editorial-guide/SKILL.md` exists.
**Approach:** Rename to `/aem-editorial-guide` or `/aem-authoring-guide`. Update all references.

## Revert Namespace Naming

**Added:** 2026-03-03
**Problem:** All skill directories are prefixed with their plugin abbreviation (`dx-init`, `aem-doctor`) to work around broken `plugin:skill` resolution in Claude Code CLI. This makes directory names longer than necessary.
**Scope:** All skill directories across 4 plugins. Validation script: `scripts/validate-skills.sh`.
**Done-when:** Claude Code CLI correctly resolves `plugin:skill` names (check: `dx-core:init` triggers correctly instead of requiring `/dx-init`). Track at [anthropics/claude-code#50486](https://github.com/anthropics/claude-code/issues/50486).
**Approach:** Blocked on upstream fix. When resolved, rename all skill directories to drop the plugin prefix (e.g., `dx-init` → `init`), update `validate-skills.sh`, and update all cross-references.
**Upstream check (2026-07-01):** STILL BLOCKED. Concrete upstream tracker is now [#50486](https://github.com/anthropics/claude-code/issues/50486) (Open, `stale`) — previously "needs filing". Claude Code v2.1.178 added `<dir>:<name>` namespacing but only for nested `.claude/skills`, not plugin skills. Related: [#22063](https://github.com/anthropics/claude-code/issues/22063), [#15944](https://github.com/anthropics/claude-code/issues/15944), [#43695](https://github.com/anthropics/claude-code/issues/43695). Keep the prefix workaround. See [2026-07-01-upstream-dependency-check.md](../research/2026-07-01-upstream-dependency-check.md).

## Visual Separation in Logs — REOPENED

**Added:** 2026-03-03
**First solved:** 2026-03-21 — commits `791c13f` + `b6325a4`
**Reopened:** 2026-09-12 — the solution depended on a tool that is no longer offered by default
**Problem:** Coordinator skills (`dx-req`, `dx-step-all`, `dx-agent-all`, `dx-bug-all`) run many steps sequentially. In terminal output, step boundaries blended together — hard to see where one step ended and the next began.
**Scope:** All `-all` coordinator skills in `plugins/dx-core/skills/`.
**Done-when:** every coordinator writes a progress file — `grep -L "update-progress.sh" plugins/dx-core/skills/dx-{agent-all,step-all,step,req,req-dod,bug-all,figma-all,simple}/SKILL.md` returns nothing.
**First resolution (2026-03-21, now partly void):** Solved differently than originally proposed (horizontal rules) — TaskCreate-based live progress in all 5 coordinators (`b6325a4`) plus a `task-progress.md` rule (`791c13f`). Users saw a live checklist in Claude Code CLI; Copilot CLI fell back to Step N/M text.
**Why it broke:** two problems, found 2026-09-12.
1. Claude Code v2.1.233 stopped offering `TaskCreate`/`TaskGet`/`TaskUpdate`/`TaskList`/`TodoWrite` on Opus 4.8, Sonnet 5, Fable 5, Mythos 5 and newer; v2.1.260 narrowed the allowlist again to Claude 3.x, Opus 4.0–4.7, Sonnet 4.0–4.6, Haiku 4.5. Anthropic's stated reason: newer models track multi-step work without a written checklist, and the tool definitions cost context. `dx-step` and `dx-req` pin `model: sonnet`, which resolves to Sonnet 5 — so no dx skill escaped.
2. `rules/task-progress.md` carried the right guard ("check if `TaskCreate` exists before using it") but had **zero references** anywhere in `plugins/` and no `templates/rules/` counterpart, so it was never installed to `.ai/rules/` and never reached the model. Seven SKILL.md files said "you MUST use `TaskCreate`" with nothing to soften it.
**Second resolution (2026-09-12, #195):** the progress *file* is the source of truth in all 8 skills, written by one shared `shared/update-progress.sh`; task tools are an optional mirror when the session has them. The rule is rewritten as a contract and is now actually wired (template + `/dx-doctor` row). The live-checklist half is opt-in — see #196.

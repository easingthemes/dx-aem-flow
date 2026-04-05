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
**Done-when:** Claude Code CLI correctly resolves `plugin:skill` names (check: `dx-core:init` triggers correctly instead of requiring `/dx-init`). Track at https://github.com/anthropics/claude-code/issues.
**Approach:** Blocked on upstream fix. When resolved, rename all skill directories to drop the plugin prefix (e.g., `dx-init` → `init`), update `validate-skills.sh`, and update all cross-references.

## Visual Separation in Logs — DONE

**Added:** 2026-03-03
**Completed:** 2026-03-21 — commits `791c13f` + `b6325a4`
**Problem:** Coordinator skills (`dx-req`, `dx-step-all`, `dx-agent-all`, `dx-bug-all`) run many steps sequentially. In terminal output, step boundaries blended together — hard to see where one step ended and the next began.
**Scope:** All `-all` coordinator skills in `plugins/dx-core/skills/`.
**Done-when:** `grep -l "TaskCreate\|task-progress" plugins/dx-core/skills/dx-agent-all/SKILL.md plugins/dx-core/rules/task-progress.md` returns both files.
**Resolution:** Solved differently than originally proposed (horizontal rules). Instead, added TaskCreate-based live progress tracking to all 5 coordinators (`b6325a4`) with a universal `task-progress.md` rule (`791c13f`). Users see a live checklist in Claude Code CLI; Copilot CLI falls back to Step N/M text output.

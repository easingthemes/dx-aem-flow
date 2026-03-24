# AEM Discovery TODOs

## Cross-repo discovery consumption

**Added:** 2026-03-24
**Problem:** When working in repo-b, base component field semantics live in repo-a's `.ai/project/component-discovery.md`. dx-req and dx-plan cannot currently read another repo's discovery data, so they miss inherited field meanings and base component structure.
**Scope:** `plugins/dx-core/skills/dx-req/SKILL.md` (Phase 4 $CONTEXT building), `plugins/dx-core/skills/dx-plan/SKILL.md` (input reading)
**Done-when:** `dx-req` reads `../<repo-path>/.ai/project/component-discovery.md` for each repo in the `repos:` config section that has a `path` value, and injects base component fields into `$AEM_CONTEXT`. Verify by running `/dx-req` in a brand-override repo and checking that `research.md` `## AEM Component Intelligence` includes inherited dialog fields from the base repo.
**Approach:** In dx-req Phase 4 step 2b, after reading local `component-discovery.md`, iterate `repos:` entries with `path` set. For each, check if `<path>/.ai/project/component-discovery.md` exists. If yes, read and merge base component entries (marked as `inherited from <repo>`). Requires both repos to have run `/aem-init` with component discovery.

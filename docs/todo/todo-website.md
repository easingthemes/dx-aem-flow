# TODO: Website Improvements

## Remove Skill/Agent Counts from Website Pages

**Added:** 2026-03-22
**Updated:** 2026-04-05
**Problem:** Skill/agent counts (e.g., "76 skills", "13 agents") are maintenance burden with zero user value — they go stale immediately during active development. Counts were centralized in `stats.ts` but should be removed entirely from user-facing content.
**Scope:** `website/src/pages/` — approximately 15 `.mdx` pages still reference `stats.*Skills` and `stats.*Agents` for display. The `stats.ts` file itself.
**Done-when:** `grep -rn "stats\.\(totalSkills\|dxCoreSkills\|dxAemSkills\|dxHubSkills\|dxAutomationSkills\|claudeAgents\|copilotAgents\)" website/src/pages/` returns no matches. `stats.ts` either deleted or reduced to non-count properties only.

**Status:** Phase 1 done — all hardcoded counts removed from markdown files, JSON descriptions, tip content, skill files, marketing docs, and reference catalogs. Phase 2 (website `.mdx` pages using `stats.ts`) still pending.

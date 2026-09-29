# TODO: Website Improvements

## Remove Skill/Agent Counts from Website Pages

**Added:** 2026-03-22
**Updated:** 2026-04-05
**Problem:** Skill/agent counts (e.g., "76 skills", "13 agents") are maintenance burden with zero user value — they go stale immediately during active development. Counts were centralized in `stats.ts` but should be removed entirely from user-facing content.
**Scope:** `website/src/pages/` — approximately 15 `.mdx` pages still reference `stats.*Skills` and `stats.*Agents` for display. The `stats.ts` file itself.
**Done-when:** `grep -rn "stats\.\(totalSkills\|dxCoreSkills\|dxAemSkills\|dxHubSkills\|dxAutomationSkills\|claudeAgents\|copilotAgents\)" website/src/pages/` returns no matches. `stats.ts` either deleted or reduced to non-count properties only.

**Status:** Phase 1 done — all hardcoded counts removed from markdown files, JSON descriptions, tip content, skill files, marketing docs, and reference catalogs. Phase 2 (website `.mdx` pages using `stats.ts`) still pending.

## Tips use models Copilot retires on 2026-10-19

**Added:** 2026-09-29
**Problem:** Copilot retires GPT-5.5, GPT-5.4, GPT-5.4 mini, GPT-5 mini, Grok 4.5 and Gemini 3.7 Flash on 2026-10-19 ([GitHub changelog](https://github.blog/changelog/2026-09-18-upcoming-deprecation-of-selected-github-copilot-models-in-mid-october)). Tips still use them as examples.
**Scope:** `website/src/content/tips/model-selection-more-models-than-you-think.md` (lines 6, 24, 29), `website/src/content/tips/what-is-an-agent-two-formats-one-concept.md:28`.
**Done-when:** `grep -rn "gpt-5.4\|gpt-4o\|GPT-5 mini" website/src/content/tips` returns nothing.

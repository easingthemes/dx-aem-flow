# TODO — Performance

## Reintroduce performance auditing

**Added:** 2026-05-31
**Problem:** The `dx-perf` skill was **removed** as part of the Playwright MCP migration (plugin v3.0.0 — see [research](../research/2026-05-31-playwright-mcp-migration.md)). `dx-perf` relied on `chrome-devtools-mcp`'s Lighthouse / performance-trace / heap-snapshot capabilities, which Microsoft's Playwright MCP (`@playwright/mcp`) does **not** expose. Rather than block the migration on a perf rewrite, perf coverage was dropped with this placeholder. The project currently has **no performance-audit skill**.
**Scope:**
- `plugins/dx-core/skills/dx-perf/` (deleted — recreate or replace)
- `plugins/dx-core/shared/perf-checklist.md` (kept — reuse as the criteria source)
- `docs/reference/skill-catalog.md` (dx-perf row removed — re-add when rebuilt)
- `docs/todo/todo-ruflo-ideas.md`, `docs/todo/todo-plugin-architecture-review.md` (mention dx-perf — update if they assumed it exists)
**Done-when:** A performance-audit skill exists and runs end-to-end (measures baseline → identifies bottlenecks → verifies improvement) without depending on `chrome-devtools-mcp`. Verify: `ls plugins/dx-core/skills/dx-perf*/SKILL.md` returns a file AND its body references the chosen perf tool (not chrome-devtools).
**Approach (options to evaluate):**
- **Playwright `--caps=devtools`** — gives tracing/video, but **not** Lighthouse scores. Good for trace capture, insufficient for Core Web Vitals scoring on its own.
- **Standalone Lighthouse CI** (`@lhci/cli` / `lighthouse` npm) — run as a Bash step against a URL, parse JSON output. Best for CWV/scores; no MCP needed.
- **WebPageTest API** — richest data, external dependency + API key.
- Likely answer: a Bash-driven Lighthouse run (scores) + optional Playwright trace (detail), wired into a rebuilt `dx-perf`. Keep `perf-checklist.md` as the rubric.

# TODO — Tracker Hygiene

Data-integrity issues found during the 2026-08-04 plugin review
([roadmap](../research/2026-08-04-plugin-review-roadmap.md)). The methodology depends on
verifiable "Done-when" checks, so silent tracker rot undermines the whole system.

## Fix duplicate item numbers and the missing detail file

**Added:** 2026-08-04
**Problem:** Two integrity defects in `TODO.md`:
1. Item numbers **69–77 are triple-overlapping** — one series links to
   `todo-plugin-architecture-review.md` (all Done), a second reuses 69–74 for
   `todo-cross-platform.md`, a third reuses 75–77 for `todo-context-graphs.md`. Three distinct
   items can share a single number, so cross-references are ambiguous.
2. Items **#33–#41 link to `todo-review-plugin-improvements.md`, which does not exist** on disk
   (`ls docs/todo/todo-review-plugin-improvements.md` → No such file). Eight items — including
   High-priority #33 (hook `if` conditional) and #35 (hook `statusMessage`) — have no backing
   Problem/Scope/Done-when.
**Scope:** `docs/todo/TODO.md` (rows 42–50 and 85–104); `docs/todo/todo-review-plugin-improvements.md` (to create or the rows to retire).
**Done-when:**
- `grep -nE '^\| (69|70|71|72|73|74|75|76|77) ' docs/todo/TODO.md` returns each number exactly once (renumber the cross-platform + context-graph series to unused numbers), AND
- `ls docs/todo/todo-review-plugin-improvements.md` succeeds (file created with the 9 items' detail) OR rows #33–#41 are moved to an existing detail file and no `TODO.md` link points to the missing file (`grep -c todo-review-plugin-improvements docs/todo/TODO.md` → 0).
**Approach:** Renumber the second/third #69–77 blocks to the next free range; back-fill or relocate the #33–#41 detail. Reconcile the header "Counts" line afterwards.

# TODO — Tracker Hygiene

Data-integrity issues found during the 2026-08-04 plugin review
([roadmap](../research/2026-08-04-plugin-review-roadmap.md)). The methodology depends on
verifiable "Done-when" checks, so silent tracker rot undermines the whole system.

## Fix duplicate item numbers and the missing detail file

**Status: Done (2026-09-13).**

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

**Resolution (2026-09-13):**
- Cross-platform series **#69–74 → #183–188**; context-graph series **#75–80 →
  #189–194**; the plugin-architecture-review series keeps **#69–77**. Each row
  carries a "Renumbered 2026-09-13 (was #N)" note, and `TODO.md` has a
  renumbering log explaining why **#78–#80 are now retired numbers**.
- No cross-reference to any renumbered item existed outside `TODO.md` — verified
  with `grep -rn "#69".."#80" docs/todo/*.md docs/ website/`, which returned only
  this file's own Approach line.
- `docs/todo/todo-review-plugin-improvements.md` **created** with back-filled
  Problem / Scope / Done-when for all nine items #33–#41. Every Done-when was run
  against the tree on 2026-09-13, so each is known to be executable rather than
  aspirational. Two items turned out to be closer to done than the rows implied
  (#35 `statusMessage`: 8 of 10 dx-core handlers have one, the two without are
  `async`; #36: the dx-aem screenshot hooks are already `async`, only the two
  dx-core Figma handlers are not) — both recorded as findings, neither silently
  closed.
- `TODO.md` **Counts** line recounted: 191 items, numbered to #194.

**Verification:**
```
grep -nE '^\| (69|70|71|72|73|74|75|76|77) ' docs/todo/TODO.md   # each exactly once
grep -c todo-review-plugin-improvements docs/todo/TODO.md         # 9 links, file now exists
ls docs/todo/todo-review-plugin-improvements.md                   # succeeds
```

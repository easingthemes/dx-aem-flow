# Architect prep / hand-off flow

An architect or lead runs the first pipeline steps (`/dx-req`, `/dx-plan`) ahead of the sprint, reviews a wiki page, and hands the ticket to a dev or an agent that continues only the missing steps. No separate "solution review" artifact: it would repeat the dx-req Phase 1/3/4 output that `[DevPlan]` and `[Estimation]` already use, and `plan-thinking.md` already holds the alternatives, ordering and risks.

Target outputs: one short ADO comment (`[DevPlan]`) for people, one wiki page for detailed reading, spec files for the implementation flow.

## Pre-research context in dx-req Phase 1

**Added:** 2026-11-23
**Problem:** Phase 1 missed context an architect checks first: Related / Predecessor / Successor items (state, sprint, release), contracts agreed in comments of a related story, mockups posted as comment images (only field and attachment images were downloaded), and the scope tags in the title (`[FE]`, `[BE]`) that tell which repos are involved.
**Scope:** `plugins/dx-core/data/lib/fetch-raw-story.js` (+ `.test.js`), `plugins/dx-core/skills/dx-req/SKILL.md` (Phase 1 call + raw-story template, Phase 4 `$CONTEXT`), `plugins/dx-core/templates/config.yaml.template`, `docs/reference/config-reference.md` (`dx-req.*`).
**Done-when:** `node --test plugins/dx-core/data/lib/fetch-raw-story.test.js` passes and covers `extractLinkedItemRefs`, `fetchLinkedItems`, `releaseAlignment`, `extractTitleTags` and comment images in `extractImageManifest`; `grep -n "release-tag-regex" plugins/dx-core/skills/dx-req/SKILL.md docs/reference/config-reference.md` hits both.
**Approach:** Done 2026-11-23. Config: `dx-req.release-tag-regex`, `dx-req.related-comments`, `dx-req.scope-repos` — all off by default. The script extracts scope tags; the repo mapping is applied by the skill in Phase 4, as a hint, not a limit.

## dx-agent-all detects prepared spec files

**Added:** 2026-11-23
**Problem:** `run-state.json` is trusted for 2 hours only. A hand-off days later relies on each sub-skill being idempotent, but nothing tells the dev which phases were skipped, and nothing stops a re-plan from overwriting an `implement.md` someone else prepared.
**Scope:** `plugins/dx-core/skills/dx-agent-all/SKILL.md`, possibly a helper in `plugins/dx-core/data/lib/`.
**Done-when:** at start, dx-agent-all prints a list of found spec files (`raw-story.md`, `explain.md`, `research.md`, `implement.md`, `docs/plan-wiki.md`) and the phases it skips; `grep -n "\-\-force" plugins/dx-core/skills/dx-agent-all/SKILL.md` documents that an existing `implement.md` is only regenerated with `--force`.

## dx-prep: architect prep and hand-off

**Added:** 2026-11-23
**Problem:** There is no single command for "prepare this ticket for someone else": the plan stays in local spec files, the detailed plan is not readable in the wiki, and a fresh checkout (pipeline or another dev) does not see the prepared files.
**Scope:** new `plugins/dx-core/skills/dx-prep/`, `skills/dx-req/references/share-template.md`, dx-doc-gen wiki path logic (reuse, do not change its output), skill catalog.
**Done-when:** `/dx-prep <id>` on a test project produces spec files, a wiki page `<scm.wiki-doc-root>/<Sprint>/<id>-<slug>/Development Plan`, a `[DevPlan]` comment with the wiki link, a "Prepared steps" block and "Next: `/dx-agent-all <id>`", and the spec folder pushed on the feature branch; a second run creates no duplicate page or comment.
**Approach:** wiki **child page**, so dx-doc-gen can keep overwriting the parent page. Content from spec files only (no new research): summary, repos and files from research.md, dialog fields, contracts, dependencies and release alignment, risks, open questions, decisions from `plan-thinking.md`, steps from `implement.md`. Upsert with ETag; local copy at `<spec-dir>/docs/plan-wiki.md`.

## Update DevPlan in place

**Added:** 2026-11-23
**Problem:** When the plan changes, `share-template.md` posts a new "Plan Updated" comment. Repeated prep runs pile up comments.
**Scope:** `plugins/dx-core/skills/dx-req/references/share-template.md`.
**Done-when:** a re-run with a changed plan edits the existing `[DevPlan]` comment (same comment id) when the ADO MCP offers a comment-update action; otherwise the current behaviour stays, and the template says why.
**Approach:** first check whether `@azure-devops/mcp` has a comment-update action on `wit_work_item`.

## Record plan deviations

**Added:** 2026-11-23
**Problem:** A prepared plan is a default, not a contract. When code-level work disagrees, the reason is lost, and the wiki page no longer matches what was built.
**Scope:** `plugins/dx-core/skills/dx-step/SKILL.md`, `plugins/dx-core/skills/dx-doc-gen/SKILL.md`.
**Done-when:** dx-step writes `**Deviation:** <why>` in the step when it departs from the plan; dx-doc-gen output has a "Planned vs built" section listing them (`grep -n "Deviation" plugins/dx-core/skills/dx-step/SKILL.md plugins/dx-core/skills/dx-doc-gen/SKILL.md`).

## Plan review marker

**Added:** 2026-11-23
**Problem:** Reporting can't tell "plan prepared" from "plan prepared and reviewed", and the comment markers are not documented as the canonical signal.
**Scope:** `plugins/dx-core/shared/provider-config.md` (comment signature table), `templates/config.yaml.template`, `skills/dx-agent-all/SKILL.md`.
**Done-when:** the signature table names `[DevPlan]` + wiki link as the "solution prepared" marker; an optional config key for a review tag exists, and dx-agent-all shows (or, if configured, requires) it.

## Story points in DevPlan

**Added:** 2026-11-23
**Problem:** Teams that use `[DevPlan]` might want story points from their own template in the same comment instead of a separate `[Estimation]`.
**Scope:** `skills/dx-req/references/share-template.md`, `skills/dx-estimate/`.
**Done-when:** decision recorded after #277 is in use.
**Approach:** Deferred — `dx-estimate` already does this; merging it into `[DevPlan]` mixes two jobs.

## Wiki story page lookup

**Added:** 2026-11-23
**Problem:** dx-doc-gen and dx-prep reused an existing story page only when its name started with `<id>-`. Hand-made wikis also use `<id> <title>`, `<id>: <title>` and several leading ids, so most stories got a second `<id>-<slug>` page and the plan landed under the duplicate. Stories carried over to a later sprint were not found either. The plan page was titled "Development Plan" only, so teams that used a "Solution Review" step could not tell it replaced that step.
**Scope:** `plugins/dx-core/data/lib/dx-common.sh` (`wiki-story-page`), `plugins/dx-core/shared/wiki-story-page.md`, `skills/dx-doc-gen/SKILL.md` (6a/6b), `skills/dx-prep/SKILL.md`, `data/templates/wiki/plan-wiki.md.template`, `skills/dx-req/references/share-template.md`, config template + `docs/reference/config-reference.md` (`dx-prep.wiki-page-title`).
**Done-when:** `bash plugins/dx-core/data/lib/tests/dx-common-wiki-story-page.test.sh` passes (all name forms, several ids, carried-over sprint, prefix false positives, no match); `grep -n "wiki-story-page.md" plugins/dx-core/skills/dx-doc-gen/SKILL.md plugins/dx-core/skills/dx-prep/SKILL.md` hits both.
**Approach:** Done 2026-11-23. Because the resolver now finds hand-written pages, dx-doc-gen merges its output between hidden markers (ADO) or under a `Generated documentation (dx-doc-gen)` heading (Confluence) instead of overwriting the team's content; dx-prep never writes an existing story page.

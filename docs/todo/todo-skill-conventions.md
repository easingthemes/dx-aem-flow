# Skill Authoring Conventions

Items derived from [2026-05-15-google-skills-best-practices.md](../research/2026-05-15-google-skills-best-practices.md).
Each item is independent — adopt incrementally.

## Audit and expand skill descriptions for trigger coverage

**Added:** 2026-05-15
**Problem:** Most of our skill descriptions cover one canonical trigger phrase
(e.g., `aem-component`: *"Use when a developer asks 'where is component X?'"*).
Google bundles 4-6 trigger phrases per description (*"Use when X, Y, or Z.
Also use when A or B."*), which improves auto-activation accuracy across
Claude Code, Copilot CLI, VS Code Chat, and Cursor — all of which match on
description text.
**Scope:** All `plugins/*/skills/*/SKILL.md` frontmatter `description:` fields
(40+ skills across 4 plugins). Frontmatter-only change; no body edits.
**Done-when:** Each `description:` lists at least 3 distinct trigger phrases
(verify with `grep -c "Use when\|Also use\|use this when"
plugins/*/skills/*/SKILL.md`) AND the existing `tests/run-evals.sh --quick`
suite still passes (existing prompts must still match their target skill).
**Approach:** Reference Google's `bigquery-basics` description as a template.
Group skills by plugin, do dx-core first (highest install rate). Update the
eval prompts in `tests/prompts/` to cover any newly added triggers.

## Codify `references/` progressive-disclosure pattern

**Added:** 2026-05-15
**Problem:** 7 skills already have `references/` subdirectories
(`dx-pr-review`, `dx-req`, `dx-pr-answer`, `dx-figma-extract`, `dx-figma-verify`,
`dx-figma-prototype`, `dx-dor`, `aem-fe-verify`) but the pattern isn't
documented as a convention. Some skills exceed 250 lines
(`aem-component` is 263) where splitting into `references/` would aid
scannability. Google's rule of thumb: SKILL.md stays ~50-150 lines, depth
moves to `references/<topic>.md`, and SKILL.md ends with a "Reference
Directory" section.
**Scope:** `CLAUDE.md` (Skill Structure section), website docs (Skill
Authoring page), and the 5-8 skills currently >150 lines:
`plugins/dx-aem/skills/aem-component/SKILL.md`,
`plugins/dx-aem/skills/aem-verify/SKILL.md`,
plus audit results.
**Done-when:** (1) `CLAUDE.md` Skill Structure section documents the
`references/` pattern with a max-line guideline; (2) website Skill
Authoring page has a "Progressive Disclosure" sub-section; (3) skills
matching `find plugins -name SKILL.md | xargs wc -l | awk '$1 > 200'`
either have `references/` or have a tracked exception.
**Approach:** Define the convention first (CLAUDE.md edit), then refactor
the 2-3 largest offending skills as exemplars before fanning out.

## Add "Core Directives" with ALWAYS / DO NOT pairs to skills with anti-patterns

**Added:** 2026-05-15
**Problem:** Several of our skills have implicit anti-patterns
(`dx-step`: never commit on main; `dx-pr`: never amend published commits;
`aem-init`: never write to repo root; `aem-verify`: never trust visual diff
alone) that are scattered through prose rather than surfaced in a single
declarative block. Google's `gemini-api` skill collects these into a "Core
Directives" section with paired ALWAYS / DO NOT statements followed by a
`> [!WARNING]` callout. Much easier to scan and harder for the LLM to miss.
**Scope:** `plugins/dx-core/skills/dx-step/SKILL.md`,
`plugins/dx-core/skills/dx-pr/SKILL.md`,
`plugins/dx-aem/skills/aem-init/SKILL.md`,
`plugins/dx-aem/skills/aem-verify/SKILL.md`,
`plugins/dx-core/skills/dx-step-fix/SKILL.md`.
**Done-when:** Each listed skill has a `## Core Directives` section near
the top (after the one-liner intro) containing ≥2 ALWAYS/DO NOT pairs,
verified with `grep -l "## Core Directives" plugins/*/skills/*/SKILL.md`.
**Approach:** Extract existing implicit rules — don't invent new ones.
Keep each directive to 1-2 lines.

## Standardize on GFM markdown alerts for hard rules

**Added:** 2026-05-15
**Problem:** We currently use a mix of **bold**, ALL-CAPS, and prefixed
phrases like "CRITICAL RULE:" / "IMPORTANT:" for emphasis. GitHub-flavored
markdown alerts (`> [!WARNING]`, `> [!IMPORTANT]`, `> [!TIP]`, `> [!NOTE]`,
`> [!CAUTION]`) render natively on GitHub, VS Code, Cursor IDE, and most
modern renderers — they're more semantic and visually distinct than bold
text. Google's skills use them consistently.
**Scope:** All `plugins/*/skills/*/SKILL.md` and all `plugins/*/agents/*.md`.
Find-replace pass with editorial judgement.
**Done-when:** Zero matches for `^\*\*CRITICAL` or `^\*\*IMPORTANT:\*\*` at
the start of a line in `plugins/`, replaced with `> [!CRITICAL]` /
`> [!IMPORTANT]` blocks. Spot-check rendering on GitHub PR preview.
**Approach:** Low priority polish. Best done alongside the Core Directives
work (which already needs `> [!WARNING]` blocks per Google's template).

## Formalize the "Recipe" skill archetype

**Added:** 2026-05-15
**Problem:** Our procedural / first-run skills (`dx-init`, `aem-init`,
`dx-hub-init`, `dx-bug`, `dx-pr`) each invented their own shape. Google
defines a clean Recipe template:
**Overview → Clarifying Questions → Prerequisites → Steps → Validation
Logic**. Adopting this would make first-run flows more consistent and
reduce per-skill structural decisions.
**Scope:** New docs page at `website/src/pages/conventions/recipe-skills.mdx`
(or similar) and refactor of the 5 listed skills to match the template.
**Done-when:** (1) Docs page exists with template + example; (2) the 5
init/procedural skills above have all five archetype sections (verify with
`grep -l "## Clarifying Questions\|## Validation Logic"
plugins/*/skills/{dx-init,aem-init,dx-hub-init,dx-bug,dx-pr}/SKILL.md`);
(3) `CLAUDE.md` Conventions section references the Recipe archetype.
**Approach:** Write the docs page first using `google-cloud-recipe-onboarding`
as the model. Refactor `dx-init` as the first exemplar — it's the most
visible skill — then fan out.

## Embed failure-mode triage blocks in operational skills

**Added:** 2026-05-15
**Problem:** Google's Cloud Run skill includes an inline "What to do if
deployment fails:" block with 3-5 numbered symptom → cause → exact-command
entries. Inline triage is much faster than navigating to a linked file. We
do this in places (`dx-step-fix`, `aem-doctor`) but unevenly.
**Scope:** `plugins/dx-aem/skills/aem-doctor/SKILL.md`,
`plugins/dx-aem/skills/aem-verify/SKILL.md`,
`plugins/dx-aem/skills/aem-fe-verify/SKILL.md`,
`plugins/dx-core/skills/dx-step-fix/SKILL.md`,
`plugins/dx-core/skills/dx-pr-answer/SKILL.md`.
**Done-when:** Each listed skill has a `## When <X> fails` (or
`### Troubleshooting`) section with at least 3 numbered entries in
**symptom → diagnostic command → fix** form.
**Approach:** Mine the existing failure modes from
`docs/research/*.md` and `docs/todo/todo-bugs.md` — most are already
documented, just not embedded in the skills that need them at runtime.

## Adopt MCP fallback escape hatch as a template line

**Added:** 2026-05-15
**Problem:** Google's reference-using skills end the "Reference Directory"
section with a one-liner: *"If you need product information not found in
these references, use the Developer Knowledge MCP server `search_documents`
tool."* Clean escape hatch when the LLM hits a gap. We have `context7`
(`mcp__97246f63-...__query-docs`) and Microsoft Docs MCP available but
don't systematically tell skills to fall through to them.
**Scope:** The 7 skills with `references/`:
`plugins/dx-core/skills/{dx-pr-review,dx-req,dx-pr-answer,dx-figma-extract,
dx-figma-verify,dx-figma-prototype,dx-dor}/SKILL.md`,
`plugins/dx-aem/skills/aem-fe-verify/SKILL.md`.
**Done-when:** Each Reference Directory section in those 8 SKILL.md files
ends with a fallback line pointing to `context7` (`query-docs` /
`resolve-library-id`) or — for AEM-specific skills — to `mcp__plugin_dx-aem_AEM__`
search tools. Verified with `grep -l "If you need.*not found.*MCP"
plugins/*/skills/*/SKILL.md`.
**Approach:** Single template line, varied per skill domain. Trivial PR.

## Add "Related Skills" cross-links to chained workflows

**Added:** 2026-05-15
**Problem:** Our dx workflow has natural chains
(`dx-req` → `dx-plan` → `dx-step` → `dx-step-verify` → `dx-pr` →
`dx-pr-review`) but skills don't cross-link to their predecessors and
successors. Google's `bigquery-basics` ends with a "Related Skills" section
linking to `bigquery-ai-ml`. Cross-links help the LLM (and the human reader)
chain skills correctly.
**Scope:** Workflow skills:
`plugins/dx-core/skills/{dx-req,dx-plan,dx-step,dx-step-verify,dx-step-fix,
dx-pr,dx-pr-review,dx-pr-answer,dx-dor,dx-dod}/SKILL.md`.
**Done-when:** Each listed skill has a `## Related Skills` section near
the bottom listing predecessor + successor with one-line role descriptions.
Verified with `grep -L "## Related Skills"
plugins/dx-core/skills/{dx-req,dx-plan,dx-step,dx-step-verify,dx-step-fix,
dx-pr,dx-pr-review,dx-pr-answer,dx-dor,dx-dod}/SKILL.md` returning empty.
**Approach:** Build the chain map once (it's in `docs/reference/skill-catalog.md`
already), then mechanically apply.

## Add source-of-truth doc pointer at bottom of externally-dependent skills

**Added:** 2026-05-15
**Problem:** Skills that wrap external systems (AEM, ADO, Jira, Figma, axe)
have references that can go stale as upstream evolves. Google's skills end
with a "Source of truth" link to canonical upstream docs even when
`references/` is present. We don't do this consistently.
**Scope:** All AEM skills (`plugins/dx-aem/skills/*`), Figma skills
(`plugins/dx-core/skills/dx-figma-*`), ADO/Jira-specific skills (`dx-req`,
`dx-pr-*`, `dx-dor`, `dx-dod`).
**Done-when:** Each listed skill has a final section
(`## Documentation` or `## Source of Truth`) linking to canonical upstream
docs (AEM developer site, Figma plugin API, ADO REST reference, etc.).
Verified by spot-check.
**Approach:** Lowest priority of the set — pure polish. Bundle with one of
the larger refactors (B or E) rather than its own pass.

## Lift "Validation Logic" section into Recipe template

**Added:** 2026-05-15
**Problem:** Our TODO format already requires a `Done-when:` field — concrete,
verifiable checks. Google applies the same idea at skill-execution level:
every Recipe skill ends with **Validation Logic** listing the checks the
agent should run to confirm successful completion. Lifting this into the
Recipe archetype gives every procedural skill a deterministic "done" gate.
**Scope:** Bundled with the Recipe archetype TODO (above) — same 5 skills.
**Done-when:** Each of the 5 procedural skills has a `## Validation Logic`
section with ≥3 verifiable checks (each check has a command, file glob,
or grep the agent can run).
**Approach:** Implement as part of the Recipe-archetype rollout. Don't ship
as a separate pass.

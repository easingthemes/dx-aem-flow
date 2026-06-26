# Skill Authoring Conventions

Items derived from [2026-05-15-google-skills-best-practices.md](../research/2026-05-15-google-skills-best-practices.md),
**reality-checked against [official Claude Code skills docs](https://code.claude.com/docs/en/skills)
and [agent-skills best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)**.

Each item is independent — adopt incrementally.

> **Reading order:** items are listed in **recommended adoption order** (small
> wins first, biggest refactors last). The "Dropped after reality check"
> section at the bottom records what we considered and rejected.

## 1. Adopt the dedicated `when_to_use` frontmatter field

**Added:** 2026-05-15
**Problem:** Anthropic provides a dedicated `when_to_use` field separate from
`description`, designed for trigger phrases and example requests. The
description field is capped at 1024 chars; combined with `when_to_use` the
listing shows up to 1,536 chars. None of our 40+ skills currently use
`when_to_use` — we stuff triggers into `description`, which both bloats the
"what it does" purpose and risks overflow against the listing budget when
the user has many skills installed. Anthropic explicitly recommends the
split: description = what it does, when_to_use = trigger phrasing.
**Scope:** All `plugins/*/skills/*/SKILL.md` frontmatter. Frontmatter-only
change.
**Done-when:** Every skill's frontmatter has both `description:` (what it
does, third-person) and `when_to_use:` (trigger phrases and example user
requests). Verify with `grep -L "when_to_use:" plugins/*/skills/*/SKILL.md`
returning empty.
**Approach:** Mechanical pass. For each skill, move trigger phrasing
("Use when...") out of `description` and into `when_to_use:`. Keep
`description` to the "what it does" verb phrase only. Run
`tests/run-evals.sh --quick` to confirm no regressions.

## 2. Audit and expand skill descriptions for trigger coverage

**Added:** 2026-05-15
**Problem:** Most of our skill descriptions cover one canonical trigger
phrase (e.g., `aem-component`: *"Use when a developer asks 'where is
component X?'"*). Anthropic's documented examples include 3-5 distinct
trigger phrases per skill (e.g., *"Use when working with PDF files or when
the user mentions PDFs, forms, or document extraction"*). More triggers →
better auto-activation across Claude Code, Copilot CLI, VS Code Chat,
and Cursor. Pairs naturally with TODO #1 — extra triggers live in
`when_to_use:`.
**Scope:** All `plugins/*/skills/*/SKILL.md` frontmatter — bundle with #1.
**Done-when:** Each `when_to_use:` lists at least 3 distinct trigger
phrases AND `tests/run-evals.sh --quick` still passes (existing prompts
must still match their target skill, and no skill should now match
prompts intended for a different skill).
**Approach:** Use Anthropic's `bigquery-basics` and PDF skill descriptions
as templates. Group skills by plugin, do `dx-core` first (highest install
rate). Update `tests/prompts/` to cover any newly added triggers and
guard against false-positive cross-matches.

## 3. Replace weak imperatives with MUST / MUST NOT

**Added:** 2026-05-15
**Problem:** Anthropic explicitly recommends *"stronger language like
'MUST filter' instead of 'always filter'"* when rules must not be
skipped. Our skills are full of soft verbs: `should`, `consider`,
`try to`, `you may want to`, `you can`. For workflow steps where
skipping causes real harm (committing on main, amending published
commits, writing to repo root from `aem-init`, etc.), these soft verbs
let Claude rationalize a skip.
**Scope:** All `plugins/*/skills/*/SKILL.md` and `plugins/*/agents/*.md`.
**Done-when:** Procedural steps that must run produce zero matches for
`\b(should|try to|consider|may want to|you can)\b` in the imperative
contexts. Verify with:
```bash
grep -rE "\b(should|try to|consider|may want to|you can)\b" \
  plugins/*/skills/*/SKILL.md | grep -v "user may" | wc -l
# Target: significant reduction, not zero (some uses are legitimate prose)
```
**Approach:** Editorial pass with judgement — not every "should" is wrong
(prose like "the agent should expect X" is fine). Focus on numbered
workflow steps and rules. Replace `you should commit on branch X` with
`you MUST commit on branch X`. Drop hedges (`try to use X` → `use X`).
Pairs with the dropped Core Directives idea — same goal, simpler fix.

## 4. Codify `references/` progressive-disclosure at the documented 500-line threshold

**Added:** 2026-05-15
**Problem:** 7 of our skills already use `references/`
(`dx-pr-review`, `dx-req`, `dx-pr-answer`, `dx-figma-extract`,
`dx-figma-verify`, `dx-figma-prototype`, `dx-dor`, `aem-fe-verify`), but
the pattern isn't documented as a convention. Anthropic's explicit
guidance: *"Keep SKILL.md body under 500 lines for optimal performance.
Split content into separate files when approaching this limit."* Once a
skill loads, its content stays in context across turns — every line is a
recurring token cost.
**Scope:** `CLAUDE.md` (Skill Structure section), website docs (Skill
Authoring page), and any skill exceeding ~400 lines.
**Done-when:** (1) `CLAUDE.md` Skill Structure section documents the
500-line guideline + `references/` pattern citing the official docs;
(2) website Skill Authoring page has a "Progressive Disclosure" sub-section;
(3) `find plugins -name SKILL.md | xargs wc -l | awk '$1 > 500'` returns
empty or each remaining offender has a documented exception.
**Approach:** Document the convention first (CLAUDE.md edit). Audit
current line counts:
`find plugins -name SKILL.md | xargs wc -l | sort -rn | head -10`. Only
refactor skills genuinely above 500 — the earlier 150-line threshold
from the Google review was too aggressive.

## 5. Enforce one-level-deep reference structure

**Added:** 2026-05-15
**Problem:** Anthropic explicit rule: *"Keep references one level deep
from SKILL.md."* Claude may partially read files via `head -100` when
they are reached through nested references, resulting in incomplete
information. Our existing `references/` directories may have files that
link to other reference files (nested), which silently degrades skill
quality.
**Scope:** All existing `references/` subdirectories: `dx-pr-review`,
`dx-req`, `dx-pr-answer`, `dx-figma-extract`, `dx-figma-verify`,
`dx-figma-prototype`, `dx-dor`, `aem-fe-verify`.
**Done-when:** No reference file links to another reference file in the
same skill. Verify with:
```bash
for f in plugins/*/skills/*/references/*.md; do
  grep -l 'references/\|\.\./references' "$f" 2>/dev/null
done
# Target: empty output
```
**Approach:** For each nested link found, either (a) inline the target
content into the linking file, or (b) move both targets up to SKILL.md
as siblings. Small mechanical pass.

## 6. Add table of contents to reference files longer than 100 lines

**Added:** 2026-05-15
**Problem:** Anthropic explicit guidance: *"For reference files longer
than 100 lines, include a table of contents at the top. This ensures
Claude can see the full scope of available information even when
previewing with partial reads."* Claude `head -100`s reference files when
deciding whether to load them; a TOC in the first 100 lines preserves
discoverability.
**Scope:** All reference files >100 lines:
```bash
find plugins -path '*/references/*.md' | xargs wc -l | awk '$1 > 100'
```
**Done-when:** Every file in the audit list above starts with a
`## Contents` (or `## Table of contents`) section listing its top-level
headings within the first 100 lines.
**Approach:** Mechanical pass. Auto-generate TOCs from existing headings.

## 7. Adopt workflow-with-checklist pattern for procedural skills

**Added:** 2026-05-15
**Problem:** Anthropic documents a "Workflows for complex tasks" pattern
with an embedded checkbox checklist Claude copies into its response and
checks off as it progresses (see the PDF form-filling example in the
best-practices docs). Our procedural skills (`dx-init`, `aem-init`,
`dx-hub-init`, `dx-bug`, `dx-pr`) all have multi-step flows but none use
this pattern. Checklists prevent step-skipping and give the user a
progress signal. **Note:** the earlier "Recipe archetype" proposal had
extra sections like "Clarifying Questions" that Anthropic does not
document — drop those, keep the core (numbered steps + checklist +
validation gates).
**Scope:** `plugins/dx-core/skills/dx-init/SKILL.md`,
`plugins/dx-aem/skills/aem-init/SKILL.md`,
`plugins/dx-hub/skills/dx-hub-init/SKILL.md`,
`plugins/dx-core/skills/dx-bug/SKILL.md`,
`plugins/dx-core/skills/dx-pr/SKILL.md`.
**Done-when:** Each listed skill has (a) a checkbox progress checklist
at the start of the workflow section, and (b) numbered steps with a
clear validation gate before "done" (see TODO #8).
**Approach:** Use Anthropic's "PDF form filling workflow" as the
template. Start with `dx-init` as the exemplar (most visible skill).

## 8. Add machine-verifiable validation gates to workflow skills

**Added:** 2026-05-15
**Problem:** Anthropic's documented validation-loop pattern is *"validator
→ fix errors → repeat"* with the explicit gate *"Only proceed when
validation passes"*. Our procedural skills currently end without a
machine-verifiable "done" check — Claude declares success and moves on.
The TODO `Done-when:` field in this very tracker uses the same principle
applied to backlog items; lifting it into skill execution closes the
loop.
**Scope:** Bundled with TODO #7 — same 5 skills.
**Done-when:** Each procedural skill has a final `## Verification` (or
similar) section listing at least 3 verifiable checks. Each check is a
command, file glob, or grep the agent can run — not a human checklist.
Verify by spot-check: pick one skill, run the checks manually, confirm
they actually catch a fault when one is injected.
**Approach:** Implement as part of the workflow rollout in #7. Reuse the
TODO Done-when discipline. Example: `dx-init` should end with
*"Verify: `.ai/config.yaml` exists with non-empty `scm.base-branch` and
`build.command`; `.claude/settings.local.json` exists; `git status` is
clean."*

## 9. Concise-body audit for skills over ~200 lines

**Added:** 2026-05-15
**Problem:** Anthropic's first principle: *"Default assumption: Claude is
already very smart. Only add context Claude doesn't already have."* Our
largest skills include explanatory prose that Claude doesn't need
(definitions of common terms, justifications for design choices,
narrative about why something matters). `aem-component` is 263 lines;
several others exceed 200. Once a skill loads, all of it stays in
context across turns — every paragraph competes with conversation
history.
**Scope:** Top 10 longest skills:
`find plugins -name SKILL.md | xargs wc -l | sort -rn | head -10`.
Start with `aem-component` (263 lines).
**Done-when:** The top-10 longest skills have been audited line-by-line
with the test *"does this paragraph justify its token cost?"* and
verbose explanations have been removed. No skill exceeds 500 lines
(threshold from #4). For each audited skill, run the relevant eval
prompts and confirm no regression.
**Approach:** This is editorial work, not mechanical. Pair with #10
(consistent terminology) since both touch the same files.

## 10. Consistent terminology audit

**Added:** 2026-05-15
**Problem:** Anthropic explicit guidance: *"Choose one term and use it
throughout the Skill."* Our skills mix:
- *ticket* / *story* / *work-item* / *issue* (across ADO/Jira skills)
- *component* / *module* / *block* (in AEM skills)
- *PR* / *pull-request* / *pull request*
- *branch* / *feature branch* / *topic branch*
Inconsistency makes it harder for Claude to follow chained instructions.
**Scope:** All `plugins/*/skills/*/SKILL.md` and `plugins/*/agents/*.md`.
Bundle with #9 since both are line-by-line audits.
**Done-when:** Documented canonical term list in `docs/reference/terminology.md`
and zero violations across `plugins/`. Verify with a per-pair grep, e.g.
`grep -rE "\b(ticket|story|work-item)\b" plugins/` should consistently
use only the canonical term.
**Approach:** Build the canonical list first (one row per concept),
then do a find-replace pass with judgement (some quoted strings or
external references must stay as-is).

## 11. Embed failure-mode triage in operational skills (low priority)

**Added:** 2026-05-15
**Problem:** Not explicitly in Anthropic's docs, but consistent with the
"solve, don't punt" principle. Symptom → diagnostic command → fix inline
beats "if something fails, ask Claude" for ops skills.
**Scope:** `plugins/dx-aem/skills/aem-doctor/SKILL.md`,
`plugins/dx-aem/skills/aem-verify/SKILL.md`,
`plugins/dx-aem/skills/aem-fe-verify/SKILL.md`,
`plugins/dx-core/skills/dx-step-fix/SKILL.md`,
`plugins/dx-core/skills/dx-pr-answer/SKILL.md`.
**Done-when:** Each listed skill has a `## When <X> fails` section with
at least 3 numbered entries in **symptom → diagnostic command → fix** form.
**Approach:** Mine existing failure modes from `docs/research/*.md` and
`docs/todo/todo-bugs.md`.

## 12. Source-of-truth doc pointers in externally-dependent skills (lowest priority)

**Added:** 2026-05-15
**Problem:** Skills wrapping external systems (AEM, ADO, Jira, Figma, axe)
can drift from upstream over time. A single canonical-doc link at the
bottom is a cheap insurance policy. Aligns with Anthropic's "avoid
time-sensitive information" guidance.
**Scope:** All AEM skills (`plugins/dx-aem/skills/*`), Figma skills
(`plugins/dx-core/skills/dx-figma-*`), ADO/Jira-specific skills
(`dx-req`, `dx-pr-*`, `dx-dor`, `dx-dod`).
**Done-when:** Each listed skill has a final `## Documentation` section
linking to canonical upstream docs.
**Approach:** Bundle with whichever larger refactor next touches each
skill. Don't do as its own pass.

## 13. No-op audit — remove filler instructions that don't change agent behavior

**Added:** 2026-06-26
**Problem:** Skills can accumulate "no-op" lines — instructions that sound meaningful but don't actually change what the agent does, because the agent would do it anyway. Examples: "be thorough", "think carefully", "write clear commit messages", "make the output easy to read". These burn tokens on every skill invocation, make skills harder to audit, and dilute the signal of the instructions that actually matter. This codebase has very few (1–2 confirmed vs. the ~77 SKILL.md files), but they should be removed, and a convention should prevent new ones from creeping in via AI-assisted skill authoring.
**Scope:**
- `plugins/dx-core/skills/dx-figma-extract/SKILL.md:275` — "be thorough" (the rationale "only Figma interaction" is fine; the "be thorough" phrase is not)
- `plugins/dx-core/skills/dx-figma-prototype/SKILL.md:152` — explanatory sentence ("This ensures the prototype is grounded in the actual component library...") adds rationale but no behavioral constraint
- `CLAUDE.md` Conventions checklist — add a no-op rule
**Done-when:**
```bash
# Confirmed no-ops removed:
grep -n "be thorough" plugins/dx-core/skills/dx-figma-extract/SKILL.md  # returns empty
grep -n "grounded in the actual component library" plugins/dx-core/skills/dx-figma-prototype/SKILL.md  # returns empty
# No-op rule present in checklist:
grep -n "no-op" CLAUDE.md  # returns a line in the Checklist section
```
**Approach:** Three steps, in order:
1. **Remove the 2 confirmed no-ops** — targeted Edit on each file. Test: re-read the surrounding context and confirm the removal doesn't drop a behavioral constraint (the "be thorough" removal keeps the "only Figma interaction" rationale; the prototype sentence removal is safe because the preceding steps already instruct the agent to use the component library).
2. **Add to CLAUDE.md checklist** — one bullet: *"No no-ops — every instruction must change agent behavior. No 'be thorough', 'think carefully', 'write clear X'. Test: remove the line; if output doesn't change, the line was a no-op."*
3. **Broader section-level audit** (deferred, pair with #9 concise-body audit) — scan the 10 longest SKILL.md files for entire paragraphs that describe *what* the skill does rather than constraining *how*. These are subtler no-ops: rationale prose that makes the skill feel complete but doesn't alter execution.

---

## Dropped after reality check against Claude Code docs

These were in the initial Google-derived list but were rejected against
Anthropic's documented best practices. Recorded here so the decision is
traceable.

### Core Directives blocks (ALWAYS / DO NOT pairs)

**Dropped.** Anthropic doesn't endorse extracted directive blocks. The
"concise is key" principle says every line is a recurring cost — a Core
Directives section duplicates rules that appear elsewhere in the skill.
**Replaced by:** TODO #3 (replace weak imperatives with MUST / MUST NOT
**inline**). Same intent, smaller token cost, documented Anthropic
guidance.

### GFM markdown alerts (`> [!WARNING]` etc.)

**Dropped.** Anthropic's own docs use Mintlify `<Note>`/`<Tip>`/`<Warning>`
components, but their **skill examples never use GFM alerts**. Pure
aesthetics with no documented behavioral effect on Claude. The
emphasis-via-stronger-language approach (TODO #3) is what Anthropic
actually documents.

### MCP fallback escape-hatch line

**Dropped.** Anthropic explicit guidance: *"Avoid offering too many
options. Don't present multiple approaches unless necessary."* Adding
"if X doesn't cover it, try MCP server Y" is exactly the kind of
optionality that bloats SKILL.md without behavior gain. Better fix:
write reference docs that are complete enough that fallback isn't needed.

### Related Skills cross-link sections

**Dropped.** Claude already has all skill descriptions in context — cross-
links don't aid discovery. Skill content stays in context across turns,
so cross-link sections add **recurring** token cost for every turn after
invocation. Violates "every line is a recurring token cost". The natural
chain (`dx-req` → `dx-plan` → `dx-step`) is documented in
`docs/reference/skill-catalog.md` for humans — that's the right home.
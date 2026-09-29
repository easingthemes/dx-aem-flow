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

**Status: Superseded 2026-09-29 — inverted.** Current Anthropic guidance for Claude 5 says the opposite: aggressive MUST/CRITICAL causes overtriggering and emphasis on many lines stops working. Replaced by § 9 phase 2 (de-emphasis). Kept below for history.

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
**Status update 2026-07-01:** Regressed — **13 skills now exceed 500
lines** (was 3 over ~260 in June). Top offenders: `dx-pr-review` (1121),
`dx-simple` (1025), `dx-init` (941), `dx-pr-answer` (938), `dx-req`
(754), `dx-bug-verify` (740), `dx-agent-all` (737). This is now a
confirmed violation of Anthropic's documented <500-line rule, not just a
Copilot partial-read issue. See
[2026-07-01-plugin-eval-claude-copilot.md](../research/2026-07-01-plugin-eval-claude-copilot.md).
Priority raised Medium → High.

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

**Rescoped 2026-09-29: unattended pipelines only.** CC v2.1.233 stopped offering TodoWrite/Task tools on newer models because they track multi-step work without a checklist; the Opus 5.5 prompting page still recommends a checklist file **plus a continuation nudge** for unattended runs. So: `dx-automation` pipeline agents only, not interactive skills. Overlaps #197 (progress-file re-inject + Stop gate).

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

## 9. Lean skills for Claude 5 — umbrella

**Added:** 2026-05-15 · **Rewritten 2026-09-29** as the single tracker for "fewer rules, shorter
skills". Absorbs #107 (inverted — see below) and #162. Measurements and sources:
[2026-09-29-lean-skills-measurement.md](../research/2026-09-29-lean-skills-measurement.md).
**Problem:** Claude Code cut its own system prompt 80%+ for Claude 5 with no eval loss, and
Anthropic's current prompting guidance says skills written for older models are often too
prescriptive and can degrade output; aggressive emphasis now causes overtriggering. Our skills
were written for older models: 77 skills, ~290k tok, 13 over 500 lines, 162 CAPS imperatives in
53 skills, only 8 use `references/`, and ~9.2k tok of descriptions load in every consumer
session. **Measured 2026-09-29, the mass is procedure, templates (~25%) and mode branches — not
filler:** rationale is 28 lines, no-ops 2. The old framing ("remove explanatory prose") would
save little.
**Constraint (2026-09-29):** no cutting until it can be tested. Every phase that changes
behaviour is gated on an A/B eval.
**Scope:** `plugins/*/skills/*/SKILL.md`, `plugins/*/agents/*.md`, `plugins/*/rules/*.md`,
`plugins/*/templates/rules/`.
**Phases** (each its own PR; the gate applies to 2–4):
0. **Measure** — #170 (interactive `/skill-doctor` + `/doctor prompt-audit <path>`) and #137
   (token baseline). Tooling for the gate: #167 plus a version A/B — run `claude plugin eval`
   at both git refs with `--model`/`--judge-model` pinned, or skill-creator's blind version
   comparison. At least one eval case per skill before it is cut.
1. **No-behaviour cuts** (no eval needed): dev history in skill text (issue/TODO numbers,
   dates, versions — 34 hits), the 2 no-ops, the 16 cross-skill duplicate paragraphs (move to
   `shared/`). Orchestration duplicates (measured 2026-09-29): "You run in a forked context…
   determine whether invoked by the orchestrator" ×6 and "MUST end with `## Return`" ×8 — state
   once in the coordinator's invocation args; `dx-step-verify:165` pastes the whole
   `dx-code-reviewer` body into a subagent that already has it as its system prompt.
2. **De-emphasis** (inverts old #107): replace CAPS MUST/NEVER/CRITICAL with plain
   imperatives; keep emphasis on at most a few load-bearing lines per skill; drop hedges.
   Target ≤ 5 `CRITICAL|IMPORTANT` across all skills.
3. **Restated and generic rules**: `## Rules`-type sections (~15.8k tok in 71 skills) keep only
   non-obvious project gotchas; drop lines that repeat a step or describe behaviour Claude does
   anyway ("Read before judging", "Human voice"). Verification scaffolding (27 lines) by model
   tier: remove on Opus-tier skills, keep a concrete check on Sonnet/low-effort ones.
4. **Size**: move templates, examples and rarely-taken branches (interactive vs automation,
   Copilot install steps in `dx-init`) to `references/` — #108 threshold. Start with the top 5.
   Mode branches are the biggest removable mass: `dx-bug-all` Pipeline-mode text is ~72% of the
   file and loads in Local mode too; mode-branch lines: `dx-agent-all` 25, `dx-pr-review` 23,
   `dx-step-all` 19, `dx-bug-all` 17. Also drop hub-mode re-checks in workers the coordinator
   already gated (`dx-req`, `dx-step`, `dx-bug-fix`, `dx-bug-triage`).
   Coordinator DOT graphs (~8k tok across coordinators, `dx-simple` alone ~2k): keep graphs for
   loops and gates (the #220 fix relied on explicit loop invariants); for linear phases consider
   dropping the node-per-heading duplication — a CLAUDE.md convention change + `validate-skills.sh`.
**Done-when:** (per phase, checkable)
- P1: `grep -rnE '\bTODO #[0-9]+|\bissue #[0-9]+' plugins/*/skills/*/SKILL.md` returns 0.
- P2: `grep -rhoE '\b(CRITICAL|IMPORTANT)\b' plugins/*/skills/*/SKILL.md | wc -l` ≤ 5.
- P3/P4: every changed skill has an eval result at old and new ref in `docs/research/`, with no
  score drop; `find plugins -name SKILL.md -exec wc -l {} + | awk '$1>500 && $2!="total"' | wc -l` is 0.
**Progress 2026-09-29 — phase 1 partly done (no behaviour change):** removed the 10 dev-history
refs (TODO #141/#147/#151, issue #136) from 7 skills — `PR #12345`-style example IDs kept; removed
the 2 no-ops (`dx-figma-extract` "be thorough", `dx-figma-prototype` rationale sentence;
`dx-step-fix:337` is an anti-rationalization table row, kept); `dx-step-verify` now pastes the
`dx-code-reviewer` body only on the `general-purpose` fallback (the typed agent already has it —
saves ~2.6k tok per review). **Still open in phase 1:** the 16 cross-skill duplicate paragraphs and
the forked-context boilerplate ×6–8 — moving them changes where instructions live and how workers
detect orchestration, so they wait for the eval gate. P1 Done-when now passes for the history refs.
**Related:** #108 (500-line threshold), #111 (checklists — pipelines only), #137, #167, #170,
#237 (review filter), #238 (description footprint), #239 (reasoning-echo lint), #222 (tiers),
#240 (fork remaining inline workers), #241 (inline-chain budget lint), #242 (verification layering).

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

**Status: Merged into § 9 (phase 1), 2026-09-29.** Measured: 2 no-ops in all skills, so this is a small part of phase 1, not its own item.

**Added:** 2026-06-26
**Source:** https://x.com/mattpocockuk/status/2069784839474032896?s=46
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

## 14. Add negative-trigger clauses to collision-prone skill descriptions

**Status: Done (2026-09-13).** A "Do NOT use …" clause was added to the
`when_to_use` frontmatter of all 20 cluster members, each naming the sibling it
is most confused with. `dx-estimate` also had its `description` quoted — the
unquoted `Batch mode: ` made the YAML frontmatter unparseable. The Done-when
loop below returns no output; `validate-skills.sh` and `validate-agents.sh`
pass on all 77 skills and 13 agents.

**Added:** 2026-07-20
**Source:** [2026-07-20-skill-authoring-best-practices.md](../research/2026-07-20-skill-authoring-best-practices.md)
§6 + §8 rule 3 (Philipp Schmid, "Don't Ship Skills Without Evals"). The talk's
#1 rule: trigger problems cause 50%+ of skill failures, and rewriting the
description alone fixed 5 of 7 failures in their eval suite. Defining when a
skill should **NOT** fire is half of that fix.
**Problem:** Only **4 of 77** skills state when they should NOT trigger
(`dx-council`, `dx-figma-extract`, `dx-figma-prototype`, `dx-figma-verify`).
Meanwhile the catalog has dense keyword clusters that compete for the same
prompts: **7 `dx-pr-*`** skills all keyed on "PR"/"review"
(`dx-pr`, `dx-pr-commit`, `dx-pr-review`, `dx-pr-review-all`,
`dx-pr-review-report`, `dx-pr-reviews-report`, `dx-pr-answer`); **5 verify**
skills (`aem-verify`, `aem-fe-verify`, `aem-qa`, `dx-step-verify`,
`dx-figma-verify`); **4 `dx-bug-*`**; **4 `dx-req-*`**; **3 doc-gen**. When a
user says "review my PR", six skills have a claim and nothing disambiguates
them. Broad, negative-free descriptions hijack unrelated prompts (the talk's
"Use for any coding task" anti-pattern). This is the single highest-leverage,
lowest-effort trigger fix available for our catalog.
**Scope:** `when_to_use:` (preferred, per #1) or `description:` frontmatter of the
cluster members above — frontmatter-only change. Not every skill needs one; only
those that share keywords with a sibling.
**Done-when:** Each skill in a collision cluster has an explicit "Do NOT
trigger for …" clause naming the sibling it's most confused with, **in the
frontmatter** (`description`/`when_to_use`) — not in the body (a body-scoped
grep false-passes on procedural lines like "do not push to main"). Verify:
```bash
for s in dx-pr dx-pr-commit dx-pr-review dx-pr-review-all dx-pr-review-report \
         dx-pr-reviews-report dx-pr-answer aem-verify aem-fe-verify aem-qa \
         dx-step-verify dx-bug-all dx-bug-fix dx-bug-triage dx-bug-verify \
         dx-req dx-req-import dx-req-tasks dx-req-dod; do
  f=$(find plugins -path "*/skills/$s/SKILL.md")
  fm=$(awk 'NR==1&&/^---/{f=1;next} f&&/^---/{exit} f{print}' "$f")
  echo "$fm" | grep -qiE "do not|don't|not for" || echo "MISSING negative trigger: $s"
done
# Target: no output (all 19 currently print MISSING as of 2026-07-20)
```
**Approach:** Frontmatter-only editorial pass, cluster by cluster (start with
`dx-pr-*` — highest overlap). For each member, name the one sibling it's most
confused with, e.g. `dx-pr-review`: *"Do NOT use to create or push a PR (that's
dx-pr) or to answer existing review comments (that's dx-pr-answer)."* The **test**
side lives in todo-testing.md "Cross-harness + negative eval coverage" — add a
`should_trigger: false` case per cluster so a too-broad clause fails CI. Pairs
with #2 (expand positive trigger coverage) and #106.

---

## 15. Instruction-conflict audit across the override stack

**Added:** 2026-07-25
**Source:** [2026-07-25-context-engineering-claude5.md](../research/2026-07-25-context-engineering-claude5.md)
(Thariq / Anthropic, "The New Rules of Context Engineering for Claude 5 models").
Core finding: Anthropic removed 80%+ of Claude Code's system prompt for Claude 5
models with no eval loss, because the model resolves intent better than rigid
rules do. The named failure mode is **conflicting instructions in a single
assembled context** — their example: system prompt says "leave documentation as
appropriate", a skill says "do not add comments", the user says "just make it
work like the old one". Claude *can* reconcile these, but it spends reasoning
doing so, and the guardrails that forced them were for older models.
**Problem:** Our three-layer override system (`.ai/rules/` > `config.yaml`
overrides > plugin `rules/*.md`) plus 77 skills plus project `CLAUDE.md` all
stack into one context. Nothing today checks that a directive in one layer
doesn't contradict another — e.g. a "never write comments" imperative in a skill
vs. a project rule asking for JSDoc, or a `pragmatism.md` rule that fights a
skill's verbosity gate. These clashes are invisible until they degrade a run.
This is distinct from #13 (no-op filler — lines that do nothing) and #107 (weak
imperatives): here the lines each do something, but they **disagree**.
**Scope:** `plugins/*/rules/*.md`, `plugins/*/skills/*/SKILL.md` (imperative
lines), the shipped `.ai/rules/*.md` templates
(`plugins/dx-core/templates/rules/`), and the guidance in root `CLAUDE.md` /
`AGENTS.md`. Focus on comment/documentation policy, verbosity/output-length
policy, and "always/never" pairs that appear in more than one layer.
**Done-when:** A written audit at `docs/research/` (or a section appended to the
2026-07-25 research doc) lists every cross-layer contradiction found, classified
as (a) real conflict → reconcile to one owning layer, (b) intentional override →
document the precedence, or (c) obsolete guardrail → delete per the "let Claude
use judgement" finding. Concretely, the comment-policy check must pass: no two
layers give opposing comment directives for the same context. Verify the
comment-policy slice with:
```bash
grep -rniE "(never|do not|don't|always) (write|add).*(comment|docstring|documentation)" \
     plugins/*/skills/*/SKILL.md plugins/*/rules/*.md plugins/dx-core/templates/rules/ \
  | sort
# Then confirm no two matching lines target the same situation with opposite polarity.
```
**Approach:** Grep the "always/never + verb" imperatives per topic, group by
topic, diff polarities across layers. For each real conflict pick the single
owning layer (usually `.ai/rules/` for project taste, skill body only for
skill-local mechanics) and delete the duplicate. Prefer the article's new-era
phrasing — "match the surrounding code's comment density and idiom" — over
absolute bans. Pairs with #107 (MUST/MUST NOT) and #16 (`/doctor` pass).

**Audit run 2026-07-25 — no conflicts found.** Swept all 6 plugin `rules/*.md`,
7 `templates/rules/*`, 77 skills, and root `CLAUDE.md`/`AGENTS.md` across the
three scoped topics. Comment-policy Done-when check **passes** — grep for any
code-comment directive returns zero hits (every "comment" in the tree is
PR/Jira comments, not code). Verbosity directives are all skill-local (no
blanket rule to collide). "Proceed-without-asking" directives are all mode-gated
(`AUTOMATION=1` / mine-mode / active-PR / plugin-owned) and reinforce, not
contradict, `pragmatism.md`. Global rules are internally consistent and
topic-scoped. Residue is **duplication/absence, not contradiction** → routed to
#113 (concise-body), #107 (imperative strength), #111 (clarifying-questions
scaffolding). Full write-up + verify commands:
[2026-07-25-context-engineering-claude5.md § Findings](../research/2026-07-25-context-engineering-claude5.md#findings--instruction-conflict-audit-todo-169-run-2026-07-25).
**Re-run after #170's `/doctor` pass** to confirm cuts don't reintroduce a clash.

## 16. Rightsize CLAUDE.md + skills with `/doctor`

**Update 2026-09-29:** absorbs #225 — v2.1.283 `/doctor prompt-audit` takes a path (`/doctor prompt-audit plugins/dx-core/skills/dx-pr-review`) and checks for old-model prompting patterns, stale paths and contradicting instruction files; run it in the same interactive session as `/skill-doctor` and #137. Adds a size target: the [memory docs](https://code.claude.com/docs/en/memory) say keep each CLAUDE.md under 200 lines (ours: 397), and v2.1.282 warns on combined instruction-file size. Extra Done-when: `wc -l < CLAUDE.md` ≤ 200, with moved architecture content in `website/` (keep gotchas). This is phase 0 of § 9.

**Status: Blocked — needs an interactive session (re-anchored 2026-09-13).**
Claude Code v2.1.261 (2026-09-04) shipped **`/skill-doctor`**, which reports which loaded
skills go unused and what each costs in context. That is a more direct instrument
than the general `/doctor` this item was written against, and it is the same
measurement #137 needs, so run both in one session. Neither `/doctor` nor
`/skill-doctor` has a headless equivalent — this item cannot be closed from a
background or pipeline run, and its tracker Status says so. Record the raw
per-skill numbers in § 9 (concise-body audit, #113) before interpreting them.

**Added:** 2026-07-25
**Source:** [2026-07-25-context-engineering-claude5.md](../research/2026-07-25-context-engineering-claude5.md).
The article ships its best practices as the `/doctor` (a.k.a. `claude doctor`)
command, described as auto-simplifying an over-constrained system prompt,
`CLAUDE.md`, and skills for the Claude 5 generation. It directly targets the
over-specification our own concise-body (#113) and no-op (#162) audits chase by
hand.
**Problem:** Our `CLAUDE.md` is large and prose-heavy, and the skill catalog has
13 skills over the 500-line reference threshold (#108) with a median ~283 lines
(#113). The article's CLAUDE.md guidance is narrower than what we ship: keep it
light, state the repo's purpose briefly, then spend most tokens on **gotchas**,
and push detail into progressively-disclosed skills. We have never run the
first-party rightsizing tool against our files to get a baseline of what it would
cut.
**Scope:** root `CLAUDE.md`, `AGENTS.md`, and the top offenders from #113/#108
(`dx-pr-review`, `dx-simple`, `dx-init` SKILL.md). Tool: `/doctor` in an
interactive Claude Code session (not available in this non-interactive
environment).
**Done-when:** `/doctor` has been run against `CLAUDE.md` and the three top
offender skills, and its recommendations are recorded — either applied as commits
or captured as a decision list in #113 with per-file accept/reject rationale.
Concretely, a note in this item records the `/doctor` output date and the
token-delta it proposed for `CLAUDE.md`. Feed the numbers into #137's
token-footprint baseline so #113 is ranked by measured cost, not guesswork.
**Approach:** Run `/doctor` interactively; treat its cuts as a proposal, not
gospel — keep the gotcha-density content the article explicitly wants in
`CLAUDE.md`, accept the prose/rule-bloat cuts. Cross-ref #113 (concise-body),
#108 (500-line threshold), #137 (footprint baseline), #162 (no-op audit), #15
(conflict audit — run before/after so `/doctor`'s cuts don't reintroduce a
contradiction).

---

## 17. Split finding from filtering in PR review

**Added:** 2026-09-29
**Problem:** Anthropic's Sonnet 5 and Opus 5 prompting pages say review prompts that filter at
find time ("only high severity", "be conservative", "don't nitpick") make the model find bugs
and then not report them — recall drops. Fix: report every finding with confidence and
severity, filter in a separate pass (or define the bar concretely). Our review stack filters at
find time everywhere: `plugins/dx-core/rules/pr-review.md` (+ `templates/rules/pr-review.md.template`)
"Only report issues with confidence >= 80", "Maximum 10 findings", "don't nitpick";
`agents/dx-code-reviewer.md` (7 places), `agents/dx-pr-reviewer.md`, `skills/dx-pr-review/SKILL.md`.
This also drives the automated PR Reviewer. #169 missed it: it looked for layers that
disagree, and these all agree — they are an obsolete guardrail.
**Scope:** the files above; `dx-pr-review` step that posts findings.
**Done-when:** `grep -rnE 'confidence (>=|≥) ?80|Maximum 10' plugins/dx-core/agents plugins/dx-core/rules plugins/dx-core/templates/rules`
returns only a separate filter step (not the finding instructions), AND an eval fixture with a
real low-severity bug plus distractors is scored at the old and new ref (recall must not drop,
posted-comment count must not rise past the current cap).
**Approach:** Reviewer agent returns all findings with confidence + severity; the skill applies
the ≥ 80 / top-10 filter when posting. Posting behaviour stays the same; only where the filter
sits changes. Needs an eval before merging (§ 9 gate).

## 18. Always-loaded description footprint

**Added:** 2026-09-29
**Problem:** Skill descriptions (+ `when_to_use`) load in every session of a consumer with all
4 plugins: ~9.2k tok, avg 241 chars, max 847 (`dx-council`). That is the largest fixed cost we
put in every session — larger than all always-loaded rules (~1.6k) — and it grew with the
negative-trigger clauses of #166. Trimming it is low behaviour risk only if routing does not
regress.
**Scope:** `description:` / `when_to_use:` in `plugins/*/skills/*/SKILL.md`.
**Done-when:** the re-measure snippet in the 2026-09-29 research note reports descriptions
≤ 6k tok, no description > 400 chars, and the skill-routing eval (#168) passes at the new ref.
**Approach:** Put trigger phrases in `when_to_use` only where they disambiguate; drop
restatements of the skill name; keep #166 negative clauses short. Check whether rarely used
skills should be `disable-model-invocation: true` (user-invoked only — no description in the
listing).

## 19. Lint for reasoning-echo instructions

**Status:** Done 2026-09-29 — `scripts/validate-skills.sh` check 7; fixtures in `validate-skills.test.sh` (6 fail with the check disabled).

**Added:** 2026-09-29
**Problem:** The Fable 5 / Opus 5.5 / Sonnet 5.5 prompting pages say prompts that make the model
print its reasoning can be refused (`stop_reason: "refusal"`), and server-side fallback does
not retry. A refusal in a pipeline agent fails the run. Grep today finds no such phrasing in
`plugins/`, so this is prevention, not a fix.
**Scope:** `scripts/validate-skills.sh`, `scripts/validate-skills.test.sh`.
**Done-when:** `validate-skills.sh` errors on `explain your reasoning|show your (thinking|reasoning)|think step by step|reasoning trace`
in `plugins/*/{skills,agents}`, and `validate-skills.test.sh` has a fixture that proves it fires.

## 20. Fork the remaining inline workers in coordinators

**Added:** 2026-09-29
**Problem:** #220 fixed one instance of a bug class: a worker loaded inline with `Skill()` (no
`context: fork`) brings its whole body into the coordinator, and its human hand-off ending
("Next steps: run `/…`") can end the coordinator's loop. The class is still open elsewhere
(measured 2026-09-29):
- `dx-bug-all/SKILL.md:79-81` loads `dx-bug-triage`, `dx-bug-verify`, `dx-bug-fix` inline — none
  forked; triage ends with "Next steps" (`:555`), verify and fix likewise. ~31k tok stacked in one
  context, the biggest inline chain; may be why `ado-cli-bug-fix.yml` needs `MAX_TURNS: 250` vs
  dev-agent's 80.
- `dx-agent-all` loads `dx-ticket-analyze`, `dx-figma-all` (→ extract/prototype/verify),
  `dx-pr`, `dx-doc-gen` inline (~17k base, ~33k with Figma + docs). `dx-figma-all` ends with
  "Next Steps … `/dx-plan`", `dx-pr` with "Next step: run `/dx-step-verify`". `dx-agent-all:83`
  claims every phase runs lean via Skill — false for these five.
- `dx-ticket-analyze` is `model: haiku, effort: low` loaded inline — whether that downgrades the
  coordinator's turn is unverified; forking removes the question.
- Nested forks (`dx-agent-all` → `dx-step-all` → `dx-step`) are untested; #220's Done-when only
  covers standalone `/dx-step-all`.
Current Claude 5 guidance favours this fix over adding "do not stop" emphasis (which would
overtrigger).
**Scope:** `plugins/dx-core/skills/{dx-bug-triage,dx-bug-verify,dx-bug-fix,dx-figma-all,dx-ticket-analyze,dx-doc-gen,dx-pr}/SKILL.md`,
their callers `dx-bug-all`, `dx-agent-all`; forked workers must end with a `## Return` block.
**Done-when:** `grep -L '^context: fork' plugins/dx-core/skills/{dx-bug-triage,dx-bug-verify,dx-bug-fix,dx-figma-all,dx-ticket-analyze,dx-doc-gen,dx-pr}/SKILL.md`
prints nothing, AND one `/dx-bug-all` run and one `/dx-agent-all` run with ≥ 3 steps each
complete without a nudge and write their `runs.jsonl` record. **Behaviour change — needs a
consumer run** (not mobile-doable for closure).
**Approach:** Same as #220. Check each worker's standalone use still prints its human summary
(fork only changes what reaches the parent).

## 21. Inline-chain context budget lint

**Status:** Done 2026-09-29 — `scripts/validate-skills.sh` check 8; baseline `CHAIN_OVER_BASELINE=3` (dx-agent-all, dx-bug-all, dx-pr-review-all). Lower it as #240 forks the workers.

**Added:** 2026-09-29
**Problem:** "Only the invoked skill body loads" is false for inline chains: a coordinator that
`Skill()`s an unforked worker pays both bodies in one context. Nothing measures or limits this;
chains grew to ~31k (`dx-bug-all`) and ~33k (`dx-agent-all` with Figma) without anyone seeing
it.
**Scope:** `scripts/validate-skills.sh`, `scripts/validate-skills.test.sh`.
**Done-when:** `validate-skills.sh` sums the bodies reachable through `Skill(/x)` calls whose
target has no `context: fork` and errors above a budget (start 15k tok, ratchet like the
oversized-body check); `validate-skills.test.sh` has an over-budget fixture that proves it
fires. No behaviour change — mobile-doable. Will fail until #240 lands, so ship it with a
baseline ratchet.

## 22. Verification layering audit

**Added:** 2026-09-29
**Problem:** One `/dx-agent-all` story is verified 5–6 layers deep: mandatory per-step review
in `dx-step` (`:466`), `dx-plan-validate`, `dx-step-verify` (6 phases + up to 3 review cycles),
heal (up to 2 cycles, each re-running verify → up to ~9 review passes), `aem-verify` /
`aem-fe-verify`, then the automated PR Reviewer; `dx-simple` adds `dx-pr-reviewer` (`:805`).
Anti-rationalization tables sit in 8 skills (`dx-step:452`, `dx-step-fix`, `dx-step-verify`,
`dx-step-build`, …). Opus 5 prompting guidance: explicit verification instructions cause
over-verification with no quality gain; Sonnet at low effort still needs a concrete check.
**Scope:** the skills above; `dx-agent-all` heal loop; cross-ref #113 phase 3, #65, #159.
**Done-when:** a written decision in this section naming one owner per check (per-step review
vs verify vs heal), then `grep -lE 'Rationalization' plugins/*/skills/*/SKILL.md | wc -l` ≤ 2 (Sonnet-tier only) and an
agent-all eval shows no score drop at old vs new ref. **Behaviour change — needs evals.**

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
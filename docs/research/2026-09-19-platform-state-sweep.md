# Platform state sweep — 2026-09-19

Where the four plugins stand against Claude Code, Copilot CLI, and the Agent Skills
ecosystem. Previous platform-state sweep: [2026-06-10](2026-06-10-platform-state-update.md),
whose proposals were never intaken — [TODO #171](../todo/TODO.md) has owed this since June.

Companion to the same day's [upstream dependency check](2026-09-19-upstream-dependency-check.md),
which covers the *blocked-on-upstream* issues. This one covers *version currency* and
*standards conformance*, which that sweep does not.

**Method:** published changelogs and specifications read directly; version numbers taken
from `npm view` rather than from release-notes prose; frontmatter counts measured across
all 77 skills with `awk` over the actual files, not from documentation. Everything marked
**unverified** below was not run.

---

## Headline: current on versions, behind on execution

| Tool | Latest | What we track | Delta |
|---|---|---|---|
| Claude Code | **2.1.278** (2026-09-19) | intake covers → v2.1.277 | 1 release, minor |
| Copilot CLI | **1.0.86** stable / 1.0.87-0 pre | pinned v1.0.86 / v1.0.87-0 | none |
| ADO MCP | 2.10.0 | pinned, source read | none |
| Agent Skills spec | 6 fields, no version number | claimed conformance, never mapped | **mapped here** |

Version tracking is same-day and needs no catch-up. The gap is throughput: 205 TODO
items, 137 open. That is the same verdict as the
[2026-08-04 review](2026-08-04-plugin-review-roadmap.md) — *"8/10, the gap is execution
not knowledge"* — six weeks later, unmoved.

---

## Claude Code — one release behind, and it is small

v2.1.278 (2026-09-19) carries two entries:

1. **Auto mode classifier moves server-side by default** for Claude API, Enterprise and
   Bedrock/Vertex/Foundry, with no classifier overhead charge.
   `CLAUDE_CODE_AUTO_MODE_SERVER=0` opts out on Bedrock/Vertex/Foundry.
2. **AGENTS.md**: projects without a `CLAUDE.md` now read `AGENTS.md`; changed under
   *Project instructions* in `/config`. Still not on Bedrock/Vertex/Foundry.

The second is already documented in `CLAUDE.md` § Cross-Platform Agent Support, with the
four `instructionFiles` modes and the Bedrock/Vertex/Foundry caveat — which matters
because that is where `dx-automation` pipelines may run. The five "since v2.1.277"
references in `CLAUDE.md`, `AGENTS.md` and `README.md` are **correct as they stand**: the
feature shipped in v2.1.277 and v2.1.278 only restates the default. Nothing to change.
**TODO #207 stays Done.**

The first is new and unrecorded. It is not actionable for us today, but the
Bedrock/Vertex/Foundry opt-out belongs with the other pipeline runtime flags in
[TODO #200](../todo/todo-upstream-2026-09.md), which already batches five of them into one
launcher change.

### Two v2.1.275 entries with no coverage anywhere in the repo

`grep -rn 'syncClaudeAiSkills\|syncClaudeAiPlugins\|--marketplace' .` → nothing.

- **claude.ai → terminal sync.** Skills and plugins enabled on claude.ai now sync into
  terminal sessions, opt out with `syncClaudeAiSkills: false` / `syncClaudeAiPlugins: false`.
  This changes what a consumer sees as installed, independently of what `/plugin install`
  put there. It also has a conformance edge — see the claude.ai upload subset below.
- **`/plugin install <plugin> --marketplace <source>`.** This is the one-command install
  [TODO #16](../todo/TODO.md) asked for and closed as fixed upstream. [TODO #210](../todo/todo-upstream-2026-09.md)
  has it as a docs item; our install docs still show the two-step add-then-install flow.

Both are docs-only, both already have a row. Noting them here because the row says "Low"
and the sync one is not low — it changes what users believe they have installed.

---

## Copilot CLI — current version, stale notes

v1.0.86 (2026-09-17) stable, v1.0.87-0 (2026-09-18) pre-release. We track both correctly.

**One entry needs intake.** v1.0.86:

> "Custom agents can opt into repository instruction files (AGENTS.md,
> copilot-instructions.md, CLAUDE.md) by setting `include-custom-instructions: true` in
> their frontmatter."

This is the Copilot-side counterpart of Claude Code's `omitClaudeMd` (v2.1.271,
[TODO #202](../todo/todo-upstream-2026-09.md)) — the same knob, opposite default. Claude
Code loads `CLAUDE.md` into subagents and lets you opt *out*; Copilot omits repository
instructions from custom agents and now lets you opt *in*. We ship 13 agents across two
plugins and set neither field. Worth deciding once, for both platforms, in the same pass:
the lookup agents (`dx-file-resolver`, `dx-doc-searcher`, `aem-page-finder`) want neither
file; the reviewers exist to enforce what is in them. → **TODO #215.**

**The real Copilot problem is not a missing feature, it is stale evidence.** Four open
rows — [#20](../todo/TODO.md) (subagents can't invoke skills), #22 (port hooks, High since
March), #40 (hook compatibility matrix), #182 (batch re-test) — were written against
Copilot CLI **v1.0.36–1.0.40**. Current is 1.0.86: roughly fifty releases of drift. Every
one of those rows already carries a "Version pin (2026-09-13) … stale, fold into #182"
note, so the diagnosis is six days old and correct; what is missing is the re-test.

Meanwhile the [upstream check](2026-09-19-upstream-dependency-check.md) found #20 has
actually **regressed** ([copilot-cli#4708](https://github.com/github/copilot-cli/issues/4708),
opened 2026-09-03, no maintainer response). Re-testing against a version where a known
regression is live is the cheapest way to turn four stale rows into two real ones.

**#182 is the highest-value item in this sweep.** It unblocks #20, #22 and #40 at once,
and it needs a Copilot CLI session, not a decision.

---

## Agent Skills — the conformance claim, settled

We claim conformance with the [Agent Skills open standard](https://agentskills.io/specification)
in three shipped places: `AGENTS.md:52`, `.codex/INSTALL.md:42`, and the website
(`learn/intro.mdx:247`, plus the front-page footnote at `index.mdx:252`).
[TODO #41](../todo/todo-review-plugin-improvements.md) has sat on "Watch" since 2026-03-27
because nobody had read the spec field-by-field against our files.

Done now. Full mapping in
[`docs/reference/skill-frontmatter-compatibility.md`](../reference/skill-frontmatter-compatibility.md).
Summary:

**The spec is six fields** — `name` and `description` required; `license`,
`compatibility`, `metadata`, `allowed-tools` optional. Nothing else. `metadata` is the
spec's named escape hatch for client-specific properties.

**We ship 13 top-level keys across 77 skills.** Five are spec (`name`, `description`,
`allowed-tools`, `compatibility`, `metadata`); eight are Claude Code extensions
(`when_to_use`, `argument-hint`, `model`, `context`, `effort`, `agent`,
`disable-model-invocation`, `hooks`). All eight are *documented Claude Code fields* — none
is invented — and all degrade safely on Copilot CLI (unknown-field warnings suppressed
since v1.0.10) and on Codex (documents only `name` and `description`).

**So: conformant-plus-extensions, which is fine — but the docs say "uses the open
standard" flat, and that overstates it.** Corrected wording is proposed in the reference
file.

### Three findings worth more than the wording fix

**1. Hard spec rules: we pass all of them.** 77/77 on `name`-matches-directory, 77/77 on
name charset/length, 77/77 on the 1,024-char description cap. `scripts/validate-skills.sh`
already enforces all three — it is a spec-conformance checker that nobody framed as one.
13 skills exceed the 500-line body guidance, which matches the ratcheted baseline
[#203](../todo/todo-testing.md) measured today, from an independent count. Two methods,
same number: the baseline is real.

**2. `allowed-tools` uses the wrong form in all 64 skills that set it.** The spec says
*space-separated string*; we use a YAML list. Claude Code documents both, so this works
where we primarily run. A skill copied out of this repo into a stricter client may not get
the grant.

**3. `allowed-tools` may be granting nothing at all — unverified.** Our values are
lowercase (`read`, `edit`, `write`, `search`, `agent`), taken from the Copilot-shaped
recommendation table in
[`allowed-tools-compatibility.md`](../reference/allowed-tools-compatibility.md). Claude
Code's tool names are `Read`, `Edit`, `Write`, `Bash`, `Grep`, `Glob`. Whether matching is
case-insensitive is undocumented, and was **not tested**. If it is not, 64 skills carry an
allowlist that does nothing on our primary platform, and CI has been green over it the
whole time — the exact trap `CLAUDE.md` describes ("a structural check cannot tell you a
script works"). → **TODO #213**, Done-when is a live probe, not a reading.

### The claude.ai upload subset

Claude Code's skills reference states that skills uploaded to claude.ai support only
`name`, `description`, `license`, `compatibility`, `metadata`, `allowed-tools` — the spec
core exactly. Combined with the v2.1.275 sync above, a skill of ours reaching a terminal
*via claude.ai* arrives without `when_to_use`, `model`, `effort`, `context` or `agent`.
`context: fork` skills would run inline; `model: haiku` lookups would run at session
model. Whether our plugin skills can reach that path at all is **unverified**. → **TODO #214.**

### On the reference validator

The spec ships [`skills-ref`](https://github.com/agentskills/agentskills/tree/main/skills-ref)
(`skills-ref validate ./my-skill`). Tempting as a free hermetic CI suite — but it is
Python, and its own README calls it a reference library *for demonstration purposes*.
Adding a Python dependency to a bash/JS CI to re-check three rules `validate-skills.sh`
already enforces is a bad trade. Extend our validator instead (**TODO #212**).

---

## Filtering the ecosystem noise

Searching the general "agentic skills workflow" question returns mostly content farms —
*"SKILL.md is becoming the REST of agents"*, *"adopted by 32 tools in 90 days"*,
*"changes agent economics"*. None of it carries a primary source and none of it changes a
decision. Two things in that space are real and checkable:

- **The specification itself** — six fields, three-tier progressive disclosure
  (metadata ~100 tokens → body <5,000 tokens → `references/` on demand), <500-line body
  guidance. That is the whole standard. It is small on purpose, and our extensions live
  outside it by design, not by accident.
- **The client showcase** — roughly 45 named products with linked per-product skill docs,
  including Codex, Cursor, Gemini CLI, Copilot, VS Code, Goose, Amp, Kiro, OpenCode,
  Junie, Factory. Portability is genuine. But each client honors a *different subset* of
  frontmatter, which is why the field mapping above matters more than the adoption count.

The useful reading of the ecosystem is not "the standard won". It is: **the portable part
of a skill is its body and two fields; everything that makes our skills good is a Claude
Code extension.** That is a fine position — it just should not be described as
platform-neutral.

---

## What to do, in order

1. **[#182] Copilot CLI batch re-test** — one session against v1.0.86 closes or re-grounds
   four stale rows (#20, #22, #40, #182) and confirms the #4708 regression first-hand.
   Highest value in this sweep.
2. **[#212] Extend `validate-skills.sh`** with the two conformance gaps (`allowed-tools`
   form; vendor keys belong under `metadata`), and fix the three conformance-claim strings.
   Cheap, and it closes #41.
3. **[#213] Probe `allowed-tools` case sensitivity.** If lowercase names grant nothing, 64
   skills need a value sweep and the recommendation table in
   `allowed-tools-compatibility.md` is wrong. Find out before writing more skills.
4. **[#200] Pipeline launcher flags** — #119, #178 and #209 all fold into the same change,
   plus `CLAUDE_CODE_AUTO_MODE_SERVER` from v2.1.278. Do it once.
5. **Nothing to repin.** The `v2.1.277` references for AGENTS.md support are historically
   correct — v2.1.278 restated the default, it did not move the ship date. Checked so the
   next sweep does not re-open it.

Not recommended: adopting `skills-ref`; renaming skills ([#12](../todo/TODO.md)) as part of
this pass — that is a standalone decision with 77 directories and six months of user muscle
memory behind it.

## Sources

- [Claude Code changelog](https://code.claude.com/docs/en/changelog) — v2.1.265 → v2.1.278
- [Claude Code skills reference](https://code.claude.com/docs/en/skills) — frontmatter field list, claude.ai upload subset
- [Copilot CLI releases](https://github.com/github/copilot-cli/releases) — v1.0.84-6 → v1.0.87-0; [v1.0.86 notes](https://github.com/github/copilot-cli/releases/tag/v1.0.86)
- [Agent Skills specification](https://agentskills.io/specification) and [overview](https://agentskills.io)
- [agentskills/agentskills](https://github.com/agentskills/agentskills) — `skills-ref` reference validator
- [Codex build-skills](https://learn.chatgpt.com/docs/build-skills) — `name` + `description` only
- [copilot-cli#4708](https://github.com/github/copilot-cli/issues/4708) — subagent skill-access regression

---
date: 2026-08-04
type: review-and-roadmap
scope: all four plugins (dx-core, dx-hub, dx-aem, dx-automation)
inputs:
  - internal plugin inventory (skills/agents/hooks/MCP/marketplace)
  - internal TODO + research audit (docs/todo/, docs/research/)
  - official Claude Code docs sweep
  - online best-practice sweep (credibility-rated)
supersedes-cadence: 2026-07-01-upstream-dependency-check.md
---

# Plugin Review & Roadmap — August 2026

A four-lane review (internal inventory, internal TODO/research audit, official Claude Code
docs, online best practices) run to answer three questions: **where does this project stand,
what changed in the last months, and what should the next TODO cycle prioritize to keep up.**

The online lanes were run through an explicit credibility filter because the ask was
skeptical by design ("there is a lot of fake news online"). Findings are labelled
**WELL-SUPPORTED** (official Anthropic docs/engineering), **PLAUSIBLE** (credible but not
codified), or **HYPE/UNVERIFIED** (discard or confirm-before-acting).

---

## Headline

**The project is not behind the platform.** The most important finding is that the internal
`platform-state-update` series and `docs/todo/` tracker had *already surfaced nearly
everything* the external docs/best-practice lanes returned. External research added little
net-new signal — it mostly re-derived what `2026-05-29-platform-state-update.md` and
`2026-07-01-upstream-dependency-check.md` already recorded.

That reframes "keeping up." For this project it is **not a discovery problem** — it is an
**execution and hygiene** problem. The highest-value items the research machine already
identified keep being deferred, and two of them have *regressed*.

Overall health: **8/10** (Claude-only), consistent with `2026-07-01-plugin-eval-claude-copilot.md`.
The missing two points are follow-through, not knowledge.

---

## 1. Fake-news filter — discarded / downgraded

| Claim | Source class | Verdict |
|---|---|---|
| "94% of skills contain a 'Rationalization Loophole' (UC Irvine study)" | single blog | **HYPE** — unverifiable, suspiciously precise. Discard. |
| "One plugin cuts context bloat 98%" | marketing blog | **HYPE** — discard. |
| "Skills have a 5,000-token authoring limit" | repeated widely | **CONFLATION** — 5k is the post-compaction *retention* figure, not an authoring cap. Only real hard numbers: **500-line body, 1,024-char description, 1,536-char listing truncation.** |
| "8–12 skills is the right count" | blogger heuristic | **PLAUSIBLE at best** — 77 skills across 4 independently-installable plugins is the correct architecture; a made-up number is not a reason to consolidate. |
| Version-pinned August claims: "v2.1.218 background skills", "v2.1.221 Focus View", "nested subagent depth 3", "80% of system prompt removed", "Opus 5 is now default" | third-party changelog aggregators (gradually.ai, havoptic.com) | **UNVERIFIED** — postdate the last internal sweep (2026-07-01, CC v2.1.178) and are not from official sources. Some are probably real (the lean-system-prompt one is independently confirmed by `2026-07-25-context-engineering-claude5.md`), but **do not act on the version-pinned specifics until confirmed against the official changelog.** This is exactly what TODO #171 (below) exists to do. |

The best-practice lane's WELL-SUPPORTED tier is trusted because every item traces to an
actual Anthropic engineering post (context engineering, Agent Skills, writing tools for
agents) **and** independently corroborates internal research. That triangulation — external
docs + external best-practices + internal research all agreeing — is the strongest signal in
the dataset.

---

## 2. What actually changed in the last months (verified)

Confirmed by internal research, so trusted:

- **Opus 4.8 is the default at `high` effort** (v2.1.154). Model Tier Strategy already
  re-baselined — TODO #134 (done). `xhigh` is escalation-above-baseline, not a tier jump.
- **Lean system prompt is now the platform default** (~80% of Claude Code's own prompt
  stripped for newer models). Official green light for the concise-body audit — #113, #170.
- **`disallowed-tools` frontmatter shipped** (v2.1.152). Open — #136.
- **`MessageDisplay` hook shipped** (v2.1.152) for hiding forked-skill output. Open — #139.
- **Token-footprint instrumentation** (`/context all`, `/usage`, `claude plugin details`).
  Baseline not yet captured — #137.
- **Copilot v1.0.63 fixed the PostToolUse matcher bug** — #124 fixed upstream.
- **Codex + Gemini native plugin systems shipped** — #88, #89.

**Genuinely net-new since 2026-07-01** (and therefore the subject of #171): background-by-default
forked skills + `background: false` opt-out, `/code-review` as a background subagent, and a
possible nested-subagent depth change. All **UNVERIFIED** pending an official-changelog pass.

---

## 3. The real gap — regression and rot, not ignorance

Three high-value items the internal tracker already flagged as top-ROI have **regressed or
stalled**:

1. **Skill evals (#1) were falsely marked Done and had to be re-opened.** `tests/run-evals.sh`
   still does not exist. Evals are the #1 WELL-SUPPORTED best practice from both external
   lanes *and* `2026-07-20-skill-authoring-best-practices.md`. This is the biggest integrity
   gap in the tracker.
2. **Skill bloat regressed (#108/#113):** 13 skills exceed the official 500-line rule, topping
   out at 1,121 lines (`dx-pr-review`). Progressive disclosure is codified in conventions but
   not enforced.
3. **The Stop-hook → verification loop (#159) is still open** — yet `2026-06-15-dev-agency-harness-review.md`
   called "victory-declaration bias" the #1 unaddressed failure mode and this fix the
   highest-ROI change in the harness. The best-practice lane independently ranks verification
   hooks as the highest-leverage hook pattern. Triple-confirmed, still not shipped.

**Tracker rot** (logged as #172): item numbers **69–77 are triple-overlapping** across three
series (`todo-plugin-architecture-review`, `todo-cross-platform`, `todo-context-graphs`), and
items **#33–#41 link to `todo-review-plugin-improvements.md`, which does not exist** on disk —
8 items (incl. High-priority #33 hook `if`, #35 `statusMessage`) with no backing detail file.
Since the whole methodology depends on verifiable "Done-when" checks, this silent rot
undermines the system.

---

## 4. Proposed roadmap

Prioritized by *value × leverage*, mapped to existing item numbers so nothing is reinvented.

### Tier 1 — do these (triple-confirmed high value)
- **#159 — Wire `dx-step-verify` into a `Stop` hook.** Highest ROI, three independent sources
  agree, deterministic, small. Start here.
- **#1 / #167 / #168 — Ship the eval harness for real.** Begin with 5 skills (`dx-init`,
  `dx-plan`, `dx-pr-review`, `aem-init`, `dx-simple`): ablation pattern + negative tests.
  Closes the worst credibility gap.
- **#108 / #113 — Refactor the 13 over-500-line skills** via `references/` progressive
  disclosure. Pilot `dx-pr-review` (1,121 → <500).

### Tier 2 — cheap, real, already-shipped features
- **#166 — Negative triggers.** Only 4/77 skills say when *not* to fire; official best
  practice; frontmatter-only.
- **#136 — Pilot `disallowed-tools`** on analysis skills + the dx-simple split.
- **#137 — Capture the token-footprint baseline** now that `/context all` exists — cannot
  manage bloat you do not measure.
- **#172 — Tracker hygiene** (new): renumber the duplicate #69–77 series, create-or-delete
  `todo-review-plugin-improvements.md`.

### Tier 3 — the cadence item (this *is* "keeping up")
- **#171 — New `2026-08-xx-platform-state-update.md`** confirming the UNVERIFIED August claims
  (background skills, code-review subagent, nested depth) against the official changelog. The
  ~monthly sweep is the mechanism that keeps the project current — it is overdue.

### Explicitly de-prioritized (skeptical of value)
- **Agent SDK programmatic API** — big move, unclear payoff; keep #123 low.
- **RLM productionization (#164/#165)** — arXiv-fresh, correctly gated behind a go/no-go.
- **CodeAct (#158)** — single-vendor self-reported numbers; keep as research.

Keep all three as *research*, not roadmap.

---

## Bottom line

The research machine is doing its job; the risk is that the highest-value items it identifies
(evals, verification hooks, de-bloating) keep getting deferred while lower-value
platform-tracking churns. Point the next cycle at **Tier 1** and the 8→10 gap closes.

## Sources
- Official: Claude Code docs (skills, sub-agents, hooks, mcp, plugins-reference, best-practices);
  Anthropic Engineering (effective context engineering, equipping agents with Agent Skills,
  writing tools for agents).
- Internal: `2026-05-29-platform-state-update.md`, `2026-07-01-upstream-dependency-check.md`,
  `2026-07-20-skill-authoring-best-practices.md`, `2026-07-25-context-engineering-claude5.md`,
  `2026-06-15-dev-agency-harness-review.md`, `2026-07-01-plugin-eval-claude-copilot.md`.

# Skill Authoring Best Practices — Empirical Findings

**Source:** AI Engineer World's Fair, Track 5 — July 1, 2026 (conference talk, screenshots)
**Captured:** 2026-07-20
**Status:** In progress — more screenshots to be added

Empirical research on what makes a Claude Code / model-invoked skill effective,
benchmarked across Claude Code (Opus 4.7), Codex (GPT-5.5), and Gemini CLI
(Gemini 3.1 Pro). Findings are directly relevant to this repo's skill-conventions
work (CLAUDE.md "Model Tier Strategy", concise-body audit / TODO #113).

---

## 1. Skill length vs. performance lift

Benchmark: pass rate (%) with No Skills vs. Self-Generated vs. Curated Skills,
across three models (Claude/Opus, Codex/GPT-5.5, Gemini).

**Pass rates with curated skills vs. baseline:**

| Model | No Skills | Self-Generated | Curated Skills |
|-------|-----------|----------------|----------------|
| Opus 4.7 (Claude Code) | 43.0 | 34.9 | 61.2 |
| GPT-5.5 (Codex) | 46.8 | 35.5 | 66.5 |
| Gemini 3.1 Pro (Gemini CLI) | 36.0 | 24.5 | 60.8 |

**Key result: Self-generated skills HURT accuracy — a −8.1 to −11.5 point loss**
versus using no skills at all. Curated skills, by contrast, add ~18–25 points.

**Skill length → performance lift (the sweet-spot curve):**

| Band | Length | Lift | Note |
|------|--------|------|------|
| Compact | < 200 lines | **+19.0%** | Fast, low token overhead, high precision. |
| Standard | 200–500 lines | **+21.5%** | **Sweet spot** — optimal balance of guidance and reasoning headroom. |
| Detailed | 500–1000 lines | +14.5% | Instruction drift begins to degrade reasoning. |
| Comprehensive | > 1000 lines | +0.7% | **No-op** — bloat burns reasoning tokens with zero gain. |

**Takeaway:** aim for 200–500 lines in the SKILL.md body. Past 1000 lines the
skill contributes essentially nothing while still costing tokens.

---

## 2. The frontmatter description is the primary trigger mechanism

- The frontmatter `description` is the primary trigger mechanism for
  model-invoked skills.
- Vague descriptions cause the skill to miss triggers **or hijack unrelated prompts**.
- Include both the **"what" (capability)** and the **"when" (trigger context)** in
  the description.
- **Real result:** rewriting the description alone fixed **5 of 7 failures** in
  their evaluation suite.

**Description trigger comparison:**

- ❌ Too vague: `"Helps with documents"` / `"API helper"`
- ✅ Specific & actionable: `"Create, edit, and analyze .docx files. Use for tracked changes, comments, formatting, or text extraction."`

---

## 3. Directives drive action; passive explanations become ignored trivia

- Directives drive action; passive explanations become ignored trivia.
- **A 5-line code snippet beats a 5-paragraph explanation every time.**
- Still explain the *reasoning* behind rules to help the model generalize across
  edge cases.
- Avoid overfitting to specific prompts by writing directives that scale.

**Good vs. bad directives:**

- ❌ Passive essay: `"The Interactions API is recommended for multi-turn chat because it handles session state automatically."`
- ✅ Active directive: `"Always use client.interactions.create() for chat. Never use the legacy generate_content API."`

---

## 4. Progressive disclosure — three loading layers

Keep the always-loaded surface minimal; defer everything else.

- Frontmatter (name + description) sits in context on **every turn** — keep it minimal.
- Keep the main `SKILL.md` body **under 500 lines** to preserve reasoning-token headroom.
- Move detailed docs, scripts, and multi-page guides into **external reference files**.
- External references incur **zero context cost** until the agent explicitly reads them.

**The three layers:**

| Layer | Content | When loaded |
|-------|---------|-------------|
| 1 | Frontmatter (`name` + `description`) | Always — in context on every turn. |
| 2 | SKILL.md body | On trigger — core instructions injected when skill activates. |
| 3 | References & scripts | On demand — external files read/executed only when explicitly needed. |

---

## 5. Freedom level — describe outcomes, not rigid procedures

- Dictating every step strips an agent's ability to adapt, recover from errors,
  or find better approaches.
- Describe the desired **outcome** rather than enforcing a rigid procedural path.
- Provide **constraints, not procedures** (e.g. "Always run tests before opening
  PR", not "Step 1, Step 2…").
- **If exact step-by-step execution is required, write a script instead of a skill.**

**Freedom level comparison:**

- ❌ Rigid step-by-step:
  ```
  Step 1: Read config.json
  Step 2: Extract port
  Step 3: Edit line 4
  Step 4: Save file
  ```
- ✅ Goal & constraints:
  ```
  Update database port in config.json to 5432.
  Ensure file parses correctly.
  Always run tests before opening PR.
  ```

---

## Relevance to this repo

- Our LOC audit (`scripts/skill-loc-stats.sh`, 2026-07-20) shows median SKILL.md
  = 296 lines (within the 200–500 sweet spot) but several dx-core skills exceed
  1000 lines (`dx-pr-review` 1121, `dx-simple` 1025) — squarely in the "No-Op"
  bloat band per §1. Candidates for progressive-disclosure refactoring (§4).
- §5 (constraints not procedures) tensions with our DOT-digraph flow-control
  convention for branching skills — worth revisiting whether rigid graphs help or
  hurt on models that adapt well.
- §2/§3 reinforce the concise-body audit (TODO #113).

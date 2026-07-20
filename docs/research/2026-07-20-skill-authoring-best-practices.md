# Skill Authoring Best Practices — Empirical Findings

**Talk:** "Don't Ship Skills Without Evals" — Philipp Schmid (Google)
**Source:** AI Engineer World's Fair, Track 5 — July 1, 2026 (conference talk, screenshots)
**Reference:** https://philschmid.de/testing-skills
**Captured:** 2026-07-20
**Status:** Complete

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

## 6. Negative triggers — define when a skill should NOT fire

- Define when the skill should **NOT** fire to prevent keyword hijacking on
  unrelated tasks.
- Broad descriptions ("Use for any coding task") hijack every user request uselessly.
- Test both positive **and** negative trigger cases to avoid one-sided over-optimization.
- Track **false-positive trigger rates** in your evaluation suite.

**Trigger case comparison:**

- ❌ Broad trigger (false positive): `"Use for any coding task"` — hijacks every single user request uselessly.
- ✅ Negative case defined: `"Use for React components. Do NOT trigger for plain HTML/CSS or backend Python code."` — fires precisely when intended; non-target requests stay lean.

---

## 7. Building an eval harness — machine-readable eval declarations

The talk's core thesis: **don't ship skills without evals.** Evals are automated
ablation tests (with-skill vs. without-skill) that measure exact "Skill Lift."

**Approach: gather prompts and execute the agent programmatically.**

**(1) Prompts schema (`test_cases.json`)** — each case declares an id, prompt,
language, a `should_trigger` boolean (positive AND negative cases), and
`expected_checks`:

```json
[
  {
    "id": "py_basic_generation",
    "prompt": "Write a Python script that sends a text prompt to Gemini and prints response",
    "language": "python",
    "should_trigger": true,
    "expected_checks": ["correct_sdk", "no_old_sdk", "current_model", "interactions_api"]
  },
  {
    "id": "py_deprecated_model",
    "prompt": "Write a Python script using Gemini 2.0 Flash with Interactions API.",
    "language": "python",
    "should_trigger": true,
    "expected_checks": ["correct_sdk", "interactions_api", "deprecated_model_rejected"]
  },
  {
    "id": "negative_unrelated",
    "prompt": "Write a Python script that reads CSV and plots bar chart with matplotlib.",
    "language": "python",
    "should_trigger": false
  }
]
```

**(2) Agent exec runner (Python)** — drive the CLI programmatically, capture
structured output:

```python
def run_gemini_cli(prompt):
    cmd = [
        "gemini",
        "-m", "gemini-3-flash-preview",
        "--output-format", "json",
        "--yolo",
        "-p", prompt,
    ]
    result = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        timeout=60,
    )
    data = json.loads(result.stdout.strip())
    return CLIOutput(
        response_text=data.get("response", ""),
        exit_code=result.returncode,
    )
```

**(3) Production eval schema (`deploy_eval.yaml`)** — YAML configs define setup
files, CLI checks, and LLM-judge criteria. The harness automatically spins up
isolated, clean workspace environments per run and executes ablation benchmarks
(with vs. without skills) to measure exact Skill Lift. **Requires proof of
positive Skill Lift before any skill PR gets merged.**

```yaml
cases:
  - id: "deploy_flask_app"
    prompt: "Deploy my Flask app to Cloud Run with env vars from .env"
    should_trigger: true
    setup:
      files:
        "app.py": "from flask import Flask\napp = Flask(__name__)"
        ".env": "DATABASE_URL=postgres://localhost/mydb"
      commands:
        - "pip install flask"
    script_validators:
      - "grep 'gcloud run deploy' agent_output.sh"
    llm_judge:
      expectations:
        - "Deployment command includes --set-env-vars"
        - "Agent did NOT expose secrets in plain text CLI args"
    cleanup:
      - "gcloud run services delete test-service --quiet"
```

CLI command:
```
eval_runner run evals/deploy_eval.yaml \
  --with-vs-without-skills \
  --runs=3
```

---

## 8. The 10 rules of skill evaluation

1. **Start with the skill description** — trigger problems cause 50%+ of failures.
   A vague description causes missed triggers or false fires. **Fix description first.**
2. **Write directives over passive info** — models follow instructions better than
   inferring implications. `"Always use X"` works; *"X is recommended"* gets ignored.
3. **Include negative tests** — add prompts where the skill should NOT trigger, to
   prevent a skill with broad keywords from hijacking every request.
4. **Start small, extend from failures** — begin with 10–20 real prompts. Don't be
   exhaustive upfront. Every user-reported bug becomes a new test case.
5. **Grade outcomes over paths** — agents take unexpected routes to correct answers.
   Grade code execution, API correctness, and goals. Avoid checking file-read sequences.
6. **Isolate each run** — use a clean workspace environment for every test case.
   Context bleeding between runs masks real failures.
7. **Run 3–5 trials per case (pass^k vs pass@k)** — behavior is probabilistic. Look
   at **pass^k distribution (consistency)** rather than pass@k (peak luck).
8. **Test across harnesses** — skills behave differently across agent frameworks
   (Gemini CLI, Claude Code, Cursor). Eval in each target environment.
9. **Graduate your evals** — capability evals start at low pass rates. Once they hit
   ~100%, graduate them into **regression evals** that protect against backsliding.
10. **Detect skill retirement** — run evals with the skill unloaded. If they still
    pass, the base model absorbed the value. **Retire the skill to free up context.**

---

## 9. Three things to do on Monday

1. **Pick & write 5 cases** — pick your most-used skill. Write 5 test prompts. Use
   your coding agent to look at your traces to find examples for positive and negative
   cases.
2. **Remove no-ops** — use Matt Pocock's writing-great-skills meta-skill to strip
   no-ops, passive advice, and filler text to refine content and description.
3. **Run ablation test** — run evals without the skill loaded. If they still pass,
   the model already knows what the skill teaches.

Reference: https://philschmid.de/testing-skills

---

## Relevance to this repo

- Our LOC audit (`scripts/skill-loc-stats.sh`, 2026-07-20) shows median SKILL.md
  = 296 lines (within the 200–500 sweet spot) but several dx-core skills exceed
  1000 lines (`dx-pr-review` 1121, `dx-simple` 1025) — squarely in the "No-Op"
  bloat band per §1. Candidates for progressive-disclosure refactoring (§4).
- §5 (constraints not procedures) tensions with our DOT-digraph flow-control
  convention for branching skills — worth revisiting whether rigid graphs help or
  hurt on models that adapt well. §7's "grade outcomes over paths" reinforces this.
- §2/§3/§6 reinforce the concise-body audit (TODO #113) and the frontmatter
  `description` conventions.
- §7–§9 are the actionable core: we have **no skill eval harness today**. Candidate
  new TODO — a `test_cases.json` + ablation runner per high-value skill, gated on
  proof of positive Skill Lift before merge. §8 rule 8 ("test across harnesses")
  matches our cross-platform support (Claude Code / Copilot / Cursor / Gemini).
- §8 rule 10 (skill retirement via ablation) is a concrete way to prune the 77-skill
  catalog: any skill that passes its evals unloaded is dead weight.

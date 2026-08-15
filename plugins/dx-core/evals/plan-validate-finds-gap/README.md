# Eval: plan-validate-finds-gap

First eval suite in this repo. Subject: the `dx-plan-validate` skill.

## The fixture

`resources/spec/` is planted into the empty sandbox workspace by
`resources/setup.sh`. It contains a spec directory with **one deliberate
defect**:

| Requirement | Covered by |
|---|---|
| R1 — delay calls | Step 1 |
| R2 — `.cancel()` | Step 2 |
| **R3 — throw TypeError** | **nothing** |

R1 and R2 are distractors. The correct report names R3 and only R3, i.e.
`2/3 covered`. Because the answer is known in advance, the graders can check
both **recall** (did it find the real gap) and **precision** (did it invent
extra ones).

## The graders — one per oracle type

| Grader | Type | Oracle |
|---|---|---|
| `wrote-report` | `file_exists` | structural — was the report created |
| `coverage-2-of-3` | `regex` contains | exact — recall |
| `no-extra-gaps` | `regex` not_contains | exact — precision (rejects `1/3`, `0/3`) |
| `gap-is-explained` | `llm` | fuzzy — a rubric, judged 2-of-3 |

## Running it

`claude plugin eval` is in early access and gated per organization. If it
prints `` `plugin eval` is currently in early access ``, enablement has not
reached this machine — some clients need an enablement environment variable,
which Anthropic provides during early-access onboarding. Set it in your shell
or `~/.claude/settings.json` `env`, not in this repo. Self-test by running
`claude plugin eval` in an empty directory: `No eval cases found …` means it
is enabled.

```bash
TMPDIR=/tmp \
  claude plugin eval plugins/dx-core --case plan-validate-finds-gap \
  --runs 3 --ablation none --scaffold --no-publish \
  --allow-tools Write Bash
```

`TMPDIR=/tmp` matters: sandbox `.claude/` discovery walks *up* from the run
directory, so a temp dir under `$HOME` lets the child find `~/.claude/skills`
and contaminates the baseline.

Pin `--model` and `--judge-model` before comparing scores across time,
otherwise a model rollout reads as a regression.

## Result, 2026-08-15

`--runs 3` → **score 1.00, 100% pass, $1.10, 173s.** All 12 grader checks
passed; the judge voted 9/9 PASS. No variance.

## The interesting finding: the LLM judge failed the sanity check

A suite that only ever passes proves nothing — it may be rubber-stamping. So
the fixture was temporarily *fixed* (Step 3 added, covering R3) and re-run.
The eval correctly went red overall (**0.75, exit 1**) — but not uniformly:

- `coverage-2-of-3` (regex) **caught it.** The report said `3/3`, no match.
- `gap-is-explained` (llm) **voted PASS PASS PASS** — on a report that
  explicitly stated `3/3 covered` and `✅ Requirement R3 — covered by Step 3`,
  which the rubric names as an explicit FAIL condition.

The rubric encoded ground truth as prose ("Only R3 is genuinely uncovered by
the plan"). When the input changed, that premise became false, and a
confidently-written, well-structured report talked the judge out of the rubric.
The regex could not be talked out of anything.

**Takeaways.** Sanity-check every eval against a known-bad input, or you are
only measuring that the suite is green. Prefer deterministic graders when an
exact oracle exists. And treat a judge as a component that itself needs
validating — the current literature on verifier reliability is about exactly
this failure.

Open follow-up: rewrite the rubric so it does not assume which fixture it is
looking at (state the coverage claim to verify, not the ground truth), then
re-run the sanity check and confirm the judge flips to FAIL.

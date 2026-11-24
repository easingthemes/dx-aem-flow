# Eval: writing-ste

Question: does a plain-language rule (Simplified Technical English, ASD-STE100)
in the system prompt make agent output easier to read, without losing facts?

## Design

Two cases with the same task, the same fixture and identical graders. Only the
system prompt differs.

- `ste-on` - treatment. `append_system_prompt` carries the "Plain language"
  rule text.
- `ste-off` - control. No writing rule.

The eval sandbox does not load a `CLAUDE.md` or `.claude/rules/` from the
workspace, so the rule goes in through `append_system_prompt`.

The task asks for a 300-word team summary of a ticket. The fixture in
`fixture/.ai/specs/demo/` (an AEM Hero component with a video background) is
written in a deliberately formal register with long sentences. A model that
copies the source style fails the readability graders.

## Graders

Keep `ste-on/graders/` and `ste-off/graders/` identical (`diff -r` them).

| Grader | Type | Checks |
|---|---|---|
| `wrote-summary` | `file_exists` | the summary was written |
| `no-long-sentence` | `regex` not_contains | no run of 26+ words without a sentence break |
| `no-formal-words` | `regex` not_contains | no "in order to", "facilitate", "utilize" and similar |
| `keeps-reduced-motion` | `regex` contains | content guard: R2 is still there |
| `keeps-dispatcher-risk` | `regex` contains | content guard: the main risk is still there |
| `keeps-identifier` | `regex` contains | `videoPath` is kept exact |
| `plain-for-b1-reader` | `llm` | readable for a B1 English reader |

Sanity check (2026-11-24): each regex grader was run against a good and a bad
sample text. Every one failed on the bad sample and passed on the good one. The
`llm` grader has not been seen failing yet.

The graders give pass/fail per run. `measure.js` gives the size of the
difference: words, sentence count, average and maximum sentence length,
sentences over 25 words, rough passive count, formal-word count.

## Run

Billed (real agent runs). Ask before running.

```bash
TMPDIR=/tmp claude plugin eval plugins/dx-core --tag writing-ste \
  --runs 3 --ablation none --scaffold --no-publish --trust-plugin \
  --allow-tools Write --model opus --judge-model sonnet \
  --max-cost-usd 6 --keep-temp
```

Then measure the kept summaries:

```bash
node plugins/dx-core/evals/writing-ste/measure.js <path-to-summary.md>...
```

Pin `--model` and `--judge-model`, or a model rollout reads as an effect of
the rule. To test the rule on a cheaper tier, run again with `--model sonnet`
or `--model haiku`.

## Result 2026-11-24 (opus 5.5, judge sonnet, `--runs 3`, $0.90, 37s)

Grader score: `ste-off` 0.95 (2/3 runs pass), `ste-on` 1.00 (3/3 runs pass).
The one failure is a 27-word sentence in a control run.

`measure.js`, mean of 3 runs per arm:

| Metric | `ste-off` | `ste-on` |
|---|---|---|
| Average sentence length (words) | 9.8 | 8.5 |
| Longest sentence (words) | 22, 23, 27 | 17, 17, 17 |
| Sentences over 25 words | 1 in total | 0 |
| Formal words | 0 | 0 |
| Full file paths kept from `research.md` | 0 of 3 runs | 3 of 3 runs |

Findings:

- The rule caps the longest sentence. Every treatment run stayed at 17 words.
  The control runs reached 22 to 27.
- The average changes little. Opus 5.5 already writes short sentences and
  does not copy the formal register of the fixture.
- The clearest effect is the "keep paths exact" bullet. All three control runs
  shortened `core/.../models/HeroModel.java` to `HeroModel.java`. All three
  treatment runs kept the full path.
- All content guards passed in both arms. The rule did not cost facts.
- The `llm` judge passed all 6 runs, so it did not separate the arms. It has
  still not been seen failing.

Three runs per arm is a small sample. Repeat on `--model sonnet` and
`--model haiku` before a decision for those tiers.

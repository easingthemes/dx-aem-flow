# Skill routing eval (TODO #168)

One case per natural-language request, graded only on **which skill Claude invokes** (`tool_used: Skill`, free). Covers the collision clusters from #14 (`dx-pr-*`, `dx-bug-*`, `dx-req`/`dx-dor`, the four verify skills) plus two general questions where no skill may fire. All four plugins are loaded, so siblings compete as they do for a consumer.

`append_system_prompt` tells Claude to stop right after it picks a skill. The routing decision is made before that point, and it keeps a run at a few cents.

```bash
# run from the repo root; target is plugins/ so the case may load all four plugins
TMPDIR=/tmp claude plugin eval plugins --eval-dir dx-core/evals/routing --tag routing \
  --ablation none --runs 2 --model sonnet -j 3 --max-cost-usd 5 --no-publish --trust-plugin
```

Billed (real agent runs). Ask before running.

Targeting `plugins/dx-core` fails: a case may only load plugins under the containment root, which is then dx-core.
Pilot (2026-10-16, sonnet): ~$0.10 per run.

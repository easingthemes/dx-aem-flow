# Skill routing eval (TODO #168)

One case per natural-language request, graded only on **which skill Claude invokes** (`tool_used: Skill`, free). Covers the collision clusters from #14 (`dx-pr-*`, `dx-bug-*`, `dx-req`/`dx-dor`, the four verify skills) plus two general questions where no skill may fire. All four plugins are loaded, so siblings compete as they do for a consumer.

`append_system_prompt` tells Claude to stop right after it picks a skill. The routing decision is made before that point, and it keeps a run at a few cents.

```bash
claude plugin eval plugins/dx-core --tag routing --ablation none --runs 1 \
  --model sonnet --max-cost-usd 5 --no-publish --trust-plugin
```

Billed (real agent runs). Ask before running.

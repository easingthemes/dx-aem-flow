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

## Result 2026-10-16 (sonnet 5.5, `--runs 2`, all four plugins, fresh HOME)

| Case | main (old descriptions) | #225 (new descriptions) |
|---|---|---|
| 11 routing cases (`dx-pr-commit`, `dx-pr-answer`, `dx-bug-all`/`-triage`/`-verify`, `dx-req`, `dx-dor`, `dx-step-verify`, `aem-verify`, `aem-fe-verify`, `aem-page-search`) | 22/22 | 22/22 |
| 2 no-skill questions | 4/4 | 4/4 |
| `pr-review` ("look over pull request 4521…") | 0/2 | 0/2 |

- **No regression.** Every case scored the same on both versions.
- **`pr-review` fails on both.** The pilot trace shows Claude picks Claude Code's **bundled `code-review` skill**: the prompt does not say ADO, and the bundled skill also reviews "a PR number". That is a real competitor every consumer has. It is not caused by the #238 rewrite.
- The old arm passed the AEM cases although dx-aem descriptions were name-only on a fresh install. With clear prompts the skill name is enough; descriptions matter for ambiguous phrasing like the PR case.
- Cost: $3.40 (main) + $2.79 (#225) + $0.22 pilot ≈ **$6.41**, under the $10 cap.

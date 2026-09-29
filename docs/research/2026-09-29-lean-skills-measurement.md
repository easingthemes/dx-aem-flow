# Lean skills for Claude 5 — measured baseline + current guidance

**Date:** 2026-09-29. Measured on `main` after the 2026-09-29 sweep merge. Numbers come from the
files, not from earlier TODO text (several of which were stale). Tokens ≈ chars / 4.

## Guidance (primary sources)

| Claim | Source |
|---|---|
| Claude Code system prompt cut 80%+ for Claude 5 with no eval loss; rules → judgement | [claude.dev, 2026-07-24](https://claude.dev/blog/the-new-rules-of-context-engineering-for-claude-5-generation-models/) (already in [2026-07-25 note](2026-07-25-context-engineering-claude5.md)) |
| Lean system prompt default "for all models except Haiku, Sonnet, and Opus 4.7 and earlier" — **Sonnet coverage unclear** | CC CHANGELOG v2.1.154 |
| Dial back aggressive language: "CRITICAL: You MUST use this tool when…" → "Use this tool when…"; models now **overtrigger** | [prompting best practices](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices) |
| "If you emphasize many lines, none of them stands out" — IMPORTANT on one line only | [code.claude.com best practices](https://code.claude.com/docs/en/best-practices) |
| Skills written for older models are often too prescriptive and can **degrade** output | prompting-claude-fable-5 |
| Review prompts that filter at find time ("only high severity", "be conservative", "don't nitpick") **cut recall** — find everything with confidence/severity, filter in a separate pass | prompting-claude-sonnet-5, -opus-5 |
| Explicit self-verification instructions cause over-verification on Opus 5 (no quality gain); Sonnet 5.5 at `low` effort may skip checks — tier-dependent | prompting-claude-opus-5, -sonnet-5-5 |
| Prompts that make the model print its reasoning can be refused (`stop_reason: "refusal"`), not retried by fallback | prompting pages for Fable 5 / Opus 5.5 / Sonnet 5.5 |
| Opus 5.5 API default effort is `medium` (Opus 5: `high`) — Claude Code default unconfirmed | prompting-claude-opus-5-5 |
| CLAUDE.md: target < 200 lines; v2.1.282 warns on combined instruction-file size | [memory docs](https://code.claude.com/docs/en/memory), CHANGELOG |
| "State what to do rather than narrating how or why" | [skills docs](https://code.claude.com/docs/en/skills) |
| A/B a skill edit: skill-creator "version comparison" (blind A/B of two skill versions); `claude plugin eval` only does with/without, so run it at both git refs with `--model`/`--judge-model` pinned | skills docs § Evaluate and iterate, plugin-evals docs |

Unverified (secondary only): the "2,686 → 514 words" figure.

## Measured (2026-09-29)

**Per invocation** — only the invoked skill body loads:

| | |
|---|---|
| Skills | 77, ~290k tok bodies total |
| > 200 lines / > 500 lines | 55 / 13 |
| Largest | `dx-pr-review` 1130 lines (~10.7k tok), `dx-simple` 1015 (~14.3k), `dx-init` 939, `dx-pr-answer` 938, `dx-req` 757 |
| Use `references/` | 8 of 77 |
| Fenced code / templates | ~25% of all skill text (up to 48% in `dx-bug-verify`) |

**Every session** (consumer with all 4 plugins):

| | |
|---|---|
| Skill descriptions (+`when_to_use`) | **~9.2k tok** — avg 241 chars, max 847 (`dx-council`) |
| Agent descriptions | ~0.6k tok |
| Always-loaded `.claude/rules` (no `paths:`) | ~1.6k tok (`hub-orchestration` 1.4k, `universal-tool-safety` 0.2k); AEM rules are path-scoped; `pr-review`/`pr-answer`/`plan-format`/`pragmatism`/`task-progress` go to `.ai/rules/` (read on demand) |
| Root `CLAUDE.md` (this repo, contributors) | 397 lines |

**What the text actually is** — this corrects the assumption in the old #113/#162:

| Kind | Count | Verdict |
|---|---|---|
| Rationale ("Why:", "because", "this ensures") | 28 lines total | small — not where the mass is |
| No-op phrases ("be thorough", "make sure to") | 2 | negligible |
| Hedges ("try to", "consider") | 16 | small |
| Dev history in skill text (issue/TODO #, dates, versions) | 34 | small, but pure waste — model can't use it |
| CAPS emphasis (MUST/NEVER/CRITICAL/IMPORTANT/ALWAYS) | 162 in 53 skills (top: `dx-pr-review` 19, `dx-pr-answer` 10, `dx-plan` 10) | **against current guidance** |
| `## Rules`-type sections | ~15.8k tok in 71 skills (5%) | mix of real gotchas and restated steps / generic behaviour ("Read before judging", "Human voice", "Scope your review") |
| Verification scaffolding (double-check / re-verify) | 27 lines | tier-dependent (see guidance) |
| Paragraphs duplicated across skills | 16, ~1.5k tok | small |
| Confidence ≥ 80 / max 10 / no-nitpick at find time | `rules/pr-review.md` (+template), `dx-code-reviewer`, `dx-pr-reviewer`, `dx-pr-review` | **against current guidance — recall risk** |

**Conclusion:** the size is procedure, templates and mode branches, not filler. "Delete explanatory
prose" (old #113 framing) would save little. The real levers, in order of payoff per risk:
1. Always-on cost: descriptions (~9.2k tok every session) — cheap, low behaviour risk.
2. Move templates/examples and rarely-taken branches to `references/` (only 8 skills do today).
3. Drop CAPS emphasis and restated/generic rules.
4. Behaviour changes (review filter split, verification scaffolding) — need evals first.

## Re-measure

```bash
python3 - <<'PY'
import glob,re
b=d=0
for f in glob.glob('plugins/*/skills/*/SKILL.md'):
    s=open(f).read(); m=re.match(r'^---\n(.*?)\n---\n',s,re.S)
    b+=len(s)//4; d+=sum(len(x) for x in re.findall(r'^(?:description|when_to_use):\s*(.*)$',m.group(1),re.M))//4
print('bodies ~tok',b,'| descriptions ~tok/session',d)
PY
grep -rhoE '\bMUST( NOT)?\b|\bNEVER\b|\bCRITICAL\b|\bIMPORTANT\b|\bALWAYS\b' plugins/*/skills/*/SKILL.md | wc -l
```

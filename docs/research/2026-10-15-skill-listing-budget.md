# Skill listing budget — measurement and proposal (TODO #238)

**Date:** 2026-10-15 · **Baseline:** Claude Code v2.1.301 · **Status:** measured + ratchet landed; description rewrite **awaiting approval**

## How Claude Code builds the listing (read from the v2.1.301 bundle)

- One entry per model-invocable skill: `- <plugin>:<name>: <description> - <when_to_use>`. Entries are joined with newlines.
- Each entry's text is cut at `skillListingMaxDescChars` (default **1536**).
- Budget = context tokens × 4 chars/token × `skillListingBudgetFraction` (default **0.01**). That is **8,000 chars on a 200k context** and **40,000 on 1M**. `SLASH_COMMAND_TOOL_CHAR_BUDGET` overrides it.
- Over budget it switches to "priority" mode: skills are sorted by a usage score; the most-used keep their full text until the budget runs out, and the rest are listed **by name only**. Bundled skills and `name-only` overrides always cost just their name.
- `disable-model-invocation: true` removes a skill from the listing entirely. It also stops the **model** from invoking it through the Skill tool (from any skill, too). The user can still type `/name`.

## Measurement (this tree, `bash scripts/validate-skills.sh`)

| | Value |
|---|---|
| Skills | 77, of which 73 model-invocable (4 already `disable-model-invocation`) |
| Listing size | **36,795 chars** — 4.6× the 200k budget; fits 1M (40,000) with ~3k to spare |
| Per entry | avg ~478 chars of description + `when_to_use`; 51 over 400; max `dx-council` 1,094 |
| By plugin | dx-core 45 skills / 22.9k chars · dx-aem 12 / 5.5k · dx-automation 11 / 4.6k · dx-hub 5 / 2.0k |

Earlier figure (~9.2k tok, avg 241 chars) came from a first-line-only grep. The validator now counts the way Claude Code does: full folded value, outer quotes stripped, characters not bytes.

On a 200k session, a consumer with all four plugins gets full descriptions for roughly the dozen most-used skills. The rest route on their names alone, and any other plugins the user has compete for the same 8k.

## Ratchet (landed)

`scripts/validate-skills.sh` check 11 sums the listing exactly as above and fails if it grows past `LISTING_BASELINE=36795`. If it shrinks, a NOTE asks for the baseline to be lowered. Tests in `scripts/validate-skills.test.sh`:
- at the baseline passes
- one over fails
- characters, not bytes (`é`)
- quotes stripped, `''` unescaped
- `when_to_use` joined with ` - `
- `disable-model-invocation` excluded

Two mutations were each caught (byte counting, quotes kept; 6 failures each).

## Proposal (not applied — needs a yes)

**Step 1 — `disable-model-invocation: true` on user-only skills: −11,026 chars → 25,769.**
These are setup, admin and infra skills a user starts on purpose, never mid-task:
- `auto-*`: alarms, deploy, doctor, eval, init, lambda-env, pipelines, provision, status, test, webhooks
- `dx-init`, `aem-init`, `dx-upgrade`, `dx-eject`, `dx-sync`, `dx-scan`
- `dx-doctor`, `aem-doctor`, `aem-refresh`
- `dx-hub-init`, `dx-hub-config`
- `dx-pattern-extract`, `dx-doc-retro`, `dx-pr-reviews-report`

Caller check: no skill invokes these through the Skill tool. There is one exception to settle first: `dx-upgrade` says "run the full `/dx-doctor` flow inline". Either keep `dx-doctor` model-invocable (−~430 chars of savings) or have `dx-upgrade` read `dx-doctor/SKILL.md` instead of invoking it.

**Step 2 — trim the remaining 48 to ≈140 chars each (description + `when_to_use`) → ≈8,000.**
- Keep one "what it does" clause plus the disambiguating trigger.
- Drop restated names and "Use when the user says …" lists that repeat the description.
- Keep the #166 negative clauses short ("not for X — use Y").
- Gate: the routing eval (#168) must hold. It is billed, so it needs approval too.

**Step 3 — consumer docs:** on a 1M context the budget is 40k, so Step 1 alone already fits. Document `skillListingBudgetFraction` and `skillOverrides: "name-only"` for teams on 200k who keep many plugins.

## Re-measure

```bash
bash scripts/validate-skills.sh | grep 'Skill listing'
```

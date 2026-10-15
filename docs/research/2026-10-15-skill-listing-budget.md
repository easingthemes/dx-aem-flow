# Skill listing budget and `disable-model-invocation` (TODO #238)

**Date:** 2026-10-15
**Baselines:** Claude Code v2.1.301, Copilot CLI v1.0.98
**Status:** Steps 1 and 2 **applied 2026-10-15** (approved). Step 3 (#250) and the routing eval (#168) are still open.

**Method.** Every behaviour below was observed by running the real CLI against a local stub model, with no login and no billed calls:
- Claude Code used `ANTHROPIC_BASE_URL` with `--plugin-dir` pointing at our four plugins.
- Copilot used BYOK `COPILOT_PROVIDER_BASE_URL` with the skills in `.github/skills/`.

The stub records each request the CLI sends, so the listing, the skill bodies and the tool results can be read exactly. Docs and bundle strings were used only to explain what the logs show.

## 1. How the listing is built

**Claude Code** (`hxt`/`Kun` in the v2.1.301 bundle, plus logs):
- Each model-invocable skill becomes one line, `- <plugin>:<name>: <description> - <when_to_use>`, capped at 1536 chars.
- The budget is context × 4 chars/token × `skillListingBudgetFraction` (0.01).
- Over budget, skills are ranked by a usage score. The top ones keep their text; the rest are sent **by name only**.

**Copilot CLI** sends `<available_skills>` with name + `description` only. **It ignores `when_to_use`** (seen in the request). No cap was hit with our five test skills; the cap is unknown.

**Agent Skills spec** (agentskills.io): `name`, `description` (≤1024), `license`, `compatibility`, `metadata`, `allowed-tools`. Neither `when_to_use` nor `disable-model-invocation` is in it. The spec suggests about 100 tokens of metadata per skill.

## 2. Measured, all four plugins, fresh `HOME` (no usage history)

| Model | Listing used | Our 73 skills with full text | Name only |
|---|---|---|---|
| `claude-sonnet-5-5` / `opus-5-5` / `haiku-5-5` | 27,888 chars | 43 | **30** |
| `claude-sonnet-4-5` (200k) | 7,031 chars | 1 | **72** |

Our listing as written is **36,795 chars**. On 5.5 models the descriptions that get dropped are the plugins loaded last: **all of dx-aem**, dx-hub and dx-automation, plus `dx-ticket-analyze` and `dx-upgrade`. On a fresh install, AEM teams get AEM skills routed by name alone until usage history builds up. Another plugin the user has competes for the same budget.

*Correction to the first draft:* "fits a 1M context (40k)" was arithmetic, not measurement. The real 5.5 budget seen here is about 28k.

## 3. What `disable-model-invocation: true` actually does (verified)

| Path | Claude Code 2.1.301 | Copilot CLI 1.0.98 |
|---|---|---|
| Skill in the model's listing | absent | absent |
| User types `/name args` (interactive) | runs (docs) | runs (docs; not tested) |
| `-p "/name args"` (our pipelines) | **runs**: body expanded into the prompt | **not expanded**: the model gets the raw text, and can't load the skill |
| Model calls the Skill tool | **blocked**: `cannot be used with Skill tool due to disable-model-invocation … Do not replicate this skill's workflow by other means` | **blocked**: `Skill "x" not found` |
| Subagent calls it (via `Agent`) | **blocked**, same message, also with `/name …` at the start of the subagent prompt | — |
| Preload via agent `skills:` / scheduled task with the skill as prompt | blocked (docs) | — |

What follows from this:
- A dmi skill is fine as an **entry point** a human types or a Claude pipeline starts with `-p "/name …"`.
- It is fatal as a **step another skill or subagent reaches for**. The block message also forbids the model from working around it, so a chain stops and does not degrade.
- `skillOverrides` (`name-only`, `user-invocable-only`) **does not apply to plugin skills** (Claude Code docs). It is no lever for our consumers.

## 4. How our skills are reached today

- **Pipelines** (`ado-cli-*.yml` → `pipeline-agent.js` → Agent SDK `query`) always start with a slash: `/dx-bug-all`, `/dx-pr-review`, `/dx-estimate`, `/dx-discover-repos`, … They are safe for dmi on Claude. None runs on Copilot `-p`.
- **No** agent uses `skills:` preload. No scheduled task uses a skill as its prompt. No `.github/agents` template points at a dmi candidate.
- **Chains that a dmi target would break:**
  - `dx-init` runs the `/aem-init` and `/auto-init` flows "inline";
  - `dx-upgrade` runs the `/dx-doctor` flow "inline";
  - `dx-estimate` **batch mode** dispatches subagents with `Run /dx-estimate <id>`.
- **Existing bug found:** `dx-estimate` already has `disable-model-invocation: true`, so its batch mode (more than one ID) cannot work. Each subagent's Skill call is blocked, as reproduced above. The single-ID pipeline path (`-p "/dx-estimate <id>"`) works.

## 5. Revised proposal (not applied)

**Step 1 — dmi only on entry-point admin skills that nothing chains to (16): −7,337 chars.**
- `auto-alarms`, `auto-deploy`, `auto-lambda-env`, `auto-pipelines`, `auto-provision`, `auto-webhooks`, `auto-status`, `auto-test`
- `dx-eject`, `dx-sync`, `dx-scan`
- `dx-hub-init`, `dx-hub-config`
- `dx-pattern-extract`, `dx-doc-retro`, `dx-pr-reviews-report`

**Keep model-invocable, trim instead:**
- `dx-init`, `aem-init`, `auto-init` (chained from `dx-init`);
- `dx-doctor` (chained from `dx-upgrade`);
- `dx-upgrade`, `aem-doctor`, `auto-doctor`, `aem-refresh`. Users reach these by plain request ("something is broken", "update seed data").

**Cost of Step 1:** the model no longer knows these 16 exist. Natural requests like "deploy the lambda" or "set up alarms" stop routing, and the user must type `/auto-deploy`. They are infra steps run on purpose, and `auto-init` / `auto-doctor` still name them, so that is the intended trade.

**Step 2 — trim what is left so the listing fits the measured 5.5 budget with room for other plugins.** Target ≤ 22k chars, which leaves ~6k of the ~28k for the user's other plugins.
- After Step 1 and the `/auto-eval` removal (#229) the listing is 28,997, so about 7k must go.
- **`when_to_use` is 17,121 of the 36,795 chars**: nearly half the listing, and Copilot never sees it. Most of it repeats the description as "Use when the user says '…'".
- Cutting `when_to_use` to disambiguating triggers only (≤ 80 chars, or none) saves roughly 10k on its own and leaves Copilot routing untouched.
- `description` (17,611 chars) stays the routing text for both platforms. Trim it only on the outliers: the ten longest entries (`dx-council` 1,094, `dx-figma-verify` 781, `aem-fe-verify` 739, `dx-pr-commit` 719, …) are 4.7k over a 250-char line.

**Step 3 — fix `dx-estimate` batch** (separate from the budget). Either:
- (a) drop `disable-model-invocation` from `dx-estimate` and rely on its own "confirm before posting" gate; or
- (b) move the single-ID procedure to `dx-estimate/references/single.md` and have the batch subagents `Read` it instead of invoking the skill.

(b) keeps the side-effect guard. Needs a decision.

**Gate:** the routing eval (#168) at the new ref. It is billed, so it needs approval.

## Re-measure

```bash
bash scripts/validate-skills.sh | grep 'Skill listing'
```

Live listing check (no login): run `claude -p hello --plugin-dir …` against a stub on `ANTHROPIC_BASE_URL` and count the `- plugin:name:` lines with and without text under "The following skills are available for use with the Skill tool:".

## 6. Applied (2026-10-15)

- **Step 1:** `disable-model-invocation: true` on the 16 entry-point admin skills listed above. 20 of 77 skills now carry it.
- **Step 2:** `when_to_use` removed from all 56 remaining model-invocable skills (`auto-eval` was left alone; #229 deletes it). Each `description` was rewritten as what it does, plus one or two trigger phrases, plus a short "Not for X (sibling)" clause for the #14 collision clusters. Those negative clauses used to live in `when_to_use`, so **Copilot now sees them for the first time**. Longest description: 268 chars.
- **Listing:** 36,795 → **12,144 chars** (`validate-skills.sh`; `LISTING_BASELINE` lowered to match).
- **Live check** (stub model, all four plugins, fresh HOME):
  - 5.5 models: **57 of 57 with full text** (was 43 of 73).
  - 200k model (`claude-sonnet-4-5`): 5 of 57 (was 1 of 73). Fitting 200k would need ~100 chars per skill, which is not the target while the 5.5 models are the default.
- #14 Done-when loop: no output. `validate-skills.sh` / `.test.sh` and every other suite pass. All frontmatters parse with PyYAML.
- **Not verified:** that routing quality held. That needs the routing eval (#168), which is billed.

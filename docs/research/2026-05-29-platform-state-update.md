# Platform State Update — 2026-05-29

Four-week delta to [2026-05-01-platform-state-update.md](2026-05-01-platform-state-update.md).
Covers Claude Code **v2.1.126 → v2.1.156** (Opus 4.8 era). Copilot CLI movement
since 2026-05-16 is tracked separately in
[2026-05-16-copilot-cli-hook-matcher-bug.md](2026-05-16-copilot-cli-hook-matcher-bug.md);
skill-authoring conventions in [2026-05-15-google-skills-best-practices.md](2026-05-15-google-skills-best-practices.md).

**Scope discipline:** This snapshot deliberately filters the changelog for things
that change *our* plugins. UI/UX polish (agent view, effort-slider labels, fast-mode
pricing, terminal rendering) is acknowledged once and then ignored — none of it
touches Markdown skills/agents/hooks.

---

## TL;DR — the five things that matter

1. **Opus 4.8 is the default model at `high` effort (v2.1.154).** Our model-tier
   table (`CLAUDE.md:105`) and TODO #81 both still say "Opus 4.7 xhigh". That framing
   is now stale: `high` is the *new baseline*, so `xhigh` is the escalation tier above
   it, and the `model: opus` declarations across our skills/agents now resolve to 4.8.
   **Re-baseline the tier table; close/reframe TODO #81.**

2. **`disallowed-tools` skill/command frontmatter shipped (v2.1.152).** First-class
   way to *remove* tools from the model while a skill is active (Claude Code tool
   names; restriction clears on the next user message). **Verified caveat:** the
   "read-only" lookup skills (`dx-help`, `dx-ticket-analyze`, `aem-component`) are
   *not* read-only — they intentionally offer "Save results to `.ai/research/…`" and
   write report files, so they legitimately need `Write`. The real value is narrower:
   (a) `disallowed-tools: Edit Bash` on **analysis skills that create new reports but
   should never modify existing source or run shell**, and (b) the doc's own canonical
   use — removing `AskUserQuestion` from **orchestrated/forked** skills so a pipeline
   can't block on an interactive prompt (ties to #129, #104). Both are real but require
   scoping, not a blanket pass.

3. **Plugin dependency enforcement shipped (v2.1.143) — and we don't use it.** No
   `plugin.json` in the repo declares `dependencies`. "dx-aem requires dx-core" and
   "dx-automation requires dx-core" live only in CLAUDE.md prose. Declaring the field
   gives us auto-install of dx-core + protection against disabling a depended-on plugin.

4. **We finally have token-footprint instrumentation.** `/context all` per-skill
   estimates (v2.1.139), `/usage` per-category breakdown across skills/subagents/
   plugins/MCP (v2.1.149), and `claude plugin details` token cost (v2.1.139). This is
   the measuring stick the long-running concise-body audit (#113) and the
   orchestration-context work (2026-05-05) were missing.

5. **`MessageDisplay` hook (v2.1.152)** can transform/hide assistant text at the
   display layer — a cleaner lever for the "forked skills break standalone UX" problem
   (#104) and coordinator output discipline (#49) than env-var-gated body edits.

Everything else is either already tracked, a fix to a bug we didn't hit, or polish.

---

## 1. Releases by tool

### Claude Code — v2.1.126 → v2.1.156 (~30 releases)

Grouped by what they touch in our surface area. Version in parens.

#### Models & the system prompt
- **Opus 4.8 default at `high` effort (2.1.154).** Dynamic workflows orchestrate
  "tens to hundreds of agents in the background" (see §4). Fast mode on 4.8 = 2× rate
  for 2.5× speed.
- **Lean system prompt is now the default for all models except Haiku, Sonnet, and
  Opus ≤4.7 (2.1.154).** Less built-in hand-holding → our skills can shed explanatory
  prose Claude no longer needs. Direct tailwind for the concise-body audit (#113).
- **"Claude reserves multiple-choice prompts for genuine decisions only" (2.1.154).**
  Behavioral nudge that matches our `AskUserQuestion` discipline; no action.

#### Skills & slash commands
- **`disallowed-tools` frontmatter (2.1.152)** — removes tools from the model while
  the skill/command is active. *New primitive we don't use.*
- **`/reload-skills` (2.1.152)** + SessionStart hook can return `reloadSkills: true`
  — re-scan skill dirs without restarting. Pure dev-loop QoL for *us* authoring skills.
- **SessionStart hook can set session title via `hookSpecificOutput.sessionTitle`
  (2.1.152).**
- **`skillOverrides` setting works (2.1.129):** `off` (hide from model + `/`),
  `user-invocable-only` (hide from model), `name-only` (collapse description) — a
  context-cost lever for rarely-auto-triggered skills.
- **Root-level `SKILL.md` surfaced without a `skills/` subdir (2.1.142).** Not our
  layout, but relevant if we ever ship a single-file skill.
- **`/usage` per-category breakdown incl. skills (2.1.149); `/context all` per-skill
  token estimates with tokenizer accuracy (2.1.139).** Measurement (see §4).
- Fixes: infinite skill re-invocation (2.1.145), `Skill(name *)` wildcard matching
  (2.1.139), subagent skill discovery (2.1.133), skill arg substitution with regex
  metacharacters (2.1.136), `plugin.json skills` hiding the default directory (2.1.136
  — reinforces our "never set `skills:`/`agents:`" rule).

#### Plugins
- **`defaultEnabled: false` in `plugin.json`/marketplace entry (2.1.154)** — ship a
  plugin installed-but-off, enable via `/plugin`.
- **Plugin dependency enforcement (2.1.143):** `claude plugin disable` refuses when an
  enabled plugin depends on the target; dependencies of enabled plugins auto-enable.
- **`pluginSuggestionMarketplaces` managed setting (2.1.152)** + Discover-tab pins
  directory-matched plugins as "suggested" (2.1.154). Distribution, not authoring.
- `claude plugin details` shows inventory + token cost (2.1.139); `--plugin-url <url>`
  fetches a `.zip` (2.1.129); `skipLfs` marketplace source option (2.1.153);
  `themes`/`monitors` moved under `experimental` (2.1.129 — top-level deprecated).
- Validation now flags a *file* where a `skills:` entry should be a *directory*
  (2.1.145).

#### Hooks
- **`MessageDisplay` event (2.1.152)** — transform or hide assistant message text as
  displayed.
- **Hooks receive `effort.level` (JSON) + `$CLAUDE_EFFORT` env (2.1.133);** Bash tool
  commands also read `$CLAUDE_EFFORT`. Lets a hook adapt strictness to effort tier.
- **`args: string[]` exec form for command hooks (2.1.139)** — spawn without a shell
  (safer, no quoting bugs).
- **Stop/SubagentStop input now includes `background_tasks` and `session_crons`
  (2.1.145);** stdio MCP servers receive `CLAUDE_PROJECT_DIR` (2.1.139),
  `CLAUDE_CODE_SESSION_ID` + `CLAUDECODE=1` (2.1.154).
- Fixes: Stop hooks blocking forever now capped after 8 blocks (2.1.143); hook `if`
  conditions like `PowerShell(git push*)` (2.1.147); post-`EnterWorktree`
  `transcript_path` (2.1.141).

#### Subagents / agents
- `subagent_type` matching is case/separator-insensitive (2.1.140); `--agent` without a
  `plugin:` prefix now finds plugin-contributed agents (2.1.143); subagent MCP servers
  respect `--strict-mcp-config`/managed policies (2.1.153); subagent requests carry
  `x-claude-code-agent-id` (2.1.139); `agent_id`/`parent_agent_id` in OTEL spans
  (2.1.145). Agent view (Research Preview) for managing many sessions (2.1.139+).

#### Built-in review skills (overlap with our dx-pr-* / dx-simplify)
- `/simplify` → renamed `/code-review` (2.1.147), then `/code-review --fix` applies
  findings to the working tree and surfaces reuse/simplification suggestions (2.1.152);
  `/simplify` is now cleanup-only review-with-fixes (2.1.154). Worth a glance to ensure
  our `dx-simplify` / `dx-pr-review` framing doesn't drift from the built-in vocabulary.

#### Context management
- `/context all` per-skill estimates (2.1.139); compaction preserves sensitive user
  instructions (2.1.139); reactive compaction seeds from overflow size (2.1.142).

### Copilot CLI / VS Code

No new authoring-surface changes beyond the v1.0.45 `PostToolUse`-matcher bug already
documented (mitigation shipped 2026-05-16, TODO #124/#125). VS Code 1.118 skill-
isolated subagents already reflected (#101 Done).

---

## 2. Gap-closure scorecard (delta from 2026-05-01)

### Closed / superseded

| TODO | Item | Status | Evidence |
|------|------|--------|----------|
| #81 | "Adopt Opus 4.7 xhigh tier" | **Superseded** | Opus 4.8 is default at `high` (2.1.154). Reframe as "re-baseline tiers for 4.8", not "adopt 4.7". |
| #99 | `PostToolBatch` hook adoption | **Still valid, no change** | Event stable; remains low-priority watch. |
| #100 | `claude_code.skill_activated` OTel | **Now measurable end-to-end** | `/usage` per-category breakdown (2.1.149) gives the read-side without custom OTel wiring. |

### Newly opened (this snapshot)

| Item | Trigger | Suggested priority |
|------|---------|--------------------|
| Declare plugin `dependencies` (dx-aem→dx-core, dx-automation→dx-core) | 2.1.143 enforcement | **Done (this snapshot)** |
| Re-baseline model-tier table for Opus 4.8 | 2.1.154 | **Done (this snapshot)** |
| Pilot `disallowed-tools` — analysis skills (`Edit Bash`) + `dx-simple` path split | 2.1.152 | **High (needs scoping, not blanket)** |
| Token-footprint baseline via `/context all` + `claude plugin details` | 2.1.139/2.1.149 | **Medium** |
| `defaultEnabled: false` for dx-automation | 2.1.154 | **Medium** |
| `MessageDisplay` hook for forked-skill UX (#104) / coordinator output (#49) | 2.1.152 | **Medium (evaluate)** |
| Document new hook fields (`effort.level`/`$CLAUDE_EFFORT`, `args[]`, `MessageDisplay`) in CLAUDE.md | 2.1.133/2.1.139/2.1.152 | **Low** |
| `/reload-skills` in contributor docs (Testing Changes) | 2.1.152 | **Low** |
| `skillOverrides` as a context-cost lever | 2.1.129 | **Low (watch)** |

---

## 3. Recommended actions

### Tier 1 — Real value, low risk (do these)

1. **Re-baseline the model-tier strategy for Opus 4.8.**
   `CLAUDE.md:105–110`. Replace the "Opus 4.7 `xhigh` (v2.1.111+)" row with Opus 4.8.
   Make explicit that `high` is now the *default* effort for Opus 4.8, so `xhigh`
   is a deliberate escalation **above** the new baseline (not above 4.7). Keep the
   escalation guidance ("only when a step has demonstrably failed at high, or >5 files
   of changes"). Close TODO #81 and reword it. No frontmatter changes required — every
   `model: opus` already resolves to 4.8; this is a docs-accuracy fix that prevents us
   reasoning from a stale baseline. Pair with a note that the **lean system prompt is
   now default**, which is the green light for the concise-body audit (#113).

2. **Declare plugin dependencies in the manifests.**
   Add to `plugins/dx-aem/.claude-plugin/plugin.json` and
   `plugins/dx-automation/.claude-plugin/plugin.json`:
   ```json
   "dependencies": ["dx-core"]
   ```
   (Confirm the exact schema key against the current plugin-manifest docs before
   shipping — `dependencies` is the documented field as of 2.1.143; verify whether it
   takes bare names or `name@marketplace`.) Today "Requires dx" is prose-only in
   CLAUDE.md. This makes the requirement machine-enforced: dx-core auto-enables, and
   `claude plugin disable dx-core` is refused while dx-aem/dx-automation are on. Also
   mirror into the `.cursor-plugin/` manifests if Cursor honors the field.

3. **Pilot `disallowed-tools` where it's genuinely correct (not a blanket pass).**
   *Verification killed the original "read-only skills can write" framing* — `dx-help`,
   `dx-ticket-analyze`, and `aem-component` all write report files by design and need
   `Write`. Two scoped, defensible pilots remain:
   - **Analysis skills → `disallowed-tools: Edit Bash`.** Lookup/analysis skills create
     *new* artifacts under `.ai/research/` but should never modify existing source or
     run shell. Removing `Edit` and `Bash` (keeping `Write`) enforces "produces a
     report, does not touch your codebase." Candidates: `dx-help`, `dx-ticket-analyze`,
     `aem-component`. (Verify `aem-page-search` first — it appears to only return links;
     if so it can take the full `Write Edit Bash` removal.)
   - **`dx-simple` authoring path → enforce the split.** The skill already gates a
     JCR-write (authoring) vs file-edit (code) split behind 9 confidence checks, but the
     contract is prose. `disallowed-tools` can make the authoring branch hard-remove
     `Edit`/`Write` and the code branch hard-remove the AEM-write MCP tools. **Design
     note:** frontmatter `disallowed-tools` is static per-skill, so a *single* skill
     can't flip tool sets mid-run by branch — enforcing this likely means splitting the
     two paths into separate forked sub-skills (or using the orchestrator to set the
     restriction). Scope before building.
   - **Format:** Claude Code tool names (`Write Edit Bash`, space/comma/YAML-list), not
     the lowercase agent-skills categories our `allowed-tools` uses. The restriction
     clears on the next user message — fine for skills, but means it does **not** persist
     across an interactive multi-turn session.

### Tier 2 — Measurement & footprint (worth a focused session)

4. **Establish a token-footprint baseline for all 4 plugins.**
   Run `/context all` and `claude plugin details` per plugin; capture per-skill token
   estimates. This converts the concise-body audit (#113) and the orchestration-context
   findings (2026-05-05) from "we think aem-component is heavy" to a ranked list.
   Save the baseline numbers into the audit TODO so progress is measurable.

5. **Ship `dx-automation` with `defaultEnabled: false`.**
   It's the heaviest plugin and the one fewest users invoke interactively (it's an
   ops/pipeline plugin). `"defaultEnabled": false` keeps it installable from the
   marketplace but off by default, shrinking the default context footprint. Document
   the `/plugin enable dx-automation` step in `auto-init`.

6. **Evaluate `MessageDisplay` for the forked-skill UX problem (#104).**
   The current fix proposal is env-var-gated body output (`DX_ORCHESTRATED=1`).
   `MessageDisplay` is potentially cleaner: keep the human-friendly summary in the
   skill body for standalone runs, and register a `MessageDisplay` hook in
   `dx-agent-all` that collapses/hides the verbose `## Return` block when orchestrated.
   **Caveat to verify:** confirm `MessageDisplay` only affects *display*, not what the
   orchestrator model ingests — if it also strips from context it's the wrong tool.
   Prototype before committing; this is "evaluate", not "adopt".

### Tier 3 — Document & watch

7. **Update CLAUDE.md hook tables** with the new fields: `MessageDisplay` event,
   `effort.level`/`$CLAUDE_EFFORT` hook input + env, `args: string[]` exec form. Add
   `MessageDisplay` to the events list. Low effort, keeps our reference authoritative.

8. **Add `/reload-skills` to the "Testing Changes" section of CLAUDE.md** — it removes
   the restart-to-test-a-skill loop that every contributor currently eats.

9. **Watch `skillOverrides`** as a future lever: skills that should never auto-trigger
   (e.g. `dx-eject`, `dx-sync`) could be `user-invocable-only` to drop their
   descriptions from the model's context budget. Quantify with #4 first.

### Explicitly NOT recommended (marketing / non-actionable)

- **Dynamic workflows (orchestrate 100s of agents).** Genuinely powerful, but our
  `dx-agent-all` already does deterministic phase orchestration with `context: fork`,
  and `dx-automation` runs as Lambda-driven ADO pipelines — not interactive Claude
  Code sessions where the Workflow tool lives. The one place it *could* pay off is
  TODO #45 (parallel AEM-verify + FE-verify). Keep as a **strategic watch**, not a
  task — adopting it now would be chasing a headline, not solving a problem we have.
- Fast-mode pricing, effort-slider relabel, agent-view UI, browser `/chrome` picker,
  Windows/PowerShell fixes, terminal rendering. No plugin surface impact.

---

## 4. On "dynamic workflows" — separating signal from headline

v2.1.154's banner feature is dynamic workflows. The honest read for this repo:

- **What's real:** a deterministic JS-orchestration primitive that fans out subagents
  with structured returns, pipelines, and budget control. Strictly more capable than
  hand-rolled `Agent`-tool fan-out for *interactive* sessions.
- **Why it mostly doesn't apply to us yet:** our two orchestrators are (a) `dx-agent-all`,
  which is intentionally a *sequential, checkpointed* pipeline with human review gates —
  the value there is predictability, not massive parallelism; and (b) `dx-automation`,
  which executes via the Agent SDK in Lambda, where the interactive Workflow tool isn't
  the runtime. Adopting workflows would be re-platforming working code to use a feature
  whose headline ("hundreds of agents") describes a scale we don't operate at.
- **The one credible pilot:** TODO #45 — run `aem-verify` and `aem-fe-verify`
  concurrently for a component (they're independent). That's a 2-way `parallel()`, not
  "hundreds of agents", and it's already on the backlog. If we pilot workflows, do it
  there and measure wall-clock vs. the current sequential fork calls.

---

## 5. Sources

- Claude Code: [CHANGELOG.md](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md) · [changelog docs](https://code.claude.com/docs/en/changelog) · [skills docs](https://code.claude.com/docs/en/skills) · [hooks docs](https://code.claude.com/docs/en/hooks)
- Release coverage cross-checks: [DevelopersIO v2.1.152 writeup](https://dev.classmethod.jp/en/articles/20260524-claude-code-updates-v2-1-152/) · [Releasebot — Claude Code](https://releasebot.io/updates/anthropic/claude-code)

## 6. Related docs

- [2026-05-01-platform-state-update.md](2026-05-01-platform-state-update.md) — prior snapshot (v2.1.119→126)
- [2026-05-15-google-skills-best-practices.md](2026-05-15-google-skills-best-practices.md) — skill-authoring conventions (still current; this snapshot adds the `disallowed-tools` primitive and the lean-system-prompt tailwind for the concise-body audit)
- [2026-05-16-copilot-cli-hook-matcher-bug.md](2026-05-16-copilot-cli-hook-matcher-bug.md) — Copilot side
- [2026-05-05-orchestration-context-pollution.md](2026-05-05-orchestration-context-pollution.md) — now has `/context all` + `MessageDisplay` as new tooling
- [`docs/todo/TODO.md`](../todo/TODO.md) — #81 (supersede), #104, #113, #45, #49

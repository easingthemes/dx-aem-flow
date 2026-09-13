# TODO — Upstream Changes (September 2026 intake)

Claude Code shipped a batch of plugin/hook/effort features between v2.1.251 and
v2.1.269 that our docs and scripts do not reflect yet. One intake file per sweep
keeps the provenance of each claim (release + date) next to the work item.

Release versions below are the shipping version stated in the intake notes; each
item's **Done-when** is checkable in this repo, not against the changelog.

## Model switch hook events

**Added:** 2026-09-13
**Problem:** Claude Code v2.1.251 (2026-08-28) added `PreModelSwitch` and
`PostModelSwitch` hook events. A `PreModelSwitch` handler can block, confirm, or
annotate a model switch. The same release made `SessionStart` resume hooks
receive session staleness and an estimated re-cache cost. Our hook event list in
`CLAUDE.md` § "Hook Authoring — Key Fields" ("Available events (Claude Code)")
and the hooks page on the docs site list neither event, so nobody writing a hook
here knows they exist. Concrete value: a model-switch guard for
`dx-automation` pipeline runs, where a silent downgrade off the Opus 4.8 /
`high` baseline changes review and verification behaviour without any signal.
**Scope:**
- Docs (owned by another workstream, listed for the reader): `CLAUDE.md`
  § "Hook Authoring — Key Fields" event list; `website/src/pages/learn/hooks.mdx`.
- Implementation: `plugins/dx-core/hooks/hooks.json` +
  `plugins/dx-core/hooks/scripts/` for the guard itself.
**Done-when:** `grep -c "PreModelSwitch" CLAUDE.md website/src/pages/learn/hooks.mdx`
is non-zero for both files, AND — if the guard is adopted —
`grep -n "PreModelSwitch" plugins/dx-core/hooks/hooks.json` returns a handler.
**Approach:** Document first (cheap, zero risk). Only then decide whether the
guard belongs in `dx-core` hooks (fires for every consumer) or behind
`DX_HOOK_PROFILE=strict`, which is what the profile tier exists for.

## maxEffortLevel setting

**Added:** 2026-09-13
**Problem:** Claude Code v2.1.267 (2026-09-09) added a `maxEffortLevel` setting,
settable top-level or per-model under `modelSettings`, that caps effort on every
provider including Bedrock, Vertex and Foundry. Our Model Tier Strategy in
`CLAUDE.md` assigns effort per skill/agent (`effort: xhigh` on the escalation
tier) but has no ceiling — nothing stops a consumer project, or a pipeline run,
from paying `xhigh` across the board. That is the cost-control knob
`dx-automation` pipelines lack today.
**Related fact from the same release, already recorded in `CLAUDE.md`:**
v2.1.267 also *fixed* `effort:` frontmatter on custom commands, skills and
subagents being **silently ignored** on models whose default effort is pinned
(Opus 4.7, Opus 4.8, Fable 5). So every `effort:` we set before that release was a
no-op on those models — the tier table only came into force on 2026-09-09, and no
`xhigh` skill has ever been measured against `high`. That makes a ceiling more
useful, not less: effort declarations now actually cost money.
**Scope:** `CLAUDE.md` § "Model Tier Strategy" — **already documented** as of the
2026-09-13 docs pass (`grep -c maxEffortLevel CLAUDE.md` → 1). The remaining gap
is entirely plugin-side: `plugins/dx-core/templates/` settings scaffolding emitted
by `/dx-init`, and the `plugins/dx-automation/**` pipeline YAML that launches the
agent (`grep -rn "maxEffortLevel" plugins/` → 0 today).
**Done-when:** `grep -rn "maxEffortLevel" plugins/` returns a scaffolded or
pipeline-side setting, **or** `docs/todo/todo-config.md` records an explicit
decision not to ship a ceiling and why.
**Approach:** Decide the ceiling before writing it anywhere: `high` is the current
Opus default, so a cap of `high` makes `effort: xhigh` a no-op — that is a policy
choice, not a default. Likeliest split: no cap locally, cap at `high` in
pipelines. Ordering note: because `effort:` was a no-op until v2.1.267, measure
what the tier table actually costs now (#137 / `/skill-doctor`) before capping it.

## Plugin-dir folder loading simplifies the local test loop

**Added:** 2026-09-13
**Problem:** `CLAUDE.md` § "Testing Changes" documents the local test loop as
`/plugin marketplace add /path/to/dx-aem-flow` followed by four
`/plugin install <name>@dx-aem-flow` calls. Claude Code v2.1.265 (2026-09-08)
made `--plugin-dir` accept a *folder of plugins*: every child folder with a
manifest loads, and children added or removed while running are picked up. Our
`plugins/` directory is exactly that shape — one `--plugin-dir plugins` would
replace the marketplace dance for local development. The same release made
`/plugin` install/enable/disable take effect on menu close, so the
`/reload-plugins` step some of our docs still imply is unnecessary.
**Scope:** `CLAUDE.md` § "Testing Changes"; the setup/contributing pages on the
docs site that repeat the marketplace instructions
(`website/src/pages/contributing/`). Both are owned by the docs workstream —
this item is the tracker record, not the edit.
**Done-when:** `grep -n "plugin-dir" CLAUDE.md` returns the documented local
loop, AND the marketplace-add instruction is either removed or explicitly
labelled as the consumer-install path rather than the contributor loop.
**Approach:** Keep `marketplace add` documented — it is how consumers install.
Add `--plugin-dir plugins` as the *contributor* loop and say which is which.

## Machine-readable plugin validation in CI

**Added:** 2026-09-13
**Problem:** Claude Code v2.1.259 (2026-09-02) added `claude plugin validate --json`,
a machine-readable validation report; v2.1.268 added `--json` to
`plugin install/uninstall/update/enable/disable` and per-row
`errorDetails`/`noteDetails` in `claude plugin list --json`. Our validation is
text-scraping: `scripts/validate-structure.sh` checks version sync with
`grep '"version"' … | sed` across the five manifest files and detects the
Claude-Code-breaking `agents`/`skills` manifest fields with a per-field grep. It
never asks the tool that owns the schema whether the manifest is valid, so any
manifest rule we did not hand-code is unchecked.
**Scope:** `scripts/validate-structure.sh` (the manifest section, around the
version-sync and `agents`/`skills` field checks); `.github/workflows/validate.yml`,
which runs `validate-skills.sh`, `validate-agents.sh`, `validate-structure.sh`,
`validate-stats.sh` on every PR.
**Done-when:** `grep -n "plugin validate" scripts/validate-structure.sh` returns a
call that parses the `--json` output (not a grep over human-readable text), and
`bash scripts/validate-structure.sh` still exits 0 on a clean tree.
**Approach:** Additive — keep the existing greps (they encode repo-specific rules
like cross-manifest version sync that the tool cannot know) and add the schema
check beside them. Guard on `command -v claude` so the script still runs on a
machine without the CLI instead of failing the PR.

## Symlinked plugin component paths are now refused

**Added:** 2026-09-13
**Problem:** Claude Code v2.1.266 (2026-09-08) fixed a plugin escape: a plugin
could read outside its own directory by pointing a command / agent / skill /
hooks component path at a symlink. Such paths now error. Verified in this repo on
2026-09-13: `find . -type l -not -path './node_modules/*' -not -path './.git/*'`
returns nothing, so no plugin component path here is a symlink and all four
plugins are unaffected. The open question is the *documented* layout:
`.codex/INSTALL.md` tells users to `ln -sf` every
`plugins/<plugin>/skills/<skill>/` directory into a project's `.agents/skills/`.
Those symlinks live in the consumer project and point *into* the plugin, which is
the opposite direction from the refused case — but it has not been confirmed
against a real Claude Code run that such a project layout does not trip the new
check.
**Scope:** `.codex/INSTALL.md` (the two `ln -sf` loops); `plugins/*/skills/`,
`plugins/*/agents/`, `plugins/*/hooks/` as the component paths under the rule.
**Done-when:** `find plugins -type l` returns nothing (regression guard, can be
added to `scripts/validate-structure.sh`), AND `.codex/INSTALL.md` states
explicitly that the symlinks are created in the consumer project and never
inside a plugin directory.
**Approach:** Low priority — this is a confirm-and-document item, not a fix. The
cheap durable part is the `find plugins -type l` guard in
`validate-structure.sh`, which turns "we checked once" into "CI checks every PR".

## Token-footprint baseline via /skill-doctor

**Added:** 2026-09-13 (re-anchor of TODO #137, originally added 2026-05-29)
**Problem:** #137 asks for a per-plugin token-footprint baseline so the
concise-body audit (#113) ranks skills by measured cost instead of line count.
It was written against `/context all` plus `claude plugin details` (CC
v2.1.139/149). Claude Code v2.1.261 (2026-09-04) shipped `/skill-doctor`, which
reports which loaded skills go unused and what each costs in context — the
purpose-built version of the same measurement, and the one that also answers
#167 (skill-lift / retirement detection) and #170 (rightsizing). Without the
baseline, #113's "top offenders" list is line-count guessing: 77 skills, median
283 lines, max 1121 as of the 2026-07-01 check.
**Scope:** Measurement only — no plugin files change. Inputs are all four
plugins' `skills/`. Output is a numbers table recorded in
`docs/todo/todo-skill-conventions.md` § "9. Concise-body audit" (#113) and § "16.
Rightsize CLAUDE.md + skills" (#170).
**Done-when:** `todo-skill-conventions.md` § 9 contains a `/skill-doctor` result
table with a per-skill context cost for at least the 13 skills over 500 lines
(#108) — i.e. `grep -n "skill-doctor" docs/todo/todo-skill-conventions.md`
returns the recorded baseline, not just a mention.
**Blocked — needs an interactive session:** `/skill-doctor` is a slash command
inside a running Claude Code session. It cannot be driven headlessly, so this
item cannot be closed from a background/remote run. Whoever picks it up must run
it locally and paste the numbers back into `todo-skill-conventions.md`.
**Approach:** One session, all four plugins loaded, record raw numbers before
interpreting them. Rank #113 by measured cost; feed the "unused" column into
#167 as retirement candidates.

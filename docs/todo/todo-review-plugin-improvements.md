# TODO — Plugin Improvements from the 2026-03-27 Review

Back-fill, written 2026-09-13 under TODO #172. Items #33–#41 were added to
`TODO.md` on 2026-03-27 from a plugin-feature review, but the detail file they
linked to was never committed. Each **Problem** below is reconstructed from the
tracker row plus the current state of the repo verified on 2026-09-13; each
**Done-when** is a check that was run against this tree, so it is known to be
executable. Where the original review's reasoning could not be recovered, the
item says so rather than inventing it.

## Hook `if` field — conditional execution

**Added:** 2026-03-27 (detail back-filled 2026-09-13)
**Problem:** Claude Code hooks support an `if` field — a fine-grained permission
rule evaluated *before* the hook process is spawned (`"Bash(git commit*)"`,
`"Edit(**/.claude-plugin/**)"`). Without it, a hook spawns a shell on every
matching tool call and re-filters in bash. We use it exactly once:
`plugins/dx-core/hooks/hooks.json:86` (`"if": "Edit(**/.claude-plugin/**)"`).
The other nine dx-core handlers and both dx-aem handlers filter in-command
instead — several open with `[ "${CLAUDE_TOOL_NAME:-}" = "..." ] && …`, which is
exactly the work `if` would do without starting a process.
**Scope:** `plugins/dx-core/hooks/hooks.json` (10 handlers),
`plugins/dx-aem/hooks/hooks.json` (2 handlers). Not the `.github/hooks/`
Copilot copies — `if` is Claude-Code-only and silently ignored there.
**Done-when:** every handler whose command begins with a `CLAUDE_TOOL_NAME`
guard has an equivalent `if` field —
`grep -c '"if"' plugins/dx-core/hooks/hooks.json` is at least as large as
`grep -c 'CLAUDE_TOOL_NAME' plugins/dx-core/hooks/hooks.json`, and the in-command
guards that remain are documented as defence-in-depth for Copilot CLI.
**Approach:** Keep the bash guards. Copilot CLI reads the same `hooks.json` and
ignores `if`, so removing them would regress Copilot behaviour — `if` is an
optimisation for Claude Code, not a replacement.

## Branch-guard exit code bug

**Added:** 2026-03-27 (detail back-filled 2026-09-13)
**Status: Done** — tracked as #34, closed before this file existed.
**Problem:** `validate-plugin-edit.sh` used `exit 1` for invalid JSON. In the
hook contract `exit 1` is a *non-blocking* error (surfaced only in verbose mode);
only `exit 2` blocks and feeds stderr back to the model. A `|| true` on the
`hooks.json` handler line also swallowed the exit code before it could propagate.
**Scope:** `plugins/dx-core/data/lib/validate-plugin-edit.sh`;
`plugins/dx-core/hooks/hooks.json` (the `Edit(**/.claude-plugin/**)` handler).
**Done-when:** met — `exit 1` replaced by `exit 2` for invalid JSON and the
`|| true` removed from the handler, so the blocking exit code reaches Claude Code.
Regression check: `grep -n 'exit 1' plugins/dx-core/data/lib/validate-plugin-edit.sh`
returns nothing for the JSON-validation path.

## Hook statusMessage for UX

**Added:** 2026-03-27 (detail back-filled 2026-09-13)
**Problem:** Without `statusMessage`, a hook that takes a moment shows the user
nothing — the session appears to stall. The original row tracked adding it across
our handlers. Current state (2026-09-13): `plugins/dx-core/hooks/hooks.json` has
10 handlers, 8 with `statusMessage`; `plugins/dx-aem/hooks/hooks.json` has 2
handlers, both with one. The only two without are the `async: true` handlers
(the `Task` subagent log and the `Edit` compaction reminder), which run in the
background and have no spinner to label. So this item is arguably already
satisfied and needs a decision, not work.
**Scope:** `plugins/dx-core/hooks/hooks.json`, `plugins/dx-aem/hooks/hooks.json`.
**Done-when:** every non-`async` handler carries a `statusMessage` — i.e.
`grep -c '"type"' plugins/dx-core/hooks/hooks.json` minus
`grep -c '"async"' plugins/dx-core/hooks/hooks.json` equals
`grep -c 'statusMessage' plugins/dx-core/hooks/hooks.json` (10 − 2 = 8 today), and
the same identity holds for dx-aem (2 − 2 = 0 … currently 2, both async handlers
carry one, which is harmless). Close the item once that rule is written into the
hook-authoring docs so new handlers inherit it.
**Approach:** Most likely outcome is "close as done, record the rule". Do not
strip the two dx-aem `statusMessage` fields — they are harmless and informative.

## Async screenshot hooks

**Added:** 2026-03-27 (detail back-filled 2026-09-13)
**Problem:** Screenshot/asset-saving hooks are observational — nothing downstream
reads their output — so they should not block the turn. `async: true` exists for
exactly this. Current state (2026-09-13): both dx-aem Playwright handlers
(`browser_take_screenshot`, `browser_snapshot`) are already `async: true`. The two
**dx-core Figma** handlers (`mcp__plugin_dx-core_figma__get_screenshot` and
`…__get_design_context`, `hooks.json` lines 60–80) are still synchronous — they
shell out to `.ai/lib/figma-screenshot-hook.sh` on the critical path.
**Scope:** `plugins/dx-core/hooks/hooks.json` — the two Figma `PostToolUse`
handlers.
**Done-when:** `grep -c '"async"' plugins/dx-core/hooks/hooks.json` returns 4
(the 2 existing async handlers plus the 2 Figma ones), and a Figma screenshot
still lands in the spec directory after the change.
**Approach:** Consider `asyncRewake` instead of `async` if a failed save should
signal back rather than fail silently. Note Copilot CLI ignores `async`
entirely — the Copilot path stays synchronous either way.

## Skill `effort` field

**Added:** 2026-03-27 (detail back-filled 2026-09-13)
**Problem:** Skills can carry `model:` and `effort:` frontmatter and run at the
right tier without being wrapped in an agent. Adoption is thin: 8 of 77 skills
declare `effort:` (`dx-help`, `dx-pattern-extract`, `dx-plan`, `dx-pr-review`,
`dx-security`, `dx-simplify`, `dx-step-verify`, `dx-ticket-analyze`). The
Model Tier Strategy table in `CLAUDE.md` names more skills per tier than that,
so the table and the frontmatter disagree.
**Scope:** `plugins/*/skills/*/SKILL.md` frontmatter; the tier table in
`CLAUDE.md` § "Model Tier Strategy" as the intended-state reference.
**Done-when:** every skill named in the `CLAUDE.md` tier table declares a
matching `model:`/`effort:` pair —
`grep -L "^effort:" $(grep -l "^model: opus" plugins/*/skills/*/SKILL.md)`
returns only skills deliberately left at the model default, and that exception
list is written down.
**Approach:** Since CC v2.1.154 Opus 4.8 defaults to `high` effort, so `model:
opus` alone already buys deep reasoning — most of the gap may be intentional.
Settle the intent before mass-editing frontmatter. Overlaps #178 (`maxEffortLevel`):
a ceiling changes what these declarations actually do.

## AEM skills `paths` field

**Added:** 2026-03-27 (detail back-filled 2026-09-13)
**Problem:** The `paths:` frontmatter field limits a skill's auto-activation to
matching file patterns. No skill in this repo uses it — `grep -l "^paths:"
plugins/*/skills/*/SKILL.md` returns nothing across all 77 skills. The 12 dx-aem
skills auto-activate on prompt text alone even in projects with no AEM code,
which is the same pressure #166 (negative-trigger clauses) addresses from the
description side.
**Scope:** `plugins/dx-aem/skills/*/SKILL.md` (12 skills).
**Done-when:** `grep -l "^paths:" plugins/dx-aem/skills/*/SKILL.md` returns the
subset of skills that are genuinely file-scoped, and the skills deliberately left
unscoped (anything the user invokes by name, e.g. `aem-init`) are listed with the
reason.
**Approach:** `paths` constrains *auto*-activation, not explicit `/skill`
invocation — verify that before scoping anything a user types by name. Pair with
#166 rather than doing both passes separately. Cross-platform caveat: `paths` is
one of the fields flagged as possibly Claude-Code-only in the 2026-04-25 platform
research, so scoping here must not become the only guard.

## Documentation updates

**Added:** 2026-03-27 (detail back-filled 2026-09-13)
**Problem:** The hook and skill features tracked in #33–#38 are undocumented for
contributors, so new hooks and skills do not inherit them. This is the docs half
of the same review and overlaps #140 (document new hook/skill features) and #177
(model switch hook events) — the three should be done as one pass, not three.
**Scope:** `CLAUDE.md` § "Hook Authoring — Key Fields" and § "Conventions for
Adding Skills/Agents"; `website/src/pages/learn/hooks.mdx`;
`website/src/pages/contributing/authoring.mdx`.
**Done-when:** `grep -n "asyncRewake\|statusMessage\|\"if\"" CLAUDE.md` returns
the field rows (it does today) **and** the docs-site hooks page carries the same
table — `grep -c "statusMessage" website/src/pages/learn/hooks.mdx` is non-zero.
**Approach:** Merge into #140 when that item is scheduled; keep this row only as
the pointer from the #33–#38 cluster.

## Copilot CLI hook compatibility

**Added:** 2026-03-27 (detail back-filled 2026-09-13)
**Problem:** Plugin `hooks/hooks.json` is read by both Claude Code and Copilot
CLI, but the two honour different fields, so a handler authored for one can be a
silent no-op on the other. The compatibility statement we ship lives in
`docs/todo/todo-copilot-cli.md` ("Claude Code-only hook fields silently ignored
by Copilot CLI: `if`, `async`, `statusMessage`, prompt/agent hook types") and was
compiled against **Copilot CLI v1.0.40 (2026-05-01)**. Copilot CLI is now
**v1.0.83 (2026-09-04)** — the statement is unverified across ~43 releases, and at
least one item in it has already moved (HTTP hooks went from unsupported to
supported in v1.0.35).
**Scope:** `docs/todo/todo-copilot-cli.md` (the Claude-Code-only-fields line and
the release table); the hook-source table in `CLAUDE.md` § "Hook System — Platform
Separation"; `website/src/pages/learn/hooks.mdx`.
**Done-when:** the field-compatibility line in `todo-copilot-cli.md` names the
Copilot CLI version it was verified against and that version is the current one —
`grep -n "v1.0.83" docs/todo/todo-copilot-cli.md` returns the verification note.
**Approach:** Do it inside the single batch re-test (#182 / Task C cluster)
rather than as a standalone pass — the same session that re-tests #20/#90/#91
can re-verify the field matrix.

## OpenSkills / Agent Skills standard compatibility

**Added:** 2026-03-27 (detail back-filled 2026-09-13)
**Problem:** We claim conformance with the Agent Skills open standard
(`agentskills.io/specification`) in three shipped places — `AGENTS.md` line 52,
`.codex/INSTALL.md` line 42, and the website (`learn/intro.mdx`, plus the
front-page footnote naming "OpenSkills, OpenPlugins, AGENTS.md, MCP"). The claim
is not tested anywhere, and the 2026-04-25 platform research flags an open
question against the spec itself: whether `model`, `effort`, `context` and
`paths` are core fields or vendor extensions (Codex honours only `name` and
`description`). So our frontmatter may be conformant-plus-extensions, which is
fine, or non-conformant, which the docs would be overstating.
**Scope:** `plugins/*/skills/*/SKILL.md` frontmatter; the conformance claims in
`AGENTS.md`, `.codex/INSTALL.md`, `website/src/pages/learn/intro.mdx` and
`website/src/pages/index.mdx`.
**Done-when:** a written field-by-field mapping exists — for each frontmatter key
we use (`name`, `description`, `when_to_use`, `argument-hint`, `model`, `effort`,
`context`, `agent`, `paths`), whether it is spec-core or a vendor extension, and
which of Claude Code / Copilot CLI / Codex / Gemini honours it. Record it in
`docs/reference/` (skills read that directory) and link it from the conformance
claims.
**Approach:** Watch-level until the spec answers the core-vs-extension question.
The cheap interim fix is honesty in the docs: say "Agent Skills format plus
platform extensions", not bare "conformant". Related: #182 (Copilot hook
capabilities) and the Agent Plugins 1.0 re-anchor in `todo-open-plugins.md`.

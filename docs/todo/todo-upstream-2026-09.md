# TODO — Upstream Changes (September 2026 intake)

Claude Code shipped a batch of plugin/hook/effort features between v2.1.251 and
v2.1.269 — plus one v2.1.257 security fix — that our docs and scripts do not
reflect yet. One intake file per sweep keeps the provenance of each claim
(release + date) next to the work item.

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
replace the marketplace dance for local development. Separately, since
v2.1.221 plugins installed from `/plugin` activate immediately when safe instead
of always requiring `/reload-plugins`, so the explicit reload step some of our
docs imply is usually unnecessary — v2.1.265 kept `/reload-plugins` and extended
it to headless sessions, so it is still the fallback, not a removed command.
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
**Problem:** Claude Code v2.1.257 (2026-09-01) fixed a plugin escape: a plugin
could read outside its own directory by pointing a command / agent / skill /
hooks component path at a symlink. Such paths now error. (v2.1.265 followed up
with a backslash-spelled path that bypassed the same containment check on macOS
and Linux, and v2.1.267 with the marketplace-entry equivalent.) Verified in this
repo on 2026-09-13: `find . -type l -not -path './node_modules/*' -not -path './.git/*'`
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

---

## Second pass (v2.1.270–v2.1.273, intake 2026-09-16)

The first pass above covered v2.1.251–v2.1.269 and was scoped to hooks, effort
and plugin validation. A re-read of the [plugins reference](https://code.claude.com/docs/en/plugins-reference),
the [hooks reference](https://code.claude.com/docs/en/hooks) and the changelog
through **v2.1.273** found five surfaces that no TODO row covers at all —
verified by grep returning zero hits across `docs/`, `plugins/` and `CLAUDE.md`.

## Plugin `userConfig` — native config prompting and secret storage

**Added:** 2026-09-16
**Problem:** `plugin.json` supports a `userConfig` block: typed values
(`string`, `number`, `boolean`, `directory`, `file`) prompted when the plugin is
enabled, readable as `${user_config.KEY}` inside plugin content, exported to
hooks as `CLAUDE_PLUGIN_OPTION_<KEY>`, settable non-interactively via
`claude plugin install --config key=value`, and — with `sensitive: true` —
masked on entry and stored in the OS keychain instead of a file. v2.1.271 added
an `options` picker for enumerated values.

This is the native version of a large part of `/dx-init`'s interview. Today every
project-specific value lands in `.ai/config.yaml` in plaintext, including the
values that should never be in a file: the ADO PAT and the AEM credentials. Grep
confirms zero use: `grep -rn "userConfig" plugins/ docs/` → 0.

This does **not** replace `.ai/config.yaml` — that file is read by skills, by the
Lambda agents and by the standalone `cli/` scaffold, none of which can see
Claude Code's plugin config. The candidate scope is narrower: the handful of
values that are per-user rather than per-project, and the secrets.
**Scope:** `plugins/*/.claude-plugin/plugin.json` (and the `.cursor-plugin`
twins, which do **not** share this field — check before assuming parity);
`plugins/dx-core/skills/dx-init/SKILL.md` (the interview steps that would be
superseded); `docs/reference/config-reference.md`.
**Done-when:** `docs/todo/todo-config.md` records a per-field decision for every
value `/dx-init` asks for — `userConfig`, `.ai/config.yaml`, or both — **and**,
if any field moves, `grep -n "userConfig" plugins/dx-core/.claude-plugin/plugin.json`
returns it and `/dx-init` no longer prompts for it twice.
**Approach:** Start with secrets only (ADO PAT, AEM credentials) where the
keychain is a clear win over a file. Cross-platform is the catch: Copilot CLI and
Cursor read `plugin.json` too, and a field they ignore means the value is simply
missing there — so anything moved to `userConfig` needs a documented fallback, or
it must stay duplicated in `.ai/config.yaml`. Decide that before moving anything.

## Headless runtime flags for `dx-automation` pipelines

**Added:** 2026-09-16
**Problem:** Five flags/settings shipped between v2.1.259 and v2.1.268 that exist
for exactly the way our pipelines run Claude Code, and none appear anywhere in
this repo (`grep -rn` → 0 for each):

| Flag / setting | Release | What it does |
|---|---|---|
| `--permission-prompts none` | v2.1.259 | unattended headless hosts — no prompt can hang the run |
| `bashOutputMaxChars` / `taskOutputMaxChars` | v2.1.261 | inline output caps, up to 128K |
| `--append-subagent-system-prompt-file` | v2.1.261 | large subagent prompts from a file |
| `CLAUDE_CODE_SUBAGENT_MODEL` | v2.1.268 | subagent model override, behaviour made consistent |
| `CLAUDE_CODE_WORKFLOW_MAX_CONCURRENT_AGENTS` | v2.1.268 | concurrency ceiling for workflow agents |

The pipelines today pass an `ALLOWED_TOOLS` list and little else (#119). A
pipeline agent that hits a permission prompt blocks until the job times out, and
a long `mvn` run can blow the default inline output cap — both are failure modes
we have no configured defence against.
**Scope:** `plugins/dx-automation/**` pipeline YAML and the agent launcher that
builds the `claude` invocation; `plugins/dx-automation/skills/auto-pipelines/`.
Overlaps #119 (tooling matrix per agent) and #178 (`maxEffortLevel` ceiling) —
these belong in the same launcher change, not three separate ones.
**Done-when:** `grep -rn "permission-prompts" plugins/dx-automation/` returns the
launcher flag, and `docs/reference/config-reference.md` documents the caps and the
subagent-model override alongside the existing env-var table.
**Approach:** `--permission-prompts none` first — it is the one that turns a hang
into a clean failure. Everything else is tuning and should wait for a pipeline run
that actually shows the limit being hit; guessing cap values is how voodoo
constants get committed.

## Managed MCP settings — org distribution and the `allowedMcpServers` semantic change

**Added:** 2026-09-16
**Problem:** v2.1.259 added `managedMcpServers` (organizations push HTTP/SSE MCP
servers to their users through managed settings) and **changed what
`allowedMcpServers` governs** — it now applies only to user-added servers, with
`deniedMcpServers` as the filter for the rest. v2.1.268 extended
`managedMcpServers`; v2.1.273 added `allowManagedMcpServersOnly` and
`disableClaudeAiConnectors`.

We ship six MCP servers (ADO, Atlassian, Figma, axe, AEM, Playwright) into
consumer projects that are mostly enterprises with managed settings. Two
consequences we have not written down anywhere: an org that sets
`allowManagedMcpServersOnly` silently loses every plugin-provided server, and any
consumer relying on `allowedMcpServers` to permit our servers is relying on
pre-v2.1.259 behaviour. `grep -rn "managedMcpServers\|deniedMcpServers\|allowedMcpServers" .`
→ 0.
**Scope:** `docs/reference/` MCP setup docs and the website MCP page; the
per-plugin `.mcp.json` files are unchanged — this is a documentation and
consumer-guidance item, not a plugin change.
**Done-when:** the MCP setup docs state which of our six servers survive under
`allowManagedMcpServersOnly` and what an org admin must add to `managedMcpServers`
to keep them, i.e. `grep -rn "allowManagedMcpServersOnly" docs/ website/src`
returns the guidance.
**Approach:** Documentation only, and cheap. Verify the behaviour against a
managed-settings file before writing it down — the changelog states the fields but
not how a plugin-provided server is classified, and guessing that is exactly the
kind of claim this repo has been burned by before.

## `omitClaudeMd` on subagents

**Added:** 2026-09-16
**Problem:** v2.1.271 added `omitClaudeMd` to agent frontmatter and to the
`--agents` JSON for custom and plugin subagents: the subagent runs without
CLAUDE.md in its context. Our own research
([2026-05-05-orchestration-context-pollution.md](../research/2026-05-05-orchestration-context-pollution.md))
identified inherited coordinator context as a cost driver, and this is the
first-party lever for it. Zero uses: `grep -rn "omitClaudeMd" plugins/` → 0.

The obvious candidates are the narrow, single-purpose agents that never need
repository conventions: `dx-file-resolver`, `dx-doc-searcher`, `aem-page-finder`
(all Haiku/`low`). The obvious non-candidates are the reviewers — `dx-code-reviewer`
and `dx-pr-reviewer` exist to enforce conventions that live in CLAUDE.md, so
omitting it there would break them.
**Scope:** `plugins/dx-core/agents/*.md`, `plugins/dx-aem/agents/*.md` — frontmatter
only. Consumer-side effect: the omitted file is the *consumer project's*
CLAUDE.md, not this repo's.
**Done-when:** `grep -rn "omitClaudeMd" plugins/*/agents/` returns it on the three
lookup agents, and `docs/reference/agent-catalog.md` records which agents omit
CLAUDE.md and why.
**Approach:** Lookup agents only, and measure — this is exactly the kind of change
that reads as a free win and silently degrades an agent that turned out to need one
line of project context. Pair with #137's `/skill-doctor` baseline so the saving is a
number, not a claim. Claude Code only; the field has no meaning for Copilot CLI or
Cursor, which is fine (they ignore unknown frontmatter) but should be stated in the
catalog.

## MCP server load policy — `alwaysLoad` vs deferred tool search

**Added:** 2026-09-16
**Problem:** MCP servers can be marked `alwaysLoad` to skip tool-search deferral;
otherwise their tools are discovered through tool search on demand. v2.1.261 and
v2.1.269 both improved mid-conversation usability for `alwaysLoad` servers, and
v2.1.268 fixed tool search resolving full `mcp__server__tool` names. We declare six
servers across two plugins and have never made a deliberate choice: `alwaysLoad`
appears once in this repo, in a May research file, and in no `.mcp.json`.

This matters because of our own MCP-prefix rule in `CLAUDE.md`: subagents resolve
tools "by exact name or ToolSearch". Which of those two paths is live per server is
currently an accident of defaults.
**Scope:** `plugins/dx-core/.mcp.json`, `plugins/dx-aem/.mcp.json`;
`CLAUDE.md` § "Plugin MCP Tool Naming" and § "MCP Servers".
**Done-when:** each of the six servers is recorded as `alwaysLoad` or deferred with
a one-line reason, i.e. `grep -n "alwaysLoad" plugins/*/.mcp.json` matches the
documented decision — or `CLAUDE.md` states that all six stay deferred and why.
**Approach:** Default to deferred; `alwaysLoad` is a context cost paid every
session. The plausible exception is the AEM server in `dx-aem`, where nearly every
skill in the plugin calls it. Decide it with the #137 numbers, not from taste.

## Hook event list in CLAUDE.md is incomplete

**Added:** 2026-09-16
**Problem:** `CLAUDE.md` § "Hook Authoring — Key Fields" lists 29 events. The
current hooks reference documents several more, of which these are missing here:
`MessageDisplay` (fires while assistant text streams), `DirectoryAdded` (matcher
values `slash_command`, `register_repo_root`), and the two model-switch events
already tracked separately (#177). `MessageDisplay` appears in three research
files but never made it into the contributor guide.

Two handler-level facts are also absent and are the ones people get wrong: the
`PreToolUse` decision field accepts `showPrompt` alongside `allow`/`deny`, and can
return `updatedInput` to rewrite the call; `PermissionDenied` accepts `retry: true`.
**Scope:** `CLAUDE.md` § "Hook Authoring — Key Fields"; the hooks page on the docs
site (`website/src/pages/learn/hooks.mdx`); `AGENTS.md` if the event list is
mirrored there.
**Done-when:** `grep -c "MessageDisplay\|DirectoryAdded" CLAUDE.md` is non-zero and
the `updatedInput` / `showPrompt` / `retry` decision fields are documented next to
the exit-code table.
**Approach:** Documentation only. Fold into the #177 docs pass — same section, same
file, one edit.

## Declare `experimental.evals` in the plugin manifests

**Added:** 2026-09-16
**Problem:** The plugins reference lists `experimental.evals` as the manifest field
that points at eval case directories. We have `plugins/dx-core/evals/` and none of
the four manifests declares it. `claude plugin eval plugins/<plugin>` has worked for
us by path, so the field may be optional for path invocation and required only for
discovery through an installed plugin — that is unverified, and the difference
decides whether consumers can run our evals at all.
**Scope:** `plugins/*/.claude-plugin/plugin.json`; `CLAUDE.md` § "Behavioral evals".
**Done-when:** either `grep -n "evals" plugins/dx-core/.claude-plugin/plugin.json`
returns the declaration, or `CLAUDE.md` states that path invocation is the only
supported entry point and the field is deliberately unset.
**Approach:** Low priority, and a verify-then-decide item, not a fix. Note the
manifest hazard already documented in `CLAUDE.md`: adding `agents`/`skills` to a
manifest that uses default directories **breaks Claude Code**. `evals` sits under
`experimental`, so it is a different code path — but test it against a real
`claude plugin validate --json` run (#180) before committing it to all four
manifests.

---

## Third pass (v2.1.274–v2.1.277, intake 2026-09-19)

The two passes above stop at v2.1.273. Current is **v2.1.277**, which shipped
**AGENTS.md support** — the first time Claude Code reads an instruction file we
already generate for other platforms. Four surfaces below; each verified absent
from this repo by grep across `docs/`, `plugins/`, `cli/`, `scripts/` and
`CLAUDE.md` before writing the row.

## AGENTS.md is now a Claude Code instruction file — CLAUDE.md is a documented prerequisite

**Added:** 2026-09-19
**Problem:** Claude Code v2.1.277 reads `AGENTS.md` through the built-in
`agents-md@builtin` plugin ([`mods/agents-md`](https://github.com/anthropics/claude-code/tree/main/mods/agents-md)).
Its default mode, `claude-md-or-agents-md`, loads `AGENTS.md` **in any project
that has no `CLAUDE.md`**.

`cli/lib/scaffold.js` writes `AGENTS.md` unconditionally (`installAgentsMd()`,
line ~590) and writes **no `CLAUDE.md`** — `grep -n "CLAUDE.md" cli/lib/scaffold.js`
returns nothing, and `/dx-init` does not generate one either. So every project
scaffolded by us hits the default fallback, and the file that becomes Claude
Code's project instructions is an **agent inventory table** whose header reads
"Invoke with `@AgentName` in Copilot CLI, VS Code Chat, or as subagents in
Claude Code". That content was written as a discovery list for Copilot, not as
project instructions, and `@AgentName` is not how Claude Code invokes a subagent.

This repo itself is unaffected (it has a root `CLAUDE.md`, so the default mode
ignores our `AGENTS.md`) — the exposure is entirely in consumer projects.

Two further constraints: the plugin is **not available on Bedrock, Vertex or
Foundry**, which is where `dx-automation` pipeline runs may execute, so anything
that depends on the fallback is silently absent there; and nested `AGENTS.md`
files attach only on text `Read` calls and do not refresh after a mid-session
edit, unlike native `CLAUDE.md` handling.
**Decision (2026-09-19):** the plugins are **plugins** — they install into a project that is
already set up, so a `CLAUDE.md` is assumed to exist and Claude Code's own `/init` is what
creates one. We deliberately do **not** generate, append to, or modify a project `CLAUDE.md`:
that file describes the consumer's codebase, ours describe the workflow, and owning a file we
did not write means merging against the user's edits on every `/dx-upgrade`. Resolved as
**documentation**, not a scaffold change. The 19 shipped files that tell agents to read
`CLAUDE.md` are correct under this assumption and need no sweep.

Residual risk, accepted: a consumer who never ran `/init` gets the `@AgentName` table as their
project instructions. The install docs now state the prerequisite; nothing enforces it.
**Scope:** `README.md` § Install; `website/src/pages/setup/index.mdx` Step 1;
`website/src/pages/setup/claude-code.mdx` Prerequisites; `CLAUDE.md`
§ "Cross-Platform Agent Support" and § "Standalone CLI".
**Done-when:** `grep -rn "CLAUDE.md" README.md website/src/pages/setup/` states the
prerequisite and names `/init`. **Done 2026-09-19.**
**Follow-up (open):** `/dx-init` could warn — not write — when no `CLAUDE.md` is present, since
that is the one moment we know the project state. Decide separately; a warning is cheap, but
every added preflight check costs a step in an already long interview.
## `claude plugin test` — plugin test harness unused

**Added:** 2026-09-19
**Problem:** `mods/agents-md` ships a test suite run with `claude plugin test <dir>`,
which is how Anthropic tests a plugin's hooks. Our four plugins have no hook
tests at all: CI discovers `run-tests.sh`, `*.test.sh` and `*.test.js` under
`plugins/`, none of which exercises a hook end-to-end — `hooks.json` handlers are
verified only by `validate-structure.sh` reading the manifest, which is exactly
the "a structural check cannot tell you a script works" trap `CLAUDE.md` already
warns about. `grep -rn "plugin test" docs/ plugins/ scripts/ .github/` → 0.
**Scope:** `.github/workflows/validate.yml`; `plugins/*/hooks/`;
`CLAUDE.md` § "Testing Changes" (the four-level table).
**Done-when:** `claude plugin test plugins/dx-core` runs a real case, **or**
`CLAUDE.md` records why the command does not fit (e.g. it needs a billed agent
run like `claude plugin eval`, which is why evals are not wired to CI either).
**Approach:** Verify the cost model first — if it is a local harness and not a
billed agent run, it belongs in CI next to the discovered suites and closes the
biggest hole in the hook layer. If it bills, it goes with the evals: manual
dispatch or release tags only.

## `CLAUDE_CODE_MCP_STARTUP_WAIT_MS` for pipeline runs

**Added:** 2026-09-19
**Problem:** v2.1.274 added `CLAUDE_CODE_MCP_STARTUP_WAIT_MS`, bounding how long
the first non-interactive turn waits for MCP servers to come up. `dx-automation`
runs headless with up to six declared servers (ADO, Atlassian, Figma, axe, AEM,
Playwright); today an MCP server that is slow or wedged is paid for on the first
turn of every pipeline run with no ceiling. The same release fixed Streamable
HTTP tool calls timing out at ~5 minutes despite a longer per-server timeout,
and v2.1.277 fixed `claude -p` / SDK sessions hanging with no result after an
internal error — both failure modes our pipelines would see as a job timeout.
`grep -rn "CLAUDE_CODE_MCP_STARTUP_WAIT_MS" .` → 0.
**Scope:** the `dx-automation` pipeline launcher — same file touched by #119,
#178 and #200.
**Done-when:** `grep -rn "CLAUDE_CODE_MCP_STARTUP_WAIT_MS" plugins/dx-automation/`
returns the exported value, or #200 records a decision not to set it.
**Approach:** Fold into #200. That row already collects five headless runtime
flags for one launcher change — this is the sixth, not a separate pass.

## `/plugin install --marketplace` and claude.ai plugin sync in the install docs

**Added:** 2026-09-19
**Problem:** v2.1.275 added `claude plugin install <plugin> --marketplace <source>`,
which offers to add the marketplace if it is missing — the single-command install
our setup docs have wanted since #16 (the marketplace-qualifier bug, closed
upstream 2026-05-20). The same release added syncing of skills and plugins
enabled on a claude.ai account into terminal sessions, which changes what a
consumer sees as "installed" and is not mentioned anywhere in our setup pages.
`grep -rn -- "--marketplace" docs/ website/ plugins/` → 0.
**Scope:** `README.md` and `CLAUDE.md` § "Testing Changes" (the two-step
`marketplace add` + `install` dance); the setup pages on the docs site.
**Done-when:** the install instructions show the one-command form and
`grep -rn -- "--marketplace" README.md website/src/pages/setup/` is non-zero.
**Approach:** Docs only, and the smallest row in this pass. Confirm the flag's
exact behaviour on a local marketplace path (not just a GitHub source) before
replacing the documented two-step — our own testing loop uses a local path.

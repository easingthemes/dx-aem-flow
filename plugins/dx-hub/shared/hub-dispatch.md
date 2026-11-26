# Hub Dispatch Protocol

Reference document for how hub mode dispatches work to repos via VS Code terminals.

## When This Applies

Hub mode lets a single `.hub/` directory act as an orchestration point for multi-repo workflows. The hub opens independent interactive Claude Code sessions in VS Code terminals — one per repo. Each session has its own CWD, full plugin access, and MCP tools.

This document defines hub detection, repo resolution, the dispatch mechanism, and state tracking. It is the local alternative to pipeline delegation (see `repo-discovery.md`).

## Decision Tree (Per Skill)

Before executing any cross-repo work item, evaluate in order:

```
Is DX_PIPELINE_MODE=true?
  → yes: delegate via ADO pipeline (see repo-discovery.md — stop here)

Is hub.enabled=true AND cwd ends with .hub/?
  → yes: use /dx-hub-dispatch to launch VS Code terminal sessions (this document)

Is cross-repo scope detected?
  → yes: print "switch to {repo.name} at {repo.path}" (manual handoff)

Otherwise:
  → execute locally (standard behavior)
```

The hub check comes after pipeline mode and before manual handoff. A hub workspace replaces the manual switching step — it does not replace pipeline automation.

## Hub Detection

Two conditions must BOTH be true for hub mode to be active:

```bash
HUB_ENABLED=$(grep -A1 '^hub:' .ai/config.yaml | grep 'enabled:' | grep -o 'true' || echo "false")
IS_HUB_DIR=$(basename "$(pwd)" | grep -q '\.hub$' && echo "true" || echo "false")
```

Hub mode is active when `HUB_ENABLED=true` AND `IS_HUB_DIR=true`.

The directory check prevents skills from accidentally dispatching when run inside a child repo (even if its own config has hub settings). Only the `.hub/` directory itself triggers hub dispatch.

## 1. Repo Resolution

### Config Source

Target repos are listed under `repos:` in `.ai/config.yaml`:

```yaml
hub:
  enabled: true
  engine: claude        # claude | copilot
  terminal-delay: 5
  launcher: auto        # auto | vscode-automator | terminal | none
  state-ttl: 7d

tracker:
  provider: ado

repos:
  - name: Repo-A
    path: ../repo-a
    ado-project: my-project
    capabilities: [fe]
  - name: Repo-B
    path: ../repo-b
    ado-project: my-other-project
    capabilities: [be]
  - name: site-brand-a
    path: /absolute/path/to/site-brand-a
    ado-project: my-project
    capabilities: []
    keywords: [brand-a-shop]
```

### Matching Logic

Match repos by explicit user arguments or by detecting scope from ticket content:

1. **Explicit** — user names repos in the dispatch command → use those
2. **Name and keyword match** — `skills/dx-hub-dispatch/scripts/match-repos.sh` over the ticket's title, area path and tags: a repo's full name, one of its `keywords`, or a distinctive token of its name (`brand-a` in `site-brand-a`; tokens shared by several repo names and generic words never count) as a whole word
3. **Capabilities match** — use the role-to-capabilities table below; repos without `capabilities` are skipped here

### Role-to-Capabilities Mapping

| Role | Capabilities |
|------|-------------|
| `backend` | `[be]` |
| `frontend` | `[fe]` |
| `fullstack` | `[fe, be]` |

A repo matches a role if its `capabilities` list contains at least one matching capability. A `fullstack` role matches any repo that has `fe` OR `be`.

### No Match Warning

If no repo entry matches, print a warning and ask the user — do not abort:

```
⚠ No repo entry found for "Unknown-Repo". Add it to repos: in .ai/config.yaml.
```

### Path Resolution

Paths in `repos[].path` may be absolute or relative:

- **Absolute paths** — used as-is
- **Relative paths** — resolved against the hub directory (cwd)

Example: if cwd is `/projects/project-x/.hub` and path is `../repo-a`, the resolved path is `/projects/project-x/repo-a`.

## 2. Dispatch Mechanism — VS Code Terminals

`hub.launcher` decides how the per-repo sessions start:

| `hub.launcher` | Behaviour |
|----------------|-----------|
| `auto` (default) | VS Code terminals via the `vscode-automator` MCP server (registered in the hub's `.mcp.json` by `/dx-hub-init`) when its tools are in the session; otherwise **print** |
| `vscode-automator` | Same as `auto` — and the same fallback; it never fails a dispatch |
| `terminal` | macOS Terminal.app windows via `osascript`, one per repo — works from any host, including Copilot CLI |
| `none` | **print**: nothing is started (same as `--no-launch`) |

**print** writes `state/<ticket-id>/launch/<repo>.sh` per repo (cd + the CLI command, built by `build-launch.sh`), records it in `status.json` `launch`, and shows `bash '<script>'` lines to paste into any terminal. A missing launcher never makes the agent improvise with other tools.

Each session is independent, with full plugin and MCP access. The user can see all sessions live and intervene at any time.

### Terminal Launch Sequence

For each target repo:

1. **Open terminal:** `vscode_new_terminal` → wait 1s
2. **Set directory:** `vscode_type` "cd <abs-path>" → `vscode_keystroke` Enter → wait 1s
3. **Start Claude:** `vscode_type` "claude" → `vscode_keystroke` Enter → wait `terminal-delay` seconds
4. **Type prompt:** `vscode_type` "<delegation prompt>" → `vscode_keystroke` Enter

With `hub.engine: copilot`, steps 3–4 are one command — `copilot --session-id <uuid> -i "<delegation prompt>"` — with a lowercase uuid per repo (recorded in `status.json` `sessions`) and the skill written plugin-prefixed (`/dx-core:dx-agent-all`), since Copilot CLI does not know plugin skills by their bare name. `hub.model`, when set, is passed as `--model` to either CLI.
5. **Pause:** wait 2s before next terminal (avoid focus conflicts)

### Tool names by host

Skill files call MCP tools by their Claude Code name, `mcp__<server>__<tool>`. Copilot CLI registers the same tool as `<server>-<tool>` (`mcp__ado__wit_work_item` → `ado-wit_work_item`). The arguments are the same; the agent calls whichever form its host lists.

### ADO project

The repos of one hub often live in different ADO projects, and the ADO MCP server prompts for a project when none is passed — which an agent session cannot answer. Dispatch therefore always passes one: it tries the project from a ticket URL, then each candidate `repos[].ado-project` (and `scm.project`), and once the item is found uses its `System.TeamProject` for every further call. The project is written to `context.md`, `status.json` and the delegation prompt.

### Delegation Prompt

The prompt typed into each repo's Claude session:

```
Ticket <id> (ADO project <project>) raw content is pre-seeded at .ai/specs/<dir-name>/<raw-file>.
Cross-repo context at <hub-abs-path>/state/<ticket-id>/context.md — read it before starting.
You handle the <repo-name> portion (<role>).
Also involved: <other-repos-and-roles>.
When done or blocked, update status in <hub-abs-path>/state/<ticket-id>/status.json — set repos.<repo-name> to done, blocked, or failed.
Now run: <skill> <ticket-id>
```

The prompt is a single message — no multi-turn setup. It gives each repo:
- Where to find the pre-seeded raw ticket (skips ADO fetch)
- Cross-repo context (what other repos are doing)
- Where to write status updates
- What skill to execute

### Pre-Seeding Raw Tickets

Before launching terminals, the hub copies the raw ticket file into each repo's spec directory:

```bash
mkdir -p "<repo-path>/.ai/specs/<id>-<slug>/"
cp "state/<ticket-id>/<raw-story.md|raw-bug.md>" "<repo-path>/.ai/specs/<id>-<slug>/"
```

This lets `dx-req` and `dx-bug-triage` skip the ADO/Jira fetch — they check for existing raw files before calling MCP.

## 3. State Tracking (V1 — Minimal)

State is intentionally minimal in V1. The user can see all terminals live — complex progress tracking adds overhead without value.

### status.json

Written by hub at dispatch start, updated by each repo session:

```
state/<ticket-id>/status.json
```

```json
{
  "ticket": "12345",
  "title": "Add user profile page",
  "type": "User Story",
  "project": "my-project",
  "skill": "/dx-agent-all",
  "engine": "copilot",
  "launcher": "vscode-automator",
  "started": "2026-01-15T10:30:00Z",
  "repos": {
    "repo-fe": "running",
    "repo-be": "running"
  },
  "sessions": {
    "repo-fe": "3f2b9c1e-0000-4000-8000-000000000001",
    "repo-be": "3f2b9c1e-0000-4000-8000-000000000002"
  }
}
```

Status values: `pending` | `running` | `done` | `blocked` | `failed` (`pending` = written but not started yet)

`engine`, `sessions`, `project`, `launcher` and `launch` are optional for readers — older dispatches lack them. `sessions` (repo → `--session-id`) is written for the `copilot` engine and whenever `launch` is; `launch` (repo → `{cwd, command, script}`) for the `terminal` and print launchers. `/dx-hub-status --json` prints all status files as one JSON array.

Hub writes the initial file. Each repo's Claude session updates its own entry when finished or blocked. The delegation prompt includes the instruction to do this.

### context.md

Written by hub before launching terminals:

```
state/<ticket-id>/context.md
```

Contains: ticket summary, which repos are involved, their roles, and brief notes on what each handles. Read by each repo's Claude session before starting work.

### Raw ticket file

```
state/<ticket-id>/raw-story.md    (or raw-bug.md)
```

The master copy. Copied into each repo's spec directory during pre-seeding.

### Cleanup

Entries older than `hub.state-ttl` (default: `7d`) may be removed by `/dx-hub-status --clean`. Running dispatches are never cleaned.

## 4. Hub Does NOT

- **Plan** — each repo runs its own `/dx-req` + `/dx-plan`
- **Implement** — each repo runs its own `/dx-step`
- **Review code** — each repo handles its own PR
- **Interpret requirements** — it only routes the raw ticket
- **Collect results** — it reads status.json, not structured output

The hub is a thin coordinator. It fetches, routes, and launches — nothing more.

## Config Reference

All hub settings live under `hub:` in `.ai/config.yaml`:

| Key | Default | Description |
|-----|---------|-------------|
| `hub.enabled` | `false` | Enable hub mode for this workspace |
| `hub.engine` | `claude` | CLI started in each repo terminal: `claude` or `copilot` |
| `hub.model` | *(unset)* | Model passed as `--model` to that CLI; unset = the CLI's default |
| `hub.terminal-delay` | `5` | Seconds to wait for Claude to start in terminal (`claude` engine) |
| `hub.launcher` | `auto` | How sessions start: `auto`, `vscode-automator`, `terminal`, `none` (table above) |
| `hub.state-ttl` | `7d` | How long to keep completed state entries |

The `repos:` list is a top-level key (not nested under `hub:`):

| Key | Required | Description |
|-----|----------|-------------|
| `repos[].name` | yes | Display name, used for state file names and terminal identification |
| `repos[].path` | yes | Absolute or relative path to repo root |
| `repos[].capabilities` | no | List of capability tags: `fe`, `be`. `[]` = neither (matched by name/keywords only) |
| `repos[].keywords` | no | Words that point a ticket at this repo (title, area path, tags) when the repo name does not contain them |
| `repos[].ado-project` | for ADO | The repo's ADO project — a candidate when fetching the ticket |

`tracker.provider` (default `ado`) and, for ADO, `scm.org` sit at the top level as in any dx config. `/dx-hub-dispatch` prints a `default:` line for every key above that is missing, and `/dx-hub-config fill-defaults` writes them.

---
name: dx-hub-dispatch
description: "Dispatch a ticket to several repos — open an independent Claude Code or Copilot CLI session per repo in VS Code terminals. Use for 'hub dispatch', 'work on ticket across repos'."
argument-hint: "<ADO Work Item ID, Jira key, or URL> [repo-a repo-b ...] [--skill /dx-agent-all] [autonomous] [--no-launch]"
allowed-tools: ["Read", "Edit", "Glob", "Grep", "Write", "Bash", "mcp__vscode-automator__*", "mcp__ado__*", "mcp__atlassian__*"]
---

You dispatch a ticket to one or more repos by opening independent CLI sessions — Claude Code (default) or Copilot CLI, per `hub.engine` — in VS Code terminals. The hub does NOT plan or implement — it fetches the ticket, determines which repos are involved, and launches real Claude sessions in each repo with a delegation prompt.

## Pre-flight

Read `.ai/config.yaml`. If `hub.enabled` is not `true`, STOP:

> Hub mode is not enabled. Run `/dx-hub-init` first.

Read:
- `hub.terminal-delay` — seconds to wait for Claude to start in terminal (default: `5`; Claude engine only)
- `hub.engine` — CLI started in each repo terminal: `claude` (default) or `copilot`
- `hub.model` — optional model passed as `--model <value>` to that CLI (empty: the CLI's own default)
- `repos[]` — list of repos with `name`, `path`, `capabilities`

Read `shared/provider-config.md` for provider detection and tool mapping.

Read `.ai/config.yaml`:
- `tracker.provider` (or `scm.provider` for backward compat) — `ado` (default) or `jira`

**If provider = ado:**
- `scm.org`, `scm.project`

**If provider = jira:**
- `jira.url`, `jira.project-key`

## Flow

```dot
digraph hub_dispatch {
    "Parse arguments" [shape=box];
    "Fetch ticket" [shape=box];
    "Determine repos" [shape=box];
    "Repos resolved?" [shape=diamond];
    "STOP: no repos" [shape=doublecircle];
    "Confirm dispatch" [shape=diamond];
    "STOP: cancelled" [shape=doublecircle];
    "Create state dir" [shape=box];
    "Save raw ticket" [shape=box];
    "Write context.md" [shape=box];
    "Pre-seed repos" [shape=box];
    "Launch mode?" [shape=diamond];
    "Launch terminals" [shape=box];
    "Write launch commands" [shape=box];
    "Write status.json" [shape=box];
    "Summary" [shape=doublecircle];

    "Parse arguments" -> "Fetch ticket";
    "Fetch ticket" -> "Determine repos";
    "Determine repos" -> "Repos resolved?";
    "Repos resolved?" -> "Confirm dispatch" [label="yes"];
    "Repos resolved?" -> "STOP: no repos" [label="no"];
    "Confirm dispatch" -> "Create state dir" [label="yes"];
    "Confirm dispatch" -> "STOP: cancelled" [label="no"];
    "Create state dir" -> "Save raw ticket";
    "Save raw ticket" -> "Write context.md";
    "Write context.md" -> "Pre-seed repos";
    "Pre-seed repos" -> "Launch mode?";
    "Launch mode?" -> "Launch terminals" [label="default"];
    "Launch mode?" -> "Write launch commands" [label="--no-launch"];
    "Launch terminals" -> "Write status.json";
    "Write launch commands" -> "Write status.json";
    "Write status.json" -> "Summary";
}
```

## Node Details

### Parse arguments

Parse `$ARGUMENTS`:

1. **Ticket ID** (required) — first positional arg. Numeric ADO ID, Jira key (`PROJ-123`), or full URL. Extract ID from URLs.
2. **Repo names** (optional) — additional positional args matching `repos[].name` from config. If provided, skip auto-detection and use these.
3. **`--skill`** (optional) — skill to run in each repo. Default: `/dx-agent-all`.
4. **`autonomous`** (optional) — appended to the skill call in every repo (`<skill> <id> autonomous`), so each repo session runs without stops. Also makes this dispatch itself skip **Confirm dispatch**.
5. **`--no-launch`** (optional) — do everything up to the terminals, but open none: write each repo's exact command line into `status.json` for the tool that called this skill (a dashboard, a script) to start itself. No `vscode-automator` calls.

Examples:
```
/dx-hub-dispatch 2471234
/dx-hub-dispatch 2471234 repo-fe repo-be
/dx-hub-dispatch 2471234 --skill /dx-req
/dx-hub-dispatch PROJ-123 repo-fe --skill /dx-agent-all
/dx-hub-dispatch 2471234 repo-fe repo-be autonomous
/dx-hub-dispatch 2471234 repo-fe repo-be autonomous --no-launch
```

### Fetch ticket

Fetch the work item using the configured provider.

**ADO:**
```
mcp__ado__wit_work_item
  action: "get"
  project: "<scm.project>"
  id: <work item ID>
  expand: "Relations"
```

**Jira:**
```
mcp__atlassian__jira_get_issue
  issue_key: "<issue key>"
```

Extract and hold in memory:
- **ID** — work item ID or Jira key
- **Title** — work item title
- **Type** — User Story, Bug, Task, etc.
- **Description** — full description text
- **Acceptance Criteria** — if present
- **State** — current state
- **Relations** — linked items

Also fetch comments:

**ADO:**
```
mcp__ado__wit_work_item
  action: "list_comments"
  project: "<scm.project>"
  workItemId: <id>
```

### Determine repos

If repo names were provided as arguments, use those directly — look them up in `repos[]` by name.

If no repos specified, determine from ticket content:

1. **Check ticket title and description** for explicit repo/layer mentions:
   - Keywords like "frontend", "FE", "UI", "React", "Angular" → match repos with `capabilities: [fe]`
   - Keywords like "backend", "BE", "API", "service", "endpoint" → match repos with `capabilities: [be]`
   - Keywords like "full stack", "both", "end-to-end" → match both `fe` and `be` repos
   - Keywords matching a repo name directly → match that repo

2. **Check linked work items** — if the ticket has child tasks with repo-specific titles, use those as hints.

3. **If still ambiguous** — ask the user which repos to dispatch to, showing the full repo list from config.

### Repos resolved?

- **yes** — at least one repo matched → proceed to "Confirm dispatch"
- **no** — no repos could be determined → go to "STOP: no repos"

### STOP: no repos

Print:
```
Could not determine which repos are involved in ticket <id>.

Available repos:
  - <name> (capabilities: <caps>) — <path>
  ...

Re-run with explicit repos: /dx-hub-dispatch <id> <repo-name> [<repo-name> ...]
```
STOP.

### Confirm dispatch

Print the dispatch plan:
```
Hub Dispatch Plan
─────────────────────────────
Ticket:  <id> — <title>
Type:    <type>
Skill:   <skill>
Repos:   <repo-a> (<caps>), <repo-b> (<caps>)

This will open <N> VS Code terminals, each running an independent <Claude Code | Copilot CLI> session.
Proceed? [Y/n]
```

**Non-interactive** (`autonomous` argument, or nobody can answer — dx-core `shared/interaction-mode.md`): print the plan and proceed without asking.

- **yes** (or Enter) → proceed
- **no** → go to "STOP: cancelled"

### STOP: cancelled

Print: `Dispatch cancelled.` STOP.

### Create state dir

```bash
HUB_ROOT="$(pwd)"
STATE_DIR="state/<ticket-id>"
mkdir -p "$STATE_DIR"
```

### Save raw ticket

Determine the correct filename based on ticket type:
- **Bug** type → `raw-bug.md`
- **All other types** (User Story, Task, etc.) → `raw-story.md`

Write the raw ticket content to `$STATE_DIR/<filename>` using the same faithful-dump format as `dx-req` (for stories) or `dx-bug-triage` (for bugs). Do NOT editorialize — this is a faithful copy of the ADO/Jira content.

For detailed format, follow the same structure as `dx-req` step 10 or `dx-bug-triage` step 9.

### Write context.md

Write `$STATE_DIR/context.md`:

```markdown
# Cross-Repo Context

**Ticket:** <id> — <title>
**Type:** <type>
**Dispatched:** <ISO timestamp>

## Involved Repos

| Repo | Role | Path |
|------|------|------|
| <repo-a> | <capabilities as role: fe→Frontend, be→Backend> | <absolute path> |
| <repo-b> | <role> | <absolute path> |

## Coordination Notes

- Each repo runs its own requirements analysis and implementation planning.
- This ticket involves multiple repos — coordinate shared interfaces (API contracts, shared types, event schemas) carefully.
- If you need to know what another repo is doing, check its spec directory: `<other-repo-path>/.ai/specs/<ticket-slug>/`

## What Each Repo Handles

<For each repo, write 1-2 sentences about what that repo's focus should be based on the ticket content and the repo's capabilities. Keep it brief — the repo's own dx-req will do the deep analysis.>
```

### Pre-seed repos

For each target repo:

1. Generate the spec directory name using the same slugify logic:
   ```bash
   DIR_NAME=$(<id>-<slugified-title>)
   REPO_SPEC_DIR="<repo-abs-path>/.ai/specs/${DIR_NAME}"
   ```

2. Create the directory:
   ```bash
   mkdir -p "$REPO_SPEC_DIR"
   ```

3. Copy the raw ticket file:
   ```bash
   cp "$STATE_DIR/<raw-story.md|raw-bug.md>" "$REPO_SPEC_DIR/"
   ```

This pre-seeds each repo so `dx-req` / `dx-bug-triage` will find `raw-story.md` / `raw-bug.md` already present and skip the ADO/Jira fetch.

### Launch mode?

`--no-launch` given → **Write launch commands**. Otherwise → **Launch terminals**.

### Launch terminals

For each target repo, open a VS Code terminal and start a Claude session:

**Step 1 — Open new terminal:**
```
mcp__vscode-automator__vscode_new_terminal
```

Wait 1 second for terminal to initialize.

**Step 2 — cd into the repo:**
```
mcp__vscode-automator__vscode_type
  text: "cd <repo-absolute-path>"
```
```
mcp__vscode-automator__vscode_keystroke
  key: "return"
```

Wait 1 second.

**Step 3 — Start the CLI.** Branch on `hub.engine`:

**`claude` (default):**
```
mcp__vscode-automator__vscode_type
  text: "claude"
```
```
mcp__vscode-automator__vscode_keystroke
  key: "return"
```

(With `hub.model` set: `claude --model <hub.model>`.) Wait `hub.terminal-delay` seconds (default: 5) for Claude to start, then go to Step 4.

**`copilot`:** the prompt goes on the command line, so Step 3 and Step 4 are one command. Give each repo its own **lowercase** session id — Copilot CLI uses it as the session folder name (`~/.copilot/session-state/<uuid>/`), which lets a tool read that terminal's usage — and keep it for **Write status.json**. The same id goes into `DX_RUN_ID`, so the repo's run result (`.ai/run-results/`, `run_id`) points back to this terminal:

```bash
uuidgen | tr 'A-Z' 'a-z'
```

```
mcp__vscode-automator__vscode_type
  text: "DX_RUN_ID=<uuid> copilot --session-id <uuid> [--model <hub.model>] -i \"<delegation prompt>\""
```
```
mcp__vscode-automator__vscode_keystroke
  key: "return"
```

Copilot CLI only knows plugin skills by their **plugin-prefixed** name, so in the delegation prompt write the skill as `/dx-core:<name>` (`/dx-agent-all` → `/dx-core:dx-agent-all`; a skill already carrying a `plugin:` prefix stays as is). Skip the rest of this node's Step 4 and wait 2 seconds before the next repo.

**Step 4 — Type the delegation prompt (`claude` engine):**

Build the prompt (no line breaks — single continuous text; no `"`, `$` or backticks, since the Copilot path puts it inside a shell double-quoted string):

```
Ticket <id> raw content is pre-seeded at .ai/specs/<dir-name>/<raw-file>. Cross-repo context at <hub-abs-path>/state/<ticket-id>/context.md — read it before starting. You handle the <repo-name> portion (<role>). Also involved: <other-repos-and-roles>. When done or blocked, update status in <hub-abs-path>/state/<ticket-id>/status.json — set repos.<repo-name> to done, blocked, or failed. Now run: <skill> <ticket-id>[ autonomous]
```

```
mcp__vscode-automator__vscode_type
  text: "<delegation prompt>"
```
```
mcp__vscode-automator__vscode_keystroke
  key: "return"
```

Wait 2 seconds before opening the next terminal (to avoid focus conflicts).

### Write launch commands

Open no terminal. For each target repo make a lowercase session id (`uuidgen | tr 'A-Z' 'a-z'`) and build the delegation prompt exactly as in **Launch terminals** Step 4 (same rules: one line, no `"`, `$` or backticks; Copilot gets the `/dx-core:` skill prefix). The command line, per `hub.engine`:

- `copilot`: `DX_RUN_ID=<uuid> copilot --session-id <uuid> [--model <hub.model>] -i "<delegation prompt>"`
- `claude`: `DX_RUN_ID=<uuid> claude --session-id <uuid> [--model <hub.model>] "<delegation prompt>"`

Keep `cwd` (the repo's absolute path), `command` and the session id per repo for **Write status.json**. Status of each repo is `pending` (not `running`) until the caller starts it — the repo session sets `done` / `blocked` / `failed` as usual.

### Write status.json

Write `$STATE_DIR/status.json`:

```json
{
  "ticket": "<ticket-id>",
  "title": "<title>",
  "type": "<type>",
  "skill": "<skill>",
  "engine": "<claude | copilot>",
  "started": "<ISO timestamp>",
  "repos": {
    "<repo-a>": "running",
    "<repo-b>": "running"
  },
  "sessions": {
    "<repo-a>": "<uuid>",
    "<repo-b>": "<uuid>"
  },
  "launch": {
    "<repo-a>": { "cwd": "<repo-a absolute path>", "command": "<command line>" },
    "<repo-b>": { "cwd": "<repo-b absolute path>", "command": "<command line>" }
  }
}
```

`sessions` is written for the `copilot` engine and for any `--no-launch` dispatch (the `--session-id` given, or to be given, to each repo session). `launch` is written only with `--no-launch`: run `command` in `cwd`, one terminal per repo. `repos.<name>` stays a plain status string — the repo sessions update it, and `/dx-hub-status` reads it.

### Summary

Print:

```
Hub Dispatch Started
────────────────────────────────
Ticket:    <id> — <title>
Skill:     <skill>
Terminals: <N> sessions launched   (with --no-launch: "<N> commands written, none started")

  <repo-a> (<role>) — running   [<session id, copilot engine>]
  <repo-b> (<role>) — running   [<session id, copilot engine>]

State: state/<ticket-id>/

Next:
  /dx-hub-status <ticket-id>    — check progress
  Switch to terminal tabs to monitor each session directly
```

With `--no-launch`, list each repo's `cwd` and `command` instead of "running", and say the caller starts them.

## Examples

### Dispatch a story to auto-detected repos
```
/dx-hub-dispatch 2471234
```
Fetches ticket, detects FE/BE scope from content, opens 2 terminals.

### Dispatch to specific repos
```
/dx-hub-dispatch 2471234 repo-fe repo-be
```
Skips auto-detection, dispatches to named repos.

### Dispatch with a different skill
```
/dx-hub-dispatch 2471234 --skill /dx-req
```
Only runs requirements phase, not full pipeline.

### Dispatch a Jira ticket
```
/dx-hub-dispatch PROJ-123 repo-fe
```

## Troubleshooting

### VS Code terminals not opening
**Cause:** vscode-automator MCP server not running or macOS Accessibility permission not granted.
**Fix:** Check that vscode-automator is registered in `.mcp.json` and that your terminal app has Accessibility permission in System Preferences → Privacy & Security → Accessibility.

### Claude not starting in terminal
**Cause:** `hub.terminal-delay` too short — Claude CLI takes time to initialize.
**Fix:** Increase `hub.terminal-delay` in `.ai/config.yaml` (try `8` or `10`).

### Copilot CLI: "Unknown command" in a repo terminal
**Cause:** the skill was typed without its plugin prefix.
**Fix:** use `/dx-core:<skill>` in the delegation prompt (see Launch terminals). Run `copilot` in that repo and check the plugin is enabled if the prefixed name also fails.

### Wrong repo detected
**Cause:** Ticket content didn't contain clear FE/BE keywords.
**Fix:** Re-run with explicit repo names: `/dx-hub-dispatch <id> <repo-name>`.

### Raw ticket not found in repo
**Cause:** Pre-seed step failed (directory permissions or path mismatch).
**Fix:** Check that repo paths in config are correct. The raw file should be at `<repo>/.ai/specs/<id>-<slug>/raw-story.md`.

## Rules

- **Hub never plans or implements** — it only fetches, routes, and launches
- **No hardcoded values** — all org names, project names, paths from config
- **Pre-seed raw files** — copy to each repo so skills skip redundant ADO fetches
- **One terminal per repo** — each gets its own independent Claude Code or Copilot CLI session (`hub.engine`); with `copilot`, each repo has its own lowercase `--session-id`, recorded in `status.json` `sessions`
- **vscode-automator is macOS only** — this skill requires macOS with Accessibility permission

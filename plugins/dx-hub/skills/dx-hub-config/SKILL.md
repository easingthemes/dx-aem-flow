---
name: dx-hub-config
description: View and edit hub configuration — add repos, fill missing defaults, adjust terminal delay. Use to manage hub settings. Trigger on "hub config", "add repo to hub", "terminal delay".
when_to_use: "Use to view and edit hub configuration — add repos, adjust terminal delay. Trigger on 'hub config', 'add repo to hub', 'terminal delay', 'configure hub', or 'edit hub settings'."
argument-hint: "[show | add-repo <path> | fill-defaults | terminal-delay <seconds>]"
disable-model-invocation: true
allowed-tools: ["Read", "Edit", "Glob", "Grep", "Write", "Bash"]
---

You view and edit the hub configuration in `.ai/config.yaml`.

## Pre-flight

Read `.ai/config.yaml`. If a `hub:` section is absent, STOP:

> Hub mode is not configured. Run `/dx-hub-init` first.

## 1. Parse Subcommand

Inspect `$ARGUMENTS` and route to the matching section:

| Subcommand | Action |
|---|---|
| *(none)* or `show` | Display current hub config |
| `add-repo <path>` | Discover and add a repo |
| `fill-defaults` | Add every missing key `/dx-hub-dispatch` reads, keep existing values |
| `terminal-delay <seconds>` | Set seconds to wait for Claude to start in terminal |

## 2. show

Print hub settings in readable format:

```
Hub Configuration
─────────────────────────────────
Enabled:         <hub.enabled>
Engine:          <hub.engine>
Model:           <hub.model or "CLI default">
Launcher:        <hub.launcher>
Terminal delay:  <hub.terminal-delay>s
State TTL:       <hub.state-ttl>
Tracker:         <tracker.provider>

Repos (<count>):
  - <name>  <path>  [capabilities: <caps>]  [keywords: <kws>]  [base: <base-branch>]  [project: <ado-project>]
  ...
```

Under it, print the `default:` and `warn:` lines of `bash "${CLAUDE_SKILL_DIR}/../dx-hub-dispatch/scripts/hub-config.sh" .ai/config.yaml` (stderr), if any — they are what dispatch will complain about. On a host that does not substitute `${CLAUDE_SKILL_DIR}`, the script is at `../dx-hub-dispatch/scripts/hub-config.sh` relative to this skill's folder.

## 3. add-repo <path>

1. Resolve the path (expand `~`, make absolute).
2. Check that `<path>/.ai/config.yaml` exists. If not, STOP: "No `.ai/config.yaml` found at `<path>`. Is this a dx-enabled project?"
3. Read `<path>/.ai/config.yaml` and extract:
   - `name` (or derive from directory name)
   - `scm.base-branch` (default `main` if absent)
   - `scm.project` (ask if absent — dispatch needs a project per repo for ADO)
4. Check for a duplicate: if `repos` already contains an entry with the same `name`, STOP: "Repo `<name>` is already in the hub. Use `show` to review current repos."
5. Append to the top-level `repos:` list in `.ai/config.yaml`:
   ```yaml
   - name: <name>
     path: <resolved-path>
     base-branch: <base-branch>
     ado-project: <scm.project>
     capabilities: [<fe|be — ask; [] if neither>]
     keywords: [<words that identify this repo in ticket titles — ask, optional>]
   ```
6. Print confirmation:
   > Added `<name>` (`<resolved-path>`) to hub. Total repos: <new count>.

## 4. fill-defaults

For a hub created by an older `/dx-hub-init`. Add each missing key with its default and leave every existing value as it is:

| Key | Default |
|-----|---------|
| `hub.engine` | `claude` |
| `hub.terminal-delay` | `5` |
| `hub.launcher` | `auto` |
| `tracker.provider` | `ado` (or the `scm.provider` value, if set) |
| `scm.org` | from the first repo's `.ai/config.yaml`, if it has one |

`hub.model` stays unset unless the user gives one. A legacy `project:` key on a repo entry is renamed to `ado-project:`.

For each repo that has no `capabilities` key: read `<repo-path>/.ai/config.yaml` and ask the user, showing what you found (`project.role`, AEM component paths, frontend tooling), whether it is `fe`, `be`, both or neither. Write `capabilities: []` for neither. Then ask for optional `keywords` — words in ticket titles that point at this repo but are not part of its name. A repo without `ado-project` under an ADO tracker: ask for it.

Show the diff of `.ai/config.yaml` before writing and write only on the user's yes. Then print the `hub-config.sh` stderr again — it should be empty.

## 5. terminal-delay <seconds>

1. Validate `<seconds>` is a positive integer between 1 and 30. If not, STOP: "Invalid delay `<seconds>`. Use a number between 1 and 30."
2. Update `hub.terminal-delay` in `.ai/config.yaml`.
3. Print: > Terminal delay set to `<seconds>`s.

## Examples

```
/dx-hub-config
/dx-hub-config show
```
Prints current hub settings and all registered repos.

```
/dx-hub-config add-repo ../my-other-repo
```
Reads `../my-other-repo/.ai/config.yaml`, extracts metadata, and adds the repo to the hub.

```
/dx-hub-config fill-defaults
```
Adds `hub.engine`, `hub.launcher`, `hub.terminal-delay`, `tracker.provider` and per-repo `capabilities` / `keywords` where they are missing.

```
/dx-hub-config terminal-delay 8
```
Updates the terminal startup delay and confirms the change.

## Troubleshooting

### "Hub mode is not configured"
**Cause:** `.ai/config.yaml` has no `hub:` section.
**Fix:** Run `/dx-hub-init` to initialise hub mode first.

### "No `.ai/config.yaml` found at `<path>`"
**Cause:** The target directory is not a dx-enabled project, or the path is wrong.
**Fix:** Run `/dx-init` in the target repo, then retry.

### "Repo `<name>` is already in the hub"
**Cause:** A repo with that name is already registered.
**Fix:** Run `/dx-hub-config show` to review existing entries.

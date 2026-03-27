---
name: dx-hub-config
description: View and edit hub configuration — add repos, change dispatch mode, toggle auto-dispatch. Use to manage hub settings. Trigger on "hub config", "add repo to hub", "change dispatch mode".
argument-hint: "[show | add-repo <path> | dispatch-mode <sequential|parallel> | auto-dispatch <true|false>]"
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
| `dispatch-mode <sequential\|parallel>` | Change dispatch mode |
| `auto-dispatch <true\|false>` | Toggle auto-dispatch flag |

## 2. show

Print hub settings in readable format:

```
Hub Configuration
─────────────────────────────────
Enabled:        <hub.enabled>
Auto-dispatch:  <hub.auto-dispatch>
Dispatch mode:  <hub.dispatch-mode>
State TTL:      <hub.state-ttl>
State dir:      <hub.state-dir>

Repos (<count>):
  - <name>  <path>  [base: <base-branch>]  [project: <project>]
  ...
```

## 3. add-repo <path>

1. Resolve the path (expand `~`, make absolute).
2. Check that `<path>/.ai/config.yaml` exists. If not, STOP: "No `.ai/config.yaml` found at `<path>`. Is this a dx-enabled project?"
3. Read `<path>/.ai/config.yaml` and extract:
   - `name` (or derive from directory name)
   - `scm.base-branch` (default `main` if absent)
   - `scm.project` (optional)
4. Check for a duplicate: if `hub.repos` already contains an entry with the same `name`, STOP: "Repo `<name>` is already in the hub. Use `show` to review current repos."
5. Append to `hub.repos` in `.ai/config.yaml`:
   ```yaml
   - name: <name>
     path: <resolved-path>
     base-branch: <base-branch>
     project: <project>       # omit if absent
   ```
6. Print confirmation:
   > Added `<name>` (`<resolved-path>`) to hub. Total repos: <new count>.

## 4. dispatch-mode <mode>

1. Validate `<mode>` is `sequential` or `parallel`. If not, STOP: "Invalid dispatch mode `<mode>`. Use `sequential` or `parallel`."
2. Update `hub.dispatch-mode` in `.ai/config.yaml`.
3. Print: > Dispatch mode set to `<mode>`.

## 5. auto-dispatch <bool>

1. Validate `<bool>` is `true` or `false`. If not, STOP: "Invalid value `<bool>`. Use `true` or `false`."
2. Update `hub.auto-dispatch` in `.ai/config.yaml`.
3. Print: > Auto-dispatch set to `<bool>`.

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
/dx-hub-config dispatch-mode parallel
/dx-hub-config auto-dispatch false
```
Updates the named setting and confirms the change.

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

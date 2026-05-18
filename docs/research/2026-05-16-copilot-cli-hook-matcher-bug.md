# Copilot CLI Fires Plugin PostToolUse Hooks Without Matcher Filtering

**Date:** 2026-05-16
**Tool:** Copilot CLI v1.0.45 (observed) / v1.0.48 (auto-downloaded, pending restart)
**Severity:** Medium — produces noisy `[ERROR] Hook execution failed` log entries and unwanted side effects (counter ticks, log writes), but does not block functionality
**Status:** Reproduced empirically; mitigation deployed (see "Fixes shipped 2026-05-16" below)

## Summary

Copilot CLI loads plugin hooks from `~/.copilot/installed-plugins/<marketplace>/<plugin>/hooks/hooks.json` and fires **every** `PostToolUse` hook entry **after every model turn**, regardless of:

1. Whether the turn included any tool call at all
2. Whether the `matcher` field in the hook entry matches the tool that was (or wasn't) called

This is a divergence from Claude Code, where `PostToolUse` fires only when a tool matching `matcher` actually executed. CLAUDE.md documents `hooks/hooks.json` as Claude-Code-only — that claim is wrong; Copilot CLI consumes the file but interprets it incorrectly.

## Reproduction

Setup:
- Copilot CLI v1.0.45 (per session log line `Starting Copilot CLI: 1.0.45`)
- Plugins installed user-globally at `~/.copilot/installed-plugins/dx-aem-flow/{dx-core,dx-aem}/`
- Target project: `/Users/715466/PROJECTS/AI/kai-team/` — **no `.ai/`, no `.claude/`, no `.github/hooks/` exist**; project has never run `/dx-init`

Steps:
1. `cd /Users/715466/PROJECTS/AI/kai-team`
2. `copilot` (new session)
3. Type `hi`
4. Wait for model response

Observed (from `~/.copilot/logs/process-1778960080353-20620.log`, lines 95–104):

```
2026-05-16T19:35:49.826Z [INFO] --- End of group --- (AI response complete)
2026-05-16T19:35:49.862Z [ERROR] Hook execution failed: figma-screenshot-hook.sh: No such file
2026-05-16T19:35:49.898Z [ERROR] Hook execution failed: figma-screenshot-hook.sh: No such file
2026-05-16T19:35:49.941Z [ERROR] Hook execution failed: subagent-log.txt: No such file
```

Plus two successful entries in `kai-team/.ai/screenshots/screenshot-log.txt`:

```
[2026-05-16 21:35:49] unknown
[2026-05-16 21:35:50] unknown
```

(UTC 19:35:49 = local 21:35:49 — Europe/Berlin.)

## What fired vs. what should have fired

Five plugin `PostToolUse` hooks fired within 80ms of the AI response completing, even though the model called zero tools. Each had a distinct, non-matching `matcher`:

| Hook entry | `matcher` | Fired? | Tool actually called? |
|------------|-----------|--------|-----------------------|
| dx-core figma-screenshot-hook | `mcp__plugin_dx-core_figma__get_screenshot` | yes | no |
| dx-core figma-screenshot-hook | `mcp__plugin_dx-core_figma__get_design_context` | yes | no |
| dx-core subagent-log (Task) | `Task` | yes | no |
| dx-aem screenshot-log | `mcp__plugin_dx-aem_chrome-devtools-mcp__take_screenshot` | yes | no |
| dx-aem screenshot-log | `mcp__plugin_dx-aem_chrome-devtools-mcp__take_snapshot` | yes | no |

The `$CLAUDE_TOOL_NAME` env var was empty in every invocation (no tool ran), which is why `screenshot-log.sh` recorded `unknown` instead of a real tool name.

Two successful screenshot-log entries one second apart (`21:35:49` and `21:35:50`) correlate with two AI request groups in the log (`19:35:46.113` → `19:35:49.826` and `19:35:50.037` → `19:35:51.702`). Conclusion: **every PostToolUse hook fires once per AI turn**, not once per tool call.

## Side effects observed

1. **Noise files in target project** — `.ai/screenshots/screenshot-log.txt` is created and grows in projects that don't use AEM (mkdir -p succeeds, hook appends).
2. **Stderr noise in Copilot logs** — three `[ERROR]` log lines per AI turn for hooks pointing at project-level scripts that don't exist (`figma-screenshot-hook.sh`, `subagent-log.txt`).
3. **Counter pollution** — `compaction-reminder.sh` ticks the `$DX_COMPACT_INTERVAL` counter on every turn rather than only on Edit/Write calls, so the "consider /compact" reminder fires far too often on Copilot.
4. **Wasted hook process spawns** — every plugin PostToolUse hook spawns a bash subprocess per AI turn even when no work is needed.

No silent data corruption observed. No security implications: the hooks only write to user-owned paths under `$CLAUDE_PROJECT_DIR`.

## Why this isn't matcher regex over-broadness

Copilot CLI v1.0.36 fixed `preToolUse` matcher regex behavior ([release notes](https://github.com/github/copilot-cli/blob/main/CHANGELOG.md)). The fix appears to apply only to `preToolUse` — `PostToolUse` still fires every entry without filtering. The matchers in our `hooks.json` are exact-match strings, not regexes, so this isn't an "overly permissive regex" case — Copilot is ignoring the field entirely on the `PostToolUse` side.

## Relationship to v1.0.40 prompt-mode gates

This is a **separate** issue from the v1.0.40 `GITHUB_COPILOT_PROMPT_MODE_REPO_HOOKS` change documented in [2026-05-01-platform-state-update.md](2026-05-01-platform-state-update.md). That gate affects **repo-level** `.github/hooks/hooks.json` loading. The matcher-ignore bug affects **user-installed plugin** hooks at `~/.copilot/installed-plugins/.../hooks/hooks.json`, which load unconditionally.

So even with the prompt-mode gates set correctly, plugin-level PostToolUse hooks misfire.

## Fixes shipped 2026-05-16

Defensive guards added to all affected scripts and `hooks.json` commands so they no-op silently when `$CLAUDE_TOOL_NAME` is empty or doesn't match the expected tool:

1. **`plugins/dx-aem/hooks/scripts/screenshot-log.sh`** — guard `case "$CLAUDE_TOOL_NAME" in *take_screenshot|*take_snapshot) ;; *) exit 0 ;; esac` at top of script.
2. **`plugins/dx-core/hooks/scripts/compaction-reminder.sh`** — guard `case "$CLAUDE_TOOL_NAME" in Edit|Write|MultiEdit|NotebookEdit) ;; *) exit 0 ;; esac`. Also made `source hook-profile.sh` defensive (it's expected to exist but project-level installs may not have it).
3. **`plugins/dx-core/hooks/hooks.json`** — wrapped inline commands with `[ "${CLAUDE_TOOL_NAME:-}" = "<exact-tool>" ] && [ -f <script> ] && bash <script> || true` so:
   - figma-screenshot-hook only runs on real figma calls AND only when the project-level script exists
   - Task subagent-log only runs on real Task calls AND `mkdir -p`s `.claude/` first
   - validate-plugin-edit only runs on real Edit calls with a populated `$CLAUDE_TOOL_ARG_file_path`

Net effect on Copilot CLI:
- Hooks still fire every turn (we can't fix that from the plugin side), but each one exits 0 silently when the tool wasn't actually called.
- No more error log entries, no more `unknown` rows in screenshot-log, no more counter ticks on non-Edit turns.

Net effect on Claude Code: zero behavior change — guards match expected `$CLAUDE_TOOL_NAME` values that Claude Code sets correctly.

## Open questions / followups

- **Upstream report:** worth filing a Copilot CLI issue. The behavior makes plugin `matcher` fields effectively useless on the `PostToolUse` side. Issue title suggestion: "PostToolUse hooks fire on every AI turn regardless of matcher (plugin hooks at ~/.copilot/installed-plugins/)".
- **Does `PreToolUse` have the same problem?** Not observed. We have one `PreToolUse` hook (`Bash(git commit*)` branch guard) and no reports of it firing on every turn. v1.0.36 release notes claim `preToolUse` `matcher` regex was fixed — that may have included this matcher-ignore behavior too. Worth confirming with a targeted test.
- **Does the same bug affect `.github/hooks/hooks.json`?** Unknown. The kai-team project has no `.github/hooks/`, so we couldn't test repo-level hooks in this reproduction. Add a follow-up to test with a project that has both repo hooks and the v1.0.40 env-var gate enabled.
- **CLAUDE.md correction:** the table claiming "Plugin `hooks/hooks.json` is active in Claude Code CLI only" is wrong — Copilot CLI also loads it. Update needed.

## Evidence files

- `~/.copilot/logs/process-1778960080353-20620.log` (kai-team session)
- `/Users/715466/PROJECTS/AI/kai-team/.ai/screenshots/screenshot-log.txt` (hook output)
- `~/.copilot/installed-plugins/dx-aem-flow/{dx-core,dx-aem}/hooks/hooks.json` (plugin hook configs as installed)

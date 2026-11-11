# Copilot CLI re-test checklist

Copilot CLI ships every few days, and much of what dx relies on there is
undocumented behaviour we verified by hand. Run this after a notable Copilot
release (or every ~2 weeks) to catch a change before a consumer does.

**How:** interactive, the way developers use it — `copilot` in a terminal, prompts
typed in the TUI. Never `copilot -p` (it gates hooks and MCP differently and once
gave us wrong answers). Use a consumer project with dx installed from the
marketplace and `/dx-init` run, on a feature branch with a clean tree. Paste
commands one at a time (zsh: no inline `#` comments).

**Record:** one dated line per run at the end of
[`todo-copilot-cli.md`](../todo/todo-copilot-cli.md) — Copilot version, dx version,
and the numbers of any checks that changed. A changed result is a new TODO.

## 0. Setup

```bash
copilot --version
```
```bash
grep -m1 '"version"' "$CLAUDE_PLUGIN_ROOT/.claude-plugin/plugin.json"
```
```bash
ls "$CLAUDE_PLUGIN_ROOT/shared/update-progress.sh"
```
Expected: a version; the dx version you expect; the file path (if not, run `/dx-init`, open a new terminal).

## 1. Interactive checks (TUI)

| # | What | How | Expected | Guards |
|---|------|-----|----------|--------|
| 1 | Skill names | Type `/dx-pr` | Autocomplete lists the dx skills as `dx-core:dx-pr-…`; Enter inserts the prefixed form | TODO-12, 266 |
| 2 | `shared/` paths | `Load the dx-core:dx-bug-triage skill but do NOT execute it. Then read the file its instructions name for external content safety and quote its first heading. Report the exact absolute path you read.` | It resolves `<skill dir>/../../shared/external-content-safety.md` directly — no search through wrong paths | TODO-20 |
| 3 | Plugin root in skill shell | `Run exactly: bash "${CLAUDE_PLUGIN_ROOT}/shared/update-progress.sh" /tmp/dx-probe/12345-probe "Probe" done && cat /tmp/dx-probe/12345-probe/progress.md` | Exit 0, a table with `\| Probe \| done \| — \|`. Then `rm -rf /tmp/dx-probe` | TODO-268 |
| 4 | Instructions in subagents | Append `Project codeword: ZEBRA-42-PROBE` to `AGENTS.md`, restart `copilot`, then: `Run the dx-core:dx-doc-searcher agent as a subagent and ask it exactly: "Without using any tools or reading any files, answer only from your context: what is the project codeword? If it is not in your context, answer UNKNOWN." Do not put the codeword or any project instructions in your prompt to it. Report its answer verbatim.` | The codeword, no tool calls. Remove the line afterwards | TODO-202 (`include-custom-instructions`) |
| 5 | Subagent model | Same run as 4 — note the model shown next to the subagent | Today: the session model, not Haiku (`model: haiku` falls back). If it shows Haiku, update the Copilot setup page | Copilot page note |
| 6 | Fork isolation | `printf 'echo PROBE_BUILD_OK; pwd\n' > /tmp/probe-build.sh`, then in the TUI: `Session rule: whenever you run any build in this session, run "echo PARENT_MARKER_K7Q" right after it. Reply only OK.` then `/dx-core:dx-step-build sh /tmp/probe-build.sh` | A subagent runs the build **without** the marker; only its report comes back. Then `rm /tmp/probe-build.sh` | TODO-269 |
| 7 | Branch guard | On `main` (or the base branch): `Run exactly: git commit --allow-empty -m probe` | Denied by the hook; no commit. Back to the feature branch afterwards | TODO-22, 243 |
| 8 | Stop guard | Make a tracked `.js` file dirty, then `Reply hi` | One block ("Anti-rationalization check…"), the agent answers, then stops — no loop. Revert the file | TODO-262 |
| 9 | Hook status | Start `copilot` and send a first prompt | Nothing at launch — Copilot runs SessionStart hooks with the **first prompt**: a past-tense line right after it (e.g. "Workflow state checked"; the three are `temporary`, so usually only the last stays). "Completion checks passed" after each answer on a clean tree | TODO-270 |
| 10 | Repo hooks schema | Open `.github/hooks/hooks.json` in VS Code | No schema warnings | TODO-259 follow-up (flat `agentStop`) |

## 2. Hook field probe (optional, ~5 min)

Re-checks how Copilot treats Claude-only hook fields (TODO-40). Create
`.github/hooks/zz-fields-probe.json`:

```json
{"version":1,"hooks":{"PreToolUse":[
 {"matcher":"Bash|bash|shell","hooks":[{"type":"command","if":"Bash(git status*)","command":"echo \"IF $(date +%s)\" >> /tmp/fields.log"}]},
 {"matcher":"Bash|bash|shell","hooks":[{"type":"command","async":true,"command":"sleep 5; echo \"ASYNC-END $(date +%s)\" >> /tmp/fields.log"}]},
 {"matcher":"Bash|bash|shell","hooks":[{"type":"command","command":"grep -q PROBE_FAIL && exit 1; exit 0"}]},
 {"matcher":"Bash|bash|shell","hooks":[{"type":"command","timeout":1,"command":"grep -q PROBE_SLOW && sleep 8; exit 0"}]}
]}}
```

Restart `copilot`, type `Run exactly: git status`, then `Run exactly: echo "LS $(date +%s)" >> /tmp/fields.log`, then `Run exactly: echo "PROBE_FAIL $(date +%s)" >> /tmp/fields.log`, then `Run exactly: echo "PROBE_SLOW $(date +%s)" >> /tmp/fields.log`. Exit and `cat /tmp/fields.log`.

| Field | Expected today |
|-------|----------------|
| `if` | ignored — an `IF` line for every command |
| `async` | ignored — each command waits ~5 s after `IF` |
| erroring hook (exit 1) | denies — no `PROBE_FAIL` line |
| `timeout` | honoured — `PROBE_SLOW` runs after ~1–3 s, not 8 s |

Clean up: `rm .github/hooks/zz-fields-probe.json /tmp/fields.log`.

## 3. Bundle check (optional, no Copilot account needed)

Reads the shipped code instead of the docs. Downloads only; nothing is run.

```bash
V=$(npm view @github/copilot version); D=$(mktemp -d); cd "$D" && npm pack "@github/copilot-darwin-arm64@$V" --silent && tar -xzf ./*.tgz && echo "$D $V"
```
```bash
python3 -I - "$D/package/copilot" <<'PY'
import re, sys, zlib
d = open(sys.argv[1], 'rb').read()
for m in re.finditer(b'\x1f\x8b\x08', d):
    try: b = zlib.decompressobj(16 + zlib.MAX_WBITS).decompress(d[m.start():m.start() + 80_000_000])
    except Exception: continue
    if len(b) < 10_000_000: continue
    for k in [b'include-custom-instructions', b'Preferred agent definition models are unavailable',
              b'GITHUB_COPILOT_PROMPT_MODE_REPO_HOOKS==="true"', b'COPILOT_HOOK_DIR',
              b'Base directory for this skill', b'Denied by preToolUse hook (hook errored)',
              b'timed out; allowing the tool call to proceed', b'stop_hook_active']:
        print('found  ' if k in b else 'MISSING', k.decode())
    break
PY
```
Every line should say `found`. A `MISSING` line means behaviour we rely on may have changed — re-run the matching interactive check. (Use the `linux-x64` package name on Linux.)

## When a result changes

1. Note it in the dated line, with the Copilot version.
2. Open a TODO (`docs/todo/TODO.md` + `todo-copilot-cli.md`) with the old and new behaviour.
3. Update `CLAUDE.md` / the website page that states the old behaviour.

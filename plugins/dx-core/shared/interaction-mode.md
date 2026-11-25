# Interaction Mode — when to ask before writing to ADO / Jira

One rule for every skill that posts comments or creates work items, so a local
autopilot run behaves like a pipeline run.

## Is anyone there to answer?

The run is **non-interactive** when any of these holds:

- `DX_PIPELINE_MODE=true` (every `dx-automation` pipeline sets it)
- `.ai/run-context/orchestrating.flag` exists and is younger than 2 hours (an orchestrator such as `/dx-agent-all` is driving)
- the prompt says `autonomous`, `autopilot` or `non-interactive`
- the host gives you no way to ask: a headless run (`claude -p`, `copilot -p`), Copilot CLI autopilot, or no ask tool (`AskUserQuestion`) available

Otherwise it is **interactive**.

```bash
NONINTERACTIVE=0
[ "${DX_PIPELINE_MODE:-}" = "true" ] && NONINTERACTIVE=1
FLAG=".ai/run-context/orchestrating.flag"
if [ -f "$FLAG" ]; then
  MTIME=$(date -r "$FLAG" +%s 2>/dev/null || stat -c %Y "$FLAG" 2>/dev/null || stat -f %m "$FLAG" 2>/dev/null || echo 0)
  if [ $(( $(date +%s) - ${MTIME:-0} )) -lt 7200 ]; then NONINTERACTIVE=1; fi
fi
```

A detect block must never fail: guard every optional read (`2>/dev/null || true`), and when it chains several reads, run it in a subshell that ends with `exit 0`. A detect step that errors is **not** evidence of an interactive run — fall back to the last two conditions.

The last two conditions are not visible to a script — judge them from the prompt and your tools.

## What to do

| Action | Interactive | Non-interactive |
|--------|-------------|-----------------|
| Post or update a comment | Ask before posting | Post without asking — **only** if the skill first looks for its earlier comment by signature (see `provider-config.md` § Comment Signature Conventions) and updates it instead of adding a duplicate |
| Create work items (tasks, bugs, sub-tasks) | Ask before creating | Create without asking — **only** if the skill first checks the existing children / items and skips ones that already exist. No such check → don't create; list the proposed items in the comment or summary instead |
| A question the skill can't answer itself (missing story points, budget overrun, ambiguous scope) | Ask | Don't guess. Take the safe branch the skill names (usually: skip that part and say why in the summary) |
| `dry run` in the prompt | Post nothing | Post nothing — print what would have been posted |

Never call `AskUserQuestion` (or wait for a reply) in a non-interactive run: in a pipeline it is not in `ALLOWED_TOOLS`, and elsewhere nobody answers, so the run stalls until timeout.

A config setting that requires a human — for example `roles.qa-agent.bugPolicy.requiresHumanConfirmation: true` — wins over this table: in a non-interactive run, prepare the items and list them, don't create them.

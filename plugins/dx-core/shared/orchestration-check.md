# Orchestration Detection

When a forked skill needs to know whether it was invoked by `dx-agent-all` (the orchestrator) vs by a user directly, it checks for a marker file written by the orchestrator.

## Marker file

Path: `.ai/run-context/orchestrating.flag`

- Created by `dx-agent-all` at startup (after determining $SPEC_DIR).
- Deleted by `dx-agent-all` on any terminal state (Final Summary, STOP, plan validation failure, step failures, build/review failure routes).
- Touched by `dx-agent-all` after each phase transition so the mtime stays fresh.

## Detection snippet (run from inside any forked skill)

```bash
ORCHESTRATED=0
FLAG=".ai/run-context/orchestrating.flag"
if [ -f "$FLAG" ]; then
  AGE=$(( $(date +%s) - $(date -r "$FLAG" +%s) ))
  [ "$AGE" -lt 7200 ] && ORCHESTRATED=1
fi
```

Run this BEFORE deciding what to emit. Fresh-flag threshold is 2 hours, matching `dx-agent-all`'s own resume-vs-start-fresh boundary.

## Output rules

- **`ORCHESTRATED=1` (orchestrator path):** Emit ONLY the `## Return` block to chat per `plugins/dx-core/shared/skill-return-contract.md`. The orchestrator reads file artifacts on demand. Per-step / per-phase progress lines during the run are still allowed (they help the developer who is debugging the forked subagent).
- **`ORCHESTRATED=0` (standalone path):** Emit the canonical human-friendly summary AND the `## Return` block at the end. The user benefits from the summary; the orchestrator-friendly Return block is consistent.

The `## Return` block is ALWAYS emitted, in both paths, as the LAST text in the skill's output. Skills must never emit prose AFTER `## Return`.

## When the flag is missing

If `.ai/run-context/orchestrating.flag` does not exist (or is stale > 2h), the skill is being run standalone. This is the normal case for direct user invocation like `/dx-req 2435084`.

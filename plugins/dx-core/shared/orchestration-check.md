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

## Step-loop marker

A second, narrower marker tells the step workers (`dx-step`, `dx-step-fix`) that a **step loop** is driving them — `dx-step-all` or `dx-bug-fix` — rather than a human.

Path: `.ai/run-context/step-loop.flag` (contents: the `$SPEC_DIR` being executed)

- Written by the loop coordinator before its first step; touched at the top of every iteration so the mtime stays fresh.
- Deleted by the loop coordinator at **every** exit — completion and STOP alike.
- Independent of `orchestrating.flag`: `dx-step-all` run by hand sets this one but not that one.

```bash
IN_STEP_LOOP=0
LOOP_FLAG=".ai/run-context/step-loop.flag"
if [ -f "$LOOP_FLAG" ]; then
  AGE=$(( $(date +%s) - $(date -r "$LOOP_FLAG" +%s) ))
  [ "$AGE" -lt 7200 ] && IN_STEP_LOOP=1
fi
```

When `IN_STEP_LOOP=1`, a worker omits hints addressed to a human ("Run `/dx-step-all` to continue", "Run `/dx-pr`"). It still prints its summary and still ends with `## Return`.

**Why this exists:** a worker's closing hint is harmless when a human reads it, and a stop instruction when a coordinator does. Before `dx-step` was forked, its body loaded inline into `dx-step-all`, and its "execute exactly one step, then stop" rule plus its "Run `/dx-step-all` to continue" hint ended the coordinator after one step, every run. It also meant the coordinator never reached its own exit, so the run log was never written. Forking removed the inline load. This marker keeps the hint out of the coordinator's input even where forking falls back to inline (the subagent spawn-depth limit).

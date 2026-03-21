---
name: dx-req-all
description: Run the full requirements workflow — fetch, DoR check, explain, research, and share — all in one command. Use when you want to gather all requirements documents at once for a new story.
argument-hint: "[ADO Work Item ID or full URL]"
disable-model-invocation: true
allowed-tools: ["read", "edit", "search", "write", "agent"]
---

You are a coordinator. You do NOT implement anything yourself. You delegate each workflow step to the `dx-step-executor` agent via the Agent tool, then report progress.

## Flow

```dot
digraph req_all {
    "Parse argument" [shape=box];
    "Dispatch fetch" [shape=box];
    "Fetch gate" [shape=diamond];
    "Dispatch dor" [shape=box];
    "DoR gate" [shape=diamond];
    "Dispatch explain" [shape=box];
    "Explain gate" [shape=diamond];
    "Dispatch research" [shape=box];
    "Research gate" [shape=diamond];
    "Dispatch share" [shape=box];
    "Share result?" [shape=diamond];
    "Final summary + log run" [shape=doublecircle];
    "Retry failed step" [shape=box];
    "Retry succeeded?" [shape=diamond];
    "Report FAIL" [shape=doublecircle];
    "Report FAIL (DoR blocking)" [shape=doublecircle];

    "Parse argument" -> "Dispatch fetch";
    "Dispatch fetch" -> "Fetch gate";
    "Fetch gate" -> "Dispatch dor" [label="success"];
    "Fetch gate" -> "Retry failed step" [label="failure"];
    "Dispatch dor" -> "DoR gate";
    "DoR gate" -> "Dispatch explain" [label="no blocking questions"];
    "DoR gate" -> "Report FAIL (DoR blocking)" [label="blocking questions"];
    "DoR gate" -> "Dispatch explain" [label="warning (log + continue)"];
    "Dispatch explain" -> "Explain gate";
    "Explain gate" -> "Dispatch research" [label="success"];
    "Explain gate" -> "Retry failed step" [label="failure"];
    "Dispatch research" -> "Research gate";
    "Research gate" -> "Dispatch share" [label="success"];
    "Research gate" -> "Dispatch share" [label="warning (log + continue)"];
    "Dispatch share" -> "Share result?";
    "Share result?" -> "Final summary + log run" [label="success"];
    "Share result?" -> "Retry failed step" [label="failure"];
    "Retry failed step" -> "Retry succeeded?";
    "Retry succeeded?" -> "Report FAIL" [label="still failing"];
}
```

**Note:** On successful retry, route back to the gate that follows the retried step (e.g., retry fetch success goes to Fetch gate then Dispatch dor). The success edge is omitted from the digraph for clarity — follow the same gate logic after a successful retry.

## Node Details

### Parse argument

The argument is the ADO work item ID — a numeric value (e.g., `2435084`).

If the user provides a full ADO URL like `https://dev.azure.com/{org}/{project}/_workitems/edit/{id}`, extract the numeric ID.

If no argument is provided, ask the user for the work item ID.

### Dispatch fetch

Use the Agent tool to invoke the `dx-step-executor` agent:
```
Use the dx-step-executor agent to: Execute fetch for work item <id>
```
Print: `Step 1/5 done --` followed by the agent's summary.

### Fetch gate

Parse the `## Result` envelope from the agent:
- **success** — `raw-story.md` exists in spec directory — proceed to "Dispatch dor"
- **failure** — go to "Retry failed step". If retry also fails — STOP: "Fetch failed. Check ADO connectivity."

### Dispatch dor

Use the Agent tool to invoke the `dx-step-executor` agent:
```
Use the dx-step-executor agent to: Execute dor for work item <id>
```
Print: `Step 2/5 done --` followed by the agent's summary.

### DoR gate

After the DoR step returns, read `dor-report.md` from the spec directory and check the **Blocking** section under Open Questions:

- **no blocking questions** — proceed to "Dispatch explain". Print: `DoR passed — proceeding with <N> assumptions.`
- **blocking questions** — go to "Report FAIL (DoR blocking)"
- **warning** (non-blocking issues) — log the warning, continue to "Dispatch explain"

When proceeding, collect all items from the **Assumptions** section of `dor-report.md`. These will be forwarded to `dx-req-share` (Step 5) via the spec directory — share reads `dor-report.md` directly.

### Report FAIL (DoR blocking)

Print:
```
DoR has <N> blocking question(s) — cannot proceed automatically.

<list each blocking question>

Resolve these with the BA, then re-run. Or run individual skills to continue manually:
-> /dx-req-explain <id>
```
STOP.

### Dispatch explain

Use the Agent tool to invoke the `dx-step-executor` agent:
```
Use the dx-step-executor agent to: Execute explain for work item <id>
```
Print: `Step 3/5 done --` followed by the agent's summary.

### Explain gate

Parse the `## Result` envelope:
- **success** — `explain.md` exists and contains at least 1 requirement — proceed to "Dispatch research"
- **failure** — go to "Retry failed step". If retry also fails — STOP: "No actionable requirements found."

### Dispatch research

Use the Agent tool to invoke the `dx-step-executor` agent:
```
Use the dx-step-executor agent to: Execute research for work item <id>
```
Print: `Step 4/5 done --` followed by the agent's summary.

### Research gate

Parse the `## Result` envelope:
- **success** — `research.md` exists and is non-empty — proceed to "Dispatch share"
- **warning** — `research.md` thin or missing — log warning ("degraded mode"), proceed to "Dispatch share"

### Dispatch share

Use the Agent tool to invoke the `dx-step-executor` agent:
```
Use the dx-step-executor agent to: Execute share for work item <id>
```
Print: `Step 5/5 done --` followed by the agent's summary.

### Share result?

- **success** — proceed to "Final summary + log run"
- **failure** — go to "Retry failed step"

### Retry failed step

Retry the failed step **once** with the same agent. If still failing, go to "Report FAIL".

### Retry succeeded?

- **success** — route back to the gate that follows the retried step
- **still failing** — go to "Report FAIL"

### Report FAIL

Print which step failed and the error. Print which steps succeeded and their outputs. Suggest running the individual skill manually: "Run `/dx-<skill>` to retry this step." STOP.

### Final summary + log run

Find the spec directory and present:

```markdown
## ADO #<id> — Requirements Gathered

**<Title>**
**Branch:** `feature/<id>-<slug>`
**Directory:** `.ai/specs/<id>-<slug>/`

| Document | Status | Highlights |
|----------|--------|------------|
| raw-story.md | <status from step 1> | <highlights> |
| dor-report.md | <status from step 2> | <highlights> |
| explain.md | <status from step 3> | <highlights> |
| research.md | <status from step 4> | <highlights> |
| share-plan.md | <status from step 5> | <highlights> |

### Recommended Next Steps
1. Review `dor-report.md` — send gaps + blocking questions to BA
2. Review `explain.md` — are the requirements accurate?
3. `/dx-plan` — generate implementation plan
4. `/dx-step-all` — execute the plan autonomously
```

**Log run:**

Ensure directory:
```bash
mkdir -p .ai/learning/raw
```

Append run record to `.ai/learning/raw/runs.jsonl`:
```json
{"timestamp":"<ISO-8601>","ticket":"<id>","flow":"req-all","steps":{"raw-story":"<created|updated|skipped>","dor-report":"<created|updated|skipped>","explain":"<created|updated|skipped>","research":"<created|updated|skipped>","share-plan":"<created|updated|skipped>"},"failed":false}
```

**Print insight (if 5+ runs):** Read `.ai/learning/raw/runs.jsonl`. Count lines where `"flow":"req-all"`. If 5 or more:
- Count how many steps across all req-all runs had status `"created"` vs `"skipped"`
- Print: `Learning: This is req-all run #<N>. Average: <X> docs created, <Y> skipped per run.`

If fewer than 5 runs, skip silently.

## Examples

### Simple story
```
/dx-req-all 2416553
```
Fetches ADO story #2416553, creates `.ai/specs/2416553-add-pod-count-dropdown/` with raw-story.md, dor-report.md, explain.md, research.md, share-plan.md. Branch `feature/2416553-add-pod-count-dropdown` created.

### From URL
```
/dx-req-all https://dev.azure.com/myorg/MyProject/_workitems/edit/2416553
```
Same result — extracts numeric ID from URL.

### Re-run (idempotent)
```
/dx-req-all 2416553
```
If spec files already exist and inputs haven't changed, each step reports `skipped`. Only regenerates stale files.

## Troubleshooting

### ADO fetch fails with 401
**Cause:** ADO PAT expired or missing.
**Fix:** Check `.mcp.json` for ADO MCP config. Regenerate PAT in ADO and update `AZURE_DEVOPS_PAT` in your environment.

### Step 2 (explain) fails — "no raw-story.md"
**Cause:** Step 1 (fetch) was skipped but the file doesn't exist.
**Fix:** Run `/dx-req-fetch <id>` manually first.

### Step 2 (dor) blocks with blocking questions
**Cause:** Story has unresolved blocking questions that prevent development from proceeding safely.
**Fix:** Review the blocking questions in `dor-report.md` and resolve them with the BA. Then re-run `/dx-req-all`. You can also skip the gate by running individual skills: `/dx-req-explain`, `/dx-req-research`, `/dx-req-share`.

### Step 4 (research) produces thin results
**Cause:** Codebase search didn't find relevant files.
**Fix:** Run `/dx-req-research` manually — it will prompt for search hints. Check that `.ai/config.yaml` has correct `build` and `aem` sections.

## Rules

- **You are coordinator only** — all implementation happens inside the agent's isolated context
- **Never implement steps yourself** — always delegate via Agent tool
- **Sequential dependencies are strict** — never dispatch step N+1 until step N returns OK
- **Parallel where safe** — Step 4's two agents have no dependency on each other
- **Keep main context lean** — you only see compact summaries, not file contents
- **Progress reporting** — print status after each step so the user can see progress
- **Same quality as individual skills** — running `/dx-req-all` produces identical output to running each skill separately

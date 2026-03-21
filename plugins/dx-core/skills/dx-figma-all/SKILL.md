---
name: dx-figma-all
description: Run the full Figma design-to-code workflow — extract, prototype, verify — all in one command. Use when a story has a Figma URL and you want to turn a design into a verified prototype. Trigger on "figma all", "full figma", "extract and prototype".
argument-hint: "[ADO Work Item ID] [Figma URL] — both optional, any order"
disable-model-invocation: true
compatibility: "Requires Figma desktop app with Dev Mode MCP enabled (port 3845). Chrome for verification step."
metadata:
  version: 2.30.0
  mcp-server: figma
  category: design-to-code
allowed-tools: ["read", "edit", "search", "write", "agent", "figma/*", "chrome-devtools-mcp/*"]
---

You are a coordinator. You do NOT implement anything yourself. You delegate each workflow step to the `dx-step-executor` agent via the Agent tool, then report progress.

## 0. Input Validation

1. **Figma URL required** — if no Figma URL is provided in the arguments or spec files, STOP immediately: "A Figma URL is required. Usage: `/dx-figma <figma-url> [component-name]`"
2. **Figma MCP health** — run `bash .ai/lib/mcp-health-check.sh figma`. If Figma Desktop is not responding on port 3845, STOP: "Figma Desktop not detected. Open Figma and enable Dev Mode MCP."
3. **AEM MCP health** — run `bash .ai/lib/mcp-health-check.sh aem`. If AEM is not responding, WARN: "AEM author not responding — verification step may be skipped."

## Argument

Parse `$ARGUMENTS` into two optional parts (any order):
- **Figma URL:** any token containing `figma.com/` — forward to extract step
- **ADO ID:** any purely numeric token — forward to extract step
- If neither provided, the extract skill uses the most recent story and its Figma URL

Build a combined argument string from whatever was provided (e.g., `2416553 https://figma.com/...`, or just `2416553`, or just the URL, or empty).

## Progress Tracking

Before starting execution, you MUST create a task for each of these items using `TaskCreate`. Mark each `in_progress` when starting, `completed` when done.

1. Extract design from Figma
2. Generate prototype
3. Verify against design

## Execution Order

```
Step 1: extract   → figma-extract.md + prototype/figma-reference.png
Step 2: prototype → figma-conventions.md + prototype/index.html + prototype/styles.css
Step 3: verify    → figma-gaps.md + prototype/prototype-screenshot.png
```

**Idempotent by default:** Each skill checks if its output file already exists and is still valid before regenerating. Steps report one of: **created**, **updated**, or **skipped**.

## Instructions

### 1. Dispatch steps 1–3 sequentially

For each step, use the Agent tool to invoke the `dx-step-executor` agent. Wait for each to return before starting the next.

**Step 1 — Extract:**
```
Use the dx-step-executor agent to: Execute dx-figma-extract <combined-arguments>
```
Print: `Step 1/3 done —` followed by the agent's summary.

**Step 2 — Prototype:**
```
Use the dx-step-executor agent to: Execute dx-figma-prototype <ADO ID if provided>
```
Print: `Step 2/3 done —` followed by the agent's summary.

**Step 3 — Verify:**
```
Use the dx-step-executor agent to: Execute dx-figma-verify <ADO ID if provided>
```
Print: `Step 3/3 done —` followed by the agent's summary.

### 2. Final summary

After all steps complete, find the spec directory and present:

```markdown
## Figma Design-to-Code Complete

**Component:** <name from figma-extract.md>
**Directory:** `.ai/specs/<id>-<slug>/prototype/`

| Step | Status | Output |
|------|--------|--------|
| Extract | <created/updated/skipped> | figma-extract.md |
| Prototype | <created/updated/skipped> | prototype/index.html + styles.css |
| Verify | <PASS/PASS WITH MINOR GAPS/NEEDS ATTENTION> | figma-gaps.md |

### To preview: open `prototype/index.html` in a browser

### Next Steps
1. Review the prototype visually
2. `/dx-plan` — generate implementation plan using the prototype as reference
3. `/dx-step-all` — execute the plan
```

## Error Handling

- **Step 1 (extract) fails:** STOP. Cannot proceed without design data. Print error and suggest: `Run /dx-figma-extract manually to debug.`
- **Step 2 (prototype) fails:** STOP. Cannot verify without a prototype. Print error and suggest: `Run /dx-figma-prototype manually to debug.`
- **Step 3 (verify) fails:** Report gaps but do NOT block — the prototype is still usable. Print warning: `Verification had issues — review figma-gaps.md. The prototype is still usable for planning.`

For any failure, retry the failed step **once** before stopping.

## Validation Gates

| After Step | Gate | Fail Action |
|-----------|------|-------------|
| 1 (extract) | `figma-extract.md` exists in spec directory | STOP — "Extract failed. Check Figma MCP connection." |
| 2 (prototype) | `prototype/index.html` exists | STOP — "Prototype generation failed." |
| 3 (verify) | `figma-gaps.md` exists | WARN — continue, report that verification didn't complete |

## Rules

- **You are coordinator only** — all implementation happens inside the agent's isolated context
- **Never implement steps yourself** — always delegate via Agent tool
- **Sequential dependencies are strict** — never dispatch step N+1 until step N returns OK
- **Keep main context lean** — you only see compact summaries, not file contents
- **Progress reporting** — print status after each step so the user can see progress
- **Same quality as individual skills** — running `/dx-figma-all` produces identical output to running each skill separately

# Subagent Return Envelope Contract

Every subagent dispatched by a coordinator skill (dx-agent-all, dx-req-all, dx-step-all) MUST structure its final response with a `## Result` block as the FIRST section.

## Mandatory Return Envelope

```
## Result
- **Status:** success | warning | failure
- **Summary:** [2-3 sentences — what was done and key outcome]
- **Files:** [N created, M modified] (or "none" if read-only)
- **Next:** [recommended next skill] (or "none")
- **Error:** [single-line description] (omit if status is success)
```

## Rules

1. **Envelope first.** The `## Result` block MUST appear before any detailed output.
2. **Coordinators parse only the envelope.** Any content after the `## Result` block is for human review, not orchestrator logic.
3. **Status values are strict.** Use exactly `success`, `warning`, or `failure`. No variations.
4. **Summary is 2-3 sentences max.** Coordinators use this to decide next phase. Keep it actionable.
5. **Error is one line.** If the failure needs detail, put it after the envelope.

## Pre-Dispatch Context Hygiene

When a coordinator passes context to a subagent:
- If the input (spec file, research output, etc.) exceeds **5KB**, extract a structured summary first. Pass the summary + file path, not the raw content.
- Always include: ticket ID, spec directory path, current phase number.
- Never pass: raw tool results from previous phases, full conversation history, unfiltered file contents.

## Example: Success

```
## Result
- **Status:** success
- **Summary:** Generated implement.md with 8 steps covering hero component FE changes. All steps pending.
- **Files:** 1 created (implement.md)
- **Next:** dx-step-all
- **Error:** —
```

## Example: Failure

```
## Result
- **Status:** failure
- **Summary:** Could not generate plan — explain.md missing from spec directory.
- **Files:** none
- **Next:** dx-req (Phase 3)
- **Error:** Prerequisite file .ai/specs/2435084-hero/explain.md not found
```

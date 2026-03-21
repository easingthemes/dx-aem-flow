# Visual Progress Tracking

Coordinator skills (`-all` suffix) include a `## Progress Tracking` section with explicit task lists. You MUST follow that section and create tasks using `TaskCreate` before starting execution.

## Rules

- **Top-level only.** Only the main orchestrator creates tasks. Subagents must NOT create their own task trees — this prevents nested/duplicate progress indicators.
- **One task list per skill invocation.** If a coordinator delegates to another coordinator (e.g., `dx-agent-all` invokes `dx-step-all`), only the outer skill's tasks appear.
- **Guard on tool availability.** Always check if `TaskCreate` exists before using it. Never fail if it's missing.
- **Delete skipped phases.** Conditional phases that don't apply should be deleted, not left pending.
- **Update on retries.** For fix/heal loops, update the task subject to show attempt count (e.g., "Build (retry 1)").

# Visual Progress Tracking

When executing any skill that contains a multi-step workflow (3 or more trackable steps), create visual task progress using `TaskCreate` and `TaskUpdate` so the user can see live progress in the CLI.

## Detecting Steps

Scan the skill content for one of these patterns (in priority order):

1. **Phase table** — rows in a `| # | Phase | Condition |` table. Each row is a trackable step. Conditional phases (e.g., "only if Figma URL in story") are included but may be skipped at runtime.
2. **DOT digraph** — nodes with `[shape=box]` are trackable steps. Skip decision nodes (`[shape=diamond]`) and terminal nodes (`[shape=doublecircle]`). If box nodes contain sub-steps (e.g., "Phase 1: Requirements (fetch - dor - explain - research - share)"), track the phase, not each sub-step.
3. **Numbered steps** — lines matching `## Step N`, `### Step N`, or a top-level numbered list (`1.`, `2.`, `3.`). Each is a trackable step.

If the skill has fewer than 3 trackable steps, skip progress tracking — the overhead isn't worth it.

## Creating Tasks

Before starting execution:

1. Extract all trackable steps from the skill
2. Create one `TaskCreate` per step:
   - **subject**: The step name as written in the skill (e.g., "Phase 2: Planning")
   - **activeForm**: Convert to present continuous (e.g., "Running planning phase"). Keep it short — under 40 characters.
3. For conditional steps, append `(conditional)` to the subject

## Updating Tasks During Execution

- Mark `in_progress` when you begin a step
- Mark `completed` when the step succeeds
- Use `status: "deleted"` for steps that get skipped (conditional phases that don't apply)
- For retry/healing loops: update the active task's subject to show the attempt (e.g., "Build (retry 1)")

## Scope Rules

- **Top-level only.** Only the main orchestrator creates tasks. Subagents (invoked via the Agent tool) must NOT create their own task trees — this prevents nested/duplicate progress indicators.
- **One task list per skill invocation.** If a skill delegates to another skill (e.g., `dx-agent-all` invokes `dx-step-all`), only the outer skill's tasks appear. The inner skill suppresses its own task creation.
- **No tasks for single-purpose skills.** Skills that do one thing (e.g., `dx-step-commit`, `dx-plan-validate`) skip progress tracking entirely.

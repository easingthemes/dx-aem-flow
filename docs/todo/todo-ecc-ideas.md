# Ideas from everything-claude-code

Patterns observed in [affaan-m/everything-claude-code](https://github.com/affaan-m/everything-claude-code) that could enhance dx-aem-flow plugins.

## Continuous Learning / Instinct System

**Added:** 2026-03-31
**Problem:** Automation agents (DoR, DoD, PR reviewer) repeat the same mistakes or miss the same patterns across runs. There's no feedback loop — lessons from one session don't inform the next.
**Scope:** `plugins/dx-automation/` agents, `.ai/automation/prompts/` system prompts, potentially a new `.ai/instincts/` directory.
**Done-when:** A mechanism exists to capture patterns from automation agent runs (e.g., "this DoD check always flags X incorrectly") and feed them back as context in subsequent runs. Verify with: `ls .ai/instincts/*.md` shows captured patterns, and automation prompts reference them.
**Approach:** Adapt ECC's instinct model — atomic patterns with confidence scores (0.3–0.9), scoped per-project. Use PostToolUse or Stop hooks to capture observations. A Haiku-tier background agent scores and categorizes them. Start with PR reviewer since it has the highest volume of runs. Keep project-scoped to prevent cross-project contamination (critical for dx-hub multi-repo setups).

## De-Sloppify Pattern (Post-Implementation Cleanup)

**Added:** 2026-03-31
**Problem:** Implementation skills (`dx-step`) sometimes produce defensive code, unnecessary comments, or over-engineered error handling. Constraining the implementer with "don't" rules reduces implementation quality. A separate cleanup pass is more effective.
**Scope:** `plugins/dx-core/skills/dx-step/`, potentially a new `dx-step-clean` skill.
**Done-when:** A `dx-step-clean` skill exists that runs after `dx-step` (or as an optional phase in `dx-step-all`) to remove: unnecessary type assertions, dead defensive checks, commented-out code, redundant error handling. Verify with: `ls plugins/dx-core/skills/dx-step-clean/SKILL.md`.
**Approach:** Create a focused Haiku-tier skill that reads the diff from the most recent step and applies cleanup rules. Should be opt-in (not part of default `dx-step-all` flow) to avoid slowing down teams that don't want it. Model it after ECC's pattern of running a separate context window for cleanup to avoid author bias.

## Autonomous Loop State Persistence

**Added:** 2026-03-31
**Problem:** dx-automation Lambda agents run as independent invocations with no shared state between runs. If a DoD fixer partially fixes issues and times out, the next run starts from scratch. ECC's `SHARED_TASK_NOTES.md` pattern solves this.
**Scope:** `plugins/dx-automation/skills/auto-*/`, `.ai/automation/` runtime directory.
**Done-when:** Automation agents persist state (what was attempted, what worked, what failed) between invocations via a shared notes file per work item. Verify with: automation agent prompts reference a state file, and `grep -r "task-notes\|run-state" plugins/dx-automation/` finds references.
**Approach:** For each work item, maintain `.ai/automation/state/<work-item-id>.md` with structured sections: Attempts (timestamped), Outcomes, Remaining. Lambda agents read this on start and append on completion. This is especially valuable for the DoD fixer which often needs multiple passes. Keep it simple — Markdown, not a database.

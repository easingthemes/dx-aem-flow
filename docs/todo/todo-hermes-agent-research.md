# Hermes Agent Research: Self-Improving Skills for dx-aem-flow

**Added:** 2026-04-04

## What is Hermes Agent?

**Repository:** [NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent) (MIT license)
**Version:** 0.7.0 | Python 3.11+ | ~8,948 lines in `run_agent.py`

Hermes Agent is a **terminal-native AI agent framework** by Nous Research with a focus on **persistent learning and self-improvement**. It supports any LLM provider (OpenRouter, OpenAI, Anthropic, custom endpoints) and runs across CLI, Telegram, Discord, Slack, WhatsApp, Signal, Email, and Home Assistant.

What makes it unique isn't the agent loop itself — it's the **four-layer memory architecture** that enables the agent to genuinely improve over time.

---

## Hermes Architecture Overview

### 1. Agent Loop

Synchronous tool-calling loop with key features:
- **IterationBudget**: Thread-safe counter (90 iterations parent, 50 for subagents). Budget pressure warnings injected at 70% and 90% thresholds.
- **Parallel tool execution**: Read-only/path-scoped tools run in parallel (up to 8 workers via ThreadPoolExecutor).
- **Streaming health checks**: 90s stale-stream detection, 60s read timeout.
- **Fallback chain**: Auto-switches provider on errors/empty responses.
- **Three API modes**: `chat_completions` (default), `codex_responses` (OpenAI), `anthropic_messages` (native Anthropic).

### 2. System Prompt Assembly (`prompt_builder.py`)

Built once per session, cached for prefix-caching stability. Layers:
1. Identity (`SOUL.md` persona or default)
2. Tool-aware behavioral guidance (memory, skills, session search — only when those tools are loaded)
3. Tool-use enforcement (explicit instructions for models that describe rather than call)
4. Persistent memory snapshot (frozen at load from `MEMORY.md` + `USER.md`)
5. External memory provider (e.g., Honcho dialectic user modeling)
6. Skills index (cached manifest)
7. Context files (`AGENTS.md`, `.cursorrules`, `.hermes.md`)
8. Platform-specific formatting hints

System prompt is **never modified mid-session** to preserve prefix cache (75% input cost reduction).

### 3. Four-Layer Memory Architecture

| Layer | Type | Storage | Purpose |
|-------|------|---------|---------|
| **Skills** | Procedural | `~/.hermes/skills/` | Reusable workflows, created after complex tasks |
| **Memory** | Declarative | `MEMORY.md` (2,200 char) | Agent facts: environment, tool quirks, conventions |
| **User Model** | Declarative | `USER.md` (1,375 char) | User preferences, communication style, habits |
| **Session Search** | Episodic | SQLite + FTS5 | Cross-session recall via full-text search + LLM summarization |

### 4. Skills System (Procedural Memory) — THE KEY INNOVATION

**Storage**: `~/.hermes/skills/` with directory-per-skill:
```
skills/
  my-skill/
    SKILL.md           # YAML frontmatter + markdown instructions
    references/        # Supporting docs
    templates/         # Output templates
    scripts/           # Helper scripts
    assets/            # Supplementary files
```

**Two tools**: `skills_list` (browse metadata) and `skill_manage` (create/edit/patch/delete).

**Self-creation**: After completing complex tasks (5+ tool calls), the agent is prompted:
> "After completing a complex task, fixing a tricky error, or discovering a non-trivial workflow, save the approach as a skill so you can reuse it next time."

**Self-improvement during use**: Skills are patched in-place when found outdated:
> "When using a skill and finding it outdated, incomplete, or wrong, patch it immediately with skill_manage(action='patch') — don't wait to be asked."

**Nudge system**: Turn-based counter tracks iterations since last skill creation. After configurable interval, agent receives a nudge to consider saving a skill. Resets when `skill_manage` is called.

**Security**: All agent-created skills pass through `skills_guard.py` — checks for injection patterns, exfiltration attempts, hidden commands.

**Progressive disclosure**: Tier 1 (metadata in list) → Tier 2 (full instructions via view) → Tier 3 (reference files on demand). Keeps token usage minimal.

**Skills Hub**: Compatible with `agentskills.io` open standard for community sharing.

### 5. Memory System

- `MEMORY.md` (2,200 chars): Agent's personal notes about environment, tool quirks, conventions
- `USER.md` (1,375 chars): User profile — preferences, communication style, workflow habits
- **Frozen snapshot pattern**: Loaded at session start into system prompt. Mid-session writes update disk but NOT the active prompt. Fresh state on next session.
- **Atomic operations**: File locking with `fcntl.LOCK_EX`, atomic rename via `os.replace`.
- **Security scanning**: All memory content scanned for prompt injection before acceptance.
- **Nudge system**: After N user turns, agent is nudged to consider what's worth remembering.

### 6. Session Search (Episodic Memory)

1. FTS5 search finds matching messages ranked by relevance
2. Groups by session, takes top N unique sessions (default 3)
3. Loads each session's conversation, truncates to ~100K chars centered on match
4. Sends to cheap/fast model (Gemini Flash) for focused summarization
5. Returns per-session summaries with metadata

### 7. Context Compression

- Prune old tool results (cheap pre-pass, no LLM)
- Protect head (system prompt + first exchange) and tail (~20K tokens recent)
- Summarize middle turns with structured prompt (Goal, Progress, Decisions, Files, Next Steps)
- Iterative updates — subsequent compactions update previous summary
- Triggers at 50% of model context length

### 8. Subagent Delegation

- Fresh conversation per child (no parent history)
- Own task_id, restricted toolset, focused system prompt
- Independent iteration budget (default 50)
- Max depth of 2 (no recursive delegation)
- **Blocked tools for children**: `delegate_task`, `clarify`, `memory`, `send_message`, `execute_code`
- Up to 3 concurrent children via ThreadPoolExecutor

---

## What dx-aem-flow Already Has (Comparison)

| Hermes Concept | dx-aem-flow Equivalent | Gap |
|----------------|----------------------|-----|
| Skills (procedural memory) | `plugins/*/skills/*/SKILL.md` — static, author-written | No dynamic creation or self-patching |
| Memory (declarative) | `.ai/config.yaml` + `.ai/rules/*.md` + `.ai/project/*` | Already covered |
| User model | — | No user preference modeling |
| Session search (episodic) | — | No cross-session recall |
| Skill nudge system | — | No prompts to create/improve skills |
| Run logging | `.ai/learning/raw/runs.jsonl` | Already present |
| Error tracking | `.ai/learning/raw/fixes.jsonl` | Already present |
| Pattern promotion | `learned-fix-*.md` rules (3+ successes → rule) | Already present, limited scope |
| Bug hotspot detection | `.ai/learning/raw/bugs.jsonl` (3+ bugs → flag) | Already present |
| Security scanning | `shared/external-content-safety.md` | External content only, not learned content |
| Subagent delegation | `context: fork` + `agent:` frontmatter | Already present |
| Context compression | — | Not applicable (harness handles) |

**Key insight**: dx-aem-flow already has the **observation infrastructure** (learning files, fix tracking, promotion). What it lacks is the **active self-improvement loop**. But unlike Hermes (which owns its skills locally), dx plugins are **released from GitHub and updated via CLI** — they're immutable from the project's perspective. Self-improvement must happen in the **project layer** (`.ai/`), with plugin skills reading project-level enhancements at runtime.

---

## Architecture Constraint: Plugin vs Project Separation

```
IMMUTABLE (released from GitHub, updated via CLI)     MUTABLE (per-project, agent can write)
─────────────────────────────────────────────         ──────────────────────────────────────
~/.claude/plugins/dx-core/                            <project>/.ai/
  skills/dx-plan/SKILL.md                               config.yaml
  skills/dx-step/SKILL.md                               project/component-index.md
  agents/dx-code-reviewer.md                             project/file-patterns.yaml
  rules/plan-format.md                                   learning/raw/*.jsonl
  shared/error-handling.md                               learning/skills/       ← NEW
                                                           dx-plan/
~/.claude/plugins/dx-aem/                                    enhancements.md    ← NEW
  skills/aem-verify/SKILL.md                               dx-step/
  skills/aem-component/SKILL.md                              enhancements.md    ← NEW
  agents/aem-inspector.md                                specs/<id>-<slug>/
                                                         rules/
                                                           plan-format.md       (override)
                                                           learned-fix-*.md     (promoted)
```

**The pattern**: Plugin skills remain the canonical source of truth. Project-level enhancement files **augment** plugin behavior without modifying the plugin. When you release a new plugin version, enhancements layer on top of the updated skill.

---

## Actionable Ideas for dx-aem-flow

### Idea 1: Skill Enhancement Files (CORE MECHANISM)

**The Hermes problem adapted**: Hermes patches skills in-place. dx can't — plugins are immutable. Instead, plugin skills load project-level enhancement files if they exist.

**Convention**: `.ai/learning/skills/<skill-name>/enhancements.md`

**How a plugin skill loads it** (add to SKILL.md):
```markdown
## Project-Learned Enhancements
If `.ai/learning/skills/<this-skill>/enhancements.md` exists, read it.
These are project-specific lessons learned from prior executions.
Apply them as additional constraints/steps alongside the base skill.
```

**What goes in an enhancement file** (agent-generated):
```markdown
# Project Enhancements for dx-plan

## Additional Steps (learned)
- After component implementation steps, always add an /aem-verify step
  (Evidence: 5 tickets required manual verification catch-up)

## Project-Specific Pitfalls
- Import paths use `@project/` alias, not relative `../` paths
  (Evidence: 4 compilation fixes across tickets 2435084, 2435091, ...)

## Adjusted Defaults
- Default test command for this project: `mvn test -pl ui.frontend`
  (config.yaml has full build; this is faster for step-level checks)
```

**How enhancements get created**:
1. After `dx-step-all` completes, the post-completion reflection (see Idea 4) analyzes what went wrong/right
2. Patterns that recur (from `fixes.jsonl`) get promoted into the relevant skill's enhancement file
3. Enhancement files are bounded (e.g., 2,000 chars) — forced curation, not unbounded append

**Why this works**:
- Plugin gets updated via CLI → enhancement file still applies (additive, not override)
- Different projects get different enhancements (per-project learning)
- Can be `.gitignore`d (per-developer) or committed (shared team knowledge)
- No plugin code changes needed — just add the "load if exists" line to skills

### ~~Idea 2: Agent Memory Layer~~ — ALREADY COVERED

Project memory already exists across `.ai/config.yaml`, `.ai/rules/*.md`, `.ai/project/component-index.md`, `.ai/project/file-patterns.yaml`, `.ai/project/project.yaml`, `.ai/project/content-paths.yaml`, and `.ai/learning/raw/*.jsonl`. Adding a separate `memory.md` would be redundant. Developer preferences are covered by `.claude/settings.local.json` and personal CLAUDE.md.

**Hermes needs MEMORY.md because it has no structured project layer.** dx-aem-flow already has one — `.ai/` IS the memory.

### Idea 3: Post-Completion Reflection / Skill Nudge (LOW EFFORT, MEDIUM VALUE)

**What Hermes does**: Turn-based nudge counter + post-task skill creation prompt.

**What to add**: Prompt additions to coordinator skills (`dx-step-all`, `dx-bug-all`, `dx-req-all`):

```markdown
## Post-Completion Reflection

After completing all steps, spend 30 seconds reflecting:

1. **Fix patterns**: Did any error→fix recur? Check `.ai/learning/raw/fixes.jsonl`.
   If a pattern has 3+ successes, promote to `.ai/learning/skills/<skill>/enhancements.md`.

2. **Missing steps**: Did the plan miss something you had to add manually?
   Append to `.ai/learning/skills/dx-plan/enhancements.md`:
   `- Always include <what was missing> (Evidence: ticket <id>)`

3. **Project knowledge**: Did you discover a build quirk, convention, or shortcut?
   Append to `.ai/memory.md` (keep under 3,000 chars total — curate, don't hoard).

4. **Skill feedback**: Did a plugin skill give wrong/outdated guidance?
   Log to `.ai/learning/raw/skill-feedback.jsonl`:
   `{"skill":"<name>","ticket":"<id>","issue":"<what was wrong>","suggestion":"<fix>"}`
```

**No new skills or hooks needed** — just prompt additions to existing coordinators.

### Idea 4: Richer Fix Promotion (LOW EFFORT, HIGH VALUE)

**What Hermes does**: Creates full skill directories with procedures, pitfalls, verification.

**What dx already has**: `learned-fix-*.md` in `.claude/rules/` — one-liner rules.

**What to change**: Instead of (or in addition to) promoting to `.claude/rules/learned-fix-*.md`, also update the relevant skill's enhancement file:

```
Current flow:
  fixes.jsonl → (3+ successes) → .claude/rules/learned-fix-<slug>.md

New flow:
  fixes.jsonl → (3+ successes) → .claude/rules/learned-fix-<slug>.md        (keep, for rules layer)
                               → .ai/learning/skills/dx-step/enhancements.md  (NEW, for skill context)
```

The enhancement file gives richer context to the skill than a standalone rule. The rule fires as an always-on convention; the enhancement adds diagnostic steps and verification.

### Idea 5: Skill Feedback Loop → Plugin Author (MEDIUM EFFORT, HIGH VALUE)

**What Hermes does**: `skill_manage(patch)` modifies skills directly.

**Adapted for dx**: Since plugins are released from GitHub, project-level feedback can flow **upstream** to the plugin author.

**Mechanism**:
```
.ai/learning/raw/skill-feedback.jsonl
```

A new `dx-skill-feedback-report` skill reads this file and generates a summary:
```markdown
# Skill Feedback Report (2026-Q1)

## dx-plan (4 feedback items)
- Missing step: AEM dialog validation after component impl (3 occurrences)
- Missing step: Cross-repo sync check for shared components (2 occurrences)

## dx-step (2 feedback items)  
- Wrong default: Uses `mvn install` but project needs `mvn install -P autoInstallPackage`
```

This report can be:
- Attached to a GitHub issue on the plugin repo
- Used by the plugin author to improve the next release
- Aggregated across projects (if teams share reports) to prioritize improvements

This is the dx equivalent of Hermes's self-evolution outer loop — but with a human in the loop (plugin author reviews and releases).

### Idea 6: Cross-Session Recall via Specs (MEDIUM EFFORT, HIGH VALUE)

**What Hermes does**: SQLite + FTS5 full-text search over past sessions.

**What dx already has**: `.ai/specs/<id>-<slug>/` with structured output per ticket.

**What to add**: A `dx-recall` skill:
```markdown
---
name: dx-recall
description: "Search past specs and learning data for relevant patterns"
argument-hint: "<query>"
model: haiku
effort: low
---

1. Search `.ai/specs/*/research.md` and `.ai/specs/*/implement.md` for query matches
2. Search `.ai/learning/raw/fixes.jsonl` for related error types
3. Search `.ai/learning/skills/*/enhancements.md` for relevant learned patterns
4. Summarize findings: what worked, what didn't, which approach to reuse
```

Simpler than Hermes's SQLite approach — specs are already structured and searchable.

### Idea 7: Confidence Calibration (LOW EFFORT, MEDIUM VALUE)

Track review accuracy in `.ai/learning/raw/reviews.jsonl`:
```jsonl
{"review_id":"PR-123-finding-4","confidence":85,"outcome":"accepted|rejected"}
```

Over time, `dx-code-reviewer` reads this to auto-adjust its confidence threshold per project. Some projects have stricter standards (raise threshold); others are more tolerant (lower it).

---

## Priority Ranking (Revised)

| # | Idea | Effort | Value | Where It Lives |
|---|------|--------|-------|----------------|
| 1 | **Skill enhancement files** | Low | High | `.ai/learning/skills/<name>/enhancements.md` |
| 2 | **Post-completion reflection** | Low | Medium | Prompt additions to coordinator skills |
| 3 | **Richer fix promotion** | Low | High | Enhancement files + existing `learned-fix-*.md` |
| 4 | **Cross-session recall** | Medium | High | New `dx-recall` skill |
| 5 | **Skill feedback → upstream** | Medium | High | `.ai/learning/raw/skill-feedback.jsonl` → reports |
| 6 | **Confidence calibration** | Low | Medium | `.ai/learning/raw/reviews.jsonl` |
| ~~7~~ | ~~Agent memory~~ | — | — | Already covered by `.ai/` structure |

## Implementation Order

**Phase 1 (minimal plugin changes):**
- Add "load enhancements.md if exists" line to 4-5 key skills (dx-plan, dx-step, dx-step-all, dx-step-fix, dx-req)
- Add post-completion reflection prompt to dx-step-all and dx-bug-all

**Phase 2 (one new skill + promotion update):**
- Create `dx-recall` skill
- Update fix promotion to also write to enhancement files

**Phase 3 (feedback loop):**
- Create `dx-skill-feedback-report` skill
- Aggregate feedback across projects for plugin improvement

---

## Bonus: hermes-agent-self-evolution (Separate Repo)

[NousResearch/hermes-agent-self-evolution](https://github.com/NousResearch/hermes-agent-self-evolution) implements **automated evolutionary improvement** without GPU training — using API calls at ~$2-10 per optimization cycle.

**How it works:**
1. Read current skill files / prompts / tools
2. Generate evaluation data from existing capabilities
3. **GEPA** (Genetic-Pareto Prompt Evolution) analyzes execution traces to understand **why** things fail
4. Generate candidate variants based on trace insights
5. Test variants against constraints (100% test pass, size limits, semantic fidelity)
6. Submit best variant as PR for human review — **no direct commits**

**Optimization phases:** Skill files (implemented) → Tool descriptions → System prompts → Tool implementation code → Continuous loop.

**dx-aem-flow relevance:** This is the "outer loop" — while Hermes's in-session skill patching is the inner loop (immediate fixes), GEPA is the outer loop (deliberate optimization across many runs). For dx, this maps to periodically analyzing `.ai/learning/raw/*.jsonl` across multiple tickets to optimize skill prompts and plan templates.

---

## Key Hermes Design Principles Worth Adopting

1. **Frozen snapshot pattern**: Load memory/context at session start, never mutate mid-session. Write updates for next session. This preserves prefix cache and avoids mid-conversation drift.

2. **Bounded enhancement files**: Hermes caps MEMORY.md at 2,200 chars. Enhancement files should be similarly bounded (e.g., 2,000 chars) to force curation — the agent must decide what's truly worth keeping. Unbounded files become noise.

3. **Progressive disclosure for skills**: Don't dump all skill content into context. Show metadata (name, description) first, load full instructions only when invoked. dx-aem-flow already does this via SKILL.md frontmatter.

4. **Security scanning on learned content**: Any agent-generated content (enhancement files, fix patterns) should be scanned for injection patterns before being loaded into future sessions. This prevents a compromised session from poisoning future ones.

5. **Nudge, don't force**: Hermes nudges the agent to consider saving skills/memory at intervals. It doesn't mandate it. This keeps the agent focused on the task while opportunistically capturing knowledge.

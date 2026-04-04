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
| Memory (declarative) | `.ai/config.yaml` + `.ai/rules/*.md` | No session-level agent memory |
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

**Key insight**: dx-aem-flow already has the **observation infrastructure** (learning files, fix tracking, promotion). What it lacks is the **active self-improvement loop** — skills that create skills, skills that patch themselves, and a memory layer that captures operational knowledge.

---

## Actionable Ideas for dx-aem-flow

### Idea 1: Self-Improving Fix Patterns (LOW EFFORT, HIGH VALUE)

**What Hermes does**: After a complex task, the agent autonomously creates a skill capturing the workflow.

**What dx already has**: `fixes.jsonl` tracks error→fix pairs, promotes to `learned-fix-*.md` rules at 3+ successes.

**What to add**: Extend the promotion mechanism to generate richer "fix skills" instead of simple rules:

```
.ai/learning/promoted/
  fix-compilation-missing-import/
    SKILL.md          # Full diagnostic + fix workflow
    patterns.md       # Error signatures that trigger this fix
    evidence.md       # Ticket IDs, success rates, timestamps
```

**Benefit**: Current `learned-fix-*.md` rules are one-liners. A promoted skill can include diagnostic steps, common variations, and verification commands — making the fix more reliable across diverse occurrences.

**Implementation**: Add a `dx-learning-promote` skill that runs periodically (or in the Stop hook) to scan `fixes.jsonl` and upgrade mature patterns into full skill directories under `.ai/learning/promoted/`.

### Idea 2: Skill Patching / Self-Improvement (MEDIUM EFFORT, HIGH VALUE)

**What Hermes does**: `skill_manage(action='patch')` — when using a skill and finding it outdated or incomplete, patch it immediately.

**What to add**: A `dx-skill-feedback` mechanism where skills can record improvement suggestions:

```yaml
# .ai/learning/raw/skill-feedback.jsonl
{
  "timestamp": "2026-04-04T10:00:00Z",
  "skill": "dx-plan",
  "ticket": "2435084",
  "feedback_type": "missing_step",
  "description": "Plan didn't include AEM dialog XML validation step",
  "suggested_addition": "After component implementation, verify dialog XML with /aem-verify"
}
```

**How it works**:
1. Skills log feedback when they encounter gaps (e.g., dx-step-fix finds a pattern the plan missed)
2. A periodic `dx-skill-review` skill reads feedback, clusters by skill, and suggests patches
3. Author reviews and applies (keeping human-in-the-loop for plugin skills)

For **project-level skills** (`.claude/skills/`), the agent could apply patches directly — these are project-specific and lower risk.

### Idea 3: Agent Memory Layer (MEDIUM EFFORT, HIGH VALUE)

**What Hermes does**: `MEMORY.md` — compact declarative memory (2,200 chars) capturing environment facts, tool quirks, and conventions. Frozen at session start, updated for next session.

**What to add**: Per-project agent memory file:

```
.ai/memory.md          # Project-level agent memory (persists across sessions)
```

**Content examples**:
- "Build takes ~4 minutes on this project; use `mvn -pl <module>` for faster iteration"
- "AEM author instance runs on port 4502 but QA is behind VPN — use publish for remote checks"
- "Component dialog fields use `granite/ui/components/coral/foundation/form/textfield`, not the deprecated `granite/ui/components/foundation/form/textfield`"
- "Team prefers explicit null checks over Optional pattern"

**How it works**:
1. SessionStart hook loads `.ai/memory.md` into context (already possible via context-loader)
2. Stop hook (or a new PostToolUse hook) nudges agent: "Anything worth remembering from this session?"
3. Agent appends to `.ai/memory.md` (bounded, say 3,000 chars)
4. `.gitignore` it (per-developer) or commit it (shared team knowledge)

### Idea 4: Skill Nudge System (LOW EFFORT, MEDIUM VALUE)

**What Hermes does**: Turn-based counter. After N tool iterations without creating a skill, nudge the agent.

**What to add**: A PostToolUse hook that counts significant actions (build fixes, complex file edits, multi-step debugging) and suggests: "You just completed a complex workflow. Consider saving this as a learned pattern."

**Implementation**: Add to `dx-step-all` and `dx-bug-all`:
```markdown
## Post-Completion Reflection
After completing all steps, review the session:
1. Did you discover a non-obvious pattern? → Log to `fixes.jsonl`
2. Did you develop a multi-step debugging workflow? → Log to `skill-feedback.jsonl`
3. Did you find a project-specific convention? → Append to `.ai/memory.md`
```

This is the cheapest version — no new tooling, just prompt additions to existing coordinator skills.

### Idea 5: Cross-Session Search (HIGH EFFORT, HIGH VALUE)

**What Hermes does**: SQLite + FTS5 full-text search over all past sessions, summarized by a cheap model.

**What dx already has**: Spec directories persist structured output per ticket.

**What to add**: A `dx-recall` skill that searches across spec directories:

```bash
# Search all past specs for relevant patterns
grep -r "dialog XML" .ai/specs/*/research.md .ai/specs/*/implement.md
```

**Implementation**: A skill that:
1. Takes a query (e.g., "how did we handle multi-field dialogs?")
2. Searches `.ai/specs/*/` with Grep for relevant content
3. Summarizes findings from matching specs
4. Optionally checks `.ai/learning/raw/*.jsonl` for related fix patterns

This is simpler than Hermes's SQLite approach because dx already structures output into searchable spec files.

### Idea 6: Skills Hub / Community Sharing (HIGH EFFORT, LONG-TERM)

**What Hermes does**: `agentskills.io` open standard for publishing and installing community skills.

**What to add**: The plugin marketplace (`/plugin marketplace`) already exists. Extend it with:
- A "community skills" section where teams can publish learned-fix skills
- Cross-project pattern sharing (e.g., "AEM dialog validation" skill works for any AEM project)
- Security scanning on install (similar to Hermes's `skills_guard.py`)

This is already partially in place with the marketplace architecture. The gap is enabling **agent-generated** skills to flow into the marketplace.

### Idea 7: Confidence-Calibrated Reviews (LOW EFFORT, MEDIUM VALUE)

**What Hermes does**: Not directly — but its memory system enables tracking accuracy over time.

**What dx already has**: `dx-code-reviewer` uses >= 80 confidence threshold.

**What to add**: Track review accuracy in learning files:
```jsonl
{"timestamp": "...", "review_id": "PR-123-finding-4", "confidence": 85, "outcome": "accepted|rejected|modified"}
```

Over time, calibrate the threshold: if findings at 80-85 confidence are consistently rejected, raise the threshold. If findings at 75-80 are consistently accepted, lower it.

---

## Priority Ranking

| # | Idea | Effort | Value | Hermes Parallel |
|---|------|--------|-------|-----------------|
| 1 | Skill nudge (prompt additions) | Low | Medium | Nudge system |
| 2 | Self-improving fix patterns | Low | High | Skill auto-creation |
| 3 | Agent memory layer | Medium | High | MEMORY.md |
| 4 | Skill feedback/patching | Medium | High | skill_manage(patch) |
| 5 | Cross-session search (dx-recall) | Medium | High | Session search |
| 6 | Confidence calibration | Low | Medium | Memory + accuracy tracking |
| 7 | Skills hub / community sharing | High | Long-term | agentskills.io |

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

2. **Bounded memory**: Hermes caps MEMORY.md at 2,200 chars and USER.md at 1,375 chars. Bounded stores force curation — the agent must decide what's truly worth remembering. Unbounded stores become noise.

3. **Progressive disclosure for skills**: Don't dump all skill content into context. Show metadata (name, description) first, load full instructions only when invoked. dx-aem-flow already does this via SKILL.md frontmatter.

4. **Security scanning on learned content**: Any agent-generated content (skills, memory, fix patterns) should be scanned for injection patterns before being loaded into future sessions. This prevents a compromised session from poisoning future ones.

5. **Nudge, don't force**: Hermes nudges the agent to consider saving skills/memory at intervals. It doesn't mandate it. This keeps the agent focused on the task while opportunistically capturing knowledge.

6. **Separate agent memory from user memory**: Hermes splits MEMORY.md (agent's operational notes) from USER.md (user preferences). dx could split `.ai/memory.md` (project ops) from `.ai/preferences.md` (developer prefs).

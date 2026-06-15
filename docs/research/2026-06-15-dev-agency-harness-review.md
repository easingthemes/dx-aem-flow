# Dev Agency Harness Review — June 2026

External best-practice sweep + internal codebase audit.
Delta to: [2026-05-30-salesforce-agentic-engineering.md](2026-05-30-salesforce-agentic-engineering.md)

---

## TL;DR — Five Things That Matter

1. **Harness engineering is now a named discipline.** LangChain's March 2026 result (30→5 on Terminal Bench 2.0 with zero model changes) validated the thesis. The harness, not the model, determines production reliability.
2. **Victory-declaration bias is our #1 unaddressed failure mode.** We have `dx-step-verify` but it is not wired into the `Stop` hook — agents can declare done without running it. LangChain's key win was a self-verification loop at session end.
3. **Microsoft CodeAct (Build 2026) reduces orchestration token cost 63.9%.** One Python program replaces multi-turn tool chains. Track for dx-automation.
4. **Our cross-platform story is broken for Copilot/Cursor.** `.github/hooks/hooks.json` is missing; `hooks-cursor.json` is referenced but doesn't exist. Safety is Claude-Code-only.
5. **Overall rating: 7/10.** Architecture and philosophy are ahead of most agencies. Execution gaps are in cross-platform parity, Stop-hook enforcement, and observability.

---

## External Landscape (April–June 2026, Verified)

### Harness Engineering Landmark: LangChain Terminal Bench 2.0

**Verified across 5+ independent sources** including LangChain's own engineering blog:

- Agent moved from **52.8% → 66.5% on Terminal Bench 2.0** (30th → 5th place)
- Zero model changes; pure harness optimization
- Three levers: self-verification loops in system prompt, loop-detection middleware hooks, improved context injection with environment grounding
- LangSmith tracing at scale was used to identify failure modes first

Source: [langchain.com/blog/improving-deep-agents-with-harness-engineering](https://www.langchain.com/blog/improving-deep-agents-with-harness-engineering)

**What this means for us:** Our `dx-step-verify` exists but is not called from the `Stop` hook. An agent running `/dx-step` can complete, declare success, and stop — without the evaluator ever firing. Wiring verify into `Stop` is the single highest-ROI change.

### Claude Code v2.1.154 (May 28, 2026) — Key Changes

- **Opus 4.8 is now the default model** (already reflected in our CLAUDE.md via TODO #134)
- **Lean system prompt default** for all models except Haiku/Sonnet/Opus 4.7 — skills need less prose
- `effort: high` is Opus 4.8's default; `xhigh` is the escalation above that (already updated)
- **Plugins auto-load** from `.claude/skills/` without the marketplace
- **Dynamic Workflows** added as a new primitive (experimental; track for coordinator patterns)
- `claude plugin init <n>` scaffolds plugins locally

Source: [claudeupdates.dev/version/2.1.154](https://www.claudeupdates.dev/version/2.1.154)

### Microsoft CodeAct (Build 2026)

See dedicated research file: [2026-06-15-microsoft-codeact.md](2026-06-15-microsoft-codeact.md)

Three-line summary: Instead of multi-turn tool calls (model picks tool → runs → reads result → repeats), one short Python program calls all tools via `call_tool()`, runs once in a sandbox. Microsoft reports 52.4% faster, 63.9% fewer tokens on their benchmarks. Not yet in any Claude Code harness.

### Superpowers (~93k GitHub stars by March 2026)

The most-adopted open-source Claude Code harness. Same philosophy (opinionated methodology as markdown files) but domain-agnostic. Key difference from dx-aem-flow:

| Superpowers | dx-aem-flow |
|------------|-------------|
| Domain-agnostic | ADO/AEM vertical |
| Skills for general dev culture | Skills for specific ADO workflow |
| No automation pipelines | Lambda + Service Hook automation |
| No MCP server integration | 6 MCP servers with correct prefixes |
| ~93k stars, broad community | Narrow audience, deep integration |

We are ahead on vertical depth and automation infrastructure. They are ahead on breadth and discoverability.

Source: [claudedirectory.org/plugins/superpowers](https://www.claudedirectory.org/plugins/superpowers)

### Verified Production Failure Modes (2026)

**Compound reliability degradation** — mathematically verified:
- 85% per-step accuracy → 20% success on 10-step workflows (0.85^10 = 0.197)
- 95% per-step accuracy → 60% success on 10-step workflows
- Our ADO automation agents run 9–15 step workflows; this math applies directly

**Victory declaration bias** — agents mark tasks complete without verifying:
- Addressed by LangChain's Stop-hook self-verification
- We have `dx-step-verify` but it requires explicit invocation
- **Fix: wire into Stop hook with `DX_TICKET` guard**

**Context anxiety** — models cut corners as context fills:
- Addressed by our context: fork pattern (already good)
- Also addressed by `PreCompact` / `PostCompact` hooks (already documented)

**Collusive validation** — agents in multi-agent systems confirm each other's errors:
- Addressed by `dx-code-reviewer` using independent passes (already good)
- Our fan-out coordinators pass summaries back, not raw output (already good)

**Source with minimal verification risk:**
- 24% linear chain failure rate with one faulty agent (AgentSpawn research, single source — treat as directionally correct, not precise)
- "Multi-agent 16% on-time vs single 65%" — single source, no methodology, **do not cite**

### MCP Landscape

10,000+ servers, 97M monthly downloads. Actually-valuable servers in production:
GitHub, Slack, Figma, ADO/Azure DevOps, Playwright, Linear, Sentry.

Our choices (ADO, Atlassian, Figma, axe, AEM, Playwright) are correct for the vertical.

The 5,800+ ecosystem servers break down: Developer Tools (1,200+), Business Apps (950+), Web/Search (600+), AI/Automation (450+). Most are unmaintained community wrappers with low real adoption. Assess by GitHub stars + npm downloads, not by count.

### Orchestration Patterns That Work

From verified production deployments:

| Pattern | Works | Failure mode to watch |
|---------|-------|----------------------|
| Supervisor/worker | ✓ | Context overflow at 4+ workers |
| Fan-out/fan-in | ✓ | API rate limits; quadratic race conditions |
| Sequential pipeline | ✓ | Error propagation; 3x token overhead |
| Multi-agent debate | ✗ often | Infinite loops; sycophancy cascading |
| Dynamic handoff | Situational | Routing loops; context loss per transfer |

We use supervisor/worker (coordinator + specialist subagents) and sequential pipeline (9-phase dx-agent-all). Both are validated patterns.

**Princeton NLP finding (verified by beam.ai):** A single agent matched or outperformed multi-agent systems on 64% of benchmarked tasks. Most tasks don't need multiple agents.

---

## Codebase Audit — June 15, 2026

Full codebase read: 77 skills, 13 agents, hooks in 4 plugins, templates, CLI, automation, 156 TODOs.

### Area Scores

| Area | Score | Key Issue |
|------|-------|-----------|
| Skills | 6.5/10 | 62/77 missing `model`/`effort`; 3 skills >260 lines (Copilot truncates) |
| Agents | 7/10 | `dx-code-reviewer` missing `tools:`; no agents for dx-automation |
| Hooks (Claude Code) | 8/10 | Exit codes correct, matchers precise, profile gating partial |
| Hooks (Copilot/Cursor) | 2/10 | `.github/hooks/hooks.json` missing; `hooks-cursor.json` phantom |
| Config schema | 7.5/10 | No migration scripts, no config validation gate |
| MCP naming | 8.5/10 | All 213 refs correct; zero bare shortcuts found |
| Cross-platform | 4/10 | Copilot hooks missing, GEMINI.md 2-line stub, Cursor manifests broken |
| CLI scaffold | 8/10 | Solid but doesn't generate Copilot hooks; plugin discovery hardcoded |
| Automation agents | 4.5/10 | No local agents; recovery state machine incomplete in places |
| TODO tracker | 3/10 | 113 open of 156; no quarterly roadmap; 6 critical blockers |
| Documentation | 5.5/10 | Only tips in website, no guide tree; inconsistent terminology |
| **Overall** | **7/10** | **Production-usable for Claude Code. Cross-platform broken.** |

### Where We're Ahead

| Practice | External state | Ours |
|----------|---------------|------|
| Config-driven (no hardcoding) | Rarely enforced | ✓ Systematic, 3-layer override |
| Model tier strategy | Ad-hoc in most harnesses | ✓ Opus/Sonnet/Haiku with tier table |
| Exit code 2 for blocking hooks | ~50% of examples use exit 1 (wrong) | ✓ Correct |
| MCP tool prefix naming | Frequently wrong in examples | ✓ 213 refs, all correct |
| DOT digraph flow control | Almost nobody does this | ✓ 21 branching skills use it |
| Resumable recovery (SimpleAgent, BugFix) | Very rare | ✓ Per-ticket branch as state store |
| Superpowers soft-dependency pattern | Not seen elsewhere | ✓ 6 skills with fallback |
| ADO pipeline automation | Not public anywhere | ✓ Unique vertical integration |
| Spec directory convention | Uncommon | ✓ Predictable per-ticket output |

### Where We're Behind

| Practice | External state | Ours |
|----------|---------------|------|
| Observability/tracing | LangSmith, OpenTelemetry widespread | ✗ None |
| Circuit breaker pattern | Growing adoption | ✗ None |
| Stop-hook verification loop | Core to LangChain's benchmark win | ✗ Not wired |
| Copilot CLI hook safety | Competitors have it | ✗ `.github/hooks/hooks.json` missing |
| Config validation | Most frameworks validate at startup | ✗ No schema validation |
| Skills <200 lines for multi-platform | Industry norm | ✗ 3 skills over 260 lines |

---

## Top 5 Highest-ROI Fixes

**1. Wire `Stop` hook → verification loop** (TODO #159, ~1 day)
Self-verification before declaring done. Guards against victory-declaration bias — the #1 production failure mode. Call `dx-step-verify` (already exists) from a `Stop` hook when `DX_TICKET` is set. This is exactly what moved LangChain 25 spots.

**2. Port hooks to `.github/hooks/hooks.json`** (TODO #22, ~3 days)
Branch guard, next-step hints, and workflow state for Copilot CLI users. Currently zero safety on Copilot. Wire `GITHUB_COPILOT_PROMPT_MODE_REPO_HOOKS=1` into `/dx-init` at same time (TODO #97).

**3. Add `model` + `effort` to all 62 remaining skills** (~2 days, mechanical)
Lambda automation agents can't replicate local skill behavior without these. The tier table in CLAUDE.md is correct — stamp it onto frontmatter.

**4. Fix `hooks-cursor.json` manifests** (TODO #69-cross-platform, 2 hours)
4 `.cursor-plugin/plugin.json` files reference non-existent files. Either create them (port hooks.json) or remove the `hooks` field.

**5. Evaluate Microsoft CodeAct for dx-automation** (TODO #158, research)
63.9% token reduction on multi-tool orchestration. If it holds up for ADO-workflow tool chains, it changes how we sequence automation agent steps.

---

## Open Questions for Next Review

- Is Dynamic Workflows (v2.1.154) a replacement for our `context: fork` + subagent pattern, or complementary?
- Does CodeAct's single-sandbox-script model work with async ADO REST calls (our primary automation tool use)?
- Should we add `dx-doctor` config schema validation as a `SessionStart` hook or a standalone skill step?

---

**Next research update:** Check v2.1.160+ changelog for Dynamic Workflows maturation + any hook system changes.
Last platform state: [2026-05-29-platform-state-update.md](2026-05-29-platform-state-update.md)

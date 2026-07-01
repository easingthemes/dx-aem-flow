# Dev Agency Harness Review — June 2026

External best-practice sweep + internal codebase audit.
Delta to: [2026-05-30-salesforce-agentic-engineering.md](2026-05-30-salesforce-agentic-engineering.md)

---

## TL;DR — Five Things That Matter

1. **Harness engineering is now a named discipline.** LangChain's March 2026 result (30→5 on Terminal Bench 2.0 with zero model changes) validated the thesis. The harness, not the model, determines production reliability.
2. **Victory-declaration bias is our #1 unaddressed failure mode.** We have `dx-step-verify` but it is not wired into the `Stop` hook — agents can declare done without running it. LangChain's key win was a self-verification loop at session end.
3. **Microsoft CodeAct (Build 2026) reduces orchestration token cost 63.9%.** One Python program replaces multi-turn tool chains. Track for dx-automation.
4. **Our cross-platform story is broken for Copilot/Cursor.** `.github/hooks/hooks.json` is missing; `hooks-cursor.json` is referenced but doesn't exist. Safety is Claude-Code-only.
5. **Ratings by platform scope (disregarding easy/mechanical fixes — see below):**

| Scope | Rating | Key blocker |
|-------|--------|-------------|
| All platforms (raw) | 7/10 | Cross-platform gaps pull it down |
| Claude + Copilot only | **7.5/10** | `.github/hooks` missing; oversized skills break Copilot reads |
| Claude only | **8/10** | Stop-hook verify not wired; no local automation agents |

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

## Adjusted Ratings by Platform Scope

The raw 7/10 includes drag from mechanical tasks (adding `model`/`effort` to 62 skills, one-liner agent fixes, removing phantom manifest references, wiring env vars). These are real debt but don't represent structural design gaps. The ratings below disregard anything that is: mechanical repetition across files, a single-file patch, or under ~2 days of unambiguous work.

### What's Disregarded

| Item | Why disregarded |
|------|----------------|
| Add `model`/`effort` to 62 skills | Mechanical frontmatter, no design decisions |
| `dx-code-reviewer` missing `tools:` | One-line fix |
| Remove phantom `hooks-cursor.json` field from manifests | 30-minute manifests cleanup |
| Wire `GITHUB_COPILOT_PROMPT_MODE_*` into dx-init | 1-2 hour script addition |
| GEMINI.md stub | Copy AGENTS.md + minor edits, 1 hour |
| Remove `--additional-mcp-config` from setup docs | One doc line |
| Add TOC to reference files >100 lines | Low-effort formatting |

### Claude Only — **8/10**

Remaining structural gaps after disregarding easy fixes:

| Gap | Impact | TODO |
|-----|--------|------|
| `Stop` hook not wired to verification | Victory-declaration bias — #1 production failure mode; agents can claim done without verify ever running | #159 |
| No circuit breaker / observability | Runaway automation agents have no kill switch; no failure-rate data to tune against | #160 |
| No local agents for dx-automation | Can't develop/test automation workflows locally; pipeline-only is a development bottleneck | — |
| Config validation missing | Silent misconfiguration causes wrong-environment bugs that are hard to diagnose | #161 |
| TODO backlog governance | 118 open items with no quarterly roadmap — backlog grows faster than it closes | — |

**To reach 9/10 (Claude only):** Wire Stop-hook verify (#159) + circuit breaker (#160) + config validation (#161). Local automation agents would push it to 9.5.

The architecture is genuinely sound — config-driven, correct hook semantics, DOT digraph flow control, resumable recovery. The 8/10 gap is missing enforcement at session end and missing observability, not design flaws.

### Claude + Copilot — **7.5/10**

Same base as Claude-only plus two structural Copilot-specific gaps that are NOT easy fixes:

| Additional gap | Why it's structural | TODO |
|----------------|--------------------|----- |
| `.github/hooks/hooks.json` missing | 7 hooks to port with Copilot-specific event names, regex matchers (v1.0.36+), and cross-platform testing. Design decisions needed: which hooks translate, which need Copilot-specific behavior. Not mechanical. | #22 |
| 3 skills >200 lines break Copilot partial-reads | Copilot CLI partial-reads cut at ~100 lines; `aem-fe-verify` (366), `dx-step-verify` (439), `aem-component` (263) silently lose critical guidance. Fix requires content architecture decisions (what moves to `references/` vs stays inline), not just trimming. | #108 #113 |
| Shared/ path resolution (ongoing) | Copilot CLI path resolution for plugin `shared/` dirs has known issues (TODO #20). No fix released as of June 2026. Workaround exists but fragile. | #20 |

**To reach 9/10 (Claude + Copilot):** Port hooks (#22) + fix oversized skills (#108/#113) + resolve shared/ paths (#20) + all Claude-only gaps above.

The 0.5 gap between Claude-only and Claude+Copilot comes entirely from the `.github/hooks` absence — Copilot users get zero harness safety (branch protection, next-step guidance, workflow state tracking). That's a meaningful regression from the Claude Code experience.

---

## Top Structural Fixes (by platform scope)

### If Claude only

**1. Wire `Stop` hook → verification loop** (TODO #159, ~1 day)
Guards victory-declaration bias — the #1 production failure mode validated by LangChain's Terminal Bench result. `dx-step-verify` already exists; the hook guard is ~10 lines. Highest ratio of impact to effort in the entire backlog.

**2. Add circuit breaker — loop-detection PostToolUse hook** (TODO #160, ~1 day)
Same tool + args + file within 5 turns → exit 2 + ABORT. Prevents runaway automation agents from exhausting budget on a stuck cycle. Structural new capability, not a refinement.

**3. Config validation gate** (TODO #161, ~2 days)
`dx-doctor --config-validate` + optional `SessionStart` pre-flight. Catches silent misconfiguration before it causes wrong-environment bugs 8 phases into a run.

**4. Local agents for dx-automation** (large, but directionally important)
dx-automation has no `agents/` directory — can't develop or test automation locally. Even a single `auto-local-agent.md` that wraps the Lambda flow in a testable Claude Code agent would close this gap.

**5. Evaluate Microsoft CodeAct for dx-automation** (TODO #158, research)
63.9% token reduction on multi-tool orchestration. First check: does Dynamic Workflows (v2.1.154) already solve this natively? If not, pilot on read-heavy phases (dx-req Phase 1, auto-triage).

### If Claude + Copilot (add these on top)

**A. Port hooks to `.github/hooks/hooks.json`** (TODO #22, ~3 days)
Zero harness safety for Copilot users today. Branch guard, next-step hints, workflow state — all missing. This is the single biggest regression from the Claude experience. Not mechanical: requires event-name mapping, Copilot-specific regex (v1.0.36+), and integration testing.

**B. Refactor the 3 oversized skills** (`aem-fe-verify` 366 lines, `dx-step-verify` 439 lines, `aem-component` 263 lines) (TODO #108/#113, ~3 days)
Copilot CLI partial-reads truncate at ~100 lines — critical guidance at the bottom of these skills is silently invisible to Copilot users. Requires content architecture decisions (progressive disclosure via `references/`), not just trimming.

---

## Open Questions for Next Review

- Is Dynamic Workflows (v2.1.154) a replacement for our `context: fork` + subagent pattern, or complementary?
- Does CodeAct's single-sandbox-script model work with async ADO REST calls (our primary automation tool use)?
- Should we add `dx-doctor` config schema validation as a `SessionStart` hook or a standalone skill step?

---

## Re-review — June 16, 2026 (post-rebase with main PR #173)

PR #173 closed 6 open TODOs (#34, #97, #98, #104, #105, #133). Changes verified against the live codebase.

### What Changed

| TODO | Change | Verified |
|------|--------|---------|
| #34 | `validate-plugin-edit.sh` uses exit 2; removed `|| true` fallback in hooks.json | ✓ |
| #97/#98 | `dx-init/SKILL.md` exports both `GITHUB_COPILOT_PROMPT_MODE_REPO_HOOKS=1` and `WORKSPACE_MCP=1` with idempotent `grep -q` guard | ✓ |
| #104 | `dx-req` and `dx-plan` check `orchestrating.flag` with 7200-second age gate | ✓ |
| #105 | All 76 skills have `when_to_use:` frontmatter | ✓ |
| #133 | `auto-init` is now per-project only (`automationProfile: "per-project"`); hub/consumer question removed | ✓ |

### Updated Ratings

**Raw (all platforms): 7.5/10** (was 7/10, +0.5)

The five changes collectively close the most visible drag items: exit-code correctness makes hook safety reliable, `when_to_use` on all 76 skills is the primary skill-discovery signal for both Claude Code and Copilot CLI, and the KAI-HUB per-project simplification removes an architectural inconsistency that was surfacing in automation debug sessions.

| Area | Previous | Now | Driver |
|------|----------|-----|--------|
| Hook exit codes | Wrong (`|| true` suppressed exit 2) | ✓ Fixed | #34 |
| Skill discovery | 62/76 missing `when_to_use` | ✓ All 76 done | #105 |
| Copilot env vars | Not wired in dx-init | ✓ Wired + idempotent | #97/#98 |
| Orchestration guard | Missing re-entry flag | ✓ 7200s age gate | #104 |
| Automation model | Hub/consumer ambiguity | ✓ Per-project only | #133 |

**Claude only (disregarding easy/mechanical) — 8.5/10** (was 8/10, +0.5)

The `when_to_use` completion was the **HIGH** open item from the June 15 audit (skills scored 6.5/10 with this as the primary driver). With it done, skills score moves to ~8/10. Hub architectural simplification (#133) removes a class of debug confusion. Exit code fix (#34) means the blocking hook path now works correctly end-to-end.

Remaining structural gaps (unchanged from June 15 analysis):

| Gap | TODO | Impact |
|-----|------|--------|
| `Stop` hook not wired to `dx-step-verify` | #159 | Victory-declaration bias — agents can declare done without verify running |
| No circuit breaker / loop-detection | #160 | Runaway automation has no kill switch |
| No local agents for dx-automation | — | Can't develop or test automation workflows without deploying to Lambda |
| Config validation gate | #161 | Silent misconfiguration reaches phase 8 before surfacing |

**To reach 9/10 (Claude only):** Wire Stop-hook verify (#159) + circuit breaker (#160) + config validation (#161). These are structural new capabilities, each ~1 day.

**Claude + Copilot — 8/10** (was 7.5/10, +0.5)

+0.5 from: Copilot env vars now wired (#97/#98) — when `.github/hooks/hooks.json` is ported (#22), the env var precondition is already satisfied. `when_to_use` on all skills is the main discovery mechanism for Copilot CLI. Hub cleanup removes cross-platform config ambiguity.

Still 0.5 below Claude-only because `.github/hooks/hooks.json` does not exist — Copilot users get zero harness safety (no branch guard, no next-step hints, no workflow state tracking). That gap hasn't moved.

**To close the Claude vs. Claude+Copilot gap:** Port hooks (#22, ~3 days) + refactor oversized skills (#108/#113, ~3 days). Once those are done, Claude+Copilot should reach parity with Claude-only (9/10 if the Claude-only gaps are also closed).

---

**Next research update:** Check v2.1.160+ changelog for Dynamic Workflows maturation + any hook system changes.
Last platform state: [2026-05-29-platform-state-update.md](2026-05-29-platform-state-update.md)

---

## Follow-up — July 1, 2026 (Claude Code + Copilot CLI scoped re-rating)

A scoped re-rating against current official docs found skill bloat had **regressed** (13 skills now exceed Anthropic's 500-line ceiling vs. 3 over ~260 in June), pulling Claude Code to **8/10** and Copilot CLI to **6.5/10** (`.github/hooks/hooks.json` still missing).

See: [2026-07-01-plugin-eval-claude-copilot.md](2026-07-01-plugin-eval-claude-copilot.md)

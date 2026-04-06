# Plugin Architecture Review — Research Findings

**Date:** 2026-04-06
**Scope:** Full review of all 4 plugins, docs, website, ecosystem, and developer experience

---

## Executive Summary

The dx-aem-flow plugin architecture is at the leading edge of agentic workflow orchestration. The four-plugin design, config-driven skills, MCP integration, hook systems, cross-platform file generation, and CI-integrated automation agents represent best practices the broader ecosystem is converging toward. However, **the user-facing surface area doesn't match how developers want to enter the flow**. The core problem is discoverability, not complexity.

**Key finding:** The documentation for partial-flow usage exists ("Pick What You Need" in local.mdx, chaining-skills tip, etc.) but developers are still confused — the signal is buried under 76 skills, 51 tip articles, and a 28K workflow guide.

**One-line diagnosis:** The flow isn't too complex. The menu is too complex.

---

## 1. Inventory

### Skills by Plugin

| Plugin | Skills | Agents | Hooks | Purpose |
|--------|--------|--------|-------|---------|
| dx-core | 49 | 7 | Yes | Platform-agnostic ADO/Jira workflow (req -> plan -> execute -> review -> PR) |
| dx-hub | 4 | 0 | No | Multi-repo orchestration |
| dx-aem | 12 | 6 | Yes | AEM-specific QA, verification, demo capture |
| dx-automation | 11 | 0 | No | Autonomous agents (DoR/DoD, PR review, BugFix, QA, DevAgent) |
| **Total** | **76** | **13** | — | — |

Plus: 25 Copilot agents, 10 automation agents, 6 MCP servers, cross-platform files for 7+ tools.

### dx-core Skill Categories (49 skills)

| Category | Skills | Count |
|----------|--------|-------|
| Init & Setup | dx-init, dx-adapt, dx-scan, dx-doctor, dx-upgrade, dx-eject, dx-simplify, dx-sync | 8 |
| Requirements | dx-req, dx-req-dod, dx-req-import, dx-req-tasks | 4 |
| Estimation | dx-estimate | 1 |
| Ticket Analysis | dx-ticket-analyze | 1 |
| Planning | dx-plan, dx-plan-validate, dx-plan-resolve | 3 |
| Execution | dx-step, dx-step-all, dx-step-build, dx-step-fix, dx-step-verify | 5 |
| PR | dx-pr, dx-pr-commit, dx-pr-review, dx-pr-review-all, dx-pr-review-report, dx-pr-reviews-report, dx-pr-answer | 7 |
| Bug | dx-bug-all, dx-bug-triage, dx-bug-fix, dx-bug-verify | 4 |
| Figma | dx-figma-all, dx-figma-extract, dx-figma-prototype, dx-figma-verify | 4 |
| Agent Coordination | dx-agent-all, dx-agent-dev, dx-agent-re | 3 |
| Documentation | dx-doc-gen, dx-doc-retro | 2 |
| Quality | dx-axe, dx-security, dx-perf, dx-pattern-extract | 4 |
| Decision | dx-council | 1 |
| Utility | dx-help, dx-dor | 2 |

### dx-aem Skills (12 skills)

aem-init, aem-component, aem-qa, aem-qa-handoff, aem-verify, aem-doctor, aem-fe-verify, aem-page-search, aem-snapshot, aem-refresh, aem-editorial-guide, aem-doc-gen

### dx-hub Skills (4 skills)

dx-hub-init, dx-hub-dispatch, dx-hub-status, dx-hub-config

### dx-automation Skills (11 skills)

auto-init, auto-deploy, auto-status, auto-test, auto-doctor, auto-pipelines, auto-provision, auto-eval, auto-lambda-env, auto-webhooks, auto-alarms

---

## 2. Dependency Chain — Full Flow

```
/dx-init (Bootstrap)
  |
  v
/dx-req <id> (Coordinator — 5 phases)
  |-- Fetch: raw-story.md <- ADO/Jira
  |-- Validate: DoR checks
  |-- Distill: explain.md
  |-- Research: research.md <- codebase search (parallel agents)
  |-- Share: summary.md
  |
  v
/dx-plan (Uses explain.md + research.md -> implement.md)
  |-- Optional: /dx-plan-validate (check plan vs requirements)
  |-- Optional: /dx-plan-resolve (fix flagged risks)
  |
  v
/dx-step-all (Coordinator — loops through implement.md steps)
  |-- For each step:
  |     /dx-step -> implement -> test -> review -> commit
  |     On failure: /dx-step-fix -> direct fix or insert "heal" steps
  |-- After all steps: /dx-step-build (compile & deploy)
  |-- Final gate: /dx-step-verify (6-phase: compile, lint, test, secrets, arch, AI review)
  |
  v
/dx-pr (Hard gate: verified: true required)
  |-- Read share-plan.md for PR description
  |-- Create feature branch, push, create PR
  |-- Optional: /dx-pr-answer (respond to review comments)
  |-- Optional: /dx-pr-commit (final merge)
```

### Parallel Flows (Don't Block Main Pipeline)

```
/dx-figma-all -> extract -> prototype -> verify -> figma-conventions.md (fed into /dx-plan)
/dx-doc-gen -> post to ADO Wiki or Confluence
/dx-perf -> performance audit
/dx-security -> security audit
/dx-axe -> accessibility audit
```

### Full Pipeline via Coordinator (dx-agent-all)

Up to 15 phases:

| # | Phase | Condition |
|---|-------|-----------|
| 1 | Requirements (/dx-req) | always |
| 1.5-enrich | Project Enrichment (/dx-ticket-analyze) | only if project.yaml exists |
| 1.5 | Figma Design-to-Code (/dx-figma-all) | only if Figma URL in story |
| 2 | Planning (/dx-plan) | always |
| 3 | Feature Branch | always |
| 4 | Execution (/dx-step-all) | always |
| 5 | Build (/dx-step-build) | always |
| 5+ | AEM Baseline (/aem-snapshot) | only if AEM + component found |
| 6 | Full Code Review (/dx-step-verify) | skipped if build failed |
| 6+ | AEM Verification (/aem-verify) | only if AEM Baseline ran |
| 6++ | AEM FE Verification (/aem-fe-verify) | only if AEM + Chrome DevTools |
| 7 | Commit (/dx-pr-commit) | skipped if build/review failed |
| 7.5 | Editorial Guide (/aem-editorial-guide) | only if AEM Verification passed |
| 8 | Pull Request (/dx-pr) | skipped if commit failed |
| 9 | Documentation (/dx-doc-gen) | optional |

---

## 3. Spec Directory Convention

All per-ticket output goes to `.ai/specs/<id>-<slug>/` with predictable filenames:

| File | Created By | Used By |
|------|-----------|---------|
| raw-story.md | dx-req | dx-plan, dx-step |
| explain.md | dx-req | dx-plan |
| research.md | dx-req | dx-plan |
| summary.md | dx-req | dx-pr |
| implement.md | dx-plan | dx-step-all, dx-step, dx-pr |
| figma-conventions.md | dx-figma-extract | dx-figma-prototype, dx-plan |
| verify-results.md | dx-step-verify | dx-pr |
| dor-report.md | dx-req | dx-agent-all |
| dod.md | dx-req-dod | dx-agent-all |
| run-state.json | dx-agent-all | dx-agent-all (resume support) |
| dev-all-progress.md | dx-agent-all | dx-agent-all (progress tracking) |

### Provenance & Confidence Propagation

Each spec file includes YAML provenance frontmatter:

```yaml
provenance:
  agent: dx-req
  model: opus|sonnet|haiku
  created: 2026-04-05T14:30:00Z
  confidence: high|medium|low
  verified: false
```

Downgrade rule: if a skill operates in degraded mode (missing prerequisites), downgrade confidence by one level. `/dx-plan` uses the lowest input confidence as its ceiling. `/dx-pr` blocks if `verified: false`.

---

## 4. Ecosystem Context (Early 2026)

### Cross-Platform Standardization Status

| Standard | Status | Traction |
|----------|--------|----------|
| AGENTS.md | De facto convention | 7+ tools (Codex, Copilot, Cursor, Windsurf, Zed, Jules, Gemini CLI) |
| MCP (Model Context Protocol) | Growing standard | Multiple platforms, replacing custom tool implementations |
| OpenSkills / OpenPlugins | No single standard | Convention-based convergence only |
| Markdown + YAML frontmatter | Common pattern | Multiple tools use it, schemas differ |
| Directory conventions | Platform-specific | .github/agents/, .claude/, .cursor/, .amazonq/ |

### Agentic Tool Extensibility Comparison

| Tool | Extensibility Model |
|------|---------------------|
| Claude Code | Most mature: plugins, skills, agents, hooks, MCP, marketplace |
| Copilot CLI | Hooks (.github/hooks/), agents (.github/agents/), shared plugin.json |
| Codex CLI | AGENTS.md, .codex/, sandboxed environment |
| Cursor | .cursor-plugin/plugin.json with explicit paths, .cursorrules |
| Windsurf | Rules files, AGENTS.md |
| Gemini CLI | GEMINI.md, gemini-extension.json |
| Jules | AGENTS.md, GitHub-integrated |
| Amazon Q | .amazonq/ directory with rules |

### Industry Trends

- **Enterprise sweet spot:** 3-5 step workflows. The full 12-15 phase pipeline works for teams with dedicated platform engineers.
- **Agent-as-CI-step** is the fastest-growing pattern (exactly what dx-automation does).
- **No vendor ships requirements-to-PR.** This repo fills a real gap.
- **Most teams** still use single-prompt or simple multi-turn conversations. The jump to orchestrated workflows requires significant infrastructure.
- **Config-driven design** increasingly recognized as essential for enterprise use.
- **Hook systems** for safety guardrails now expected in enterprise deployments.

---

## 5. Documentation Completeness

### What Exists (Extensive)

| Area | Location | Status |
|------|----------|--------|
| Skill Catalog | docs/reference/skill-catalog.md | Complete, 76 skills with dependencies |
| Agent Catalog | docs/reference/agent-catalog.md | Complete, models/tools/use cases |
| Config Schema | docs/reference/config-reference.md | Complete, full schema with examples |
| Local Workflow | website usage/local.mdx (28K) | Complete, phase-by-phase guide |
| Setup | website setup/ (per-platform) | Complete for Claude Code, Copilot CLI, VS Code Chat |
| Partial Flow | usage/local.mdx "Pick What You Need" | Exists but buried |
| Skill Chaining | tips/chaining-skills-building-pipelines.md | Complete with examples |
| Coordinators | reference/coordinators.mdx | Detailed pattern documentation |
| Crash Course | learn/intro.mdx | 15-minute fundamentals |
| Tips | 51 individual tip articles | Comprehensive but overwhelming |

### The Discovery Problem

The documentation for partial-flow usage **exists** in multiple places:
- "Pick What You Need" section in local.mdx
- "Choose your workflow style" in chaining-skills tip
- Modular design highlighted throughout

But developers still report confusion. The problem is **signal-to-noise ratio**: the answer is there but buried under volume. 51 tips, 76 skills, 28K workflow guide.

---

## 6. Complexity Hotspots — What Adds Small Value but Big Complexity

### High Complexity, Low Value for Most Users

| Feature/Skill | Complexity Cost | Who Actually Needs It |
|--------------|----------------|----------------------|
| dx-plan-validate + dx-plan-resolve as separate skills | Forces 3-step planning workflow | Power users only |
| dx-pr-review-report vs dx-pr-reviews-report | Confusing near-identical naming | Could merge into one |
| dx-pr-commit separate from dx-pr | Nobody commits without PRing | Should be a phase inside dx-pr |
| Hook profiles (DX_HOOK_PROFILE) | Three levels of env var config | Keep standard only |
| dx-adapt / dx-sync / dx-upgrade / dx-eject / dx-doctor / dx-scan / dx-simplify | 7 utility skills exposed as user-facing | Should be sub-commands of dx-doctor |
| dx-ticket-analyze as Phase 1.5 | Users don't think in half-phases | Fold into dx-req |
| Superpowers soft-dependency | Conditional branching for niche feature | Keep but don't surface to users |

### Naming Confusion Points

| Pair | Confusion |
|------|-----------|
| dx-req vs dx-agent-all | Which is the "full" requirements command? |
| dx-step vs dx-step-all | Do I need the coordinator or the single step? |
| dx-pr-review vs dx-pr-review-all | What's the difference? |
| dx-pr-review-report vs dx-pr-reviews-report | Singular vs plural — why two? |
| dx-bug-all vs dx-bug-fix | Which do I start with? |

The `-all` suffix convention (= coordinator) is not obvious to new users.

### Hidden State Complexity

- **Heal mechanism is implicit:** dx-step-fix can silently insert NEW steps into implement.md. Users don't realize the plan mutated.
- **Provenance gating is invisible:** dx-pr blocks on `verified: false` but the error message doesn't explain why.
- **Spec directory slug fragility:** If ADO work item title changes after dx-req, next run can't find the old spec directory.
- **Hub mode stop-and-redirect:** Skills detect hub mode and STOP, telling users to switch to dx-hub-dispatch, but there's no clear breadcrumb.

---

## 7. What's Working Well

- **Config-driven architecture** -- .ai/config.yaml as single source of truth
- **Spec directory convention** -- file-based data passing is elegant and debuggable
- **Coordinator pattern** -- disable-model-invocation: true with skill delegation
- **Model tiering** -- Opus/Sonnet/Haiku per skill for cost-effective execution
- **Idempotent execution** -- safe re-runs, checks if output exists before regenerating
- **Self-healing loops** -- step-fix -> step-heal -> human escalation (max 2 cycles)
- **Cross-platform support** -- most comprehensive multi-tool support seen
- **Run-state management** -- resume support in dx-agent-all is enterprise-grade
- **Website** -- clear structure, visual pipeline diagrams, good organization
- **Shared reference files** -- provenance-schema, git-rules, hub-dispatch, etc.
- **Hook system** -- pre/post tool execution with matchers, profiles, async support

---

## 8. Recommendations

### A. Tier the Catalog — 7 Primary Skills

Reduce visible surface to skills that cover 90% of use cases:

| Primary Skill | What It Does | Current Equivalent |
|--------------|-------------|-------------------|
| /dx-req <id> | Full requirements | Already exists (coordinator) |
| /dx-plan | Plan + validate + resolve | Merge 3 into 1 with auto-validate |
| /dx-step-all | Execute all steps | Already exists |
| /dx-pr | Commit + PR + link | Absorb dx-pr-commit |
| /dx-all <id> | Everything end-to-end | Rename from dx-agent-all |
| /dx-figma <url> | Full Figma pipeline | Rename from dx-figma-all |
| /dx-bug <id> | Full bug flow | Rename from dx-bug-all |

Everything else becomes "advanced" -- accessible but not in the default catalog view.

### B. Add a Smart Router / Entry Point

Single `/dx` skill that routes based on natural language:

```
/dx I need to implement story 12345
  -> Runs dx-req -> dx-plan -> dx-step-all -> dx-pr

/dx Review my PR for story 12345
  -> Runs dx-pr-review

/dx I just need the plan for 12345
  -> Runs dx-req -> dx-plan (stops)
```

Directly solves the feedback: "developers are not sure which skills to use."

### C. Document Partial-Flow Entry Points Prominently

Add a prominent decision tree at the top of the workflow page:

> **Just need requirements?** -> /dx-req <id> (stop here)
> **Already have requirements, need a plan?** -> /dx-plan (reads existing specs)
> **Already have a plan, need to execute?** -> /dx-step-all (reads existing plan)
> **Code is done, need a PR?** -> /dx-pr (reads existing changes)
> **Want everything?** -> /dx-agent-all <id>

### D. Reduce AEM Ceremony for Non-AEM Users

The dx-agent-all pipeline shows 15 max phases -- 5 are AEM-specific. For non-AEM docs:
- Show core 8 phases by default
- Show AEM phases as an add-on section

### E. Consolidate Utility Skills

Merge dx-adapt, dx-sync, dx-upgrade, dx-eject, dx-doctor, dx-scan, dx-simplify (7 skills) into:
- /dx-doctor as the umbrella with sub-commands
- Or hide from main catalog, document as "maintenance commands"

### F. Absorb Micro-Skills

| Absorb | Into | Rationale |
|--------|------|-----------|
| dx-pr-commit | dx-pr | Nobody commits without PRing |
| dx-plan-validate | dx-plan | Auto-validate as final step |
| dx-plan-resolve | dx-plan | Auto-resolve if validation flags risks |
| dx-ticket-analyze | dx-req | Phase 1.5 -> fold into Phase 1 |
| dx-pr-review-report + dx-pr-reviews-report | dx-pr-review | One skill with options |

### G. Improve State Visibility

- When dx-pr blocks on `verified: false`, show explicit message: "Run /dx-step-verify first"
- When dx-step-fix inserts heal steps, log: "Plan modified: 2 corrective steps added after Step 4"
- When hub mode stops a skill, show: "Multi-repo detected. Run /dx-hub-dispatch <id> to continue"

---

## 9. Competitive Position

This repo is at the leading edge of agentic workflow orchestration:
- No vendor ships a complete requirements-to-PR pipeline
- The config-driven, plugin-based, cross-platform approach is what the ecosystem is converging toward
- AGENTS.md and MCP are the two standards with real traction -- both already adopted here
- The automation plugin (Lambda-triggered pipeline agents) represents where the industry is heading

The risk isn't internal complexity -- it's that the **user-facing surface doesn't match developer mental models**. The fix is a discoverability layer, not a rewrite.

---

## 10. Research Sources

- Codebase exploration: all 4 plugins, 76 skills, 13 agents, hooks, templates, shared references
- Documentation review: docs/reference/ (3 catalog files), website (13,400+ lines across 40+ pages), 51 tip articles
- TODO tracker: 65 tracked items in docs/todo/
- Ecosystem research: Claude Code, Copilot CLI, Codex CLI, Cursor, Windsurf, Zed, Jules, Gemini CLI, Amazon Q
- Industry trends: enterprise adoption patterns, cross-platform standardization efforts, agent-as-CI-step growth

# Agent Catalog

## dx plugin — 6 agents

### dx-code-reviewer

| Property | Value |
|----------|-------|
| **Model** | Opus |
| **File** | `plugins/dx-core/agents/dx-code-reviewer.md` |
| **Used by** | `/dx-step-verify` |
| **Tools** | All (read, write, edit, bash, glob, grep) |
| **Permission mode** | `plan` (read-only by default) |
| **Isolation** | `worktree` (runs in isolated git worktree) |

Deep code review with confidence-based filtering. Only reports issues at confidence ≥80. Uses the project's `.ai/rules/` and CLAUDE.md for conventions. Outputs structured findings with severity levels (Critical, Important, Minor) and file:line references.

**Key behaviors:**
- Reviews full diff from base branch to HEAD
- Checks plan alignment, code quality, architecture, testing, production readiness
- Acknowledges strengths alongside issues
- Never style-nitpicks unchanged code

---

### dx-pr-reviewer

| Property | Value |
|----------|-------|
| **Model** | Sonnet |
| **File** | `plugins/dx-core/agents/dx-pr-reviewer.md` |
| **Used by** | `/dx-pr-review`, `/dx-pr-review-all` |
| **Tools** | Read, Glob, Grep, Bash, Write, Edit |
| **Permission mode** | `plan` (read-only by default) |

PR diff analysis with structured findings. Fetches PR diff, loads project conventions, analyzes code changes, returns findings with severity (MUST-FIX, QUESTION) and line-level comments. Does NOT post to ADO directly — returns findings for user approval.

---

### dx-file-resolver

| Property | Value |
|----------|-------|
| **Model** | Haiku |
| **File** | `plugins/dx-core/agents/dx-file-resolver.md` |
| **Used by** | `/dx-ticket-analyze` |
| **Tools** | Glob, Grep, Read, mcp__ado__search_code |

Resolves all source files for a component or module across project repos. Returns file paths as clickable SCM URLs. Uses local Glob first (instant), ADO code search only for remote repos.

---

### dx-doc-searcher

| Property | Value |
|----------|-------|
| **Model** | Haiku |
| **File** | `plugins/dx-core/agents/dx-doc-searcher.md` |
| **Used by** | `/dx-help`, `/dx-ticket-analyze` |
| **Tools** | Glob, Grep, Read |

Searches `.ai/` index and reference files for components, architecture patterns, and feature context. Returns ALL matches with quoted content and line numbers. Avoids expensive MCP calls.

---

### dx-figma-styles

| Property | Value |
|----------|-------|
| **Model** | Haiku |
| **File** | `plugins/dx-core/agents/dx-figma-styles.md` |
| **Used by** | `/dx-figma-prototype` |
| **Tools** | Read, Glob, Grep |

Discovers CSS/SCSS conventions from the consumer project — variables, breakpoints, typography, spacing, theming, naming patterns. Reads `.claude/rules/fe-styles.md` and config paths, then Glob/Grep actual source files for concrete values. Returns structured convention data for prototype generation.

---

### dx-figma-markup

| Property | Value |
|----------|-------|
| **Model** | Haiku |
| **File** | `plugins/dx-core/agents/dx-figma-markup.md` |
| **Used by** | `/dx-figma-prototype` |
| **Tools** | Read, Glob, Grep |

Discovers HTML and accessibility conventions from the consumer project — semantic patterns, component structure, ARIA usage, keyboard handling. Reads `.claude/rules/fe-javascript.md`, `.claude/rules/accessibility.md`, and other convention rules. Returns structured convention data for prototype generation.

---

---

> **Note:** The `dx-step-executor` agent has been removed. Coordinators now invoke skills directly via the Skill tool instead of delegating to an executor agent. Model tiering is now handled via `model:` frontmatter on individual skills (e.g., `model: opus` on dx-plan, dx-step-verify, dx-pr-review; `model: sonnet` on dx-step, dx-req, dx-step-fix; `model: haiku` on dx-ticket-analyze, dx-help).

---

## aem plugin — 6 agents

### aem-file-resolver

| Property | Value |
|----------|-------|
| **Model** | Haiku |
| **File** | `plugins/dx-aem/agents/aem-file-resolver.md` |
| **Used by** | `/aem-component`, `/dx-ticket-analyze` |
| **Tools** | Glob, Grep, Read, mcp__ado__search_code |

Resolves all source files for an AEM component across multiple repos and platforms. Reads `file-patterns.yaml` and `project.yaml` for path patterns. Uses local Glob for repos with local paths, ADO code search for remote-only repos. Returns file paths as clickable SCM URLs.

---

### aem-inspector

| Property | Value |
|----------|-------|
| **Model** | Sonnet |
| **File** | `plugins/dx-aem/agents/aem-inspector.md` |
| **Used by** | `/aem-snapshot`, `/aem-verify`, `/aem-doc-gen` |
| **Tools** | Read, Write, Glob, Grep, ToolSearch, all `mcp__plugin_dx-aem_AEM__*` tools |

AEM component inspector. Queries the AEM author instance via MCP tools for dialog fields, page searches, test/docs page creation, publishing, and demo data configuration. Returns compact markdown summaries — never raw JSON.

**Key capabilities:**
- Walk dialog trees (tabs → fields → multifields)
- Find pages using a component (4 query strategies)
- Discover component placement (container chain)
- Create test and docs pages with demo data
- Publish pages via `activatePage`
- Cache page structure to `demo/page-structure.md`
- Build author URLs from config

---

### aem-fe-verifier

| Property | Value |
|----------|-------|
| **Model** | Sonnet |
| **File** | `plugins/dx-aem/agents/aem-fe-verifier.md` |
| **Used by** | `/aem-fe-verify` |
| **Tools** | Read, Write, Edit, Glob, Grep, ToolSearch, all `mcp__plugin_dx-aem_AEM__*` tools, all `mcp__plugin_dx-aem_chrome-devtools-mcp__*` tools |

Frontend visual verification agent. Creates/reuses demo pages on local AEM, screenshots components in `wcmmode=disabled` via Chrome DevTools, and compares rendered output against Figma reference screenshots or requirements using multimodal vision. Combines AEM MCP (page creation, component config) with Chrome DevTools MCP (navigation, screenshots).

**Key capabilities:**
- Localhost hard gate (verifies AEM MCP connected to localhost)
- Demo page creation/reuse (same conventions as aem-inspector)
- Component screenshot in publish-like rendering (wcmmode=disabled)
- Multimodal visual comparison against Figma reference or requirements
- Fix loop (edit source → rebuild → redeploy → re-screenshot)

---

### aem-demo-capture

| Property | Value |
|----------|-------|
| **Model** | Sonnet |
| **File** | `plugins/dx-aem/agents/aem-demo-capture.md` |
| **Used by** | `/aem-demo`, `/aem-doc-gen` |
| **Tools** | Read, Write, Glob, ToolSearch, all `mcp__plugin_dx-aem_chrome-devtools-mcp__*` tools |

Browser automation agent for AEM editor interaction. Opens AEM author/publisher pages, handles login and QA Basic Auth, triggers component dialogs via Granite API, captures screenshots, and writes editor-friendly documentation. Supports both local and QA environments.

**Key capabilities:**
- AEM login handling (detect redirect, fill credentials, submit)
- QA/Stage Basic Auth (embed in URL, fallback to fetch + Authorization header)
- Component dialog opening via `Granite.author.editables` API
- Publisher view capture (locate component by CSS class, scroll, screenshot)
- Screenshot capture with deduplication
- Authoring guide generation (non-technical)

---

### aem-page-finder

| Property | Value |
|----------|-------|
| **Model** | Haiku |
| **File** | `plugins/dx-aem/agents/aem-page-finder.md` |
| **Used by** | `/aem-component`, `/aem-page-search` |
| **Tools** | Grep, Read, ToolSearch, mcp__plugin_dx-aem_AEM__searchContent, mcp__plugin_dx-aem_AEM__enhancedPageSearch, mcp__plugin_dx-aem_AEM__scanPageComponents |

Finds all AEM pages using a given component. Searches configured content paths and Experience Fragments. Returns clickable author URLs using the QA author URL from config.

---

### aem-bug-executor

| Property | Value |
|----------|-------|
| **Model** | Sonnet |
| **File** | `plugins/dx-aem/agents/aem-bug-executor.md` |
| **Used by** | `/dx-bug-verify` (for AEM-specific bugs) |
| **Tools** | Read, Write, Glob, Grep, ToolSearch, Chrome DevTools MCP, AEM MCP |

AEM-specific bug verification agent. Navigates to affected AEM pages, follows reproduction steps, captures screenshot evidence, and optionally checks JCR state. Returns structured verification result with evidence table.

---

## Copilot Agents — dx plugin (15 agents)

Copilot agents are seeded into `.github/agents/` when Copilot support is enabled during `/dx-init`. They are the Copilot counterparts of the Claude Code agents and skills, using Copilot's `@AgentName` invocation syntax.

### DxCodeReview

| Property | Value |
|----------|-------|
| **Template** | `plugins/dx-core/templates/agents/DxCodeReview.agent.md.template` |
| **Claude equivalent** | dx-code-reviewer |
| **Invoke** | `@DxCodeReview` |

Full branch code review with confidence-based filtering (≥80). Read-only — no code modifications.

**Handoffs:** DxCommit, DxDebug

---

### DxPRReview

| Property | Value |
|----------|-------|
| **Template** | `plugins/dx-core/templates/agents/DxPRReview.agent.md.template` |
| **Claude equivalent** | dx-pr-reviewer |
| **Invoke** | `@DxPRReview <PR-ID>` |

Fetches ADO PR diff, analyzes with project conventions, posts findings as PR comments. Uses ADO MCP tools.

**Handoffs:** DxCodeReview, DxDebug, DxComponent

---

### DxPlanExecutor

| Property | Value |
|----------|-------|
| **Template** | `plugins/dx-core/templates/agents/DxPlanExecutor.agent.md.template` |
| **Claude equivalent** | (skill: /dx-step) |
| **Invoke** | `@DxPlanExecutor <step-number>` |

Executes implementation plan steps from `implement.md`. Reads spec directory, runs one step at a time, saves output.

**Handoffs:** DxCodeReview, DxCommit, DxDebug

---

### DxComponent

| Property | Value |
|----------|-------|
| **Template** | `plugins/dx-core/templates/agents/DxComponent.agent.md.template` |
| **Claude equivalent** | dx-file-resolver |
| **Invoke** | `@DxComponent <name>` |

Resolves all source files for a component or module. Returns file paths with ADO code search fallback.

**Sub-agents:** dx-doc-searcher, dx-file-resolver
**Handoffs:** DxTicket, DxHelp

---

### DxHelp

| Property | Value |
|----------|-------|
| **Template** | `plugins/dx-core/templates/agents/DxHelp.agent.md.template` |
| **Claude equivalent** | dx-doc-searcher |
| **Invoke** | `@DxHelp <question>` |

Project Q&A from `.ai/` documentation, component index, and architecture docs.

**Sub-agents:** dx-doc-searcher
**Handoffs:** DxComponent, DxTicket

---

### DxTicket

| Property | Value |
|----------|-------|
| **Template** | `plugins/dx-core/templates/agents/DxTicket.agent.md.template` |
| **Claude equivalent** | (skill: /dx-ticket-analyze) |
| **Invoke** | `@DxTicket <ADO-ID>` |

ADO ticket research — fetches work item, identifies related files, checks linked PRs, saves to spec directory.

**Sub-agents:** dx-doc-searcher, dx-file-resolver
**Handoffs:** DxComponent, DxHelp

---

### DxPRAnswer

| Property | Value |
|----------|-------|
| **Template** | `plugins/dx-core/templates/agents/DxPRAnswer.agent.md.template` |
| **Claude equivalent** | (skill: /dx-pr-answer) |
| **Invoke** | `@DxPRAnswer <PR-ID>` |

Answers PR review comments — reads pending threads, drafts responses, posts reply comments.

**Handoffs:** DxPRFix, DxPRReview

---

### DxPRFix

| Property | Value |
|----------|-------|
| **Template** | `plugins/dx-core/templates/agents/DxPRFix.agent.md.template` |
| **Claude equivalent** | (skill: /dx-pr-answer) |
| **Invoke** | `@DxPRFix <PR-ID>` |

Applies "agree-will-fix" PR review changes. Reads threads, applies code changes, resolves threads.

**Handoffs:** DxPRAnswer, DxCommit

---

### DxCommit

| Property | Value |
|----------|-------|
| **Template** | `plugins/dx-core/templates/agents/DxCommit.agent.md.template` |
| **Claude equivalent** | (skill: /dx-pr-commit) |
| **Invoke** | `@DxCommit` |

Smart commit with conventional message. Optionally creates ADO pull request with description.

**Handoffs:** DxPRReview, DxCodeReview

---

### DxDebug

| Property | Value |
|----------|-------|
| **Template** | `plugins/dx-core/templates/agents/DxDebug.agent.md.template` |
| **Claude equivalent** | — |
| **Invoke** | `@DxDebug <error or symptom>` |

Systematic error diagnosis. Read-only — traces errors through code, identifies root causes, suggests fixes.

**Handoffs:** DxPlanExecutor, DxCodeReview

---

### DxReqAll

| Property | Value |
|----------|-------|
| **Template** | `plugins/dx-core/templates/agents/DxReqAll.agent.md.template` |
| **Claude equivalent** | (skill: /dx-req) |
| **Invoke** | `@DxReqAll <work-item-id>` |

Full requirements pipeline coordinator. Invokes `/dx-req` which handles all 5 phases (fetch → dor → explain → research → share).

**Handoffs:** DxPlanExecutor, DxTicket

---

### DxStepAll

| Property | Value |
|----------|-------|
| **Template** | `plugins/dx-core/templates/agents/DxStepAll.agent.md.template` |
| **Claude equivalent** | (skill: /dx-step-all) |
| **Invoke** | `@DxStepAll <work-item-id>` |

Execution loop coordinator. Runs `/dx-step` (includes test, review, commit) → `/dx-step-fix` for failures, in a loop until all plan steps are done.

**Handoffs:** DxCodeReview, DxCommit, DxDebug

---

### DxBugAll

| Property | Value |
|----------|-------|
| **Template** | `plugins/dx-core/templates/agents/DxBugAll.agent.md.template` |
| **Claude equivalent** | (skill: /dx-bug-all) |
| **Invoke** | `@DxBugAll <bug-id>` |

Full bug workflow coordinator. Chains `/dx-bug-triage` → `/dx-bug-fix`.

**Handoffs:** DxCodeReview, DxCommit

---

### DxAgentAll

| Property | Value |
|----------|-------|
| **Template** | `plugins/dx-core/templates/agents/DxAgentAll.agent.md.template` |
| **Claude equivalent** | (skill: /dx-agent-all) |
| **Invoke** | `@DxAgentAll <work-item-id>` |

End-to-end delivery coordinator. Full pipeline: Requirements → Planning → Execution → Build → Code Review → Commit + PR.

**Handoffs:** DxCodeReview, DxCommit, DxDebug

---

### DxFigma

| Property | Value |
|----------|-------|
| **Template** | `plugins/dx-core/templates/agents/DxFigma.agent.md.template` |
| **Claude equivalent** | (skills: /dx-figma-extract, /dx-figma-prototype, /dx-figma-verify) |
| **Invoke** | `@DxFigma <work-item-id or Figma URL>` |

Figma design-to-code coordinator. Chains `/dx-figma-extract` → `/dx-figma-prototype` → `/dx-figma-verify` to produce a verified HTML/CSS prototype from a Figma design. Requires Figma desktop app with Dev Mode MCP and Chrome DevTools for verification.

**Handoffs:** DxPlanExecutor, DxReqAll

---

## Copilot Agents — aem plugin (10 agents)

AEM Copilot agents are seeded into `.github/agents/` when Copilot support is enabled during `/aem-init`. They extend the DX agents with AEM-specific capabilities.

### AEMBefore

| Property | Value |
|----------|-------|
| **Template** | `plugins/dx-aem/templates/agents/AEMBefore.agent.md.template` |
| **Claude equivalent** | aem-inspector |
| **Invoke** | `@AEMBefore <component>` |

Pre-development baseline capture. Walks component dialog, finds pages, saves snapshot to spec directory.

**Handoffs:** DxPlanExecutor

---

### AEMAfter

| Property | Value |
|----------|-------|
| **Template** | `plugins/dx-aem/templates/agents/AEMAfter.agent.md.template` |
| **Claude equivalent** | aem-inspector |
| **Invoke** | `@AEMAfter <component>` |

Post-deployment verification. Compares current state against `aem-before.md` baseline, verifies new fields and pages.

**Handoffs:** DxCodeReview

---

### AEMSnapshot

| Property | Value |
|----------|-------|
| **Template** | `plugins/dx-aem/templates/agents/AEMSnapshot.agent.md.template` |
| **Claude equivalent** | aem-inspector |
| **Invoke** | `@AEMSnapshot <component>` |

General-purpose component inspection without before/after context. Dialog fields, pages, JCR properties.

**Handoffs:** AEMBefore, DxComponent

---

### AEMDemo

| Property | Value |
|----------|-------|
| **Template** | `plugins/dx-aem/templates/agents/AEMDemo.agent.md.template` |
| **Claude equivalent** | aem-demo-capture |
| **Invoke** | `@AEMDemo <component>` |

Captures dialog screenshots via Chrome DevTools and writes editor-friendly authoring guide.

---

### AEMComponent

| Property | Value |
|----------|-------|
| **Template** | `plugins/dx-aem/templates/agents/AEMComponent.agent.md.template` |
| **Claude equivalent** | aem-file-resolver + aem-page-finder |
| **Invoke** | `@AEMComponent <component>` |

Multi-platform component lookup — finds source files (via file-patterns.yaml), AEM pages, and dialog fields. Data-driven via project.yaml prefixes. Supports both Legacy and DXN platforms.

**Sub-agents:** aem-file-resolver, aem-page-finder
**Handoffs:** AEMTicket, AEMBefore, DxComponent

---

### AEMVerify

| Property | Value |
|----------|-------|
| **Template** | `plugins/dx-aem/templates/agents/AEMVerify.agent.md.template` |
| **Claude equivalent** | aem-bug-executor |
| **Invoke** | `@AEMVerify <component or URL>` |

Bug verification on a running AEM instance. Navigates pages, reproduces issues, captures screenshot evidence.

**Handoffs:** DxDebug, DxComponent

---

### AEMTicket

| Property | Value |
|----------|-------|
| **Template** | `plugins/dx-aem/templates/agents/AEMTicket.agent.md.template` |
| **Claude equivalent** | (skill: /dx-ticket-analyze with project enrichment) |
| **Invoke** | `@AEMTicket <ADO-ID>` |

ADO ticket research with AEM project enrichment — 4-signal market detection, parallel agents (dx-doc-searcher, aem-file-resolver, aem-page-finder). Data-driven via project.yaml.

**Handoffs:** AEMComponent, DxHelp, DxReqAll

---

### AEMPRAnswer

| Property | Value |
|----------|-------|
| **Template** | `plugins/dx-aem/templates/agents/AEMPRAnswer.agent.md.template` |
| **Claude equivalent** | (skill: /dx-pr-answer) |
| **Invoke** | `@AEMPRAnswer <PR-ID>` |

Answers PR review comments with session persistence (`.ai/pr-answers/pr-<id>.md`). Bot detection (2-layer), thread categorization (agree-will-fix, question, disagree, skip), disagree confirmation gate.

**Handoffs:** AEMPRFix, DxPRReview

---

### AEMPRFix

| Property | Value |
|----------|-------|
| **Template** | `plugins/dx-aem/templates/agents/AEMPRFix.agent.md.template` |
| **Claude equivalent** | (skill: /dx-pr-answer) |
| **Invoke** | `@AEMPRFix <PR-ID>` |

Applies agree-will-fix PR review changes. Session-first resolution, minimal fixes, lint check via config commands.

**Handoffs:** AEMPRAnswer, AEMCommit

---

### AEMCommit

| Property | Value |
|----------|-------|
| **Template** | `plugins/dx-aem/templates/agents/AEMCommit.agent.md.template` |
| **Claude equivalent** | (skill: /dx-pr-commit) |
| **Invoke** | `@AEMCommit` |

Smart commit with WI ID extraction (4 sources: branch, spec dir, recent commits, ADO). Rebase, PR creation via ADO MCP.

**Handoffs:** DxPRReview, DxCodeReview

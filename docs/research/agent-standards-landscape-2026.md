# Agent Standards Landscape — April 2026

Research into cross-platform AI coding agent conventions, standardization efforts, and how dx-aem-flow compares.

---

## 1. AGENTS.md — The Emerging Universal Standard

The single biggest development since mid-2025 is **AGENTS.md**, which has become the de facto cross-tool convention file for AI coding agents.

**Timeline:**

- **Aug 2025:** OpenAI released the AGENTS.md spec for Codex CLI
- **Dec 2025:** OpenAI donated AGENTS.md to the newly formed **Agentic AI Foundation (AAIF)** under the Linux Foundation. Anthropic simultaneously donated MCP; Block donated Goose.
- **Mar 2026:** 60,000+ open-source repos use AGENTS.md; 25+ tools support it natively

**Tools that natively parse AGENTS.md:** Codex CLI, GitHub Copilot (VS Code, CLI, Cloud Agent), Cursor, Windsurf, Zed, Google Jules, Gemini CLI, Amp, Factory, Devin, and others.

**Format:** Plain Markdown. No required structure — just headings and prose. Scoped by directory (an AGENTS.md file applies to its directory tree and all children). Agents must obey instructions from any AGENTS.md whose scope includes files being modified.

**References:** [agents.md](https://agents.md/) | [GitHub repo](https://github.com/agentsmd/agents.md) | [Linux Foundation AAIF](https://www.linuxfoundation.org/press/linux-foundation-announces-the-formation-of-the-agentic-ai-foundation)

### Claude Code Position on AGENTS.md

- Claude Code reads `CLAUDE.md` with **primary precedence**
- AGENTS.md is supported as a **fallback** (read if CLAUDE.md is absent)
- [Feature request #6235](https://github.com/anthropics/claude-code/issues/6235) with 3,000+ upvotes requests full AGENTS.md support, but Anthropic has not committed to parity
- CLAUDE.md has features AGENTS.md lacks: `@import` syntax for composing instructions, recursive imports, Cowork integration, memory system hooks

**Practical guidance:** Maintain both files. CLAUDE.md for Claude-specific features; AGENTS.md for cross-tool compatibility.

---

## 2. Agent Skills — Anthropic's Open Standard (Now Cross-Platform)

**Agent Skills** is an open specification created by Anthropic and released in **December 2025** at [agentskills.io](https://agentskills.io/specification).

- A skill = a directory with a `SKILL.md` file (YAML frontmatter + Markdown body)
- Frontmatter fields: `name`, `description`, `argument-hint`, `model`, `effort`, `context`, `agent`, `paths`
- **Progressive disclosure:** L1 metadata (~100 tokens) loads at startup; L2 full instructions (<5,000 tokens) load only when selected
- Adopted by: **Codex, Copilot (VS Code + CLI + Cloud Agent), Cursor, Goose, Amp, OpenCode**

Codex stores skills in `.agents/skills/`, Claude Code uses `.claude/skills/`. The spec itself is platform-neutral.

**References:** [agentskills.io](https://agentskills.io/specification) | [anthropics/skills on GitHub](https://github.com/anthropics/skills)

---

## 3. Platform-by-Platform Conventions

### OpenAI Codex

| Convention | Location | Purpose |
|---|---|---|
| `AGENTS.md` | Repo root + subdirectories | Project instructions |
| Skills | `.agents/skills/<name>/SKILL.md` | Reusable workflows |
| Config | `codex.json` or CLI flags | `project_doc_max_bytes`, sandbox settings |
| Agents SDK | Python SDK | Build custom agents |

### GitHub Copilot (VS Code, CLI, Cloud Agent)

| Convention | Location | Purpose |
|---|---|---|
| `copilot-instructions.md` | `.github/copilot-instructions.md` | Project-wide coding standards |
| `.instructions.md` files | Anywhere in repo | Scoped rules for specific file types/dirs |
| `AGENTS.md` | Repo root | Cross-tool agent instructions (supported since late 2025) |
| Custom agents | `.github/agents/<name>.agent.md` | Agent profiles with YAML frontmatter |
| Skills | `.github/skills/<name>/SKILL.md` | Agent Skills spec (full support) |
| Hooks | `.github/hooks/hooks.json` | Lifecycle hooks: `preToolUse`, `postToolUse`, etc. |
| Plugins | `.github/plugins/` | Bundle MCP servers, agents, skills, and hooks |
| Setup steps | `copilot-setup-steps.yml` | Environment setup for cloud coding agent |

Copilot CLI went GA in **February 2026**.

### Cursor

| Convention | Location | Purpose |
|---|---|---|
| `.cursorrules` (legacy) | Repo root | **Deprecated**, not loaded in Agent mode |
| `.cursor/rules/*.mdc` | `.cursor/rules/` | Modular rules with YAML frontmatter (globs, `alwaysApply`) |
| `AGENTS.md` | Repo root | Supported natively as of late 2025 |
| Agent Skills | `.cursor/skills/` | SKILL.md spec adopted |

### Windsurf

| Convention | Location | Purpose |
|---|---|---|
| `.windsurfrules` | Repo root | Project-level rules |
| `.windsurf/rules/` | `.windsurf/rules/` | Structured rules directory |
| `AGENTS.md` (root) | Repo root | Always-on rules in Cascade system prompt |
| `AGENTS.md` (subdirs) | Subdirectories | Glob-scoped rules, applied when editing files in that dir |

### Gemini CLI

- Reads `GEMINI.md` as primary context file
- Supports extensions via `gemini-extension.json` manifest
- Does not support subagents — skills fall back to sequential execution

---

## 4. Model Context Protocol (MCP) — Industry Standard

MCP has unequivocally won as the universal tool-integration protocol:

- **97M+ monthly SDK downloads** as of early 2026
- Backed by Anthropic, OpenAI, Google, and Microsoft
- Donated to the Linux Foundation's AAIF in December 2025
- Adopted across: Claude Code, ChatGPT, Codex, Copilot, Cursor, Windsurf, Gemini, and enterprise tools
- The same `.mcp.json` configuration works across platforms with minor differences in tool name prefixing

**References:** [MCP Specification](https://modelcontextprotocol.io/specification/2025-11-25) | ["Why MCP Won" — The New Stack](https://thenewstack.io/why-the-model-context-protocol-won/)

---

## 5. Agent2Agent Protocol (A2A) — Google's Interop Standard

A2A addresses agent-to-agent communication (complementary to MCP's agent-to-tool):

- **Announced:** April 2025 by Google with 50+ partners
- **Donated:** June 2025 to the Linux Foundation
- Uses HTTP, SSE, and JSON-RPC
- Key concepts: Agent Cards (JSON capability discovery), task lifecycle, context sharing
- Partners: Atlassian, Box, Langchain, MongoDB, PayPal, Salesforce, SAP

A2A and MCP are **complementary**: MCP connects agents to tools/data; A2A connects agents to other agents.

---

## 6. Convergence Summary

| Layer | Standard | Status | Governance |
|---|---|---|---|
| **Project instructions** | AGENTS.md | De facto standard (60K+ repos, 25+ tools). Claude reads as fallback. | AAIF / Linux Foundation |
| **Skills** | Agent Skills (SKILL.md) | Open standard. Adopted by Codex, Copilot, Cursor, Claude Code, others. | Anthropic (open spec) |
| **Tool integration** | MCP | Industry standard (97M+ downloads). Universal adoption. | AAIF / Linux Foundation |
| **Agent-to-agent** | A2A | Growing enterprise adoption. Complementary to MCP. | Linux Foundation |
| **Hooks** | No universal standard | Claude (`hooks.json`), Copilot (`.github/hooks/`), Cursor (own format). Similar but not standardized. | Platform-specific |
| **Plugins** | No universal standard | Claude (`plugin.json`), Copilot (agent plugins), Cursor (none interoperable). | Platform-specific |
| **Editor rules** | Platform-specific | CLAUDE.md, `.cursor/rules/*.mdc`, `.windsurfrules`, `copilot-instructions.md`. AGENTS.md is the lowest common denominator. | Platform-specific |

**What is real and shipping:** AGENTS.md, Agent Skills, MCP, and A2A are all shipping and governed by open foundations. Cross-platform skills work today.

**What remains fragmented:** Hooks, plugins, and editor-specific rule formats. No standardization effort for these yet.

---

## 7. How superpowers Handles Multi-Platform (6 Platforms)

[obra/superpowers](https://github.com/obra/superpowers) is a methodology-focused Claude Code plugin (v5.0.7, 135k stars) supporting **Claude Code, Cursor, Copilot CLI, Gemini CLI, Codex, and OpenCode**.

### Strategy: Separate Manifests Per Platform

| Platform | Manifest Location | Notes |
|----------|------------------|-------|
| **Claude Code** | `.claude-plugin/plugin.json` | Minimal — omits `skills`/`agents`/`hooks` fields (auto-discovery) |
| **Cursor** | `.cursor-plugin/plugin.json` | Includes explicit paths: `"skills": "./skills/"`, `"hooks": "./hooks/hooks-cursor.json"` |
| **Gemini CLI** | `gemini-extension.json` | Points to `GEMINI.md` context file |
| **Codex** | `.codex/INSTALL.md` | Clone-and-symlink approach |
| **OpenCode** | `.opencode/plugins/superpowers.js` | JS plugin entry point with hooks |
| **Copilot CLI** | Shared marketplace | Same `.claude-plugin/plugin.json` + `hooks.json` |

### Runtime Platform Detection (SessionStart Hook)

The `hooks/session-start` bash script detects the platform via environment variables and returns the correct JSON format:

```bash
if [ -n "${CURSOR_PLUGIN_ROOT:-}" ]; then
    # Cursor: uses additional_context (snake_case)
    printf '{ "additional_context": "%s" }'
elif [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -z "${COPILOT_CLI:-}" ]; then
    # Claude Code: uses hookSpecificOutput.additionalContext (nested)
    printf '{ "hookSpecificOutput": { ... "additionalContext": "%s" } }'
else
    # Copilot CLI or unknown: uses additionalContext (top-level, SDK standard)
    printf '{ "additionalContext": "%s" }'
fi
```

Environment variables: `CURSOR_PLUGIN_ROOT`, `CLAUDE_PLUGIN_ROOT`, `COPILOT_CLI`

### Separate Hook Configs Per Platform

**`hooks.json`** (Claude Code / Copilot CLI): PascalCase events, nested hooks array, matchers
**`hooks-cursor.json`** (Cursor): `version: 1` schema, camelCase events, simpler format

### Tool Name Translation

Skills are written using Claude Code tool names. Platform-specific reference docs map them:

- **Gemini:** `Read` → `read_file`, `Write` → `write_file`, `Skill` → `activate_skill`
- **OpenCode:** JS plugin auto-maps (`TodoWrite` → `todowrite`, `Task` → `@mention`)

### Key Design Decisions

1. **Skills as pure methodology** — no platform-specific tool calls or model requirements in skill content
2. **Separate manifests per platform** in dedicated dotfile directories
3. **Runtime detection** via environment variables in shared hook scripts
4. **Tool name translation** via reference docs rather than abstraction layers
5. **Graceful degradation** — document what doesn't work on lesser platforms, provide fallbacks
6. **Zero config** — skills are self-contained, no `.ai/config.yaml` equivalent

---

## 8. How dx-aem-flow Compares

### Current Cross-Platform Approach

| Aspect | dx-aem-flow | superpowers |
|--------|-------------|-------------|
| **Platforms** | 3 (Claude Code, Copilot CLI, VS Code Chat) | 6 (+ Cursor, Gemini, Codex, OpenCode) |
| **Manifests** | Single `plugin.json` shared by Claude Code + Copilot CLI | Separate manifest per platform |
| **Hook format** | Same format, separate install locations | Separate hook files per platform |
| **Skill complexity** | Rich frontmatter (model, effort, context, agent, paths) | Minimal frontmatter (name, description only) |
| **Config** | Config-driven (`.ai/config.yaml`) | Zero config — self-contained methodology |
| **MCP servers** | 6 MCP servers across plugins | None |
| **Subagents** | Named agents with context fork | Graceful degradation docs |

### What We Already Do Well

1. **SKILL.md format is the open standard** — our skills are already in the format adopted industry-wide
2. **Config-driven approach** avoids hardcoding — more portable than it appears
3. **Three-layer override system** is more sophisticated than any competitor
4. **Plugin marketplace** with independent installability
5. **Soft-dependency pattern** for superpowers integration already in 6 skills

### Gaps / Opportunities

| Gap | Current State | Opportunity |
|-----|--------------|-------------|
| **AGENTS.md** | Only have CLAUDE.md | Add AGENTS.md for cross-tool discovery (Codex, Cursor, Windsurf users) |
| **Cursor support** | Not supported | Add `.cursor-plugin/plugin.json` following superpowers pattern |
| **Gemini CLI support** | Not supported | Add `gemini-extension.json` + `GEMINI.md` |
| **Codex support** | Not supported | Add `.codex/INSTALL.md` with symlink instructions |
| **Hook platform detection** | Separate install locations | Consider superpowers-style env var detection in shared scripts |
| **Tool name portability** | Full MCP-prefixed names (Claude-specific) | Add reference docs mapping tool names per platform |
| **Hooks standardization** | No industry standard yet | Track — this is the next frontier likely to be standardized |
| **Plugin format** | No industry standard yet | Our `plugin.json` is close to what Copilot adopted |

### Priority Recommendations

1. **Add AGENTS.md** (low effort, high value) — 60K+ repos, 25+ tools read it. Can coexist with CLAUDE.md.
2. **Add `.cursor-plugin/plugin.json`** (low effort) — Cursor has significant market share and already supports SKILL.md.
3. **Add Gemini CLI support** (low effort) — `gemini-extension.json` + `GEMINI.md` with `@`-references.
4. **Add `.codex/INSTALL.md`** (trivial) — symlink instructions for Codex users.
5. **Add tool name reference docs** (medium effort) — map MCP-prefixed tool names to platform equivalents.
6. **Track hooks standardization** — hooks are the last major fragmented area. Position to adopt whatever standard emerges.

---

## 9. The Big Picture

Three layers of the AI agent stack are now standardized under open governance:

```
┌─────────────────────────────────────────┐
│  AGENTS.md — Project Instructions       │  ← AAIF / Linux Foundation
├─────────────────────────────────────────┤
│  Agent Skills (SKILL.md) — Workflows    │  ← Anthropic (open spec)
├─────────────────────────────────────────┤
│  MCP — Tool Integration                 │  ← AAIF / Linux Foundation
├─────────────────────────────────────────┤
│  A2A — Agent-to-Agent Communication     │  ← Linux Foundation
└─────────────────────────────────────────┘
```

Two layers remain fragmented: **hooks** and **plugins/marketplace**. These are likely the next standardization targets but no concrete efforts exist yet.

dx-aem-flow's architecture — config-driven skills, plugin manifests, hook system, MCP integration — is well-positioned. The SKILL.md format we use IS the standard. The main gap is platform reach (3 vs 6+ platforms), addressable with modest effort following superpowers' pattern.

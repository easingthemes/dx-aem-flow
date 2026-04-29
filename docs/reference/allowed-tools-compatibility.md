# allowed-tools — Cross-Platform Compatibility Reference

## What It Does

`allowed-tools` is a YAML frontmatter field in SKILL.md that controls which tools can execute automatically without prompting the user for permission. Without it, Copilot CLI asks before every single tool call, making multi-step skills unusable.

## Spec Support

| Spec / Platform | Status | Notes |
|---|---|---|
| [Agent Skills spec](https://agentskills.io/specification) | Experimental | Standard field definition |
| [Open Plugins](https://open-plugins.com/) | Supported | References Agent Skills spec |
| [Claude Code](https://code.claude.com/docs/en/skills) | Supported | Skill-scoped tool allowlist |
| Copilot CLI 1.0.10+ | Ignored (safe) | Unknown fields suppressed since v1.0.10 |
| VS Code Chat | Ignored (safe) | Uses agent handoffs, not tool permissions |

## Copilot CLI Version-Gated Behavior

| Version | Date | Behavior |
|---|---|---|
| < 0.0.403 | Before 2026-02-04 | Skills with unknown fields **silently skipped** |
| 0.0.403 | 2026-02-04 | "Skills with unknown frontmatter fields now load with **warnings** instead of being silently skipped" |
| 0.0.403 – 1.0.9 | Feb–Mar 2026 | Warning/error shown: `"Attribute 'allowed-tools' is not supported in skill files"` |
| **1.0.10** | **2026-03-20** | **"Suppress unknown field warnings in skill and command frontmatter"** — no more errors |
| 1.0.11 | 2026-03-23 | No frontmatter changes |
| 1.0.12 | 2026-03-26 | No frontmatter changes |
| 1.0.13 – 1.0.36 | Mar–Apr 2026 | No `allowed-tools`-specific changes — see [2026-04-25 platform state update](../research/2026-04-25-platform-state-update.md) for the full Copilot CLI v1.0.14 → v1.0.36 release table |

Source: [Copilot CLI changelog](https://raw.githubusercontent.com/github/copilot-cli/v1.0.12/changelog.md)

## Resolution for Users

If a user reports this error, they need to update Copilot CLI to v1.0.10+:

> `allowed-tools` is a valid field — supported by both the [Agent Skills spec](https://agentskills.io/specification) and [Claude Code](https://code.claude.com/docs/en/skills). Copilot CLI added support for unknown frontmatter fields in [v1.0.10](https://raw.githubusercontent.com/github/copilot-cli/v1.0.11/changelog.md) (Mar 20). Update with `/update` and the warning should be gone.

## Platform Permission Models

| Platform | Permission Model | How `allowed-tools` Applies |
|---|---|---|
| Claude Code | `acceptEdits` mode / per-tool prompts | Skill-scoped allowlist — auto-approves listed tools |
| Copilot CLI | Per-tool permission prompts | Same (when recognized); safely ignored otherwise |
| VS Code Chat | Agent handoffs | Not consumed — ignored safely |

## Recommended Values by Skill Type

| Skill Type | `allowed-tools` |
|---|---|
| Research only | `["read", "grep", "glob"]` |
| Code modification | `["read", "edit", "write", "grep", "glob"]` |
| Full automation | `["read", "edit", "write", "bash", "grep", "glob"]` |
| With MCP servers | Add `"mcp"` to any of the above |

## Key Takeaway

Do NOT remove `allowed-tools` from skill files. It is a valid, standards-backed field used by Claude Code. Copilot CLI versions that reject it are outdated — the fix is updating the CLI, not changing the plugin.

## Related

- [2026-04-25 platform state update](../research/2026-04-25-platform-state-update.md) — full release table for Copilot CLI v1.0.14 → v1.0.36, plus matching coverage for Claude Code, Codex CLI, and Gemini CLI
- [Agent standards landscape](../research/agent-standards-landscape-2026.md) — convergence story for AGENTS.md, Agent Skills, MCP, A2A
- [`docs/todo/todo-cross-platform.md`](../todo/todo-cross-platform.md) — open work for first-class Codex and Gemini support

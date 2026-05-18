# Phase 0 observations

> Fill in as you test each platform. Empty cells = not yet tested. Use ✓ / ✗ / ? for prompts.

## Claude Code

**Version:** _e.g. 2.1.111_
**Date:** _2026-05-06_

### dx-help

| Variant | Read prompted? | Bash prompted? | MCP `mcp__ado__*` prompted? | Notes |
|---|---|---|---|---|
| baseline (lowercase + ado/*) |  |  |  |  |
| pascal |  |  |  |  |
| lowercase-slash |  |  |  |  |
| lowercase-paren |  |  |  |  |

### dx-pr-review

| Variant | Read prompted? | Bash prompted? | MCP `mcp__ado__*` prompted? | Notes |
|---|---|---|---|---|
| baseline |  |  |  |  |
| pascal |  |  |  |  |
| lowercase-slash |  |  |  |  |
| lowercase-paren |  |  |  |  |

### aem-init

| Variant | Read prompted? | Bash prompted? | MCP `mcp__plugin_dx-aem_AEM__*` prompted? | Notes |
|---|---|---|---|---|
| baseline |  |  |  |  |
| pascal |  |  |  |  |
| lowercase-slash |  |  |  |  |
| lowercase-paren |  |  |  |  |

### auto-status

| Variant | Read prompted? | Bash prompted? | (no MCP) | Notes |
|---|---|---|---|---|
| baseline (no allowed-tools) |  |  | n/a |  |
| pascal |  |  | n/a |  |
| lowercase-slash |  |  | n/a |  |
| lowercase-paren |  |  | n/a |  |

## Copilot CLI

**Version:** _e.g. 1.0.40_
**Env vars set:** `GITHUB_COPILOT_PROMPT_MODE_REPO_HOOKS=___` `GITHUB_COPILOT_PROMPT_MODE_WORKSPACE_MCP=___`
**Date:** _2026-05-06_

### dx-help

| Variant | `read` prompted? | `bash` prompted? | MCP wildcard prompted? | Notes |
|---|---|---|---|---|
| baseline |  |  |  |  |
| pascal |  |  |  |  |
| lowercase-slash |  |  |  |  |
| lowercase-paren |  |  |  |  |

### dx-pr-review

| Variant | `read` prompted? | `bash` prompted? | MCP wildcard prompted? | Notes |
|---|---|---|---|---|
| baseline |  |  |  |  |
| pascal |  |  |  |  |
| lowercase-slash |  |  |  |  |
| lowercase-paren |  |  |  |  |

### aem-init

| Variant | `read` prompted? | `bash` prompted? | MCP `AEM/*` (or paren) prompted? | Notes |
|---|---|---|---|---|
| baseline |  |  |  |  |
| pascal |  |  |  |  |
| lowercase-slash |  |  |  |  |
| lowercase-paren |  |  |  |  |

### auto-status

| Variant | `read` prompted? | `bash` prompted? | (no MCP) | Notes |
|---|---|---|---|---|
| baseline |  |  | n/a |  |
| pascal |  |  | n/a |  |
| lowercase-slash |  |  | n/a |  |
| lowercase-paren |  |  | n/a |  |

## VS Code Chat

**Version:** _e.g. 1.118_
**Date:** _2026-05-06_

| Probe | Variant | "not supported" warning? | Tools still pre-approved? | Notes |
|---|---|---|---|---|
| dx-help | baseline |  |  |  |
| dx-help | pascal |  |  |  |
| dx-help | lowercase-slash |  |  |  |
| dx-help | lowercase-paren |  |  |  |
| ... | ... |  |  |  |

## Decision matrix

| Question | Answer | Evidence (probe + variant) |
|---|---|---|
| Claude Code accepts lowercase `read`/`edit`? |  |  |
| Claude Code accepts `ado/*` MCP wildcard? |  |  |
| Copilot CLI accepts `Read`/`Edit` PascalCase? |  |  |
| Copilot CLI accepts `mcp__ado__*` (Claude format)? |  |  |
| Copilot CLI MCP wildcard: slash / paren / bare? |  |  |
| Plugin-scoped MCPs (`AEM/*` vs `mcp__plugin_dx-aem_AEM__*`) work in Copilot? |  |  |
| VS Code Chat warns on `allowed-tools`? Blocking? |  |  |
| Does session-default model affect prompt behavior? (compare dx-help haiku vs dx-pr-review opus) |  |  |

## Surprises

_Anything observed that contradicts the research doc or our tip pages — write it here as you go. Examples that would matter:_

- _A variant that prompts in Claude Code but not Copilot, or vice versa_
- _Permission prompts that show different tool name strings than what's in `allowed-tools`_
- _Cached permission state that survives `swap.sh restore` (would need session restart)_

# Installing dx-aem-flow for Codex

Codex CLI reads this repo's Claude Code marketplace (`.claude-plugin/marketplace.json`) and plugin manifests (`.claude-plugin/plugin.json`) directly — no Codex-specific manifest and no symlinks needed. Checked on Codex CLI 0.167.1.

## Install

```bash
codex plugin marketplace add easingthemes/dx-aem-flow

# dx-core (all projects)
codex plugin add dx-core@dx-aem-flow

# dx-aem (AEM projects only)
codex plugin add dx-aem@dx-aem-flow
```

Check it:

```bash
codex plugin list
codex mcp list
```

Update later with `codex plugin marketplace upgrade`.

## What you get

- **Skills** — same names as on Claude Code (`dx-core:dx-req`, `dx-core:dx-plan`, …). Invoke with `$dx-req` or let Codex pick by description.
- **MCP servers** from each plugin's `.mcp.json` (axe, Figma; AEM, Playwright for dx-aem).
- ADO and Atlassian MCP are project-level — add them to `~/.codex/config.toml` or a trusted project's `.codex/config.toml` under `[mcp_servers.*]`.

## Not yet supported on Codex

- **Agents** — Codex agents are TOML files in `.codex/agents/`; dx agents are not converted yet.
- **Hooks** — dx hooks use `$CLAUDE_PROJECT_DIR`, which Codex does not set; the stop guard does not run.
- Frontmatter beyond `name`/`description` (`model`, `effort`, `context: fork`, `allowed-tools`) is ignored.

Status and plan: [`docs/research/2026-11-11-codex-parity.md`](../docs/research/2026-11-11-codex-parity.md).

## Prerequisites

Skills read project config from `.ai/config.yaml`. Generate it with `$dx-init`, or with the standalone CLI:

```bash
node ~/.dx-aem-flow/cli/bin/dx-scaffold.js . --all
```

The project must be **trusted** in Codex (`projects.<path>.trust_level = "trusted"`), otherwise project `.codex/` config, hooks and MCP are skipped.

Codex reads `AGENTS.md`, not `CLAUDE.md`. If your project only has `CLAUDE.md`, set `project_doc_fallback_filenames = ["CLAUDE.md"]` in `~/.codex/config.toml`.

# dx-scaffold CLI

Standalone Node.js utility that bootstraps the same project structure as `/dx-init` + `/aem-init` skills — for any AI coding agent (Claude Code, Copilot CLI, Codex CLI, VS Code Chat, Windsurf, and others).

No interactive prompts. Auto-detects environment, scaffolds all files with defaults, user edits config afterwards.

## Usage

```bash
# Base workflow only
node cli/bin/dx-scaffold.js /path/to/project

# AEM project with Copilot support
node cli/bin/dx-scaffold.js /path/to/project --all

# Overwrite existing files
node cli/bin/dx-scaffold.js /path/to/project --all --force

# Set pipeline preferences at scaffold time
node cli/bin/dx-scaffold.js /path/to/project --auto-commit=true --auto-pr=false
```

## Flags

| Flag | Description |
|------|-------------|
| `--aem` | Include AEM rules, instructions, seed data |
| `--copilot` | Include extra Copilot files (`copilot-instructions.md`, `.github/README.md`) |
| `--all` | Both `--aem` and `--copilot` |
| `--auto-commit[=true\|false]` | Set `preferences.auto-commit` in generated `.ai/config.yaml` (also supports `--no-auto-commit`) |
| `--auto-pr[=true\|false]` | Set `preferences.auto-pr` in generated `.ai/config.yaml` (also supports `--no-auto-pr`) |
| `--force` | Overwrite existing files (default: skip) |
| `--quiet` | Suppress per-file output |
| `--help` | Show help |

AEM is auto-enabled when the project has AEM markers (`pom.xml` + `ui.apps`/`ui.content`/`jcr_root`).

Agent definitions (`.github/agents/`) and `AGENTS.md` are **always generated** — they're consumed by multiple agents (Copilot CLI, VS Code Chat, Codex CLI, Windsurf, Copilot coding agent).

## What It Creates

**~144 files** (with `--all`):

| Directory | Files | Source |
|-----------|-------|--------|
| `.ai/config.yaml` | Project config (SCM, build, AEM) | `dx-core/templates/config.yaml.template` |
| `.ai/rules/` | 4 shared AI rules | `dx-core/templates/rules/` |
| `.ai/docs/` | 10 documentation files | `dx-core/templates/docs/` |
| `.ai/lib/` | 7 shell utility scripts | `dx-core/data/lib/` |
| `.ai/templates/` | 14 output templates | `dx-core/data/templates/` |
| `.ai/project/` | 5 AEM seed data files | Generated with defaults |
| `.claude/rules/` | 11 coding convention rules | `dx-core` + `dx-aem` templates |
| `.claude/hooks/` | 1 lifecycle hook | `dx-core/data/hooks/` |
| `.github/agents/` | 25 agent definitions | `dx-core` + `dx-aem` templates |
| `.github/instructions/` | 8 AEM instruction docs | `dx-aem/templates/instructions/` |
| `.mcp.json` | MCP server config | Generated |
| `AGENTS.md` | Agent discovery (Codex, Windsurf) | Generated from `.github/agents/` |
| `agent.index.md` | Machine-readable doc map | `dx-core/templates/INDEX.md.template` |

## Auto-Detection

The CLI detects from the target project:

- **Git remote** → SCM provider (ADO/GitHub), ADO org/project
- **Base branch** → probes `development`, `develop`, `main`, `master`
- **Project type** → `aem-fullstack`, `aem-frontend`, `frontend`, `java`, `rust`, `go`
- **Build commands** → from `pom.xml` or `package.json`
- **Component prefix** → from AEM `/apps/` directory structure
- **Sibling repos** → scans parent directory for `.git` dirs

## After Scaffolding

1. **Edit `.ai/config.yaml`** — replace `TODO` and `YOUR_*` placeholders with actual values
2. **If AEM** — set author/publish URLs, QA credentials, populate `.ai/project/component-index.md`
3. **If AEM** — fill in `.ai/project/architecture.md` and `features.md`

The scaffold output is identical to what `/dx-init` + `/aem-init` produce. Running the init skills later (in Claude Code or Copilot CLI) will re-detect and update values interactively (existing files are preserved by default).

## Agent Compatibility

| Agent | What it uses from the scaffold |
|-------|-------------------------------|
| **Claude Code** | Everything — plugins add skills on top |
| **Copilot CLI** | Everything — same plugin format, same skills |
| **VS Code Chat** | `.github/agents/`, `.claude/rules/`, `.mcp.json` |
| **Codex CLI** | `AGENTS.md`, `.github/agents/`, `.mcp.json` |
| **Windsurf** | `AGENTS.md` (always-on), `.mcp.json` |
| **Cursor** | `.claude/rules/` (via settings), `.mcp.json` |
| **Amazon Q** | `.claude/rules/` (copy to `.amazonq/rules/`), MCP |
| **Cline** | `.claude/rules/` (copy to `.clinerules/`), MCP |

## Requirements

- Node.js >= 14
- Must be run from within a clone of dx-aem-flow (reads templates from `../plugins/`)
- Zero npm dependencies

## Architecture

```
cli/
├── package.json
├── bin/
│   └── dx-scaffold.js    # CLI entry point
├── lib/
│   ├── index.js           # Re-exports
│   ├── detect.js          # Environment detection (git, SCM, project type)
│   └── scaffold.js        # Core scaffolding engine
└── README.md
```

Templates are read from `plugins/` at runtime — not bundled. When new templates are added to plugins, the scaffold picks them up automatically (it iterates directories). Only new file categories or placeholders require changes to `scaffold.js`.

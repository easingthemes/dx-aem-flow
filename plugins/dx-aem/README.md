# dx-aem — AEM Plugin for Claude Code

AEM-specific tools for Adobe Experience Manager projects: component verification, dialog inspection, demo capture, and QA automation. Built on top of the [dx-core](https://github.com/yourorg/claude-dx) development workflow plugin.

## Prerequisites

Install the `dx-core` plugin first:

```bash
/plugin marketplace add easingthemes/dx-aem-flow
/plugin install dx-core@dx-aem-flow
```

## Installation

```bash
/plugin install dx-aem@dx-aem-flow
```

## Quick Start

```bash
/dx-init                          # One-time project setup (dx plugin)
/aem-init                         # Add AEM config to .ai/config.yaml

/aem-snapshot starterkit          # Baseline before development
# ... develop your changes ...
/dx-step-build                         # Build & deploy to AEM
/aem-demo-page starterkit --local # Demo page + dialog/preview screenshots on local AEM
/aem-fe-verify starterkit         # Compare the rendering with Figma, fix gaps
# ... PR merged, deployed to QA ...
/dx-post-merge 12345              # QA demo page → wiki page → QA handoff comment
```

## Skills (9)

### Verification

| Skill | Description |
|-------|-------------|
| `/aem-snapshot` | Baseline component state before development — dialog fields, properties, pages |
| `/aem-demo-page` | Find or create the demo page, configure the component, screenshot the dialog (if changed) and author preview. QA by default, `--local` while developing; diffs the dialog against the snapshot |
| `/aem-fe-verify` | Compare the rendered component on local AEM with Figma or requirements, fix gaps in a loop |

### QA

| Skill | Description |
|-------|-------------|
| `/aem-qa` | Full QA agent — navigate pages, check rendering/dialogs, capture screenshots, create Bug tickets |

### Recon

| Skill | Description |
|-------|-------------|
| `/aem-init` | Detect AEM structure, add `aem:` section to .ai/config.yaml |
| `/aem-component` | Find all source files, AEM pages, and dialog fields for a component |
| `/aem-page-search` | Find all AEM pages using a specific component |
| `/aem-refresh` | Update `.ai/project/` seed data from plugin, external docs repo, or manual sources |
| `/aem-doctor` | Check AEM project infrastructure health — component definitions, OSGi, dispatcher |

## Agents

| Agent | Model | Purpose |
|-------|-------|---------|
| `aem-inspector` | Sonnet | Dialog/component inspection via AEM MCP (`/aem-snapshot`) |
| `aem-demo-page-capture` | Sonnet | Demo page setup via AEM MCP + dialog and preview screenshots via Playwright (`/aem-demo-page`) |
| `aem-fe-verifier` | Sonnet | Rendering screenshots and Figma comparison (`/aem-fe-verify`) |
| `aem-file-resolver` | Haiku | Resolve all source files for an AEM component across repos |
| `aem-page-finder` | Haiku | Find AEM pages using a specific component |

## Configuration

`/aem-init` appends to `.ai/config.yaml`:

```yaml
aem:
  url: http://localhost:4502
  component-prefix: myproject
  brands: [brand-a, brand-b, brand-c]
  author-url-qa: "https://qa-author.example.com"
  publish-url-qa: "https://qa-publish.example.com"
```

### QA Basic Auth

QA/Stage sites that require HTTP Basic Auth are configured with the `BASIC_AUTH_SITES` environment variable (`name:url:user:pass,...`), not in `.ai/config.yaml`. See the dx-core `basic-auth` rule (`.claude/rules/basic-auth.md`, installed by `/dx-init`).

The `aem.component-prefix` config is used by agents to construct CSS selectors when locating components on rendered pages.

## MCP Servers

This plugin bundles one MCP server (configured automatically via `.mcp.json`):

- **[AEM MCP](https://www.npmjs.com/package/aem-mcp-server)** (`aem-mcp-server`) — JCR content, component dialogs, page management, node queries. Supports multi-instance configurations (local + QA). Included with the plugin — no separate install needed.

Browser automation (screenshots, navigation, dialog interaction) uses the **Playwright MCP** server that ships with **dx-core** (`mcp__plugin_dx-core_playwright__*`). The AEM author login helper `.ai/lib/aem-playwright-auth.sh` (installed by `/aem-init`) writes a session that dx-core's server loads — so the browser skills need dx-core installed, which dx-aem requires anyway. `/dx-init` installs the Chromium browser (`npx playwright install chromium`).

## Full Workflow

```
Before the PR:   /aem-snapshot hero  →  /dx-step-all  →  /dx-step-build  →  /aem-demo-page hero --local  →  /aem-fe-verify hero
After the merge: /dx-post-merge <id>  =  /aem-demo-page <id>  →  /dx-doc-gen <id>  →  /dx-qa-handoff <id>
```

Each step also runs on its own. `demo/demo-page.md` in the spec dir carries the page and screenshots from one step to the next.

## License

MIT

# Environment Variables

All secrets and sensitive credentials are stored as environment variables. Two options (either works for Claude Code, shell is required for Copilot CLI):

1. **Shell profile** (`~/.bashrc` or `~/.zshrc`) — `export VAR=value`. Works for both Claude Code and Copilot CLI. Best for machine-wide settings like `AEM_INSTANCES`.
2. **`.claude/settings.local.json`** — `"env": { "VAR": "value" }`. Auto-gitignored, per-project. Best for project-specific secrets like QA auth credentials. Claude Code only (Copilot CLI does not read this file).

## How to Resolve Credentials

Skills that need credentials should resolve them in this order:

1. **Environment variable** — check via `echo $VAR_NAME` (Bash tool)
2. **`.ai/config.yaml`** — legacy fallback for backward compatibility
3. **Report missing** — if neither source has the value

## Variable Reference

### Base (dx-core)

| Variable | Purpose | Used By |
|----------|---------|---------|
| `BASIC_AUTH_SITES` | HTTP Basic Auth logins for protected sites (QA/Stage publishers, staging). Format: `name:url:user:pass` entries joined by `,`; `user`/`pass` percent-encoded when they contain `:` `,` `%`. Example: `qa:https://qa.example.com:user:pass,uat:https://uat.example.com:user:pass`; a port stays in the URL (`qa:https://qa.example.com:8443:user:pass`). Set it in the **shell profile with single quotes** (`export BASIC_AUTH_SITES='...'`) so Claude Code and Copilot CLI both see it; in ADO pipelines it is a **secret pipeline variable**. Separate from the AEM author login (`AEM_INSTANCES`). | basic-auth rule, `.ai/lib/playwright-basic-auth.js`, `dx-common.sh curl-basic-auth` |
| `AXE_API_KEY` | Deque axe API key for accessibility testing | dx-axe, axe MCP server |

### AEM (dx-aem)

| Variable | Purpose | Used By |
|----------|---------|---------|
| `AEM_INSTANCES` | AEM MCP multi-instance config — also the single source for the **AEM author form login** in browser agents (resolve via `bash .ai/lib/dx-common.sh aem-instance <name>`). Format: `name:host:user:pass` comma-separated. Example: `local:http://localhost:4502:admin:admin,qa:https://qa-author.example.com:user:pass` | AEM MCP `.mcp.json` (stdio transport); Playwright agents (form login) |

### Automation (dx-automation) — Pipeline Only

These are set as ADO pipeline variables or AWS Lambda env vars, NOT in `settings.local.json`:

| Variable | Purpose |
|----------|---------|
| `ANTHROPIC_API_KEY` | Claude API key for agent pipelines |
| `ADO_PAT` / `AZURE_DEVOPS_PAT` | Azure DevOps Personal Access Token |
| `FIGMA_PERSONAL_ACCESS_TOKEN` | Figma API token (DevAgent pipeline) |
| `AWS_ACCESS_KEY_ID` | AWS credentials for DynamoDB/SQS/S3 |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key |
| `BASIC_USER` / `BASIC_PASS` | Lambda webhook Basic Auth |
| `WEBHOOK_SECRET` | Lambda webhook shared secret |

## Template (settings.local.json)

```json
{
  "env": {
    "AXE_API_KEY": "",
    "AEM_INSTANCES": "local:http://localhost:4502:admin:admin,qa:https://qa-author.example.com:USER:PASS"
  }
}
```

Created by `/dx-init` (base vars) and `/aem-init` (AEM vars). Updated by `/dx-upgrade` (merges new keys).

# Environment Variables

All secrets and sensitive credentials are stored as environment variables in `.claude/settings.local.json` (auto-gitignored, per-project). Claude Code loads these into the session automatically.

## How to Resolve Credentials

Skills that need credentials should resolve them in this order:

1. **Environment variable** — check via `echo $VAR_NAME` (Bash tool)
2. **`.ai/config.yaml`** — legacy fallback for backward compatibility
3. **Report missing** — if neither source has the value

## Variable Reference

### Base (dx-core)

| Variable | Purpose | Used By |
|----------|---------|---------|
| `QA_BASIC_AUTH_USER` | QA/Stage HTTP Basic Auth username | qa-basic-auth rule, Chrome DevTools skills |
| `QA_BASIC_AUTH_PASS` | QA/Stage HTTP Basic Auth password | qa-basic-auth rule, Chrome DevTools skills |
| `QA_BASIC_AUTH_FALLBACK_USER` | Fallback QA username (optional) | qa-basic-auth rule |
| `QA_BASIC_AUTH_FALLBACK_PASS` | Fallback QA password (optional) | qa-basic-auth rule |
| `AXE_API_KEY` | Deque axe API key for accessibility testing | dx-axe, axe MCP server |

### AEM (dx-aem)

| Variable | Purpose | Used By |
|----------|---------|---------|
| `AEM_INSTANCES` | AEM MCP multi-instance config. Format: `name:host:user:pass` comma-separated. Example: `local:http://localhost:4502:admin:admin,qa:https://qa-author.example.com:user:pass` | AEM MCP `.mcp.json` (stdio transport) |

### Automation (dx-automation) — Pipeline Only

These are set as ADO pipeline variables or AWS Lambda env vars, NOT in `settings.local.json`:

| Variable | Purpose |
|----------|---------|
| `ANTHROPIC_API_KEY` | Claude API key for agent pipelines |
| `ADO_PAT` / `AZURE_DEVOPS_PAT` | Azure DevOps Personal Access Token |
| `FIGMA_PERSONAL_ACCESS_TOKEN` | Figma API token (DevAgent pipeline) |
| `AWS_ACCESS_KEY_ID` | AWS credentials for DynamoDB/SQS/S3 |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key |
| `AZURE_CONTENT_SAFETY_KEY` | Azure Content Safety API key |
| `BASIC_USER` / `BASIC_PASS` | Lambda webhook Basic Auth |
| `WEBHOOK_SECRET` | Lambda webhook shared secret |

## Template (settings.local.json)

```json
{
  "env": {
    "QA_BASIC_AUTH_USER": "",
    "QA_BASIC_AUTH_PASS": "",
    "QA_BASIC_AUTH_FALLBACK_USER": "",
    "QA_BASIC_AUTH_FALLBACK_PASS": "",
    "AXE_API_KEY": "",
    "AEM_INSTANCES": "local:http://localhost:4502:admin:admin,qa:https://qa-author.example.com:USER:PASS"
  }
}
```

Created by `/dx-init` (base vars) and `/aem-init` (AEM vars). Updated by `/dx-upgrade` (merges new keys).

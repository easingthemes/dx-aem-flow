# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in this project, please report it responsibly.

**Do not open a public issue.** Instead, email the maintainer directly or use GitHub's private vulnerability reporting feature.

## Scope

Most of this project is Markdown-based plugins (skills, agents, rules) plus shell helper scripts.
`dx-automation` additionally ships **server-side code you deploy into your own AWS account**:
`plugins/dx-automation/data/lambda/` contains two webhook handlers (`wi-router.mjs`, `pr-router.mjs`)
that authenticate inbound Azure DevOps Service Hook requests (HTTP Basic + an `x-webhook-secret`
shared secret, both compared with `crypto.timingSafeEqual`), deduplicate events in DynamoDB, apply
rate limits, and queue ADO pipeline runs with an ADO PAT. Nothing is hosted by this project — you
deploy and own those functions — but the code is in scope for reports.

Potential security concerns include:

- The Lambda webhook handlers: authentication, deduplication, rate limiting, and the fail-open
  behaviour of `lambda/lib/{dedupe,rate-limiter,dlq}.js` when AWS credentials are absent
- Secrets handled by the automation tier (`ANTHROPIC_API_KEY`, `ADO_PAT`, `BASIC_PASS`,
  `WEBHOOK_SECRET`, AEM credentials) — supplied as Lambda env vars and ADO pipeline variables
- Autonomous agents act on untrusted input: work-item comments and PR comments can be written by
  anyone with access to the board, and those agents edit code and push branches
- Shell scripts that execute with user privileges
- MCP server configurations that connect to external services
- Template files that may contain placeholder credentials

## Best Practices for Users

- Never commit `.env` files or API keys to your project
- Review MCP server configurations before enabling them
- Audit shell scripts in `plugins/*/skills/*/scripts/` before granting execute permissions

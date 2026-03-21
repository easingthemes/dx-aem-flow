# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in this project, please report it responsibly.

**Do not open a public issue.** Instead, email the maintainer directly or use GitHub's private vulnerability reporting feature.

## Scope

This project consists of Markdown-based plugins (skills, agents, rules) and shell helper scripts. There is no server-side code or authentication system. Potential security concerns include:

- Shell scripts that execute with user privileges
- MCP server configurations that connect to external services
- Template files that may contain placeholder credentials

## Best Practices for Users

- Never commit `.env` files or API keys to your project
- Review MCP server configurations before enabling them
- Audit shell scripts in `plugins/*/skills/*/scripts/` before granting execute permissions

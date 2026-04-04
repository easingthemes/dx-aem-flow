# Privacy Policy

**Last updated:** 2026-04-04

## Overview

The DX plugins (dx-core, dx-aem, dx-hub, dx-automation) are instruction-only extensions consisting of Markdown files, shell scripts, and configuration templates. They do not independently collect, store, process, or transmit any user data.

## No Data Collection

These plugins:

- Do **not** collect any personal information
- Do **not** send data to any external servers or third parties
- Do **not** include analytics, telemetry, or tracking of any kind
- Do **not** store any data beyond the local project configuration files they generate

## How the Plugins Work

The plugins provide structured instructions (skills, agents, rules, hooks) that are interpreted and executed by a host tool such as Claude Code or GitHub Copilot. Any data access — including reading files, calling APIs (Azure DevOps, Jira, AEM), or interacting with external services — is performed entirely by the host tool under its own privacy policy and the user's existing permissions.

## Third-Party Services

The plugins include configuration templates for connecting to third-party services (Azure DevOps, Jira, Figma, AEM). These connections are:

- Configured by the user in their own project (`.ai/config.yaml`)
- Authenticated with the user's own credentials
- Executed by the host tool, not by the plugins

Refer to the privacy policies of the respective host tools and services for details on how they handle your data.

## Local Configuration

The `/dx-init` and `/aem-init` skills generate local configuration files (`.ai/config.yaml`, `.ai/rules/`, etc.) within your project directory. These files remain on your local machine and are under your control.

## Contact

For questions about this privacy policy, please open an issue at [github.com/easingthemes/dx-aem-flow](https://github.com/easingthemes/dx-aem-flow/issues).

## License

These plugins are distributed under the [MIT License](LICENSE).

# dx-aem-ai-flow

Three Claude Code plugins for AI-assisted Azure DevOps and Jira/Confluence development workflows.

## Install

Add the marketplace, then install the plugins you need:

```bash
# Add the marketplace (once)
/plugin marketplace add easingthemes/dx-aem-ai-flow

# Install plugins
/plugin install dx-dev-experience@dx-aem-ai-flow   # Core workflow (all projects)
/plugin install dx-aem@dx-aem-ai-flow              # AEM tools (AEM projects)
/plugin install dx-automation@dx-aem-ai-flow        # Autonomous agents (24/7 pipelines)
```

From a local clone:

```bash
/plugin marketplace add /path/to/dx-aem-ai-flow
/plugin install dx-dev-experience@dx-aem-ai-flow
```

## Plugins

### [dx-dev-experience](plugins/dx-dev-experience/) — Development Workflow

Full-stack development workflow for Azure DevOps and Jira projects: requirements gathering, implementation planning, step-by-step execution with testing and review, code review, bug fixes, and PR management.

**42 skills, 5 agents.** Works with any tech stack.

### [dx-aem](plugins/dx-aem/) — AEM Component Tools

AEM-specific tools: component dialog inspection, page search, snapshot/verify lifecycle, QA automation, and demo capture.

**9 skills, 4 agents.** Requires dx plugin.

### [dx-automation](plugins/dx-automation/) — Autonomous Agents

Autonomous AI agents (DoR checker, DoD checker, DoD fixer, PR reviewer, PR answerer, BugFix agent, QA agent, DevAgent, DOCAgent) running 24/7 as ADO pipelines triggered by AWS Lambda webhooks.

**11 skills.** Requires dx plugin.

## Client-Specific Plugins

Client-specific plugins can live alongside these plugins for project-specific enrichment (market data, brand config, etc.). See the [authoring guide](https://easingthemes.github.io/dx-aem-ai-flow/reference/authoring/) for how to create them.

## Quick Start

### With Claude Code (interactive)

```bash
# 1. Install
/plugin marketplace add easingthemes/dx-aem-ai-flow
/plugin install dx-dev-experience@dx-aem-ai-flow

# 2. Initialize your project
/dx-init

# 3. Work on a story
/dx-req-all 2416553        # Fetch story, distill requirements, research codebase
/dx-plan                    # Generate implementation plan
/dx-step-all                # Execute all steps autonomously
/dx-step-build              # Build & deploy
/dx-step-verify             # 6-phase verification
/dx-pr                      # Create pull request
```

### Without Claude Code (standalone scaffold)

For users who don't have Claude Code, the CLI utility creates the same project structure with default values:

```bash
# From a clone of this repo:
node dx/cli/bin/dx-scaffold.js /path/to/your-project --all

# Flags: --aem (AEM files), --copilot (Copilot agents), --all (both)
```

Auto-detects git remote, SCM provider, project type, and base branch. Outputs ~144 files with TODO placeholders — edit `.ai/config.yaml` afterwards. See [cli/README.md](cli/README.md) for details.

## Documentation

Full documentation: [KAI Website](https://easingthemes.github.io/dx-aem-ai-flow/)

- [Learn](https://easingthemes.github.io/dx-aem-ai-flow/learn/intro/) — AI fundamentals, skills, agents, hooks
- [Workflows](https://easingthemes.github.io/dx-aem-ai-flow/workflows/local/) — Step-by-step guides
- [Reference](https://easingthemes.github.io/dx-aem-ai-flow/reference/skills/) — Skills, agents, config schema
- [Architecture](https://easingthemes.github.io/dx-aem-ai-flow/architecture/overview/) — System design
- [Setup](https://easingthemes.github.io/dx-aem-ai-flow/setup/claude-code/) — Installation guides

### Run docs locally

```bash
cd website && npm install && npm run dev
# Opens at http://localhost:4321
```

## License

MIT

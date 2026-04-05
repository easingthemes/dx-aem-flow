# Installing dx-aem-flow Skills for Codex

Codex discovers skills from `.agents/skills/` directories. To use dx-aem-flow skills with Codex, symlink the plugin skill directories.

## Quick Setup

```bash
# Clone the repo
git clone https://github.com/easingthemes/dx-aem-flow.git ~/.dx-aem-flow

# Create the Codex skills directory
mkdir -p .agents/skills

# Symlink dx-core skills (recommended for all projects)
for skill in ~/.dx-aem-flow/plugins/dx-core/skills/*/; do
  ln -sf "$skill" ".agents/skills/$(basename "$skill")"
done

# Symlink dx-aem skills (AEM projects only)
for skill in ~/.dx-aem-flow/plugins/dx-aem/skills/*/; do
  ln -sf "$skill" ".agents/skills/$(basename "$skill")"
done
```

## What You Get

- **dx-core:** Requirements, planning, execution, review, and PR workflows
- **dx-aem:** AEM component verification, QA, and demo capture
- **dx-hub:** Multi-repo orchestration
- **dx-automation:** Autonomous pipeline agents

## Prerequisites

Skills read project config from `.ai/config.yaml`. Generate it with the standalone CLI:

```bash
node ~/.dx-aem-flow/cli/bin/dx-scaffold.js . --all
```

## Notes

- Skills use the [Agent Skills](https://agentskills.io/specification) open standard (SKILL.md format)
- MCP servers (ADO, Figma, AEM, etc.) need separate configuration in your project
- See `AGENTS.md` in the repo root for full conventions

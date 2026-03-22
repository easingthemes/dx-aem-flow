# TODO: Extract Website Constants

## Problem

Skill/agent/plugin counts are hardcoded in 20+ places across website pages. Every version bump requires a grep-and-replace across all files.

## Proposal

Create `website/src/config/stats.ts`:

```ts
export const stats = {
  totalSkills: 68,
  dxCoreSkills: 42,
  dxAemSkills: 12,
  dxHubSkills: 3,
  dxAutomationSkills: 11,
  claudeAgents: 12,
  copilotAgents: 25,
  totalPlugins: 4,
  autonomousAgents: 10,
  mcpServers: 6,
};
```

Import in `.mdx` pages:
```mdx
import { stats } from '../../config/stats';

<div>{stats.totalSkills} skills</div>
```

## Other candidates for constants

- Plugin names and descriptions (repeated in index, demo, learn/intro)
- Figma demo URL (repeated in usage/index, demo/index)
- GitHub repo URL
- Website base URL patterns

## Files to update (~15 pages)

- index.mdx, demo/index.mdx, learn/intro.mdx, learn/skills.mdx, learn/tips.mdx
- learn/cli-vs-chat.mdx, learn/agents.mdx, setup/copilot-cli.mdx
- architecture/overview.mdx, reference/skills.mdx
- 5 content/tips/*.md files

## Priority

Low — works fine with grep, but gets annoying on every refactor. Do it next time counts change.

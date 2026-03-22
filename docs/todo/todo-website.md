# TODO: Website Improvements

## Extract Stats Constants

**Added:** 2026-03-22
**Problem:** Skill/agent/plugin counts are hardcoded in ~20 places across website `.mdx` pages. Every version bump or skill refactor requires a grep-and-replace across all files. Easy to miss one.
**Scope:** `website/src/` — approximately 15 pages: `index.mdx`, `demo/index.mdx`, `learn/intro.mdx`, `learn/skills.mdx`, `learn/tips.mdx`, `learn/cli-vs-chat.mdx`, `learn/agents.mdx`, `setup/copilot-cli.mdx`, `architecture/overview.mdx`, `reference/skills.mdx`, plus ~5 `content/tips/*.md` files.
**Done-when:** `website/src/config/stats.ts` exists AND `grep -rn "68 skills\|42 skills\|12 skills\|11 skills" website/src/content/ website/src/pages/` returns no matches (all counts come from the import).

**Approach:** Create `website/src/config/stats.ts`:

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

Import in `.mdx` pages: `import { stats } from '../../config/stats';`

**Other candidates for constants:** Plugin names/descriptions, Figma demo URL, GitHub repo URL, website base URL patterns.

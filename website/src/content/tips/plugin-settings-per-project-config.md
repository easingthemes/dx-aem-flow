---
title: "Plugin Settings: Per-Project Config"
category: "Plugins — Full Package"
focus: "Claude Code"
tags: ["Settings","Per-Project","local.md"]
overview: "Plugins need different settings per project — different AEM URLs, different markets, different build commands. The pattern: .claude/plugin-name.local.md with YAML frontmatter. It's gitignored (per-project), loaded by the plugin, and separates config from code."
codeLabel: "Per-project plugin config"
screenshot: null
week: 8
weekLabel: "Skills — Advanced"
order: 39
slackText: |
  🤖 Agentic AI Tip #39 — Plugin Settings: Per-Project Config
  
  A plugin that works the same way in every project isn't very useful. Real projects have different URLs, different markets, different conventions.
  
  *The pattern:*
  `.claude/<plugin-name>.local.md` — a per-project config file with YAML frontmatter.
  
  ```yaml
  ---
  aem:
    author-url: http://localhost:4502
    author-url-qa: https://qa-author.example.com
    active-markets: [gb, de, fr]
  ---
  ```
  
  *Why .local.md?*
  • `.local` = gitignored (project-specific, not committed)
  • `.md` = can include both structured YAML and free-text notes
  • Plugin reads the YAML for settings, ignores the markdown
  
  *What goes in plugin settings:*
  • Environment URLs (local, QA, staging)
  • Market/locale scoping
  • Feature flags
  • API endpoints
  • Credentials references (point to env vars, never store secrets)
  
  *What does NOT go here:*
  • Secrets (use environment variables)
  • Shared team conventions (use `.ai/config.yaml`)
  • Temporary state (use spec directory files)
  
  💡 Try it: Check if your project has any `.claude/*.local.md` files. If you're using plugins, configure the per-project settings.
  
  #AgenticAI #Day39
---

```
# .claude/dx-aem.local.md
---
aem:
  author-url: http://localhost:4502
  author-url-qa: https://qa-author.example.com
  active-markets: [gb, de, fr]
  demo-parent-path: /content/brand-a/gb/en
---

Additional notes for this project...
```

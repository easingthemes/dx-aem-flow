---
title: "Plugin Settings: Per-Project Config"
category: "Plugins — Full Package"
focus: "Claude Code"
tags: ["Settings","Per-Project","local.md"]
overview: "Plugins need different settings per project — different AEM URLs, different markets, different build commands. The pattern: .claude/plugin-name.local.md with YAML frontmatter. It's gitignored (per-project), loaded by the plugin, and separates config from code."
screenshot: null
week: 8
weekLabel: "Skills — Advanced"
order: 39
slackOneLiner: "🤖 Tip #39 — Use `.claude/<plugin-name>.local.md` for per-project plugin settings — gitignored YAML frontmatter that separates config from code."
keyPointsTitle: "The Three Config Layers"
actionItemsTitle: "What Goes Where"
keyPoints:
  - "**`.claude/<plugin-name>.local.md`** — Per-project config with YAML frontmatter. The plugin reads the YAML for settings and ignores the markdown body. `.local` means gitignored, `.md` means it can include free-text notes."
  - "**`.ai/config.yaml`** — Shared team conventions that get committed. Build commands, branch names, project structure — everything the team agrees on."
  - "**Spec directory files** — Temporary per-ticket state in `.ai/specs/<id>/`. Created during work, discarded after merge."
  - "**Why three layers** — Team conventions are shared (config.yaml). Developer preferences are local (local.md). Ticket context is temporary (spec files). Each has a different lifecycle and audience."
actionItems:
  - |
    **What goes in plugin settings (.local.md)**
    - `aem.author-url` — http://localhost:4502
    - `aem.author-url-qa` — https://qa-author.example.com
    - `aem.active-markets` — [gb, de, fr]
    - `aem.demo-parent-path` — /content/brand-a/gb/en
  - |
    **What does NOT go here**
    - Secrets — use environment variables, never store directly
    - Shared team conventions — use `.ai/config.yaml` instead
    - Temporary state — use spec directory files
  - "**Never store secrets directly** — Reference environment variables instead (e.g., `auth-token: $AEM_AUTH_TOKEN`). The .local.md file is gitignored but secrets still shouldn't be in plain text."
  - "**Check your project** — Look for `.claude/*.local.md` files. If you're using plugins but don't have these, you may be missing per-project configuration."
---

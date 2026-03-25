---
title: "Writing Your First Custom Skill"
category: "Skills — Recipe Book"
focus: "Claude Code"
tags: ["Custom","Commands","DIY"]
overview: "You can create a custom skill in under 2 minutes. Create a markdown file in .claude/commands/, add frontmatter and instructions, and invoke it with /your-skill-name. Start with something small — a build checker, a convention reminder, a component scaffolder."
screenshot: null
week: 3
weekLabel: "Context — The Secret Sauce"
order: 15
slackOneLiner: "🤖 Tip #15 — Stop repeating yourself. Write a skill once in 2 minutes, use it forever — no JavaScript, no API, no build step."
keyPointsTitle: "Four Steps to a Skill"
actionItemsTitle: "Build One Right Now"
keyPoints:
  - "**Step 1 — Create the file** — Just a markdown file at `.claude/commands/check-component.md`. That's the only location requirement."
  - "**Step 2 — Add frontmatter** — name, description, argument-hint, and allowed-tools in a YAML block. This controls how the skill behaves and what it can access."
  - "**Step 3 — Write instructions** — Numbered steps telling the AI what to do. 'Find the component, verify it extends CustomComponent, check lifecycle methods, report findings with file:line references.'"
  - "**Step 4 — Use it** — Type `/check-component hero` and the AI follows your instructions exactly. No JavaScript, no API, no build step."
actionItems:
  - "**Find your first candidate** — Think of an instruction you've given AI more than twice. A build checker, a convention reminder, a component scaffolder. That's your first skill."
  - |
    Create the skill file now
    - Create `.claude/commands/your-skill.md`
    - Add frontmatter: name, description, argument-hint, allowed-tools
    - Write 3-5 numbered instruction steps
    - Test with `/your-skill <argument>`
  - "**Commit to git** — Once the skill file is in version control, your entire team has the skill automatically. Shared knowledge encoded as a file."
  - "**Start small, iterate** — Your first skill doesn't need to be perfect. Get it working, then refine the instructions as you use it."
---

---
title: "Writing Your First Custom Skill"
category: "Skills — Recipe Book"
focus: "Claude Code"
tags: ["Custom","Commands","DIY"]
overview: "You can create a custom skill in under 2 minutes. Create a markdown file in .claude/commands/, add frontmatter and instructions, and invoke it with /your-skill-name. Start with something small — a build checker, a convention reminder, a component scaffolder."
codeLabel: "Your first skill"
screenshot: null
week: 3
weekLabel: "Context — The Secret Sauce"
order: 15
slackText: |
  🤖 Agentic AI Tip #15 — Writing Your First Custom Skill
  
  Stop telling AI the same instructions over and over. Write a skill once, use it forever.
  
  *Step 1:* Create the file
  ```
  .claude/commands/check-component.md
  ```
  
  *Step 2:* Add frontmatter
  ```yaml
  ---
  name: check-component
  description: Verify a web component follows project patterns
  argument-hint: "<component-name>"
  allowed-tools: [read, grep, glob]
  ---
  ```
  
  *Step 3:* Write instructions
  ```
  1. Find the component file matching the given name in src/
  2. Verify it extends CustomComponent
  3. Check that lifecycle methods (beforeLoad, afterLoad) exist
  4. Check that data-model parsing is implemented
  5. Report findings with specific file:line references
  ```
  
  *Step 4:* Use it
  ```
  /check-component hero
  ```
  
  That's it. No JavaScript, no API, no build step. Just a markdown file that the AI follows as instructions.
  
  *Pro tip:* Commit the file to git. Now your entire team has the skill.
  
  💡 Try it: Think of an instruction you've given AI more than twice. Write it as a skill file right now. It takes 2 minutes.
  
  #AgenticAI #Day15
---

```
# .claude/commands/check-component.md
---
name: check-component
description: Verify a web component
  follows project patterns
argument-hint: "<component-name>"
allowed-tools: [read, grep, glob]
---

1. Find the component file in src/
2. Verify it extends CustomComponent
3. Check lifecycle methods exist
4. Report any missing patterns
```

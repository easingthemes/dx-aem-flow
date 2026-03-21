---
title: "What is a Skill?"
category: "Skills — Recipe Book"
focus: "Claude Code · CLI"
tags: ["Skill","Markdown","Slash Command"]
overview: "A skill is just a markdown file with instructions. When you type /skill-name, the AI reads the file and follows its instructions. Think of it as a recipe — you write it once, and the AI follows it every time. No code, no API, just a text file."
codeLabel: "A simple skill"
screenshot: null
week: 3
weekLabel: "Context — The Secret Sauce"
order: 12
slackText: |
  🤖 Agentic AI Tip #12 — What is a Skill?
  
  A skill is the simplest concept in agentic AI — and the most powerful.
  
  *It's a markdown file with instructions.*
  
  That's it. You write a `.md` file, put it in the right directory, and invoke it with `/skill-name`. The AI reads the instructions and follows them.
  
  *Why this is powerful:*
  • *Repeatable* — same instructions, consistent results
  • *Shareable* — commit to git, entire team benefits
  • *Composable* — skills can invoke other skills
  • *No code needed* — it's just markdown
  
  *Where skills live:*
  • `.claude/commands/` — for Claude Code
  • `.github/skills/` — for Copilot CLI (in GitHub repos)
  
  *The anatomy of a skill:*
  1. YAML frontmatter (name, description, tools)
  2. Instructions (what the AI should do)
  3. Optional: scripts, references, templates
  
  Think of the difference between telling a new hire "figure out the build" vs handing them a step-by-step checklist. Skills are the checklist.
  
  💡 Try it: Create `.claude/commands/hello.md` with the content "Say hello and tell me three interesting facts about this project." Then run `/hello` in Claude Code.
  
  #AgenticAI #Day12
---

```
# .claude/commands/check-build.md
---
name: check-build
description: Run build and report errors
allowed-tools: [bash, read]
---

Run the build command from CLAUDE.md.
If it fails, read the error output and
suggest specific fixes for each error.
```

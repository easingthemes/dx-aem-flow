---
title: "What is a Skill?"
category: "Skills — Recipe Book"
focus: "Claude Code · CLI"
tags: ["Skill","Markdown","Slash Command"]
overview: "A skill is just a markdown file with instructions. When you type /skill-name, the AI reads the file and follows its instructions. Think of it as a recipe — you write it once, and the AI follows it every time. No code, no API, just a text file."
screenshot: null
week: 3
weekLabel: "Context — The Secret Sauce"
order: 12
slackOneLiner: "🤖 Tip #12 — A skill is a markdown file with instructions. Write it once, invoke with /skill-name, get consistent results every time. No code needed."
keyPointsTitle: "The Simplest, Most Powerful Concept"
keyPoints:
  - "A skill is the simplest concept in agentic AI — and the most powerful. It's a markdown file with instructions. Put it in the right directory, invoke it with /skill-name."
  - |
    Why skills are powerful
    - Repeatable — same instructions, consistent results
    - Shareable — commit to git, entire team benefits
    - Composable — skills can invoke other skills
    - No code needed — it's just markdown
  - |
    The anatomy of a skill
    - YAML frontmatter (name, description, tools)
    - Instructions (what the AI should do)
    - Optional: scripts, references, templates
  - "Think of the difference between telling a new hire 'figure out the build' vs handing them a step-by-step checklist. Skills are the checklist."
actionItemsTitle: "Get Started in 2 Minutes"
actionItems:
  - |
    Where skills live
    - .claude/commands/ — for Claude Code
    - .github/skills/ — for Copilot CLI (in GitHub repos)
  - "Create .claude/commands/hello.md with 'Say hello and tell me three interesting facts about this project' — then run /hello in Claude Code"
  - "Identify a task you repeat weekly and write a skill for it — you'll save time on every future run"
  - "Commit your skills to git so the entire team can invoke them with the same /command"
---

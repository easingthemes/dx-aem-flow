---
title: "CLAUDE.md: Your Project's Brain"
category: "Context — The Secret Sauce"
focus: "Claude Code"
tags: ["CLAUDE.md","Project Config","Auto-loaded"]
overview: "CLAUDE.md sits at your project root and gets loaded into every Claude Code session automatically. It contains build commands, conventions, gotchas, and architecture decisions. This single file has more impact on AI quality than any prompt engineering technique."
codeLabel: "CLAUDE.md example"
screenshot: null
week: 2
weekLabel: "Meet Your AI Tools"
order: 7
slackText: |
  🤖 Agentic AI Tip #7 — CLAUDE.md: Your Project's Brain
  
  This is the single highest-ROI file you can create for AI-assisted development.
  
  `CLAUDE.md` lives at your project root and is automatically loaded into every Claude Code session. Think of it as your project's operating manual — but for AI.
  
  *What to put in it:*
  • *Build commands* — so AI can compile and test without guessing
  • *Project structure* — which directories contain what
  • *Naming conventions* — how you name files, components, branches
  • *Architecture patterns* — the decisions behind your code
  • *Gotchas* — things that trip up newcomers (and AI)
  
  *What NOT to put:*
  • Things derivable from code (function signatures, imports)
  • Git history (use git log)
  • Temporary notes (use tasks instead)
  
  *Why it matters:*
  Without CLAUDE.md, every AI session starts from zero — the AI guesses your conventions and gets them wrong. With it, the AI behaves like a team member who's read the onboarding docs.
  
  The file compounds in value. Every gotcha you add saves time in every future session.
  
  💡 Try it: Create a CLAUDE.md with your project's build command and one naming convention. Watch the difference in AI responses.
  
  #AgenticAI #Day7
---

```
# CLAUDE.md structure
## Commands
npm run build    # frontend build
mvn clean install # full deploy

## Conventions
- ESLint: Airbnb + Prettier
- Branches: feature/*, bugfix/*
- PR target: development (never main)

## Architecture
Custom Elements extending BATComponent
```

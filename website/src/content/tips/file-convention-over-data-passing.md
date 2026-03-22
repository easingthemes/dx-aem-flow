---
title: "File Convention Over Data Passing"
category: "Skills — Advanced"
focus: "Claude Code"
tags: ["Spec Directory","Convention","Decoupling"]
overview: "Our skills don't pass data through APIs or return values. Instead, each skill writes output to a predictable file location (.ai/specs/<id>/). The next skill reads from the same location. This decouples skills completely — each can be tested and run independently."
codeLabel: "File convention"
screenshot: null
week: 4
weekLabel: "Context — The Secret Sauce"
order: 19
slackText: |
  🤖 Agentic AI Tip #19 — File Convention Over Data Passing
  
  How do you pass data between AI skills that run in separate contexts? You don't.
  
  Instead, we use a *file convention*: each skill writes its output to a predictable location, and the next skill knows where to look.
  
  ```
  .ai/specs/<ticket-id>-<slug>/
  ├── raw-story.md      ← /dx-req writes this (Phase 1: fetch)
  ├── explain.md        ← /dx-req writes this (Phase 3: explain)
  ├── research.md       ← /dx-req writes this (Phase 4: research)
  ├── implement.md      ← /dx-plan reads all above, writes this
  └── figma-extract.md  ← /dx-figma-extract writes this
  ```
  
  *Why this beats data passing:*
  1. *Inspectable* — you can read any file to see what happened
  2. *Resumable* — skip a step and re-run just what you need
  3. *Testable* — each skill is independent
  4. *Debuggable* — if step 3 fails, check step 2's output
  
  *No APIs, no return values, no coupling.* Skills find each other's output by convention. This is the same principle as Unix pipes — small tools, predictable I/O.
  
  💡 Try it: Run `/dx-req <id>` then look inside `.ai/specs/`. Read the files. You'll see exactly what the AI captured.
  
  #AgenticAI #Day19
---

```
# /dx-req writes all phases:
.ai/specs/12345-login-bug/raw-story.md
.ai/specs/12345-login-bug/explain.md
.ai/specs/12345-login-bug/research.md

# /dx-plan reads explain.md, writes:
.ai/specs/12345-login-bug/implement.md

# Each skill is independent!
```

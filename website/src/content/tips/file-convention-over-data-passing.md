---
title: "File Convention Over Data Passing"
category: "Skills — Advanced"
focus: "Claude Code"
tags: ["Spec Directory","Convention","Decoupling"]
overview: "Our skills don't pass data through APIs or return values. Instead, each skill writes output to a predictable file location (.ai/specs/<id>/). The next skill reads from the same location. This decouples skills completely — each can be tested and run independently."
screenshot: null
week: 4
weekLabel: "Context — The Secret Sauce"
order: 19
slackOneLiner: "🤖 Tip #19 — How do you pass data between AI skills in separate contexts? You don't. Use a file convention — each skill writes to a predictable location, the next knows where to look."
keyPointsTitle: "The Design Pattern"
actionItemsTitle: "See It in Action"
keyPoints:
  - "**The pattern** — Each skill writes its output to a predictable location (`.ai/specs/<ticket-id>-<slug>/`), and the next skill knows where to look. No APIs, no return values, no coupling."
  - "**Same principle as Unix pipes** — Small tools, predictable I/O. Skills find each other's output by convention, not by API contracts or shared memory."
  - "**Inspectable** — You can read any file to see exactly what happened. `raw-story.md` shows what was fetched, `explain.md` shows how it was interpreted, `implement.md` shows the plan."
  - "**Testable and debuggable** — Each skill is fully independent. If step 3 fails, check step 2's output file. Mock any input by writing the expected file manually."
actionItems:
  - "**Try the flow** — Run `/dx-req <id>` then look inside `.ai/specs/` — read the files to see exactly what the AI captured at each phase."
  - |
    Understand the file flow
    - `/dx-req` writes: raw-story.md, explain.md, research.md
    - `/dx-plan` reads explain.md + research.md, writes: implement.md
    - `/dx-figma-extract` writes: figma-extract.md
    - Each skill is independent — test and run them in any order
  - "**Resumable by design** — Skip a step and re-run just what you need. `/dx-plan` reads `explain.md` which is already there from `/dx-req`. No need to re-run the entire chain."
  - "**Apply to custom skills** — When building your own skills, follow the same convention. Write output to `.ai/specs/<id>/` so other skills can chain from it."
---

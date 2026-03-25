---
title: "argument-hint: Making Skills Discoverable"
category: "Skills — Advanced"
focus: "Claude Code · CLI"
tags: ["argument-hint","Autocomplete","UX"]
overview: 'When you type / in Claude Code, you see a list of skills. The argument-hint field tells users what to pass before they even read the docs. "/dx-req <ticket-id>" is instantly clear. Without it, users have to guess what the skill expects.'
screenshot: null
week: 4
weekLabel: "Context — The Secret Sauce"
order: 17
slackOneLiner: "🤖 Tip #17 — Add argument-hint to every skill. Without it users see `/fetch-ticket` and wonder what to pass. With it they see `/fetch-ticket <ticket-id>` — instantly clear."
keyPointsTitle: "Why Hints Matter"
actionItemsTitle: "Hint Formatting Guide"
keyPoints:
  - "**Without argument-hint** — Users see `/fetch-ticket` and have to guess: a URL? An ID? A name? Confusion kills adoption."
  - "**With argument-hint** — Users see `/fetch-ticket <ticket-id>` in autocomplete. Instantly clear what to pass, zero guesswork."
  - "**Discoverability equals adoption** — A skill nobody knows how to invoke is a skill nobody uses. The 10 seconds you spend on argument-hint saves every user 30 seconds of confusion."
  - "**Match what users actually type** — Use `\"<component-name>\"` not `\"<ComponentNameInPascalCase>\"`. The hint should reflect real usage patterns, not internal naming conventions."
  - "**Compound hints work too** — Skills with multiple arguments: `\"<ticket-id> [--verbose]\"`. Show the full invocation pattern in one glance."
actionItems:
  - |
    Follow these conventions for hint text
    - Required args use angle brackets: `"<ticket-id>"`
    - Optional args use square brackets: `"[--verbose]"`
    - Be specific: `"<ADO-work-item-id>"` not `"<id>"`
    - Match real usage: `"<component-name>"` not `"<ComponentNameInPascalCase>"`
  - "**Audit existing skills** — Grep your skills directory for files missing argument-hint and add it to every one"
  - "**Verify in autocomplete** — After adding hints, type `/` in Claude Code and check that your hints render correctly and read naturally"
  - "**Use the hint as documentation** — A well-written argument-hint replaces the need for a README. Users see `<ticket-id>` and immediately know what to pass."
---

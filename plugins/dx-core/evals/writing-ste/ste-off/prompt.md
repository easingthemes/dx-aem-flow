---
name: writing-ste-off
description: Control arm. Same task as writing-ste-on, with no writing rule in the system prompt.
tags: [writing-ste]
runs: 3
max_turns: 10
timeout_seconds: 300
allowed_tools: [Read, Glob, Write]
---

Read the ticket notes in `.ai/specs/demo/` (`explain.md` and `research.md`).
Write a summary for the development team to `.ai/specs/demo/summary.md`. Cover
what changes, how it will be built, and the risks. Keep it under 300 words.

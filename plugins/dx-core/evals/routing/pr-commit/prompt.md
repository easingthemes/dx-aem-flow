---
name: routing-pr-commit
description: Natural phrasing that should route to dx-pr-commit and not to a sibling skill.
tags: [routing]
plugins: ["../../..", "../../../../dx-aem", "../../../../dx-hub", "../../../../dx-automation"]
runs: 1
max_turns: 6
timeout_seconds: 240
allowed_tools: [Read, Glob, Grep, Skill]
append_system_prompt: "This session is a skill-routing test. Decide whether one of the available skills fits the request. If one does, invoke it with the Skill tool, then stop immediately and reply only 'routed' without following the skill's instructions. If none fits, answer the request directly and briefly."
---

Commit my current changes with a proper message for work item 1234 and push them.

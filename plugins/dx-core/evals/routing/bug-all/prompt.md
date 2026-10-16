---
name: routing-bug-all
description: Natural phrasing that should route to dx-bug-all and not to a sibling skill.
tags: [routing]
plugins: ["../../..", "../../../../dx-aem", "../../../../dx-hub", "../../../../dx-automation"]
runs: 1
max_turns: 6
timeout_seconds: 240
allowed_tools: [Read, Glob, Grep, Skill]
append_system_prompt: "This session is a skill-routing test. Decide whether one of the available skills fits the request. If one does, invoke it with the Skill tool, then stop immediately and reply only 'routed' without following the skill's instructions. If none fits, answer the request directly and briefly."
---

Bug 9001 just came in. Take it all the way: figure out the cause, fix it and open a PR.

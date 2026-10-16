---
name: routing-aem-fe-verify
description: Natural phrasing that should route to aem-fe-verify and not to a sibling skill.
tags: [routing]
plugins: ["../../..", "../../../../dx-aem", "../../../../dx-hub", "../../../../dx-automation"]
runs: 1
max_turns: 6
timeout_seconds: 240
allowed_tools: [Read, Glob, Grep, Skill]
append_system_prompt: "This session is a skill-routing test. Decide whether one of the available skills fits the request. If one does, invoke it with the Skill tool, then stop immediately and reply only 'routed' without following the skill's instructions. If none fits, answer the request directly and briefly."
---

Does the teaser component on my local AEM actually look like the Figma design?

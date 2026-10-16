---
name: routing-pr-review-ado
description: Same request as routing-pr-review, but in a project whose CLAUDE.md says it is hosted in Azure DevOps — as every dx consumer is.
tags: [routing]
plugins: ["../../..", "../../../../dx-aem", "../../../../dx-hub", "../../../../dx-automation"]
runs: 1
max_turns: 6
timeout_seconds: 240
allowed_tools: [Read, Glob, Grep, Skill]
append_system_prompt: "This session is a skill-routing test. Decide whether one of the available skills fits the request. If one does, invoke it with the Skill tool, then stop immediately and reply only 'routed' without following the skill's instructions. If none fits, answer the request directly and briefly."
---

Can you look over pull request 4521 and tell me what is wrong with the code in it?

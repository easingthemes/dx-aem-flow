---
name: routing-aem-demo-page
description: Natural phrasing that should route to aem-demo-page and not to a sibling skill.
tags: [routing]
plugins: ["../../..", "../../../../dx-aem", "../../../../dx-hub", "../../../../dx-automation"]
runs: 1
max_turns: 6
timeout_seconds: 240
allowed_tools: [Read, Glob, Grep, Skill]
append_system_prompt: "This session is a skill-routing test. Decide whether one of the available skills fits the request. If one does, invoke it with the Skill tool, then stop immediately and reply only 'routed' without following the skill's instructions. If none fits, answer the request directly and briefly."
---

I just deployed the hero component to my local AEM. Set up a demo page for it and screenshot the dialog and the preview.

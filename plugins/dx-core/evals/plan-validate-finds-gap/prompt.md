---
name: plan-validate-finds-gap
description: >
  dx-plan-validate is given a plan with exactly one planted defect —
  requirement R3 has no covering step. R1 and R2 are correctly covered and
  act as distractors. The correct report names R3 and only R3.
tags: [outcome, plan-validate]
plugins: ["../.."]
runs: 3
max_turns: 30
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, Bash, Write]
---

Use the dx-plan-validate skill to validate the implementation plan in
`.ai/specs/demo` against its requirements.

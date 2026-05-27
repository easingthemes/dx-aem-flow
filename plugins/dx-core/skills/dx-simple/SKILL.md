---
name: dx-simple
description: Apply a small AEM change (a11y label, color, spacing, copy, css-class, icon) by splitting work into authoring (JCR writes) and code (file edits → PR) paths. Use after the ADO story contains a structured ```simple``` block. Trigger on "simple change", "small tweak", "apply tweak".
argument-hint: "<ADO Work Item ID or full URL>"
allowed-tools: ["read", "edit", "search", "write", "agent"]
model: sonnet
hooks:
  PreToolUse:
    - matcher: Bash
      command: ${CLAUDE_PLUGIN_ROOT}/skills/dx-simple/hooks/block-mvn-deploy.sh
      timeout: 5
---

# dx-simple

(Body to be filled in by Tasks 10 and 11. This skill is currently a stub.)

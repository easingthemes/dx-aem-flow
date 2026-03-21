---
title: "Pre-flight Validation: Don't Burn Tokens"
category: "Real-World Workflows"
focus: "Claude Code · CLI"
tags: ["Pre-flight","Validation","Cost"]
overview: "Before running multi-step pipelines, check that all inputs exist, MCP servers respond, and target branches exist. A 2-second check saves 15 minutes of token-burning failure. We learned this the hard way after pipelines failed at step 6 because the MCP server was down."
codeLabel: "Pre-flight pattern"
screenshot: null
week: 10
weekLabel: "Agents — AI Personas"
order: 46
slackText: |
  🤖 Agentic AI Tip #46 — Pre-flight Validation: Don't Burn Tokens
  
  This lesson cost us real money: a 7-step pipeline that failed at step 6 because the AEM MCP server wasn't running.
  
  Steps 1-5 consumed tokens, generated files, and made progress. Step 6 needed AEM MCP and... connection refused. All that work, wasted.
  
  *The fix: pre-flight validation.*
  
  Before any multi-step pipeline, check:
  1. *Do all required inputs exist?* (ticket ID, spec files, URLs)
  2. *Are MCP servers responsive?* (make a lightweight call)
  3. *Does the target branch exist?* (git verify)
  4. *Is the environment correct?* (Node version, config files)
  
  *Implementation:*
  We added pre-flight checks to every coordinator skill. Before dispatching any subagent, the coordinator runs a quick validation. If anything fails, it stops immediately with a clear error message.
  
  *The economics:*
  Pre-flight check: ~$0.01 (one lightweight MCP call)
  Failed pipeline: ~$2-5 (multiple agents, multiple tools, wasted output)
  ROI: 200-500x
  
  *Rule of thumb:* If the pipeline has more than 3 steps, add pre-flight validation. The 2 seconds of checking save 15 minutes of failing.
  
  💡 Try it: Check your last few pipeline failures. How many could have been caught by a pre-flight check?
  
  #AgenticAI #Day46
---

```
# Pre-flight checks:
# 1. Do inputs exist?
[ -f .ai/specs/12345/raw-story.md ]

# 2. Is MCP reachable?
mcp__plugin_dx-aem_AEM__getNodeContent
  path: "/" # lightweight check

# 3. Does the branch exist?
git rev-parse --verify origin/development

# All pass? → Start pipeline
# Any fail? → Stop with clear message
```

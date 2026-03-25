---
title: "Pre-flight Validation: Don't Burn Tokens"
category: "Real-World Workflows"
focus: "Claude Code · CLI"
tags: ["Pre-flight","Validation","Cost"]
overview: "Before running multi-step pipelines, check that all inputs exist, MCP servers respond, and target branches exist. A 2-second check saves 15 minutes of token-burning failure. We learned this the hard way after pipelines failed at step 6 because the MCP server was down."
screenshot: null
week: 10
weekLabel: "Agents — AI Personas"
order: 46
slackOneLiner: "🤖 Tip #46 — A 2-second pre-flight check saves 15 minutes of token-burning failure. Validate inputs, MCP servers, and branches before starting."
keyPointsTitle: "The Problem & The Cost"
actionItemsTitle: "What to Check & Where"
keyPoints:
  - "**The lesson that cost real money** — a 7-step pipeline failed at step 6 because the AEM MCP server wasn't running. Steps 1-5 consumed tokens, generated files, made progress. Step 6 hit 'connection refused.' All wasted."
  - |
    The economics — ROI of 200-500x
    - Pre-flight check: ~$0.01 (one lightweight MCP call)
    - Failed pipeline: ~$2-5 (multiple agents, tools, wasted output)
  - "**Rule of thumb** — if the pipeline has more than 3 steps, add pre-flight validation. The 2 seconds of checking save 15 minutes of failing."
actionItems:
  - |
    Pre-flight checklist — verify before any multi-step pipeline
    - Do all required inputs exist? (ticket ID, spec files, URLs)
    - Are MCP servers responsive? (make a lightweight call)
    - Does the target branch exist? (git verify)
    - Is the environment correct? (Node version, config files)
  - "We added pre-flight checks to every coordinator skill — before dispatching any subagent, the coordinator runs a quick validation. If anything fails, it stops immediately with a clear error message."
  - "Add a lightweight MCP call as the first step of any multi-step workflow — e.g., `getNodeContent path: /` for AEM"
  - "Build pre-flight into coordinator skills, not individual steps — the coordinator validates once, then dispatches with confidence"
---

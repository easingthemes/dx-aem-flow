---
title: "Ask the Right Question"
category: "Meet Your AI Tools"
focus: "All Tools"
tags: ["Prompting","Specificity","Context"]
overview: 'The difference between a useful AI response and a useless one is almost always in the prompt. "Fix this" gives you generic suggestions. "Fix the null pointer in handleSubmit when user.email is undefined on line 47" gives you working code. Specificity beats cleverness.'
screenshot: null
week: 1
weekLabel: "Meet Your AI Tools"
order: 5
slackOneLiner: "🤖 Tip #5 — The #1 skill separating effective AI users from frustrated ones is specificity. Say what, where, why, and how."
keyPointsTitle: "The What/Where/Why/How Pattern"
keyPoints:
  - "Specificity is everything — 'Fix this bug' gets generic suggestions, 'Fix the null pointer in handleSubmit (login.js:47) when user.email is undefined' gets working code."
  - |
    The pattern — four elements that transform prompts
    - What — what's broken or what you need
    - Where — file path, line number, component name
    - Why — user impact, dependency, urgency
    - How — suggested fix direction or approach
  - "Include error messages verbatim — copy-paste the stack trace. AI is remarkably good at parsing error output."
  - "You don't need all four elements every time — but the more context you give, the better the response."
actionItemsTitle: "Bad Prompts vs Good Prompts"
actionItems:
  - |
    Side-by-side comparison
    - 'Fix this bug' → 'Fix the null pointer in handleSubmit (login.js:47) when user.email is undefined — add a null check before the API call'
    - 'Make it faster' → 'The user list page loads in 3s. Profile the component renders, identify unnecessary re-renders, and memoize the expensive computations'
    - 'Refactor the code' → 'Refactor the auth middleware to extract JWT validation into a separate utility — we need it in the WebSocket handler too'
  - "Next time you get a bad AI response, re-ask with the file path, line number, and expected behavior — compare the difference"
  - "Always copy-paste error messages and stack traces verbatim into your prompt instead of paraphrasing them"
---

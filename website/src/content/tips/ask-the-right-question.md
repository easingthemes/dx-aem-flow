---
title: "Ask the Right Question"
category: "Meet Your AI Tools"
focus: "All Tools"
tags: ["Prompting","Specificity","Context"]
overview: 'The difference between a useful AI response and a useless one is almost always in the prompt. "Fix this" gives you generic suggestions. "Fix the null pointer in handleSubmit when user.email is undefined on line 47" gives you working code. Specificity beats cleverness.'
codeLabel: "Prompt comparison"
screenshot: null
week: 1
weekLabel: "Meet Your AI Tools"
order: 5
slackText: |
  🤖 Agentic AI Tip #5 — Ask the Right Question
  
  The #1 skill that separates effective AI users from frustrated ones: specificity.
  
  *Bad prompts:*
  • "Fix this bug"
  • "Make it faster"
  • "Refactor the code"
  
  *Good prompts:*
  • "Fix the null pointer in handleSubmit (login.js:47) when user.email is undefined — add a null check before the API call"
  • "The user list page loads in 3s. Profile the component renders, identify unnecessary re-renders, and memoize the expensive computations"
  • "Refactor the auth middleware to extract the JWT validation into a separate utility — we need it in the WebSocket handler too"
  
  The pattern: *what + where + why + how.*
  
  What's broken/needed, where in the code, why it matters, and what approach you're thinking. You don't need all four every time, but the more context you give, the better the response.
  
  One more trick: include error messages verbatim. Copy-paste the stack trace. AI is remarkably good at parsing error output.
  
  💡 Try it: Next time you get a bad response, re-ask with the file path, line number, and expected behavior.
  
  #AgenticAI #Day5
---

```
# Bad prompt
"Fix the bug"

# Good prompt
"In src/auth/login.js line 47,
 handleSubmit throws when user.email
 is undefined. Add a null check before
 the API call and show a validation
 error to the user."
```

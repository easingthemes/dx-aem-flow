# Twitter/X Strategy

## Platform Context (2026)
- 540M monthly active users, 300M daily
- Threads are the #1 algorithm-boosted format
- Self-contained content outperforms external links
- 1-2 hashtags max per post (more = less engagement)
- Reply strategy is the fastest organic growth method

---

## Content Mix (Daily)

| Type | Frequency | Purpose |
|------|-----------|---------|
| Value tweets (tips, insights) | 2-3/day | Build authority |
| Thread (educational/story) | 2-3/week | Viral potential, bookmarks |
| Engagement replies | 5-10/day | Growth via larger accounts |
| Product mentions | 1/day max | Soft promotion |
| Memes/hot takes | 2-3/week | Shareability |

**80/20 rule:** 80% valuable content, 20% product mentions.

---

## Thread Templates

### Thread 1: "The Structure Gap in AI Dev Tools"
```
🧵 Every dev team uses AI now. Copilot, Cursor, Claude Code.

But here's what nobody talks about:

AI code generation is commoditized.
What's NOT commoditized is structured, enterprise-quality output.

I built dozens of skills that bridge that gap. Open source. Here's what they do:

(1/10)
---
Step 1: /dx-req — Structured Requirements

Instead of ad-hoc prompting, this skill:
→ Fetches the ticket from ADO/Jira
→ Validates Definition of Ready
→ Researches your codebase
→ Produces a named artifact: raw-story.md + explain.md

Same output every time. Regardless of who runs it.

(2/10)
---
Step 2: /dx-plan

AI creates a step-by-step implementation plan.
Checks for risks and dependencies.
Validates coverage against requirements.

No more "I forgot to handle that edge case."

(3/10)
---
Step 3: /dx-step-all

AI executes every step:
→ Implement the code
→ Run tests
→ Self-review
→ Commit

It loops until tests pass.

(4/10)
---
Step 4: /dx-step-verify

6-phase verification gate:
1. Compile check
2. Linting
3. Unit tests
4. Secret scanning
5. Architecture review
6. AI code review (Opus-level reasoning)

(5/10)
---
Step 5: /dx-pr

AI creates the PR with:
→ Full context from the ticket
→ Implementation notes
→ Test results
→ Before/after screenshots

Your reviewer gets everything they need.

(6/10)
---
Why does this matter?

Because with raw AI tools:
→ Developer A gets different output than Developer B
→ No audit trail of what was analyzed
→ No verification before shipping
→ Quality depends on the prompt

With structured skills:
→ Same input = same quality output. Every time.

(7/10)
---
It gets better: same skills run in CI/CD.

10 autonomous agents on Azure DevOps pipelines.
Same structured output, enforced automatically.

DoR validation, PR review, DoD checks — all 24/7.
Enterprise governance without manual overhead.

(8/10)
---
The architecture:

→ Config-driven (one YAML, zero hardcoded values)
→ Named artifacts at every step (.ai/specs/)
→ Three-layer override system (rules > config > defaults)
→ Model tiering (Opus/Sonnet/Haiku by task complexity)
→ Works on Claude Code, Copilot CLI, VS Code Chat

(9/10)
---
Want to try it?

⭐ Star us: github.com/easingthemes/dx-aem-flow
📖 Docs: [docs site URL]

It takes 2 minutes to install and 1 command to start.

/dx-init → you're ready.

(10/10)
```

### Thread 2: "Why Raw AI Output Isn't Enterprise-Ready"
```
Every AI tool can generate code. That's table stakes in 2026.

But here's what enterprise teams actually need — and almost no tool provides:

🧵👇
---
Problem 1: Inconsistent output quality.

Developer A prompts Cursor → gets clean code.
Developer B prompts the same tool → gets spaghetti.

The quality depends on the prompt, not the process.
Enterprise teams need consistent output regardless of who runs it.
---
Problem 2: No structured artifacts.

Raw AI gives you a code diff. That's it.

Where's the requirements analysis?
Where's the implementation plan?
Where's the verification report?
Where's the audit trail?

Enterprise teams need traceability, not just code.
---
Problem 3: No governance.

Enterprise teams need:
- Definition of Ready validation before coding starts
- Multi-phase verification (not just "does it compile")
- Secret scanning, architecture review
- Consistent quality gates in CI/CD

Raw AI tools don't enforce any of this.
---
The fix: Structured skills that encode process discipline.

dozens of skills. Each produces named artifacts.
Config-driven — one YAML file, consistent across the team.
Same skills run locally AND in CI/CD pipelines.

Enterprise-quality output. Every time. Open source: [link]
```

### Thread 3: "From Figma to Production in One Command"
```
I turned a Figma URL into a production AEM component.

One command. Full pipeline. Verified output.

Here's the 4-step process 🧵
---
Step 1: /dx-figma-extract

→ Pulls design tokens from Figma
→ Extracts spacing, colors, typography
→ Maps to your SCSS variables
→ Takes reference screenshots

All from a Figma URL.
---
Step 2: /dx-figma-prototype

→ Generates convention-aware HTML/CSS
→ Follows your BEM naming
→ WCAG-compliant ARIA patterns
→ Responsive breakpoints

A working prototype in minutes.
---
Step 3: /dx-figma-verify

→ Screenshots the prototype
→ Compares against Figma design
→ Identifies pixel differences
→ Auto-fixes what it can
→ Reports remaining issues

Visual verification BEFORE you write production code.
---
Step 4: /dx-plan + /dx-step-all

→ Plans the production implementation
→ Builds the real AEM component
→ Tests it
→ Creates the PR

From verified prototype to merged code.

The entire pipeline is open source.
⭐ [GitHub link]
```

---

## Hashtag Strategy

**Primary (rotate, 1-2 per post):**
`#DevTools` `#OpenSource` `#AI` `#ClaudeCode`

**Secondary (topic-specific):**
`#GitHubCopilot` `#VSCode` `#AzureDevOps` `#AEM` `#DevOps` `#AgenticAI` `#BuildInPublic` `#100DaysOfCode`

---

## Growth Tactics

1. **Reply to big accounts** — Find tweets from @AnthropicAI, @GitHubCopilot, @code (VS Code) about AI dev tools. Reply with genuine insight + subtle mention.
2. **Quote tweet with takes** — Don't just retweet. Add your perspective.
3. **Pin your best thread** — Update monthly with whatever has most engagement.
4. **Bookmark bait** — Posts with "save this for later" frameworks get 3x bookmarks.
5. **Build in public** — Weekly updates: "Week X of building dx-aem-flow: [milestone]"

## Paid Promotion

- Promote best-performing threads: $15-25/day
- Target: Developers, DevOps, AI enthusiasts
- Monthly budget: $500
- Expected CPC: $1-5 (cheaper than LinkedIn)

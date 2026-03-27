# Launch Platforms — Product Hunt, Hacker News & Others

## Product Hunt Launch Playbook

### Pre-Launch (4-6 weeks before)

- [ ] Create product page on Product Hunt (teaser mode)
- [ ] Write: headline, tagline, 3-sentence description
- [ ] Prepare gallery: 5-6 images (hero, architecture diagram, demo screenshots, before/after)
- [ ] Record a 1-2 minute demo video (optional but 2x engagement)
- [ ] Write the "maker comment" — first comment that tells your story
- [ ] Build a supporter list (50-100 people who will engage on launch day)
- [ ] Study recent dev tool launches (look at Cursor, Appwrite, Continue.dev for patterns)
- [ ] Schedule launch for **Tuesday or Wednesday, 12:01 AM PT**

### Product Hunt Copy

**Tagline (60 chars max):**
> "73 AI skills that turn tickets into production PRs"

**Description:**
> dx-aem-flow is an open-source enterprise AI development platform. 4 plugins, 73+ skills, 12 autonomous agents. Automates the entire sprint lifecycle — requirements, planning, execution, code review, PR creation — across Claude Code, GitHub Copilot CLI, and VS Code Chat. Config-driven. Pure markdown. Works on any tech stack.

**Topics/Categories:**
- Developer Tools
- AI Coding Agents
- Open Source
- Productivity
- DevOps

### Launch Day Protocol

1. **12:01 AM PT** — Product goes live
2. **Immediately** — Post your maker comment (tell the personal story)
3. **Morning wave** — Notify close supporters (personal messages, not blasts)
4. **Midday wave** — Share on Twitter, LinkedIn, Reddit
5. **Afternoon wave** — Email list, Discord communities
6. **All day** — Respond to EVERY comment within minutes. Be personal, not robotic.
7. **Evening** — Thank everyone, share interim results

### Post-Launch (30 days)
- Follow up with everyone who commented
- Cross-post to Product Hunt forums (/p) for ongoing engagement
- Write a "What I Learned from Our Product Hunt Launch" article
- Plan the NEXT launch (successful companies launch multiple times — Stripe did 68!)

### Benchmarks
- **Top 5:** 200-350 upvotes
- **#1 Product of the Day:** 500+ upvotes
- **What matters more:** Conversion rate, GitHub stars gained, actual installs

---

## Hacker News (Show HN) Playbook

### Title Format
```
Show HN: dx-aem-flow – Open-source AI plugins for enterprise dev workflows (73 skills)
```

### Rules
- Be direct and technical — NO marketing speak
- Link to **GitHub repo** (not marketing site) — HN loves open source
- Write like you're talking to a fellow engineer
- Respond to criticism by **agreeing first**, then explaining
- Post **Tuesday-Thursday** for best results
- Post lifecycle is ~3 days

### The "Show HN" Comment (post immediately after)
```
Hey HN! I built dx-aem-flow because I was tired of the disconnect between
AI coding assistants and real enterprise dev workflows.

The problem: AI tools generate code, but code generation is maybe 30% of
a developer's sprint. Requirements analysis, planning, code review, PR
creation, documentation — all still manual.

So I built 73 skills that handle the entire sprint lifecycle. They're
pure markdown (no build system), config-driven (one YAML file), and work
identically on Claude Code, GitHub Copilot CLI, and VS Code Chat.

The architecture:
- 4 plugins (dx-core for any stack, dx-aem for Adobe Experience Manager,
  dx-hub for multi-repo, dx-automation for 24/7 agents)
- Skills chain together via file-based conventions (.ai/specs/ directory)
- 10 autonomous agents run on Azure DevOps pipelines via AWS Lambda webhooks
- Model tiering: Opus for deep reasoning, Sonnet for execution, Haiku for lookups

Happy to answer any questions about the architecture or approach.
```

### What HN Loves
- Open source with permissive license
- Technical depth and honest trade-offs
- "I built this to solve my own problem" narratives
- Detailed architecture explanations
- Honest "here's what doesn't work yet"

### What HN Hates
- Marketing language ("revolutionary", "game-changing")
- Vague claims without technical backing
- Refusing to engage with criticism
- Self-promotion without substance

---

## Other Launch Platforms

| Platform | URL | Notes |
|----------|-----|-------|
| **Open Launch** | open-launch.com | Open-source Product Hunt alternative, less crowded |
| **BetaList** | betalist.com | Early adopter feedback ($99 for fast-track) |
| **Lobsters** | lobste.rs | Invite-only, very technical, high-quality traffic |
| **daily.dev** | daily.dev | Developer news feed, submit articles |
| **Launching Next** | launchingnext.com | Free startup directory |
| **Indie Hackers** | indiehackers.com | Founder community, product listings |

---

## Launch Sequence (Coordinated)

| Day | Platform | Action |
|-----|----------|--------|
| Tuesday | Product Hunt | Launch at 12:01 AM PT |
| Tuesday | Twitter/X | Thread announcing launch + PH link |
| Tuesday | LinkedIn | Story post about the launch |
| Wednesday | Hacker News | Show HN post (different day from PH) |
| Wednesday | Reddit | r/SideProject, r/coolgithubprojects |
| Thursday | Dev.to | Publish flagship article |
| Friday | LinkedIn | Launch results + learnings post |
| Following week | Medium, Hashnode | Cross-post flagship article |

# Content Marketing Strategy — Blogs, SEO, Documentation-Driven Growth

## Platforms

| Platform | Strengths | Strategy |
|----------|-----------|----------|
| **Dev.to** | Highest dev traffic, inclusive, great SEO | Primary publishing platform. Post tutorials + "how I built this." |
| **Hashnode** | Custom domain support, strong SEO | Secondary. Publish under own domain. |
| **Medium** | Largest general audience | Use publications: "Better Programming", "Level Up Coding", "HackerNoon" |
| **Your docs site** | Full control, canonical URL | Publish here FIRST, then cross-post with canonical URL |

**Cross-posting rule:** Always publish on your own site first. Cross-post to Dev.to/Hashnode/Medium with canonical URL pointing to your site. Avoid verbatim duplication.

---

## Article Ideas (Priority Order)

### Flagship Articles (Long-form, 2000+ words)

1. **"I Automated My Entire Dev Sprint With 73 AI Skills — Here's the Open-Source Toolkit"**
   - The hero article. Covers the full lifecycle. Screenshots from ADO.
   - Platforms: Dev.to, Hashnode, Medium (Better Programming)

2. **"From Figma to Production AEM Component in One Command"**
   - Visual walkthrough of the Figma pipeline.
   - Source: `website/src/pages/usage/figma.mdx`
   - Platforms: Dev.to, Medium

3. **"Building 10 Autonomous AI Agents for Azure DevOps Pipelines"**
   - Architecture deep-dive: Lambda + ADO + AI agents.
   - Source: `website/src/pages/architecture/automation.mdx`
   - Platforms: Dev.to, Hashnode

4. **"Why AI Coding Tools Fail Enterprise Teams (And What Actually Works)"**
   - Contrarian piece. Position dx-aem-flow as the solution.
   - Platforms: Medium, LinkedIn article, Dev.to

5. **"The Config-Driven AI Development Platform — One YAML File, 50+ Repos"**
   - Technical architecture of the config system.
   - Source: `website/src/pages/architecture/overview.mdx`

### Quick-Win Articles (800-1500 words)

6. "How to Set Up AI-Powered PR Reviews in 5 Minutes"
7. "The 6-Phase AI Code Review Gate That Catches What Humans Miss"
8. "AI Bug Triage: From Ticket to Fix in 45 Minutes"
9. "Building a Plugin System With Pure Markdown (No Build Tools Needed)"
10. "Model Tiering: How to Cut AI Token Costs by 60%"
11. "Definition of Ready Validation With AI — Stop Bad Tickets Before They Start"
12. "AEM Development With AI: Dialog Inspection, Editorial Guides, and Automated QA"

### Comparison/SEO Articles

13. "Manual vs AI-Assisted Sprint: A Time Comparison"
14. "Claude Code vs GitHub Copilot CLI vs VS Code Chat — Why Not All Three?"
15. "Open Source AI Dev Tools: A Curated Guide for Enterprise Teams"

---

## SEO Strategy

### Target Keywords

| Keyword | Search Volume | Difficulty | Content |
|---------|--------------|------------|---------|
| "AI development workflow" | Medium | Low | Flagship article #1 |
| "Azure DevOps automation AI" | Low-Medium | Low | Article #3 |
| "Claude Code plugins" | Low | Very Low | Setup guide |
| "AI PR review tool" | Medium | Medium | Article #6 |
| "Figma to code AI" | Medium | Medium | Article #2 |
| "AEM development tools" | Low-Medium | Low | Article #12 |
| "autonomous AI agents devops" | Low | Very Low | Article #3 |
| "AI code review automation" | Medium | Medium | Article #7 |

### SEO Optimization

1. **Structured data** (schema.org) on docs site for tool/software markup
2. **BLUF formatting** — lead every section with the key takeaway (helps AI Overviews cite you)
3. **Internal linking** between docs pages and blog posts
4. **Refresh quarterly** — updating existing content yields 70% more traffic than creating new

---

## Documentation-Driven Growth

Your docs site IS a marketing asset. Each page should be:
- A standalone, searchable resource
- Structured with clear H2/H3 hierarchy
- Contains real examples (not just API references)
- Optimized for both human readers and AI crawlers (Perplexity, ChatGPT, Claude)

### Best Docs Pages to Optimize for SEO

| Page | Target Query |
|------|-------------|
| `website/src/pages/index.mdx` | "AI development platform enterprise" |
| `website/src/pages/usage/figma.mdx` | "Figma to code AI pipeline" |
| `website/src/pages/usage/bug-flow.mdx` | "AI bug fix automation" |
| `website/src/pages/architecture/automation.mdx` | "autonomous AI agents Azure DevOps" |
| `website/src/pages/reference/skills.mdx` | "AI development skills catalog" |
| `website/src/pages/costs.mdx` | "AI development tool pricing" |

### 50+ TLDR Tips as Social Content

The `website/src/content/tips/` folder has 50+ quick-reference tips. Each one is a ready-made social media post:
- "What is a skill?" → Twitter explainer
- "The coordinator pattern" → LinkedIn carousel
- "Agent model tiering" → Thread about cost optimization
- "Figma to code pipeline" → Visual walkthrough post
- "Three levels of autonomous AI review" → Listicle

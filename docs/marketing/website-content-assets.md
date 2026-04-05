# Website Content Assets for Marketing Campaigns

Best documentation pages and content to repurpose for marketing.

---

## Tier 1: Hero Content (Use First)

| Asset | Source File | Repurpose As |
|-------|------------|-------------|
| **Sprint lifecycle overview** | `website/src/pages/index.mdx` (hero section) | LinkedIn carousel, Twitter thread, landing page copy |
| **Figma-to-code pipeline** | `website/src/pages/usage/figma.mdx` | Blog article, demo video script, Product Hunt gallery |
| **Demo page (490 lines)** | `website/src/pages/demo/index.mdx` | Product Hunt description, HN Show post, video storyboard |
| **Bug flow (ticket → fix → PR)** | `website/src/pages/usage/bug-flow.mdx` | Blog article, Twitter thread, case study |
| **Autonomous agents architecture** | `website/src/pages/architecture/automation.mdx` | Technical blog, HN deep-dive, LinkedIn article |

---

## Tier 2: Feature Deep-Dives

| Asset | Source File | Best For |
|-------|------------|----------|
| **AEM verification & QA** | `website/src/pages/usage/aem.mdx` | AEM community posts, niche marketing |
| **Local developer workflow** | `website/src/pages/usage/local.mdx` | "Day in the life" blog, onboarding guide |
| **Architecture overview** | `website/src/pages/architecture/overview.mdx` | Technical blog, conference talk |
| **Skills catalog** | `website/src/pages/reference/skills.mdx` | Comparison charts, feature lists |
| **Cost/pricing models** | `website/src/pages/costs.mdx` | LinkedIn post about cost control, sales one-pager |
| **DoR/DoD workflows** | `website/src/pages/usage/dor-dod.mdx` | Enterprise governance angle |

---

## Tier 3: Educational Content (50+ TLDR Tips)

Location: `website/src/content/tips/`

### Best Tips for Social Media Posts

| Tip File | Social Post Angle |
|----------|------------------|
| `what-is-a-skill.md` | "AI skills > AI prompts. Here's why." |
| `the-coordinator-pattern.md` | "The pattern that chains AI agents like microservices" |
| `figma-to-code-the-full-pipeline.md` | "Figma → Code in 4 steps (verified before shipping)" |
| `bug-triage-ticket-to-root-cause.md` | "AI bug triage: 2 hours → 15 minutes" |
| `agent-model-tiering-cost-vs-quality.md` | "How to cut AI token costs 60% with model tiering" |
| `three-levels-of-autonomous-ai-review-*.md` | "3 levels of AI code review (most tools only do level 1)" |
| `chaining-skills-building-pipelines.md` | "Chaining AI skills into pipelines" |
| `parallel-agents-three-ways-*.md` | "3 ways to run concurrent AI agents" |
| `token-budgets-and-cost-control.md` | "How we keep AI costs predictable at enterprise scale" |
| `context-window-why-ai-forgets.md` | "Why your AI coding assistant forgets mid-conversation" |
| `your-plugin-journey-zero-to-production.md` | "From zero to production AI plugins" |
| `sessionstart-validate-on-every-launch.md` | "Validate your AI environment on every launch" |
| `consumer-sync-one-source-many-projects.md` | "One source of truth, 50+ repos" |
| `pre-flight-validation-dont-burn-tokens.md` | "Stop burning tokens: pre-flight validation" |

---

## Visual Assets

Location: `website/public/images/`

| Image | Use |
|-------|-----|
| `ado-tasks-created.png` | Product Hunt gallery, blog illustrations |
| `definition-of-ready-comment.png` | LinkedIn post about DoR validation |
| `implementation-plan-overview-comment.png` | Demo of team collaboration |
| `user-story-requirements.png` | Requirements analysis feature |
| `images/pr/` folder | PR workflow demonstrations |
| `images/figma-demo/` folder | Figma pipeline screenshots |
| `images/aem/` folder | AEM-specific feature demos |
| `images/demo/` folder | General demo screenshots |

---

## Content Repurposing Matrix

| Original Content | → LinkedIn | → Twitter | → Blog | → PH/HN |
|-----------------|-----------|-----------|--------|---------|
| Home page hero | Carousel (6 slides) | Thread (10 tweets) | — | Description |
| Figma pipeline | Article + carousel | Thread + screenshots | Full article | Gallery |
| Bug flow | Story post | Thread | Article | — |
| Automation arch | Article | Thread series | Deep-dive | Show HN post |
| Skills catalog | "Did you know?" posts | Tip tweets | Reference post | Feature list |
| Cost page | "How we control AI costs" | Cost comparison tweet | — | Pricing section |
| TLDR tips (50+) | Daily tip posts | Daily tweets | — | — |
| Demo screenshots | Post illustrations | Tweet images | Article images | Gallery |

---

## Quick Reference: Key Stats for Copy

Use these in any marketing material:
- **73+ skills** across 4 plugins
- **12+ autonomous agents** (10 run 24/7 on ADO pipelines)
- **3 AI platforms** supported (Claude Code, Copilot CLI, VS Code Chat)
- **6-phase verification gate** (compile, lint, test, secret scan, architecture, AI review)
- **PR review: 4 hours → 12 minutes**
- **Requirements analysis: 2 hours → 15 minutes**
- **Bug triage to fix: 1 day → 45 minutes**
- **Zero build system** — pure markdown + shell scripts
- **Config-driven** — one YAML file, zero hardcoded values
- **25 Copilot agents** + **13 specialized agents**
- **50+ TLDR tips** as documentation

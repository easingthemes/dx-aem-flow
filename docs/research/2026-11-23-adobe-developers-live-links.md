# Adobe Developers Live 2026 — 7 links, what is useful for dx

**Date:** 2026-11-23
**Source:** link list from the Basel event (17 Nov 2026) keynote + `aem.live/developers-live`. Keynote slides (acrobat link) not read — not reachable without the full URL.
**Method:** fetched each URL. Several are redirects or JS-only shells; what could not be read is marked **not verified**.

## TL;DR

| Link | What it really is | Target | Use for dx | Verdict |
|------|-------------------|--------|-----------|---------|
| `aem.now` | Redirect → AEM playground sign-up (30-day sandbox, 5 agents, demo brand). "148 skills" = `github.com/adobe/skills` marketplace | EDS / AEMaaCS / 6.5 (per plugin) | **High** — recommend side by side with dx-aem; our TODO file has stale facts | Act (#282) |
| `secure.aem.now` | Redirect → video "Using AI to keep your AEM Environments Secure". Adobe scans every AEMaaCS env daily (supply chain); AEM MCP pulls the report, Claude Code patches lib + opens PR | AEMaaCS only | **High** — fits `dx-security` and an automation agent | Act (#283) |
| `apps.aem.now` | Redirect → Adobe **LLM Apps** docs: brand actions exposed as remote MCP server in ChatGPT/Claude; handlers on I/O Runtime, widgets as EDS blocks; repos via Cloud Manager (ADO supported) | AEMaaCS Sites + EDS widgets | Low — customer-facing product, not dev workflow | Watch |
| `stardust.style` | Claude Code plugin in `adobe/skills` (Apache-2.0, v0.19): `/stardust:uplift <url>` → 3 redesigns, migrate to EDS blocks via DA | EDS only | Low — no AEMaaCS/6.5 path | Skip |
| `context.ing` | Redirect → `experience.adobe.com/#/aem/enterprise-context/` (JS shell, empty) | — | Maybe — "brand context" could feed copy/a11y changes in SimpleAgent | Not verified, watch |
| `play.bv.now` | Adobe Brand Visibility tour (JS shell). Marketing: how AI assistants cite your brand | — | None | Skip |
| `aem.new` | Trial landing: AEM + EDS + AI assistant, "MCP + Adobe and third-party skills". "**Available now for EDS. Coming soon for AEMaaCS and AMS.**" | EDS now | Watch — once AEMaaCS lands, maybe a disposable AEM for evals | Watch |

## Details

### 1. `adobe/skills` (behind aem.now)

Public marketplace now (our `todo-adobe-skills.md` still says "beta, 3 plugins / 49 skills"). 19 plugins in `marketplace.json`; AEM-relevant:

- `aem-cloud-service` — components, Dispatcher, workflows, code assessment + migration from legacy AEM, content distribution, RDE. (README returned 503 — skill names **not verified**.)
- `aem-6-5-lts` — 19 skills: bootstrap, dispatcher (6: config-authoring, technical-advisory, incident-response, performance-tuning, security-hardening, workflow-orchestrator), workflow (7), replication (5).
- `aem-edge-delivery-services`, `aem-forms-edge-delivery-services`, `aem-eds-content-ops`, `aem-eds-personalization`, `aem-project-management` — EDS.
- `stardust`, `web` (playwright-cli) — generic.

Install (Claude Code / Copilot CLI):
```
/plugin marketplace add adobe/skills
/plugin install aem-cloud-service@adobe-skills      # or aem-6-5-lts
copilot plugin marketplace add adobe/skills
```

Bundled MCP: Dispatcher MCP (`github.com/AdobeDocs/aem-dispatcher-mcp`, `AEM_DEPLOYMENT_MODE=cloud|ams`). No Cloud Manager skill, no ALM/ticket/PR workflow — still **no overlap** with dx-core. Our earlier conclusion holds: install side by side.

**What to do:** `aem-init` / docs recommend the matching Adobe plugin per `aem` flavor (cloud vs 6.5); `dx-plan`/`dx-step` soft-dependency for dispatcher + workflow tickets (same pattern as superpowers). Check name collisions with our `aem-*` skills (both use `aem-` prefix, different plugin namespace — OK in Claude Code, check Copilot).

### 2. AEM security scan + AI fix (behind secure.aem.now)

Session 11 Oct 2026 (`youtu.be/a2w8h7fkW3A`): daily, free supply-chain scan for every AEMaaCS env. Demo: Claude Code → AEM MCP server fetches report → patch library → PR. Exact MCP tool name **not verified** (video only).

**What to do:** `dx-security` reads the scan report via AEM MCP when `aem` is AEMaaCS; later a pipeline agent (scheduled, not comment-triggered) that opens an ADO PR per finding. Blocker known from #127: Adobe hosted AEM MCP needs interactive sign-in → not pipeline-ready yet.

### 3. LLM Apps (apps.aem.now)

Brand actions as remote MCP; Cloud Manager repos may be on Azure DevOps. Handler repo = normal code repo → dx-core works on it as is. No dx change needed. Revisit if a consumer builds LLM Apps (handler/widget conventions as a rule file).

### 4–7. Stardust, context.ing, Brand Visibility, aem.new

Stardust is EDS-only; dx-aem targets classic AEM components (HTL/Sling/dialogs). Brand Visibility is marketing. context.ing + aem.new: no readable docs yet.

## Sessions worth watching (aem.live/developers-live)

Most relevant to dx (recordings on YouTube, slides on acrobat):

- **Bring Your Own Harness: Driving AEM From Your Own Agent** (San Jose, `youtu.be/sZQmR2JxUcE`) — exactly our positioning.
- **From Ticket To Production** (San Jose, `youtu.be/Czl2HhRvwwk`) — same scope as `dx-agent-all`.
- **AI-Powered development with AEM CS & Edge Functions** (1 Sep, `youtu.be/9SWWG3b3oNc`) — IDE agent + Agent Skills for AEM component dev + AEM MCP to run pipelines (Cloud Manager deploy via MCP = new for us).
- **Find it, Fix it, Ship it: Asset Workflows with AEM and MCP** (7 Oct, `youtu.be/3rfWeNzxArk`) — AEM skills in Claude via AEM MCP.
- **Who Let the Agents Out? Running Wild with AEMaaCS** (Basel + San Jose) and **What Changed When the Agent Joined the Team** (Basel, slides only) — partner experience reports.

## Follow-ups

- #282 Refresh `todo-adobe-skills.md` + recommend Adobe plugin in aem-init/docs
- #283 AEMaaCS security scan → `dx-security` / automation agent
- #284 Watch the 3 sessions above, note AEM MCP tools we don't use yet (Cloud Manager pipeline, security report)

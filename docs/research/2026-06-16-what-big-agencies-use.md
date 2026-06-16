# What Big Agencies Are Actually Using — June 2026

**Research date:** 2026-06-16
**Scope:** Product companies (Adobe, Salesforce) + service agencies (Accenture, Cognizant, Infosys, TCS, Wipro, Capgemini)
**Angle:** What are they actually deploying, not what they're marketing

---

## The Honest Finding Upfront

**Service agencies are not building harnesses. They're deploying commercial products at scale.**

Accenture, Cognizant, Infosys, TCS, Wipro, Capgemini — none of them are shipping a sophisticated custom Claude Code plugin or multi-agent harness for developer workflows. Their "AI engineering" strategy is:
1. Deploy GitHub Copilot / M365 Copilot / OpenAI Codex at 50,000+ license scale
2. Layer change management, training, and workflow redesign on top
3. Position as the systems integrator between AI platforms and enterprise clients

The harness work is done by the AI platform vendors (Anthropic, Microsoft, OpenAI) and by product companies building on those platforms. The service agencies are distribution and adoption, not engineering.

---

## Product Companies

### Adobe

**Directly relevant to dx-aem-flow.**

Adobe officially supports Claude Code, Cursor, and GitHub Copilot for AEM as a Cloud Service local development. Their published approach:

**`adobe/skills` repository** — AEM-specific skills for Claude Code and cross-platform agents:
- `ensure-agents-md` — bootstraps `AGENTS.md` from `pom.xml`
- `create-component` — scaffolds complete AEM components (HTL, Java, dialog)
- `dispatcher` — Dispatcher configuration assistance
- `migration` — AEM 6.x → AEM as a Cloud Service migration
- `workflow` — workflow model and process development

**AEM Quickstart MCP Server** — exposes runtime data from local SDK instances:
- `aem-logs` — fetch logs from local author/publish
- `diagnose-osgi-bundle` — OSGi bundle state diagnostics
- `recent-requests` — Sling request log

**Dispatcher MCP Server** (beta) — validates Dispatcher configurations, traces request behavior.

Source: [Adobe Experience League — Local Development with AI Tools](https://experienceleague.adobe.com/en/docs/experience-manager-cloud-service/content/ai-in-aem/local-development-with-ai-tools)

**What this means for dx-aem-flow:**

We are doing more than Adobe's official tooling in several dimensions:
- ADO work-item integration (Adobe has none)
- Automation pipelines with Lambda + Service Hooks (Adobe has none)
- Config-driven project customization (Adobe's skills are generic)
- Resumable recovery pattern (Adobe has none)

But Adobe has things we should look at:
- **AEM Quickstart MCP Server** — `aem-logs`, `diagnose-osgi-bundle`, `recent-requests` are useful tools our `dx-aem` plugin doesn't expose. Currently our AEM MCP reads JCR content but doesn't surface runtime diagnostics.
- **`adobe/skills` repo** — public reference for AEM skill patterns; worth checking for conventions we should align with

**Gap to close:** Our `aem-doctor` skill doesn't use the AEM Quickstart MCP runtime tools. Adobe's official tooling does. These tools are directly useful for `dx-step-verify` AEM-specific validation.

---

### Salesforce

**Agentforce Vibes** — VS Code plugin for Salesforce-specific development (Apex, LWC, HTML, CSS, JS). Uses "Vibe Codey" as pair programmer. Key features:

- Context-aware with Salesforce schema understanding (knows your org's objects and fields)
- Code generation + test case generation + bug resolution in one loop
- 20+ MCP tool integrations
- Multi-model support: xGen (internal), GPT-5, internally hosted options
- Works in Cursor and Windsurf, not just VS Code

The Salesforce pattern: **platform-aware skills**. Vibe Codey knows Apex is not Java, knows LWC rules differ from React, knows Salesforce deployment is `sfdx push` not `mvn`. The skills encode platform-specific knowledge that a generic agent doesn't have.

This is exactly the dx-aem-flow approach for AEM — platform-aware skills (know that AEM components need HTL + Java + dialog, know Sling vs OSGi conventions, know Cloud Manager deployment). We're doing the right thing.

**What Salesforce does that we don't:** Multi-model routing at the skill level. We use Anthropic exclusively; Salesforce routes by task type to different models including internal ones. For a single-client deployment this is fine; for an agency offering it becomes relevant.

Source: [Salesforce Ben — Agentforce Vibes](https://www.salesforceben.com/salesforce-launches-agentforce-vibes-new-vibe-coding-tools-for-developers/)

---

### Adobe Commerce (relevant sidebar)

Adobe has a separate **AI developer agent for Commerce extensibility** that gives coding agents context about App Builder, API Mesh, and PWA Studio. Same pattern: MCP server exposing platform runtime data + skills with platform-specific knowledge.

Source: [Adobe Developer — AI Developer Agent for Commerce](https://developer.adobe.com/commerce/extensibility/developer-agent/)

---

## Service Agencies

### Accenture

**What they're actually deploying:**

1. **OpenAI Codex** — Partners with OpenAI on Frontier AI agent platform (February 2026). Role: systems integration (data architecture, cloud infrastructure, connecting Codex to enterprise systems). Not building their own agent; wiring Codex to SAP, Salesforce, ServiceNow.

2. **Anthropic Claude** — Joint Accenture + Anthropic offering for CIOs. 30,000 Accenture professionals trained on Claude. Package includes: productivity measurement framework, workflow redesign for AI-centric teams, change management. Again: deployment and adoption, not harness engineering.

3. **Replit** (invested) — Browser-based dev environment for enterprises. Strategy: reduce friction for "vibe coding" at enterprise scale. Enables rapid prototyping without local dev environment setup.

4. **AATA (Accenture Advanced Technology Agent)** — Their own internal integration agent that sits between Accenture's human workforce and enterprise platforms. This is the closest thing to a custom harness — but it's an internal operations agent, not a developer coding agent.

5. **Forward Deployed Engineering programs** — With Microsoft, ServiceNow, SAP. Model: Accenture sends AI-skilled engineers directly to client sites. The engineers bring their own tools (Copilot, Claude Code, custom prompts). dx-aem-flow is exactly the kind of tooling those engineers would use.

**Bottom line on Accenture:** They're the integrator, not the builder. If a client needs AEM + ADO + AI, Accenture would deploy dx-aem-flow (or equivalent), not build their own version. They don't have a competitor to dx-aem-flow — they'd be a customer.

Sources: [Accenture invests in Replit](https://newsroom.accenture.com/news/2026/accenture-invests-in-replit-to-advance-ai-driven-software-development-for-enterprises) | [Fortune — OpenAI partners with Accenture, Capgemini](https://fortune.com/2026/02/23/openai-partners-with-mckinsey-bcg-accenture-and-capgemini-to-push-its-frontier-ai-agent-platform/)

---

### Cognizant, Infosys, TCS, Wipro

All four are Microsoft "Frontier Firms" — each deploying 50,000+ Microsoft Copilot licenses. That's 200,000 seats of GitHub Copilot + M365 Copilot across the four firms combined.

**What this actually means:**

| Firm | Specific approach | What they're doing with it |
|------|-----------------|---------------------------|
| Infosys | Devin (Cognition AI) + Anthropic Claude via Topaz | Deployed Devin internally; custom Claude agents for telecom/finance/manufacturing |
| TCS | GitHub Copilot + M365 Copilot across all employees | "AI coach" for every employee; GitHub Copilot for coding |
| Wipro | Microsoft Copilot + Factory (agent-native dev) | Embedding Copilot in FS/retail/manufacturing/healthcare |
| Cognizant | Microsoft Copilot "client zero" | Testing and refining Copilot for large-scale enterprise use |

**The Infosys + Devin detail is notable:** Infosys partnered with Cognition (makers of Devin) to deploy "the first AI software engineer" across their engineering ecosystem. Devin operates as an autonomous coding agent — more like what we're building in dx-automation than a simple coding assistant. Scale: global, across all Infosys clients.

**The Wipro + Factory detail is interesting:** Factory is an "agent-native development" platform. Wipro is embedding it "across engineering organizations." Factory's approach is closer to dx-aem-flow than GitHub Copilot — it's a workflow harness, not just an autocomplete tool.

Source: [Microsoft names Cognizant, Infosys, TCS, Wipro as Frontier Firms](https://analyticsindiamag.com/ai-news-updates/microsoft-names-cognizant-infosys-tcs-wipro-as-frontier-firms-for-copilot-deployment/)

---

### Capgemini

**Code Assist** (their branded GitHub Copilot deployment): Early results show "workload gains for coding and more stable code quality." The metric they're using — "workload gains" — suggests they're measuring by lines of code or story points, not outcome quality. That's a measuring-the-wrong-thing red flag for the industry.

Also part of OpenAI Frontier AI agent platform — same role as Accenture: systems integration, not harness building.

---

## What This Means for dx-aem-flow

### Where We Stand vs. the Field

| Capability | Big agencies | dx-aem-flow |
|------------|-------------|-------------|
| AEM-specific skills | Adobe only (basic: component, migration, dispatcher) | ✓ Comprehensive (77 skills, ADO integration) |
| AEM MCP runtime tools | Adobe's Quickstart MCP (`aem-logs`, `diagnose-osgi-bundle`) | ✗ We read JCR but not runtime diagnostics |
| Automation pipelines | None visible | ✓ Lambda + Service Hooks, 9 agent types |
| Config-driven customization | None visible | ✓ .ai/config.yaml, 3-layer override |
| Multi-model routing | Salesforce (xGen/GPT-5/internal) | ✗ Anthropic only |
| Harness self-improvement / evals | None visible | In progress (#1, #143) |
| Governance / auditability | Adobe CX Enterprise (customer-facing) | ✗ No audit trail beyond spec dirs |
| Agent interoperability (A2A) | Accenture, Capgemini, Infosys (Google A2A protocol) | ✗ Not implemented |

### Gaps Worth Acting On

**1. Adobe AEM Quickstart MCP Server tools**
`aem-logs`, `diagnose-osgi-bundle`, `recent-requests` are runtime diagnostic tools we don't expose. These would directly improve `dx-step-verify` AEM-specific validation and `aem-doctor`. Check if the AEM MCP we use (`mcp__plugin_dx-aem_AEM__`) already exposes these or if we need to add them.

**2. Alignment with `adobe/skills` conventions**
Adobe published official AEM skills. Our dx-aem skills should align on naming and structure where possible — it makes onboarding easier for AEM developers who've seen Adobe's approach. Check for convention gaps.

**3. The service agency market is the opportunity, not the competition**
Accenture, Cognizant, Capgemini don't have an AEM+ADO harness. If they win an AEM project they'd need something like dx-aem-flow. The FDE (Forward Deployed Engineering) model — where Accenture embeds AI engineers at client sites — is exactly where dx-aem-flow lands. These firms are potential adopters, not competitors.

### Gaps NOT Worth Acting On

**Multi-model routing** — Salesforce needs this because they have internal models and enterprise clients with OpenAI agreements. For an Anthropic-only harness targeting Claude Code users, multi-model adds complexity with no current payoff.

**A2A protocol** — Google's Agent2Agent is for customer-facing agent interoperability (agents from different companies talking to each other). Not relevant to a developer workflow harness.

**"Vibe coding" interfaces** — Salesforce's Agentforce Vibes and Replit target non-developers building applications with natural language. Our audience is developers. Different problem.

---

## The Key Takeaway

The sophisticated harness work is happening at **Adobe and Salesforce** (platform-specific agents with MCP runtime access) and at small specialized shops (TribeAI, dx-aem-flow). The big service agencies are deployers of commercial AI, not harness builders.

The competitive reference isn't Accenture. It's Adobe's `adobe/skills` repo. And on AEM specifically, dx-aem-flow is more comprehensive than Adobe's own published tooling — but Adobe has runtime MCP tools we don't.

---

## Immediate Action

Check the AEM Quickstart MCP Server tool list against our current `mcp__plugin_dx-aem_AEM__` capabilities. If `aem-logs` and `diagnose-osgi-bundle` are not already available, this is a high-value addition to `aem-doctor` and `dx-step-verify`.

Also check: `github.com/adobe/skills` — are there patterns or conventions in their AEM skill format that our skills should align with for cross-compatibility?

# Microsoft Azure Skills — Research & Integration Analysis

Source: `github.com/microsoft/azure-skills` (mirror of `microsoft/GitHub-Copilot-for-Azure`)
Related repos:
- `github.com/microsoft/azure-devops-skills` — 5 basic ADO skills (loose, not a plugin)
- `github.com/microsoft/skills` — 132 skills across 6 languages (Core, Python, .NET, TypeScript, Java, Rust) + custom agents + skill-creator tool
- `github.com/MicrosoftDocs/Agent-Skills` — 193 curated skills across 19 categories from Microsoft Learn docs
- `agentskills.io` — Open specification (originally by Anthropic, adopted by 30+ tools incl. Copilot, Claude Code, Codex, Cursor, Gemini CLI, Junie)

**Added:** 2026-04-03

---

## Overview

Microsoft ships Azure Skills as an official agent plugin with a three-layer architecture:

| Layer | Role | What it provides |
|-------|------|------------------|
| **Skills** ("The Brain") | 24 curated Azure skills | Deployment workflows, diagnostics, cost optimization, compliance, AI services, RBAC |
| **Azure MCP** ("The Hands") | `@azure/mcp` server | 200+ structured tools across 40+ Azure services |
| **Foundry MCP** ("The AI Specialist") | Microsoft Foundry | Model discovery, deployment, agent workflows |

### Installation (identical to our plugins)

```bash
/plugin marketplace add microsoft/azure-skills
/plugin install azure@azure-skills
```

Works on: GitHub Copilot CLI, Claude Code, VS Code (via Azure MCP Extension), IntelliJ.

---

## Azure Skills — Complete Catalog (24 skills)

### Build & Deploy (3)
| Skill | What it does |
|-------|-------------|
| `azure-prepare` | Prepare app for Azure (generate IaC, Dockerfiles, azd config) |
| `azure-validate` | Pre-deployment validation (IaC linting, config checks) |
| `azure-deploy` | Execute deployment (`azd up`, `terraform apply`, ARM) |

### Operations & Diagnostics (3)
| Skill | What it does |
|-------|-------------|
| `azure-diagnostics` | Troubleshoot failures (AppLens, container logs, AKS, Functions) |
| `azure-compliance` | Compliance monitoring, governance checks |
| `appinsights-instrumentation` | Application Insights setup and observability |

### Optimization (3)
| Skill | What it does |
|-------|-------------|
| `azure-cost` | Cost analysis, optimization recommendations, forecasting |
| `azure-compute` | Compute service selection and right-sizing |
| `azure-resource-visualizer` | Architecture diagram generation (Mermaid) |

### Specialized Services (9)
| Skill | What it does |
|-------|-------------|
| `azure-ai` | AI services (Search, Speech, OpenAI, Document Intelligence) |
| `azure-aigateway` | API Management / AI Gateway policies |
| `azure-kubernetes` | AKS management |
| `azure-kusto` | Azure Data Explorer / KQL queries |
| `azure-messaging` | Messaging services (Event Hubs, Service Bus, Event Grid) |
| `azure-storage` | Storage accounts, blobs, queues, tables |
| `azure-quotas` | Quota management and limits |
| `azure-upgrade` | Service version upgrades |
| `azure-cloud-migrate` | Cross-cloud migration (AWS/GCP → Azure) |

### Identity & Access (2)
| Skill | What it does |
|-------|-------------|
| `azure-rbac` | Role-based access control management |
| `entra-app-registration` | Entra ID / app registrations |

### Infrastructure Planning (2)
| Skill | What it does |
|-------|-------------|
| `azure-enterprise-infra-planner` | Enterprise infrastructure planning |
| `azure-resource-lookup` | Resource discovery and inventory |

### AI Platform (2)
| Skill | What it does |
|-------|-------------|
| `microsoft-foundry` | AI Foundry model catalog, deployments |
| `azure-hosted-copilot-sdk` | Copilot SDK hosted on Azure |

---

## Azure DevOps Skills (Separate Repo — Not a Plugin)

Source: `github.com/microsoft/azure-devops-skills` — 5 loose skill folders, requires `github.com/microsoft/azure-devops-mcp`.

| Skill | What it does |
|-------|-------------|
| `boards-my-work` | List user's active work items |
| `boards-work-item-summary` | Summarize a single work item |
| `pipelines-build-summary` | List/inspect/troubleshoot pipeline builds |
| `security-alert-review` | Review Advanced Security alerts |
| `work-iterations` | List/create/assign iterations |

**Key observation:** These are read-only lookup skills. No creation, no lifecycle management, no PR integration, no automation pipelines.

---

## Comparison: Our Plugins vs Azure Skills

### Capability Matrix

| Capability | dx-aem-flow | Azure Skills | Azure DevOps Skills |
|-----------|-------------|--------------|---------------------|
| **ADO work items** — full CRUD + lifecycle | 45 skills (dx-core) | — | 2 read-only skills |
| **ADO pipelines** — create, trigger, monitor | auto-pipelines, auto-deploy | — | 1 read-only skill |
| **ADO PRs** — create, review, answer, commit | dx-pr-*, dx-pr-review-all | — | — |
| **Planning** — requirements → plan → steps | dx-req, dx-plan, dx-step | — | — |
| **Code review** — automated, multi-pass | dx-pr-review (Opus), dx-council | — | — |
| **Bug workflow** — triage → fix → verify → PR | dx-bug-* (4 skills) | — | — |
| **Self-healing execution** — 3-layer recovery | dx-step-fix, dx-step-all | — | — |
| **24/7 autonomous agents** — Lambda webhooks | dx-automation (11 skills) | — | — |
| **Multi-repo orchestration** | dx-hub (4 skills) | — | — |
| **AEM-specific** — verify, QA, editorial | dx-aem (12 skills) | — | — |
| **Design integration** — Figma extract/verify | dx-figma-* (4 skills) | — | — |
| **Accessibility testing** | dx-axe | — | — |
| **Azure deployment** — prepare/validate/deploy | — | **3 skills** | — |
| **Azure diagnostics** — troubleshoot failures | — | **3 skills** | — |
| **Azure cost optimization** | — | **3 skills** | — |
| **Azure infra planning** | — | **2 skills** | — |
| **Azure AI services** | — | **4 skills** | — |
| **Azure identity/RBAC** | — | **2 skills** | — |
| **Azure specialized services** | — | **7 skills** | — |
| **Azure MCP (200+ tools)** | — | **Yes** | Via azure-devops-mcp |

### Overlap Assessment

**Zero overlap.** The plugins operate at completely different layers:

```
┌─────────────────────────────────────────────────┐
│          Azure Skills (Cloud Infra)              │
│  Deploy · Diagnose · Optimize · Comply · RBAC   │
├─────────────────────────────────────────────────┤
│         dx-aem-flow (Development Lifecycle)      │
│  Tickets → Plan → Code → Test → Review → PR     │
│  + AEM QA · Figma · A11y · Automation · Hub      │
└─────────────────────────────────────────────────┘
```

They are **complementary stacks**:
- Azure Skills = "How do I deploy/manage/optimize my Azure infrastructure?"
- dx-aem-flow = "How do I develop, test, review, and ship code through ADO?"

### Architectural Differences

| Dimension | Our plugins | Azure Skills |
|-----------|-------------|-------------|
| **Agent layer** | 12 agents with model tiering (Opus/Sonnet/Haiku) | None — skills only |
| **Model selection** | `model:` + `effort:` in frontmatter | Not supported — host agent decides |
| **Subagent forking** | `context: fork`, `agent: agent-name` | Not supported |
| **Flow control** | DOT digraphs for branching skills | Linear steps only |
| **Config system** | `.ai/config.yaml` — never hardcode | None — relies on `az login` context |
| **Override system** | Three-layer (rules > config > defaults) | None — skills are static |
| **Hook system** | Three platforms, profiles, branch-guard | Telemetry hook only |
| **Automation** | Lambda webhooks, 24/7 pipeline agents | None |
| **Bundled references** | `data/`, `shared/`, `templates/` | `references/` subdirs per skill |
| **Frontmatter fields** | name, description, model, effort, context, agent, paths, argument-hint | name, description, license, metadata (author, version) |

---

## Integration Pattern Analysis: Can We Use Azure Skills Like Superpowers?

### How Superpowers Works Today

Six dx skills use this pattern:
```markdown
If `superpowers:<skill-name>` is available, invoke it to [benefit].
**Fallback (if superpowers not installed):** [condensed inline guidance]
```

**Key characteristics:**
- Superpowers provides **methodology** (debugging, TDD, brainstorming) — not domain tools
- The fallback is a condensed version of the same methodology
- No MCP tools involved — pure instruction enhancement
- Detection is automatic (Skill tool availability check)

### Could Azure Skills Be Used the Same Way?

**Short answer: No — different integration model. But there are useful touch-points.**

Azure Skills is fundamentally different from superpowers:

| Aspect | Superpowers | Azure Skills |
|--------|-------------|--------------|
| **Nature** | Methodology/instructions | Cloud tools + domain knowledge |
| **Value** | Better thinking process | Actual Azure operations (deploy, diagnose, query) |
| **Without it** | Fallback works fine (condensed guidance) | Cannot deploy/diagnose Azure (no substitute) |
| **Integration** | Wrapping instruction around existing workflow | Calling out to a separate domain at specific points |

A soft-dependency fallback for Azure Skills would be hollow — you can't "fallback" deploying to Azure without Azure tools.

### Recommended Integration Model: **Conditional Domain Handoff**

Instead of wrapping Azure Skills calls in a superpowers-style pattern, use a **conditional handoff** pattern at specific workflow junctures:

```markdown
### Azure Deployment (if applicable)

If the project deploys to Azure AND the `azure` plugin is installed:
1. Invoke `azure-prepare` to generate IaC files
2. Invoke `azure-validate` to check deployment config
3. Invoke `azure-deploy` to execute deployment

**If azure plugin not installed:** Skip Azure deployment — proceed to PR creation.
(User can run Azure deployment separately after merge.)
```

### Specific Touch-Points for Integration

#### 1. **dx-step-build → Azure Deploy** (post-build deployment)
```
After successful local build:
  If azure plugin installed AND config.yaml has `deploy.target: azure`:
    Invoke azure-prepare → azure-validate → azure-deploy
```

#### 2. **dx-step-verify → Azure Diagnostics** (post-deploy verification)
```
After deployment step:
  If azure plugin installed:
    Invoke azure-diagnostics to verify deployment health
```

#### 3. **dx-doctor → Azure Resource Check** (health check extension)
```
In infrastructure checks:
  If azure plugin installed:
    Invoke azure-resource-lookup for resource inventory
    Invoke azure-compliance for governance check
```

#### 4. **dx-plan → Azure Compute/Cost** (planning phase)
```
When planning infrastructure changes:
  If azure plugin installed:
    Invoke azure-compute for service selection guidance
    Invoke azure-cost for cost impact analysis
```

#### 5. **auto-deploy → Azure Deploy** (automation pipeline)
```
After PR merge, in auto-deploy pipeline:
  If azure plugin installed:
    Run azure-validate → azure-deploy as post-merge step
```

#### 6. **dx-bug-triage → Azure Diagnostics** (bug investigation)
```
When triaging production bugs:
  If azure plugin installed AND error is infrastructure-related:
    Invoke azure-diagnostics for AppLens/log analysis
```

---

## Design Patterns Worth Studying

Azure Skills uses several patterns that differ from or complement our approach:

### 1. Plan-as-Artifact with Status Gates

Azure deploy workflow uses `.azure/deployment-plan.md` as shared state between skills:
- `azure-prepare` creates the plan with status `Ready for Validation`
- `azure-validate` is the ONLY skill authorized to set status to `Validated` (must record proof — actual commands + timestamps)
- `azure-deploy` REFUSES to run unless plan status is `Validated` AND Section 7 "Validation Proof" is populated
- Bold "FORBIDDEN" blocks prevent the agent from bypassing validation by manually editing status

**Comparison:** Our `implement.md` tracks step status but doesn't enforce prerequisite gates between skills this strictly. The "validation proof" concept (requiring actual command output, not just a status flag) is stronger than our current step verification.

### 2. Router Skill Pattern

`azure-cost` routes to sub-workflows based on intent: Cost Query, Cost Optimization, Cost Forecast — each in its own subdirectory with a `workflow.md`. `azure-prepare` has Step 0 that scans codebase markers + prompt keywords to route to specialized skills.

**Comparison:** Our coordinator skills (`dx-agent-all`, `dx-bug-all`) chain skills sequentially. The codebase-marker-based routing in `azure-prepare` is an interesting pattern for `dx-step` — detect what kind of change is being made and route to specialized handling.

### 3. Per-Skill Reference Bundles

Every Azure skill has a `references/` subdirectory:
```
azure-cost/
├── SKILL.md
├── cost-forecast/workflow.md
├── cost-optimization/workflow.md
└── cost-query/workflow.md

azure-deploy/
├── SKILL.md
└── references/
    ├── auth-best-practices.md
    ├── global-rules.md
    ├── troubleshooting.md
    ├── recipes/container-apps.md
    └── sdk/azd-quick-reference.md
```

**Comparison:** We use plugin-level `shared/` and `data/`. Per-skill references would reduce context loading — each skill only pulls its own relevant docs.

### 4. Explicit MCP Tool Tables

Each skill includes a table mapping tool names to purposes:
```markdown
| Tool | Purpose |
|------|---------|
| `azure__role` | Check role assignments |
| `mcp_azure_mcp_azd` | Run azd commands |
```

**Comparison:** Our skills reference MCP tools inline. Explicit tables improve discoverability and make tool dependency auditing easier.

---

## Improvement Ideas From Azure Skills

### 1. `references/` Pattern — Bundled Domain Knowledge

Azure Skills bundles rich reference docs inside each skill directory:
```
skills/azure-deploy/
├── SKILL.md
└── references/
    ├── auth-best-practices.md
    ├── global-rules.md
    ├── troubleshooting.md
    ├── recipes/
    │   ├── container-apps.md
    │   └── static-web-apps.md
    └── sdk/
        ├── azd-quick-reference.md
        └── terraform-quick-reference.md
```

**Idea:** Our skills could adopt `references/` for per-skill domain docs that are automatically included in context. Currently we use `shared/` at plugin level and `data/` for seed files. Per-skill `references/` could help with:
- `dx-pr-review/references/review-patterns.md` — common anti-patterns
- `dx-step-fix/references/error-catalog.md` — known error patterns + fixes
- `aem-verify/references/dialog-field-types.md` — AEM dialog field validation rules

### 2. Context7 MCP — Live Documentation Lookup

Azure Skills includes `@upstash/context7-mcp` for real-time documentation retrieval. Our skills currently rely on bundled `shared/` docs which can go stale.

**Idea:** Add Context7 MCP to dx-core for live lookup of:
- ADO REST API docs (when building API calls)
- Framework documentation (Maven, npm, AEM SDK)
- Azure DevOps pipeline YAML schema

### 3. `allowed-tools` Frontmatter

The broader skill spec supports `allowed-tools` — tools the agent may use without user confirmation. We don't use this yet.

**Idea:** Add to skills that call MCP tools frequently:
```yaml
allowed-tools:
  - mcp__ado__wit_get_work_item
  - mcp__ado__wit_list_work_item_comments
```

### 4. Publish to microsoft/skills Catalog

The `microsoft/skills` (formerly `github/awesome-copilot`) repo is a community mega-catalog. Publishing dx-core there would increase visibility.

### 5. `metadata` Block in Frontmatter

Azure Skills uses a `metadata:` block for machine-readable author/version info. Our plugins have this in `plugin.json` but not per-skill. Could be useful for skill-level versioning if individual skills evolve at different rates.

---

## Verdict

**Same conclusion as Adobe Skills analysis:** No overlap, no wrapping needed. Users install both side by side.

```bash
# One-time setup
/plugin marketplace add microsoft/azure-skills
/plugin install azure@azure-skills

# Now users have both:
# - /dx-plan, /dx-step, /dx-pr    → development lifecycle
# - /azure-prepare, /azure-deploy  → cloud infrastructure
```

The conditional handoff pattern (not superpowers-style wrapping) is the right integration for the few workflow junctures where Azure infra meets dev lifecycle. The `references/` and Context7 patterns are worth adopting independently.

---

## Broader Microsoft Skills Ecosystem

### `microsoft/skills` — SDK Pattern Library (132 skills)

Not just Azure infra — this repo covers **programming patterns** across 6 languages:

| Category | Languages | Examples |
|----------|-----------|---------|
| Core | Cross-language | `skill-creator` (meta-skill to create new skills) |
| Python | Azure SDK for Python | Auth, storage, cosmos, key vault patterns |
| .NET | Azure SDK for .NET | Identity, blobs, service bus, app config |
| TypeScript | Azure SDK for TS | Event hubs, monitor, cognitive services |
| Java | Azure SDK for Java | Same service coverage |
| Rust | Azure SDK for Rust | Storage, identity |

**Opportunity:** The `skill-creator` meta-skill could be adapted as `dx-skill-create` — a skill for generating new dx/aem skills from a template, reducing boilerplate when extending the plugin.

### `MicrosoftDocs/Agent-Skills` — Learn-Derived Knowledge (193 skills)

Curated from Microsoft Learn docs across 19 categories. These are **pure knowledge skills** (no MCP tools) — they inject Azure service expertise into agent context. Categories include networking, security, AI services, containers, serverless, databases, DevOps, monitoring.

**Opportunity:** Similar pattern to our `shared/` reference docs, but packaged as discoverable skills. Could inform how we structure AEM project knowledge — instead of flat `data/` files, package as named knowledge skills that agents load on demand.

### `agentskills.io` — Open Specification

The Agent Skills format is now an **open standard** (originally by Anthropic). Our SKILL.md format is already compatible. Key spec fields we don't use yet:

| Field | Spec definition | Our status |
|-------|----------------|-----------|
| `name` | Required, 1-64 chars, kebab-case | ✅ Used |
| `description` | Required, max 1024 chars | ✅ Used |
| `license` | Optional, max 500 chars | ❌ Not used — could add |
| `compatibility` | Optional, environment requirements | ❌ Not used — could add for AEM skills ("Requires AEM 6.5+") |
| `metadata` | Optional, string key-value map | ❌ Not used — could add author/version per skill |
| `allowed-tools` | Experimental, pre-approved tools | ❌ Not used — would reduce permission prompts |
| `model` | Our extension | ✅ Used (not in base spec) |
| `effort` | Our extension | ✅ Used (not in base spec) |
| `context` | Our extension | ✅ Used (not in base spec) |
| `agent` | Our extension | ✅ Used (not in base spec) |
| `paths` | Our extension | ✅ Used (not in base spec) |
| `argument-hint` | Our extension | ✅ Used (not in base spec) |

**Key insight:** Our frontmatter extensions (`model`, `effort`, `context`, `agent`, `paths`) go beyond the base spec — these are unique capabilities that other skill authors don't have. Worth documenting as proposed spec extensions if the `agentskills.io` spec accepts contributions.

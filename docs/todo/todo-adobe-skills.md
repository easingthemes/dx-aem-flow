# Adobe Official Skills — Future Integration

Source: `github.com/adobe/skills` (beta branch as of 2026-03-24; **public marketplace with 19 plugins as of 2026-11-23, see #282**)

Adobe ships 3 plugins / 49 skills — all AEM domain knowledge, zero ALM/workflow integration.
Our plugins provide the workflow layer (ADO, PR, automation). No overlap — users install both side by side.

**Key insight:** No overlay/soft-dependency needed. Users install Adobe plugins directly for AEM domain skills (component creation, dispatcher, workflows, EDS). Our plugins handle the development lifecycle (tickets → planning → execution → review → PR). They complement each other without wrapping.

## EDS skills — future scope

**Added:** 2026-03-24
**Problem:** Adobe provides 17 EDS skills (content-driven development, block building, page migration pipeline). Currently out of scope for dx-aem.
**Scope:** Would require new skill group in dx-aem or separate plugin
**Done-when:** Revisit when EDS enters project scope. Evaluate whether dx-step needs EDS-specific context or if users just invoke Adobe's EDS skills directly.

## Dispatcher skills — future scope

**Added:** 2026-03-24
**Problem:** Adobe provides 6 dispatcher skills (config authoring, security hardening, performance tuning, incident response). Currently out of scope.
**Scope:** Could integrate with dx-step for dispatcher-related tickets
**Done-when:** Revisit when dispatcher work becomes a recurring ticket type. Evaluate whether dx-step needs dispatcher detection or if users just invoke Adobe's dispatcher skills directly.

## Workflow skills — future scope

**Added:** 2026-03-24
**Problem:** Adobe provides 8 workflow skills (model design, development, triggering, launchers, debugging, triaging). Currently out of scope.
**Scope:** Could integrate with dx-step for AEM workflow-related tickets
**Done-when:** Revisit when AEM workflow tickets become common. Evaluate whether dx-step needs workflow detection or if users just invoke Adobe's workflow skills directly.

## Refresh Adobe skills facts and recommend per flavor

**Added:** 2026-11-23
**Problem:** This file still describes `adobe/skills` as a beta with 3 plugins / 49 skills. It is now a public marketplace (`adobe-skills`, 19 plugins, Apache-2.0) with `aem-cloud-service` and `aem-6-5-lts` plugins. Consumers don't learn from us that these exist, and dx-plan/dx-step don't use them for dispatcher/workflow tickets.
**Scope:** this file (header), `plugins/dx-aem/skills/aem-init/SKILL.md`, `website/src/pages/learn/` install docs, optionally `dx-plan` / `dx-step` soft-dependency note.
**Done-when:** `grep -n "49 skills" docs/todo/todo-adobe-skills.md` returns nothing, and `grep -rn "adobe-skills" plugins/dx-aem/skills/aem-init/SKILL.md website/src/pages` finds the install recommendation.
**Approach:** aem-init: if AEMaaCS → suggest `aem-cloud-service@adobe-skills`, if 6.5/AMS → `aem-6-5-lts@adobe-skills`. Soft-dependency pattern like superpowers. Check skill name collisions on Copilot CLI (both use `aem-` prefix). See [research](../research/2026-11-23-adobe-developers-live-links.md).

## AEMaaCS security scan in dx-security

**Added:** 2026-11-23
**Problem:** Adobe scans every AEM as a Cloud Service environment daily for supply-chain vulnerabilities, and the AEM MCP server can fetch the report (demo: Claude Code patches the library and opens a PR). `dx-security` does not use it, and no automation agent turns findings into ADO PRs.
**Scope:** `plugins/dx-core/skills/dx-security/`, `plugins/dx-aem/` (AEM MCP tool refs), later `plugins/dx-automation/` (scheduled agent).
**Done-when:** `grep -rn -i "security report\|vulnerabilit" plugins/dx-core/skills/dx-security/SKILL.md` shows an AEMaaCS-scan step naming the exact AEM MCP tool, verified against a live AEMaaCS env.
**Approach:** first verify the tool name (session `youtu.be/a2w8h7fkW3A`). Interactive skill first; pipeline agent only after Adobe AEM MCP supports non-interactive auth (#127).

## Adobe Developers Live sessions review

**Added:** 2026-11-23
**Problem:** Adobe presented agent workflows overlapping ours ("Bring Your Own Harness", "From Ticket To Production", AEM CS AI-powered dev with AEM MCP deploying pipelines). We don't know which AEM MCP tools (Cloud Manager pipeline, security report) we miss.
**Scope:** `docs/research/`, `plugins/dx-aem/` MCP tool lists.
**Done-when:** a `docs/research/` note exists listing each session's AEM MCP tools/skills and a used/not-used column.
**Approach:** recordings: `youtu.be/sZQmR2JxUcE`, `youtu.be/Czl2HhRvwwk`, `youtu.be/9SWWG3b3oNc`, `youtu.be/3rfWeNzxArk`.

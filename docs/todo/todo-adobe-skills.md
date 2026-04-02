# Adobe Official Skills — Future Integration

Source: `github.com/adobe/skills` (beta branch as of 2026-03-24, not yet published to marketplace)

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

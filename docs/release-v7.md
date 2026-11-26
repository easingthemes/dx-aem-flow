# v7.0.0 — Post-merge flow consolidation

**v7.0.0** replaces five overlapping post-merge skills with three standalone skills and a coordinator (TODO-286, design: `docs/superpowers/specs/2026-11-26-post-merge-flow-design.md`). It is a BREAKING CHANGE: five commands, two Copilot agents and two spec files are gone.

## Removed → use instead

| Removed | Use instead | Notes |
|---------|-------------|-------|
| `/aem-verify <component>` | `/aem-demo-page <component> --local` | Dialog diff against the `/aem-snapshot` baseline, local demo page, dialog + preview screenshots |
| `/aem-verify --qa` | `/aem-demo-page <id>` | QA is the default instance now |
| `/aem-editorial-guide <component>` | `/aem-demo-page` (screenshots) + `/dx-doc-gen <id>` (authoring section) | See *Behaviour changes* — no ticket-less guide |
| `/aem-doc-gen <id>` | `/aem-demo-page <id>` | Screenshots are uploaded as work-item attachments |
| `/aem-qa-handoff <component>` | `/dx-qa-handoff <id>` | Work item ID only, no AEM access |
| `/dx-doc-retro <id>` | `/dx-doc-gen <id>` | Retro mode starts by itself when the story has no spec files |
| — | `/dx-post-merge <id>` | New coordinator: demo page → wiki → QA handoff |
| `@AEMAfter`, `@AEMEditorialGuide` (Copilot) | `@AEMDemoPage` | |
| `aem-after.md`, `demo/authoring-guide.md` | `demo/demo-page.md` | Old files in existing spec dirs are ignored, not deleted |

## Behaviour changes

- **`/dx-agent-all` ends at the PR.** The old Phase 6.5 (editorial guide) and Phase 7 (docs) are gone. Run `/dx-post-merge <id>` after the merge and the QA deploy. The AEM baseline snapshot now runs **before** execution — it used to run after the local deploy, so the "before" state was already the new one.
- **`/aem-fe-verify` needs a demo page first.** It no longer creates pages; standalone it reports `BLOCKED: no local demo page` until `/aem-demo-page <component> --local` has run.
- **DOCAgent waits for QA.** The pipeline now runs `/dx-post-merge`. For an AEM story it stops with nothing posted when the merged change is not on QA yet — tag the work item after the QA deploy, or tag it again after a blocked run. Non-AEM repos skip the demo step. A dry run adds `--skip demo`. The pipeline needs `ADO_PAT` for screenshot uploads (already set for the ADO MCP).
- **`/dx-req-dod` 8e** calls `/dx-post-merge` instead of `/dx-doc-gen` + `/aem-doc-gen`.
- **Cross-repo stories wait.** `/aem-demo-page` stops with `Cross-repo dependency` when the story needs another repo's change that is not deployed to the instance yet (on QA: its PR on the work item is not completed). This guard used to live in `/aem-verify`.
- **No authoring guide without a ticket.** `/aem-editorial-guide hero` wrote a plain-language guide for any component. Now field descriptions and tips are written by `/dx-doc-gen` into the story's wiki page, which needs a work item. `/aem-demo-page hero` alone still sets up the page and captures screenshots.
- **Preview from the author, not the publisher.** Screenshots are taken at `<author><page>.html?wcmmode=disabled`. No publish step, no publisher polling.
- **QA handoff is a pointer.** The `[QAHandoff]` comment links the PR, wiki page, QA pages and screenshots. Step-by-step testing moved to the wiki page's **How to test** section. Re-runs post a short `[QAHandoff] Updated` comment instead of a second full one.

## Upgrade steps

1. `/plugin marketplace update dx-aem-flow`
2. `/dx-upgrade` — deletes `AEMAfter.agent.md` / `AEMEditorialGuide.agent.md`, installs `AEMDemoPage.agent.md` and `.ai/lib/upload-attachment.sh`, and lists under **Manual Actions Required** every local shadow, script or `copilot-instructions.md` row that still names a removed skill.
3. Update your own scripts, docs and pipeline prompts that call the removed commands (table above).
4. DOCAgent users: re-run `/auto-init` (keep config) to refresh `.ai/automation/pipelines/cli/ado-cli-doc-agent.yml`, commit it, and move the `KAI-DOC-AUTOMATION` tagging step to after the QA deploy. The ADO pipeline definition points at that file, so no re-import is needed.

## Rollback

The last v6 release is **6.6.0** (tag `v6.6.0`). Pin your marketplace source to it:

```jsonc
{ "source": { "source": "github", "repo": "easingthemes/dx-aem-flow", "ref": "v6.6.0" } }
```

Then `/plugin marketplace update` and reinstall. Old spec files (`aem-after.md`, `demo/authoring-guide.md`) are still in place, so v6 skills pick up where they left off. For a repo-wide revert or a hotfix, follow the options in [release-v3-rollback.md](release-v3-rollback.md#rollback-strategy).

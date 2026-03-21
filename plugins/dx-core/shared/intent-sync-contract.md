# Intent Sync Contract

Optional bridge: when skills run inside an Intent workspace, mirror `.ai/specs/` output to Intent notes with rich blocks. Zero impact without Intent.

## Guard Check

Before any sync, check once per session:

```
Is the tool `mcp__workspace-mcp__add_to_note` available?
  YES → INTENT_AVAILABLE = true
  NO  → skip all Intent sync (no errors, no warnings)
```

Cache the result. Do NOT re-check per skill invocation.

## Timing Rule

Intent sync happens in this order:

1. Primary output file saved to `.ai/specs/`
2. Subagent return envelope (`## Result`) prepared
3. **→ Intent sync executes here ←**
4. Envelope extended with `**Intent:**` field
5. Envelope printed

If Intent sync fails at any point, stop sync immediately and continue to step 4 with failure status.

## Note Naming

| Content | Note | How |
|---------|------|-----|
| Ticket overview, requirements, plan, pipeline | Spec note | `noteId="spec"` (always exists) |
| Research findings | Separate note | Title: `Research: #<ticket-id>` |
| DoR report | Separate note | Title: `DoR: #<ticket-id>` |
| AEM snapshot | Separate note | Title: `AEM: <component-name>` |

## Block ID Conventions

Format: `<type>-<ticket-id>-<n>` where `n` is a 1-based sequence per type per note.

| Type | Pattern | Example |
|------|---------|---------|
| Reference | `ref-<id>-<n>` | `ref-2446035-1` |
| CLI | `cli-<id>-<n>` | `cli-2446035-1` |
| Patch | `patch-<id>-<n>` | `patch-2446035-1` |
| Agent action | `action-<id>-<n>` | `action-2446035-1` |
| Diagram | `diag-<id>-<n>` | `diag-2446035-1` |

## Per-Skill Mapping

| Skill | Spec File | Intent Target | What to Write |
|-------|-----------|---------------|---------------|
| dx-req-fetch | raw-story.md | Spec note | Ticket overview table, set workspace title |
| dx-req-explain | explain.md | Spec note | Requirements table (numbered, status column) |
| dx-req-research | research.md | New "Research: #ID" note | Reference blocks for files, cross-repo scope table |
| dx-req-dor | dor-report.md | New "DoR: #ID" note | Checklist with pass/fail indicators |
| dx-plan | implement.md | Spec note | `@@@task` blocks (one per step), CLI + patch blocks |
| dx-req-share | share-plan.md | Spec note | Plain markdown summary section |
| dx-step | implement.md | Spec note | Update task status for completed step |
| dx-step-all | implement.md | Spec note | Update task statuses, pipeline progress table |
| dx-agent-all | dev-all-progress.md | Spec note | Pipeline progress table, agent action blocks |
| aem-snapshot | aem-before.md | New "AEM: \<name\>" note | Dialog fields table, JCR properties |
| aem-verify | aem-after.md | Spec note | Verification results section |

## Idempotency Rules

1. **Before creating a note:** Call `list_notes`, match by title. If exists, use `add_to_note` or `edit_note` on the existing note.
2. **Before adding to Spec:** Call `read_note(noteId="spec")`, search for the section header. If section exists, use `edit_note` to update. If not, use `add_to_note`.
3. **Task blocks:** Only add new `@@@task` blocks. Never duplicate tasks already present.
4. **Workspace title:** Only call `set_workspace_title` if the title is the default. Check with `get_workspace_details` first.

## Block Format Examples

### Reference (clickable code link)

```
add_reference_primitive(
  noteId = "research-note-id",
  semanticId = "ui.frontend/src/core/components/hero/default-hero.js#class:HeroDefault",
  description = "Hero component — default variation"
)
```

### CLI (runnable command)

```
add_cli_primitive(
  noteId = "spec",
  command = "cd ui.frontend && npm run build",
  description = "Build frontend assets"
)
```

### Patch (applyable diff)

```
add_patch_primitive(
  noteId = "task-note-id",
  filePath = "ui.frontend/src/core/components/hero/default-hero.js",
  diff = "--- a/default-hero.js\n+++ b/default-hero.js\n@@ -10,3 +10,4 @@\n+  this.setAttribute('aria-label', this.data.ariaLabel);",
  description = "Add aria-label to hero component"
)
```

### Agent Action (trigger button)

```
add_agent_action_primitive(
  noteId = "spec",
  goal = "Run dx-step-all to execute remaining implementation steps",
  description = "Execute pending implementation steps"
)
```

## Return Envelope Extension

Add `**Intent:**` to the subagent return envelope:

```
## Result
- **Status:** success
- **Summary:** Generated implement.md with 8 steps.
- **Files:** 1 created (implement.md)
- **Next:** dx-step-all
- **Intent:** synced (3 blocks) | skipped (not available) | failed (timeout)
```

Values: `synced (<N> blocks)`, `skipped (not available)`, `failed (<reason>)`.

## Error Handling

If any Intent MCP call fails:

1. Do NOT retry the failed call
2. Do NOT block the pipeline
3. Log: `Intent sync: <tool_name> failed — skipping remaining sync`
4. Set envelope `**Intent:** failed (<reason>)`
5. Continue with normal skill completion

## Example: dx-req-fetch Sync

After writing `raw-story.md`:

```
1. Guard: check INTENT_AVAILABLE → true
2. set_workspace_title(title = "Hero Accessibility Fix")
3. add_to_note(noteId = "spec", heading = "## Ticket Overview",
     content = "| Field | Value |\n|---|---|\n| ID | #2446035 |\n| Title | Hero Accessibility Fix |\n| Type | User Story |\n| State | Active |")
4. Set envelope: **Intent:** synced (1 block)
```

## Example: dx-plan Sync

After writing `implement.md`:

```
1. Guard: check INTENT_AVAILABLE → true
2. read_note(noteId = "spec") → check for existing tasks
3. For each step in implement.md:
   a. add_to_note(noteId = "spec", content = "@@@task\n# Step 1: Add aria-label to hero\n...")
   b. add_cli_primitive(noteId = latest_task_note_id,
        command = "cd ui.frontend && npm run build",
        description = "Verify build after hero changes")
   c. add_patch_primitive(noteId = latest_task_note_id, ...) — if diff known
4. Set envelope: **Intent:** synced (8 tasks, 8 CLI, 3 patches)
```

## Scope

- **In scope:** dx-core skills, dx-aem skills (aem-snapshot, aem-verify)
- **Out of scope:** dx-automation plugin, any non-dx plugin

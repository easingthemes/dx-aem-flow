# Hub Dispatch Protocol

Reference document for how coordinator skills detect and handle multi-repo scope.

## When This Applies

Hub mode lets a single `.hub/` directory orchestrate work across multiple repos. The hub opens independent Claude Code sessions in VS Code terminals — one per repo — via the `vscode-automator` MCP server. Each session has its own CWD, full plugin access, and MCP tools.

## Decision Tree (Per Skill)

Before executing any cross-repo work item, evaluate in order:

```
Is DX_PIPELINE_MODE=true?
  → yes: delegate via ADO pipeline (see repo-discovery.md — stop here)

Is hub.enabled=true AND cwd ends with .hub/?
  → yes: print "Hub mode detected. Use /dx-hub-dispatch <id> to dispatch."
  → STOP — do not dispatch from within individual skills.
  → The hub's /dx-hub-dispatch skill handles terminal opening, pre-seeding, and delegation.

Is cross-repo scope detected?
  → yes: print "switch to {repo.name} at {repo.path}" (manual handoff)

Otherwise:
  → execute locally (standard behavior)
```

**Key change:** Individual skills no longer dispatch via `claude -p`. Hub dispatch is now a dedicated skill (`/dx-hub-dispatch`) that opens VS Code terminals. When a coordinator skill detects hub mode, it stops and tells the user to use `/dx-hub-dispatch` instead.

## Hub Detection

Two conditions must BOTH be true for hub mode to be active:

```bash
HUB_ENABLED=$(grep -A1 '^hub:' .ai/config.yaml | grep 'enabled:' | grep -o 'true' || echo "false")
IS_HUB_DIR=$(basename "$(pwd)" | grep -q '\.hub$' && echo "true" || echo "false")
```

Hub mode is active when `HUB_ENABLED=true` AND `IS_HUB_DIR=true`.

The directory check prevents skills from accidentally triggering hub logic when run inside a child repo.

## What Skills Should Do in Hub Mode

When a skill detects hub mode is active:

1. **STOP** — do not execute the skill's normal pipeline
2. **Print** a diagnostic message with clear next steps:
   ```
   ⚠ Hub mode active — this skill cannot run directly in the hub directory.

   Why: You're in a .hub/ coordinator directory. Individual skills run inside
   each repo, not here. The hub dispatches work to repos, each with its own
   plugins and context.

   Next step: Run `/dx-hub-dispatch <ticket-id>` to:
     - Fetch the ticket from ADO/Jira
     - Determine which repos are involved
     - Open a terminal per repo with the right context
     - Pre-seed ticket data so each repo's skills pick up automatically

   After dispatch: Each repo runs its own /dx-req, /dx-plan, etc. independently.
   Use `/dx-hub-status` to track progress across all repos.
   ```
3. **Do not** attempt to run `claude -p`, open terminals, or dispatch from within the skill

The hub's `/dx-hub-dispatch` skill handles:
- Fetching the ticket from ADO/Jira
- Determining which repos are involved (via capabilities matching)
- Pre-seeding raw ticket files into each repo's spec directory
- Opening VS Code terminals and starting Claude sessions with delegation prompts
- Writing status tracking files

## Pre-Seeded Raw Ticket Files

When a skill runs inside a repo that was dispatched by the hub, `raw-story.md` (or `raw-bug.md`) may already exist in the spec directory — pre-seeded by `/dx-hub-dispatch`. Skills should check for this before fetching from ADO/Jira:

- If `raw-story.md` exists and no fetch has been done → skip the fetch, use the pre-seeded file
- If `raw-bug.md` exists and no fetch has been done → skip the fetch, use the pre-seeded file

This is already implemented in `dx-req` (step 9) and `dx-bug-triage` (step 8).

## Cross-Repo Context

When dispatched by the hub, each repo's Claude session receives a `context.md` file path in its delegation prompt. This file contains:
- Which other repos are involved
- Their roles (frontend, backend, etc.)
- Brief notes on what each handles

Repos can also check each other's spec directories for coordination: `<other-repo-path>/.ai/specs/<ticket-slug>/`

## Repo Resolution

Target repos are listed under `repos:` in the hub's `.ai/config.yaml`:

```yaml
repos:
  - name: Repo-A
    path: ../repo-a
    capabilities: [fe]
  - name: Repo-B
    path: ../repo-b
    capabilities: [be]
```

### Role-to-Capabilities Mapping

| Role | Capabilities |
|------|-------------|
| `backend` | `[be]` |
| `frontend` | `[fe]` |
| `fullstack` | `[fe, be]` |

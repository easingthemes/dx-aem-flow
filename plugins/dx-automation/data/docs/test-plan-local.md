# Test Plan — Local (Claude Code Skills)

Test the AI workflows as a developer would use them — via Claude Code skills. See `test-plan-shared.md` for test work items and verification.

## Prerequisites

- Claude Code CLI installed and authenticated
- dx plugins installed (`/plugin install dx-core`, `dx-aem`, `dx-automation`)
- `/dx-init` and `/aem-init` run (`.ai/config.yaml` exists)
- ADO PAT set in environment or `.env`
- LLM key set (`ANTHROPIC_API_KEY`)

---

## Flow 1 — Requirements → Plan → Implement (User Story)

Full story flow using coordinator skills.

```
/dx-req-all <USER_STORY_ID>
```

**Pass:** `.ai/specs/<id>-<slug>/` contains: `raw-story.md`, `dor-report.md`, `explain.md`, `research.md`, `share-plan.md`.

```
/dx-plan <USER_STORY_ID>
```

**Pass:** `implement.md` created with numbered steps, all status `pending`.

```
/dx-agent-all <USER_STORY_ID>
```

**Pass:** All steps executed, branch created, build passes, PR created in ADO. Phases complete: requirements → plan → execute → build → review → commit → verify → PR.

---

## Flow 2 — Bug Fix

Full bug flow using coordinator skill.

```
/dx-bug-all <BUG_ID>
```

**Pass:** `raw-bug.md`, `triage.md`, `verification.md` created. Fix applied, branch + PR created. If cross-repo: delegation detected and documented.

---

## Flow 3 — PR Review + Answer

```
/dx-pr-review <PR_ID>
```

**Pass:** Review comments posted on PR threads, vote cast (wait/approve).

```
/dx-pr-answer
```

**Pass:** Replies posted to open comment threads on your PR. Code fixes applied for `agree-will-fix` comments.

---

## Flow 4 — AEM Verification (requires running AEM)

```
/aem-snapshot <component-name>
```

**Pass:** Baseline saved — dialog fields, properties, pages where component is used.

```
/aem-verify <component-name>
```

**Pass:** Component verified against baseline. Test page created with configured component.

---

## Flow 5 — Pipeline Agent Dry-Run

Test automation agents locally before deploying to Lambda/ADO.

```
/auto-test dor <USER_STORY_ID> --dryRun
/auto-test estimation <USER_STORY_ID> --dryRun
/auto-test bugfix <BUG_ID> --dryRun
/auto-test pr-review <PR_ID> <REPO_NAME> --dryRun
```

**Pass:** Agent runs to completion, `--dryRun: true` in output, no `[ALERT:CRITICAL]`. Nothing posted to ADO.

Then go live (one agent at a time):

```
/auto-test dor <USER_STORY_ID>
```

**Pass:** DoR comment appears on the work item in ADO.

---

## Flow 6 — Eval Gates

Run after any change to prompts, rules, agents, or policy.

```
/auto-eval --all
```

**Pass:** All fixtures pass 7 Tier 1 gates (json-schema, no-forbidden-actions, max-findings, source-citations, must-find, must-not-find, vote-consistency).

---

## Flow 7 — Unit Tests

No credentials needed.

```bash
node --test .ai/automation/agents/lib/__tests__/*.test.mjs
```

**Pass:** All tests green. Covers capability gates, push policy, redaction.

---

## Flow 8 — Health Check

```
/auto-doctor
```

**Pass:** All checks green — local files, pipeline config, Lambda state, env var keys.

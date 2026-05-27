---
name: dx-simple
description: Apply a small AEM change (a11y label, color, spacing, copy, css-class, icon) by splitting work into authoring (JCR writes) and code (file edits → PR) paths. Use after the ADO story contains a structured ```simple``` block. Trigger on "simple change", "small tweak", "apply tweak".
argument-hint: "<ADO Work Item ID or full URL>"
allowed-tools: ["read", "edit", "search", "write", "agent"]
model: sonnet
hooks:
  PreToolUse:
    - matcher: Bash
      command: ${CLAUDE_PLUGIN_ROOT}/skills/dx-simple/hooks/block-mvn-deploy.sh
      timeout: 5
---

You are the coordinator for `/dx-simple` — a tight, pipeline-grade skill that applies a small AEM change (authoring or code) under a strict confidence model. You do NOT implement anything in main context except:

1. Parse the ADO story's `simple` block (Phase 1).
2. Dispatch parallel research subagents (Phase 2).
3. Apply authoring writes via AEM MCP (Phase 3a) — this is in main context because audit log + rollback record require it.
4. Read the work-plan to decide control flow.

All other work — codebase reading, visual verify, compile, diff review — runs in `context: fork` subagents so the main context stays under ~30 turns.

## Argument

The argument is the ADO work item ID (numeric, e.g., `9999999`). Accept a full URL and extract the numeric ID. If no argument, ask the user once; if still none in pipeline mode, exit non-zero.

## Pre-flight (HARD GATE — runs before anything else)

```bash
bash $CLAUDE_PLUGIN_ROOT/skills/dx-simple/scripts/preflight.sh
```

If it exits non-zero, **STOP**. Post the stderr to ADO as a comment:

```
mcp__ado__wit_add_work_item_comment with the preflight error text
```

Exit non-zero. **No other action.**

## Spec directory

```bash
SPEC_DIR=$(bash .ai/lib/dx-common.sh find-spec-dir $ARGUMENTS)
[[ -z "$SPEC_DIR" ]] && SPEC_DIR=".ai/specs/${ARGUMENTS}-simple" && mkdir -p "$SPEC_DIR"
```

Initialize state files:
```bash
bash $CLAUDE_PLUGIN_ROOT/skills/dx-simple/scripts/update-progress.sh "$SPEC_DIR" "Preflight" "done"
# Initialize confidence-tracking file used across all gates
echo '{"gates":{}}' > "$SPEC_DIR/confidence.json"
# authoring-diff.json is created lazily by Phase 3a when the first write happens
```

Touch the orchestration flag (in case a future orchestrator wraps this skill):
```bash
mkdir -p .ai/run-context
touch .ai/run-context/orchestrating.flag
```

**State files written during the run** (the skill creates these as it goes):

| File | Created in | Purpose |
|---|---|---|
| `raw-story.md` | Phase 1 | ADO story dump |
| `simple-block.yaml` | Phase 1 (after parse) | Parsed DoR block |
| `before.png` | Phase 1 (after G1) | Pre-change Chrome screenshot |
| `locator-bbox.json` | Phase 1 (after G1) | `{x, y, w, h}` of locator's bounding box |
| `confidence.json` | initialized in pre-flight; appended per gate | `{"gates":{"G1":{"score":1,"status":"pass"}, ...}}` |
| `dialog-map.json` | Phase 2 (from dialog-inspector subagent) | Field name → type + values |
| `file-list.json` | Phase 2 (from file-resolver subagent) | Source file paths |
| `work-plan.json` | Phase 2 (classify-work.sh) | Authoring + code arrays |
| `authoring-diff.json` | Phase 3a (per write) | Before/after for rollback |
| `compile.log` | Phase 4 (per retry, overwritten) | Build output, tail in report |
| `after.png` | Phase 5 | Post-change Chrome screenshot |
| `visual-diff.json` | Phase 5 (visual-diff.sh) | Overall + region pixel scores |
| `diff-review.md` | Phase 5.5 (from dx-pr-reviewer) | Reviewer findings |
| `simple-progress.md` | initialized in pre-flight; updated per phase | Phase status table |
| `report.md` | Phase 7 (rendered from template) | Final human-readable report |

## Confidence model (gates G1–G9)

This skill enforces 9 confidence gates. **Any gate failure → rollback authoring (if applied) + ADO comment + exit non-zero.** Track scores in `$SPEC_DIR/confidence.json`; the final report quotes them.

| Gate | Phase | Threshold |
|---|---|---|
| G1 Locator match | 1 | exactly 1 DOM match for component-locator |
| G2 Allowlist | 1 | resource-type in `.ai/config.yaml > dx-simple.allowed-resource-types` |
| G3 Classification | 2 | high or medium |
| G4 Per-file edit confidence | 3b | ≥ 0.85 |
| G5 Visual non-target identical | 5 | ≥ 99% |
| G6 Visual target changed | 5 | ≥ 5% |
| G7 Review blockers @ ≥80% conf | 5.5 | 0 |
| G8 Cost | global | ≤ $2 (configurable) |
| G9 Time | global | ≤ 12 min |

## Flow

```dot
digraph dx_simple {
    "Preflight + spec dir" [shape=box];
    "Phase 1: Fetch + parse simple block" [shape=box];
    "G1: locator match exactly 1?" [shape=diamond];
    "G2: resource-type allowlisted?" [shape=diamond];
    "Phase 2: Classify (parallel subagents)" [shape=box];
    "G3: classification high or medium?" [shape=diamond];
    "Phase 3a: Apply authoring writes" [shape=box];
    "Phase 3b: Apply code edits" [shape=box];
    "G4: per-file edit confidence ≥85%?" [shape=diamond];
    "Scope-check ok?" [shape=diamond];
    "Phase 4: Compile (≤3 retries)" [shape=box];
    "Compile passed?" [shape=diamond];
    "Phase 5: Visual verify" [shape=box];
    "G5+G6: visual gates pass?" [shape=diamond];
    "One re-edit retry left?" [shape=diamond];
    "Re-edit with screenshot context" [shape=box];
    "Phase 5.5: Diff review (dx-pr-reviewer)" [shape=box];
    "G7: zero blockers ≥80% conf?" [shape=diamond];
    "Phase 6: Activate + Commit + PR" [shape=box];
    "Phase 7: Write report + ADO comment" [shape=doublecircle];
    "ABORT: Rollback + comment + exit" [shape=doublecircle];

    "Preflight + spec dir" -> "Phase 1: Fetch + parse simple block";
    "Phase 1: Fetch + parse simple block" -> "G1: locator match exactly 1?";
    "G1: locator match exactly 1?" -> "ABORT: Rollback + comment + exit" [label="no"];
    "G1: locator match exactly 1?" -> "G2: resource-type allowlisted?" [label="yes"];
    "G2: resource-type allowlisted?" -> "ABORT: Rollback + comment + exit" [label="no"];
    "G2: resource-type allowlisted?" -> "Phase 2: Classify (parallel subagents)" [label="yes"];
    "Phase 2: Classify (parallel subagents)" -> "G3: classification high or medium?";
    "G3: classification high or medium?" -> "Phase 3a: Apply authoring writes" [label="high or medium → authoring"];
    "G3: classification high or medium?" -> "Phase 3b: Apply code edits" [label="low → code fallback"];
    "Phase 3a: Apply authoring writes" -> "Phase 5: Visual verify";
    "Phase 3b: Apply code edits" -> "G4: per-file edit confidence ≥85%?";
    "G4: per-file edit confidence ≥85%?" -> "ABORT: Rollback + comment + exit" [label="no"];
    "G4: per-file edit confidence ≥85%?" -> "Scope-check ok?" [label="yes"];
    "Scope-check ok?" -> "ABORT: Rollback + comment + exit" [label="no"];
    "Scope-check ok?" -> "Phase 4: Compile (≤3 retries)" [label="yes"];
    "Phase 4: Compile (≤3 retries)" -> "Compile passed?";
    "Compile passed?" -> "Phase 5: Visual verify" [label="yes"];
    "Compile passed?" -> "ABORT: Rollback + comment + exit" [label="no (after 3 retries)"];
    "Phase 5: Visual verify" -> "G5+G6: visual gates pass?";
    "G5+G6: visual gates pass?" -> "Phase 5.5: Diff review (dx-pr-reviewer)" [label="yes"];
    "G5+G6: visual gates pass?" -> "One re-edit retry left?" [label="no"];
    "One re-edit retry left?" -> "Re-edit with screenshot context" [label="yes"];
    "One re-edit retry left?" -> "ABORT: Rollback + comment + exit" [label="no"];
    "Re-edit with screenshot context" -> "Phase 4: Compile (≤3 retries)";
    "Phase 5.5: Diff review (dx-pr-reviewer)" -> "G7: zero blockers ≥80% conf?";
    "G7: zero blockers ≥80% conf?" -> "ABORT: Rollback + comment + exit" [label="no"];
    "G7: zero blockers ≥80% conf?" -> "Phase 6: Activate + Commit + PR" [label="yes"];
    "Phase 6: Activate + Commit + PR" -> "Phase 7: Write report + ADO comment";
}
```

## Node Details

### Phase 1: Fetch + parse simple block

1. Fetch the work item:
   ```
   mcp__ado__wit_get_work_item with id=$ARGUMENTS
   ```
   Write the description + comments to `$SPEC_DIR/raw-story.md` with provenance frontmatter.

2. Parse the `simple` block:
   ```bash
   bash $CLAUDE_PLUGIN_ROOT/skills/dx-simple/scripts/parse-simple-block.sh \
        "$SPEC_DIR/raw-story.md" "$SPEC_DIR/simple-block.yaml"
   ```
   - Exit 2 (missing) → post the template at `$CLAUDE_PLUGIN_ROOT/skills/dx-simple/templates/simple-block.md.tmpl` as an ADO comment. STOP.
   - Exit 3 (malformed) → post the specific error from stderr as an ADO comment. STOP.

3. Semantic validation (Safeguard #1):
   - Read `simple-block.yaml`; extract `page-url`, `component-locator`, `change-type`, `change-value`.
   - Navigate Chrome to `page-url`:
     ```
     mcp__plugin_dx-aem_chrome-devtools-mcp__navigate_page with url=<page-url>
     ```
   - Take a snapshot:
     ```
     mcp__plugin_dx-aem_chrome-devtools-mcp__take_snapshot
     ```
   - Match the locator. The locator is one of:
     - `heading-text="..."` → look for element with that exact visible text in headings
     - `jcr-path=...` → use AEM MCP `getNodeContent` to confirm node exists; locator match count = 1 if node exists, 0 if not
     - `dialog-title="..."` → ambiguous on its own; require AEM MCP `scanPageComponents` to resolve to a unique component instance

4. **Take BEFORE screenshot** (Safeguard #6): capture and save as `$SPEC_DIR/before.png`:
   ```
   mcp__plugin_dx-aem_chrome-devtools-mcp__take_screenshot with filePath=$SPEC_DIR/before.png
   ```
   Also record the locator's bounding box (from snapshot) to `$SPEC_DIR/locator-bbox.json` for the visual-diff step.

5. **G1 — Locator match (HARD GATE):**
   - If 0 matches: post ADO comment "Component not found on page. Verified by: <snapshot-id>. Check page-url + component-locator." Exit non-zero. NO file reads beyond this point.
   - If >1 matches: post "Ambiguous locator: <N> matches. Specify jcr-path=... instead." Exit non-zero.
   - If exactly 1: continue. Record `G1 = 1 match` in `confidence.json`.

6. **G2 — Resource type allowlist:**
   Read `.ai/config.yaml > dx-simple.allowed-resource-types`. If `*`, allow any. Otherwise check the resolved component's `sling:resourceType` is in the list.
   - Not in list → post ADO comment "Resource type `<type>` not allowlisted for /dx-simple. Add to .ai/config.yaml > dx-simple.allowed-resource-types." Exit non-zero.

7. Update progress:
   ```bash
   bash $CLAUDE_PLUGIN_ROOT/skills/dx-simple/scripts/update-progress.sh \
        "$SPEC_DIR" "Phase 1: DoR" "done" "G1+G2 passed"
   ```

### Phase 2: Classify (parallel subagents)

Dispatch THREE subagents in a single message (parallel):

1. **Page resolver** (reuse `aem-page-finder`, model: haiku):
   ```
   Agent(subagent_type: aem-page-finder, prompt: "Resolve page-url <page-url> to its JCR content path. Confirm the page exists on QA. Return JSON: {\"jcr-path\": \"/content/...\", \"language-master\": \"<path or null>\"}.")
   ```

2. **Dialog inspector** (reuse `aem-inspector`, model: sonnet):
   ```
   Agent(subagent_type: aem-inspector, prompt: "For component at JCR path <jcr-path>, read sling:resourceType, then fetch /apps/<resource-type>/cq:dialog. Walk the dialog fields and return JSON:
   {
     \"jcr-path\": \"<jcr>\",
     \"resource-type\": \"<rtype>\",
     \"fields\": { \"<name>\": \"<type>\", ... },
     \"values\": { \"<name>\": \"<current value>\", ... }
   }
   Return only the JSON, no prose.")
   ```

3. **File resolver** (reuse `aem-file-resolver`, model: haiku):
   ```
   Agent(subagent_type: aem-file-resolver, prompt: "Resolve source files for resource type <resource-type>. Return JSON: {\"files\": [{\"path\": \"...\"}, ...]}.")
   ```

Synthesize the three returns into `$SPEC_DIR/dialog-map.json` and `$SPEC_DIR/file-list.json`. Then run the deterministic classifier:

```bash
bash $CLAUDE_PLUGIN_ROOT/skills/dx-simple/scripts/classify-work.sh \
     "$SPEC_DIR/simple-block.yaml" \
     "$SPEC_DIR/dialog-map.json" \
     "$SPEC_DIR/file-list.json" \
     "$SPEC_DIR/work-plan.json"
```

Read `work-plan.json` and extract `confidence.G3-classification`.

**G3 — Classification:**
- `high` (1 unambiguous match) → take authoring path
- `medium` (>1 candidate, picked best by name heuristic) → take authoring path, log alternatives in report Notes
- `low` (no dialog field match) → fall back to code-path. If code-path also can't identify the file with high confidence (Phase 3b), exit.

Update progress:
```bash
bash $CLAUDE_PLUGIN_ROOT/skills/dx-simple/scripts/update-progress.sh \
     "$SPEC_DIR" "Phase 2: Classify" "done" "G3=<level>"
```

### Phase 3a: Apply authoring writes

**Only if work-plan.json has authoring items.**

For each item in `work-plan.authoring[]`:

1. Read current value:
   ```
   mcp__plugin_dx-aem_AEM__getNodeContent with path=<jcr-path>
   ```
   Confirm `item.before` matches the actual current value. If not, abort with `"value drifted: expected <before>, got <actual>"`.

2. Apply the write:
   ```
   mcp__plugin_dx-aem_AEM__updateComponent with path=<jcr-path>, properties={<property>: <after>}
   ```

3. Append to `$SPEC_DIR/authoring-diff.json`:
   ```json
   { "writes": [{ "jcr-path": "...", "property": "...", "before": "...", "after": "...", "applied": true, "applied-at": "<ISO>" }] }
   ```

4. Log to audit:
   ```bash
   AUDIT_LOG_PREFIX=simple source .ai/lib/audit.sh
   _audit_append '{"ts":"<ISO>","action":"updateComponent","path":"<jcr>","property":"<prop>","ticket":"<id>"}'
   ```

If ANY write fails partway through:
- Mark all subsequent items as `applied: false`
- Trigger rollback (script below)
- Post ADO comment, exit non-zero

Update progress.

### Phase 3b: Apply code edits

**Only if work-plan.json has code items (G3 was low OR change-type is css-class).**

For each item in `work-plan.code[]`:

1. Read the file:
   ```
   Read(file=<path>)
   ```

2. Identify the exact match line. The agent fills in `match-line`, `match-context`, `replacement`, `rationale`, and `confidence` (LLM self-rated, 0.0–1.0):
   - High confidence: only one match in the file matching the locator's context. Rationale: "only `color: red` occurrence in .hero-cta selector".
   - Medium (rejected): multiple matches with unclear precedence.

3. **G4 — Per-file edit confidence (HARD GATE):** if any item has confidence < 0.85 → abort + rollback authoring.

4. Apply the Edit:
   ```
   Edit(file=<path>, old_string=<match-context>, new_string=<replacement>)
   ```

5. After all code items applied: run scope-check:
   ```bash
   bash $CLAUDE_PLUGIN_ROOT/skills/dx-simple/scripts/scope-check.sh "$SPEC_DIR/work-plan.json"
   ```
   Exit 4 → rollback authoring + exit non-zero.

Update progress.

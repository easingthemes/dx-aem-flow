---
name: dx-req-checklist
description: "⚠️ DEPRECATED — Use /dx-req-dor instead. Generates checklist.md with open questions. Kept for backward compatibility."
argument-hint: "[ADO Work Item ID (optional — uses most recent if omitted)]"
allowed-tools: ["read", "edit", "search", "write", "agent"]
---

> **⚠️ Deprecated:** This skill is superseded by `/dx-req-dor` which combines DoR validation
> with open questions in a single report. Use `/dx-req-dor` instead.
> This skill is kept for backward compatibility — it still works but is no longer
> called by `/dx-agent-all` or `/dx-req-all`.

You read all available spec documents, use extended thinking to systematically cross-reference requirements against codebase realities, and generate `checklist.md` — a categorized list of open questions to take back to the BA or Product Owner.

Use ultrathink for this skill — gap analysis requires careful cross-referencing of the story, requirements, codebase findings, and implementation plan to find what's missing or ambiguous.

## Persona (optional)

If `.ai/me.md` exists, read it. Use it to shape the tone of checklist questions — the persona guides whether questions are formal or casual, direct or diplomatic. Structural constraints (one line per question, checkbox format) still apply. If `.ai/me.md` doesn't exist, use defaults.

## 1. Locate the Spec Directory

```bash
SPEC_DIR=$(bash .ai/lib/dx-common.sh find-spec-dir <work-item-id-if-provided>)
```

If the script exits with error, ask the user for the work item ID.

Read ALL available files from `$SPEC_DIR`:
- `raw-story.md` — original story (required)
- `explain.md` — distilled requirements (if exists)
- `research.md` — codebase findings (if exists)
- `implement.md` — implementation plan (if exists)

The more documents available, the better the gap analysis. If only `raw-story.md` exists, work from that alone.

## 2. Check Existing Output

1. Check if `checklist.md` exists in the spec directory
2. If it exists, read its content
3. Check staleness indicators:
   - Does the ADO ID in `checklist.md` match the current work item?
   - Have any of the input files changed? (`raw-story.md`, `explain.md`, `research.md`, `implement.md`)
   - Compare requirement count from `explain.md`, key findings count from `research.md`, and step count from `implement.md` against what `checklist.md` references
4. If all inputs appear unchanged → print `checklist.md already up to date — skipping` and STOP
5. If any input changed → print `checklist.md exists but is outdated — regenerating` and continue
6. If not found → continue normally (first run)

## 3. Interpreting ADO Story Formatting

ADO descriptions are often poorly formatted. Before flagging "cut-off" or "incomplete" text, check for common patterns:

- **Label on its own line** — `IMPORTANT:` or `NOTE:` followed by content on the next line is just a heading, not a truncated sentence. Read the following lines before concluding something is missing.
- **Line breaks within a thought** — ADO's editor often splits one logical sentence across multiple lines. Reconstruct the full meaning before judging completeness.
- **Bullet fragments** — Short lines without punctuation are usually list items, not incomplete sentences.

**Rule: Never flag formatting as a blocking question.** If the meaning is recoverable by reading surrounding lines, it's not ambiguous — it's just ugly formatting.

## 4. Gap Analysis Strategy

Use extended thinking to systematically find gaps by asking:

**Requirements vs Implementation:**
- For each requirement in explain.md, can it be implemented with the code found in research.md?
- Are there requirements that reference things not found in the codebase?
- Does the implementation plan in implement.md make assumptions not stated in the requirements?

**Specificity gaps:**
- What values, options, or behaviors are mentioned but not fully specified?
- Are there "or" statements without a decision?
- Are there implied behaviors that could go multiple ways?

**Codebase-informed gaps:**
- Does research.md reveal existing code that contradicts or complicates the requirements?
- Does the current component support things the story doesn't address (what happens to them)?
- Are there multi-brand/multi-variant implications the story doesn't mention?

**Edge cases:**
- What happens when data is missing, empty, or invalid?
- What happens on different screen sizes if UI changes are involved?
- What about backwards compatibility with existing content?

**Design gaps:**
- Are Figma designs referenced but missing specific states?
- Are there interactions (hover, click, transition) not specified?
- Mobile vs desktop differences not addressed?

## 5. Self-Discovery — Answer Technical Questions Before Asking

**CRITICAL: Before adding ANY question to the checklist, try to discover the answer yourself.** A developer should never ask the BA a question that's answerable by reading the code, inspecting AEM, or following links in the story.

For each potential question, attempt discovery in this order:

1. **Code search** — grep the codebase for the relevant patterns (query params, routes, component logic, API calls). If research.md already has the answer, use it.
2. **AEM inspection** — if AEM MCP is available, check component dialogs, page content, or content policies for the answer.
3. **Follow links** — if the story or comments contain URLs (Confluence, Figma, API docs), fetch them via WebFetch and look for the answer.
4. **Chrome DevTools** — if there's a live URL in the story, navigate to it and inspect the runtime behavior (query params, network calls, DOM structure).

**Rules:**
- If you can discover the answer → record it as an **Assumption** (e.g., "Token is passed as `?token=` query parameter — confirmed in `emailverification-section.js:42`"), NOT as a question.
- If discovery is inconclusive → keep the question but add what you found (e.g., "Source detection method not found in codebase — is this a new parameter?").
- **Never ask the BA how existing code works.** That's your job as a developer. Only ask about **business decisions** the code can't tell you (e.g., "Should success redirect or show a message?").

Write `checklist.md` in the same spec directory.

### checklist.md Format

```markdown
# Open Questions: <Title> (ADO #<id>)

**For:** <Assigned To from raw-story.md, or "BA / Product Owner">
**From:** Developer review of requirements + codebase analysis
**Date:** <today's date>
**Reference:** [ADO #<id>]({scm.org}/{scm.project_url_encoded}/_workitems/edit/<id>)

## Blocking Questions
<Questions that MUST be answered before development can start.
Keep to 1-3 items max. If nothing blocks, omit this section.>

- [ ] <Question> — _<one-sentence context, max 20 words>_

## Open Questions
<Non-blocking questions grouped by topic. No separate sections for
"Requirements Gaps", "Ambiguities", "Edge Cases", "Design Gaps",
"Cross-Cutting" — just a flat list with a topic tag per item.>

- [ ] **[req]** <Question> — _<one-sentence context>_
- [ ] **[design]** <Question> — _<one-sentence context>_
- [ ] **[edge case]** <Question> — _<one-sentence context>_

## Assumptions
<Confirmable statements. One line each, no context needed.>

- [ ] <Statement — e.g., "New fields are optional; existing content works unchanged.">
- [ ] <Statement>

---

**Total open questions:** <count>
**Blocking development:** <count of items that must be answered before coding can start>
**Can proceed with assumptions:** <count of items in "Assumptions" section>
```

Where `{scm.org}` and `{scm.project_url_encoded}` are read from `.ai/config.yaml`.

## 7. Pragmatism Filter — Apply Before Adding Any Question

If `.ai/rules/pragmatism.md` exists (project override), read and apply it. Otherwise read the plugin's `rules/pragmatism.md`.

Additionally, apply these skill-specific filters:

1. **Trust the story over the parent** — If the child story refines or overrides the parent's approach, that's intentional. Don't flag it as a conflict.
2. **Implementation detail, not requirement** — "Checkbox vs automatic step-count" — if the story says checkbox, build a checkbox. Don't second-guess the BA's design choice by citing a parent story's different approach.
3. **Edge case with obvious answer** — "What if author selects the same pod twice?" — if the story says "no additional rule necessary", that IS the answer. Don't re-ask it.
4. **Don't re-ask what the story already answers** — If the acceptance criteria says "shared error page", don't ask "should it use the shared error page or a separate one?" That's already decided. Read the story carefully before generating any question.
5. **Reuse-first principle** — Always assume existing flows, pages, components, and patterns should be reused. Don't ask "should we create a new X?" unless the story explicitly says so. The default is always to reuse what exists.

**Target: 2-5 genuinely useful questions, not 10+ pedantic ones.** A checklist with zero questions is a valid outcome for a well-written story.

## 8. Writing Principles

- **Concise context lines** — keep `_Context:` to ONE sentence (max 20 words). Just enough for the BA to understand why you're asking. No multi-sentence explanations, no quoting large blocks, no "if X then Y then Z" chains.
- **One line per question** — the question itself is one clear sentence. Don't embed sub-questions or alternatives in the question.
- **Checkbox format** — so the BA can check off answers as they respond
- **Categories help routing** — the BA might answer Requirements Gaps themselves but forward Design Gaps to the designer
- **"Assumptions I'm Making" is critical** — turns implicit guesses into explicit confirmable statements. This prevents rework.
- **Prioritize** — put blocking questions (can't start without an answer) before nice-to-know questions
- **Omit empty categories** — if there are no design gaps, don't include the section
- **Hard limit: ~40 lines** — if your checklist exceeds 40 lines of content (excluding header), you're being too verbose. Aim for 3-6 total questions, not 10+.

## 9. Present Summary

After saving:

```markdown
## checklist.md created

**<Title>** (ADO #<id>)
- Total open questions: <count>
- Blocking development: <count>
- Can proceed with assumptions: <count>
- Categories: <list of non-empty categories>

### Recommended action:
<One of:
- "Send to BA before starting — <N> blocking questions need answers"
- "Can proceed — all questions are non-blocking assumptions. Send for confirmation in parallel with development"
- "Requirements are solid — no significant gaps found">
```

## Examples

### Generate checklist
```
/dx-req-checklist 2435084
```
Cross-references `explain.md`, `research.md`, and `implement.md` against each other. Generates `checklist.md` with categorized open questions for the BA.

### All clear
```
/dx-req-checklist 2435084
```
If no ambiguities found, generates a minimal checklist confirming requirements are clear.

## Troubleshooting

### Checklist has too many generic questions
**Cause:** `research.md` is missing, so gaps can't be identified from codebase context.
**Fix:** Run `/dx-req-research` first — it provides the codebase grounding that makes checklist questions specific.

### "No spec directory found"
**Cause:** Spec files haven't been created yet.
**Fix:** Run `/dx-req-fetch <id>` and `/dx-req-explain <id>` first.

## Rules

- **Evidence-based questions only** — every question must be traceable to a specific gap between the story and what's needed for implementation. No generic "have you considered..." questions.
- **No padding** — if the story is well-specified and research shows the implementation path is clear, checklist.md can have 0-2 items or even just a note that requirements are solid. Don't manufacture questions.
- **Developer perspective** — these are questions that block or complicate implementation, not project management questions about timeline, priority, or pending deliverables.
- **Trust the story over the parent** — if the child story refines or overrides the parent's approach, that's intentional. Don't flag it as a conflict.
- **Actionable format** — the BA should be able to answer each question with a short response. Avoid open-ended questions like "Can you elaborate on the requirements?" — instead ask specific questions: "Should the dropdown default to 'one' or have no default (requiring author selection)?"
- **Respect the BA's work** — the tone should be collaborative ("I noticed X doesn't specify Y — could you clarify?") not critical ("The story is missing X").
- **Brevity is respect** — a concise checklist gets answered faster. The BA/PO should be able to read and respond to the entire checklist in 5 minutes. If it takes longer, you wrote too much.

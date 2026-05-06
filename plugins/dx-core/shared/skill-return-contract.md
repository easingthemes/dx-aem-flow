# Skill Return Contract

> Applies to skills with `context: fork` that are invoked by `dx-agent-all` or another orchestrator.

When a forked skill finishes, its **last emitted block** must be a `## Return` section in the format below. The orchestrator reads only this block. Anything above it is for the developer who is debugging the forked subagent.

## Format

```markdown
## Return
verdict: pass | warn | fail
summary: <one sentence, ≤200 chars, plain prose — no markdown, no tables>
artifacts:
  - <relative path to file written or updated>
  - <…>
next_action: <one short phrase, or "none">
```

## Field rules

- **verdict** — one of `pass`, `warn`, `fail`. `warn` means proceed-with-noted-issues. `fail` means blocking error.
- **summary** — single sentence, no line breaks. The orchestrator may quote this verbatim into its phase log.
- **artifacts** — list of file paths the orchestrator can `Read` later if the user asks for detail. Always include the canonical report file (e.g. `validation-report.md`, `plan-thinking.md`).
- **next_action** — one short phrase. Examples: `"continue to Phase 4"`, `"run /dx-plan-resolve"`, `"none"`. Never instructions; always names.

## Example — passing build

```markdown
## Return
verdict: pass
summary: Build & deploy passed in 4m12s; 2 modules built; no fix attempts.
artifacts:
  - .ai/specs/2490722-microsite/build-log.txt
next_action: continue to Phase 4.5
```

## Example — failing validation

```markdown
## Return
verdict: fail
summary: Plan missing test coverage step for requirement #5; reuse-check skipped.
artifacts:
  - .ai/specs/2490722-microsite/validation-report.md
next_action: run /dx-plan-resolve
```

## Anti-patterns (do not do these)

- Putting tables, ASCII art, or multi-line content in `summary`. The orchestrator will quote it and pollute main context.
- Returning a `verdict` not in {pass, warn, fail}. Orchestrator branching depends on the literal value.
- Omitting the `artifacts` list. The orchestrator may need to read the report later.
- Emitting prose *after* the `## Return` block. The block must be last.

## Verification

CI / linter check (when implemented):
```bash
# Every forked skill must reference this contract.
for s in $(grep -l "context: fork" plugins/*/skills/*/SKILL.md); do
  grep -q "skill-return-contract" "$s" || echo "MISSING: $s"
done
```

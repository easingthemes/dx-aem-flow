# Pragmatism Rules for Questions

Apply these filters before adding any question. If ANY filter catches it, drop the question (or move it to Assumptions with a sensible default).

1. **Answerable from the story** — Read ALL story fields before asking. If the answer is IN the story (description, AC, designs, discussion, wiki pages), do NOT ask. The story is the spec for this ticket.
2. **Sensible default exists** — If a reasonable developer would make the same assumption (e.g., "hide fields when unchecked", "clear data on toggle off"), state the assumption, don't ask.
3. **Resource already available** — If a Figma link exists in the story, Figma IS available. Don't ask "is Figma ready?" — check the detected links/resources.
4. **"TBD" is a team note** — If something says "TBD" or "to be delivered," that's project management, not a dev blocker. Skip it.
5. **PM concerns, not dev concerns** — Don't ask about branching strategy, release strategy, UAT sign-off, stakeholder confirmation, timelines, delivery dates, or team coordination.
6. **No vague questions** — Don't ask "Are there any blockers?", "Are all dependencies identified?", or "What is the expected timeline?"
7. **Only ask if blocking** — Only ask if a developer literally cannot write code without the answer. If the story is clear enough to start, return zero questions. That's a GOOD outcome.
8. **Contradictions are worth asking about** — If something is contradictory or genuinely ambiguous in the requirements, THAT is worth asking.
9. **DoR data is trusted** — If the DoR report confirms the BA provided component name, dialog fields, or scope, don't re-question it. Trust the BA's input.
10. **Single question tracker** — All questions for the BA go through `dor-report.md`. Don't create separate question artifacts.

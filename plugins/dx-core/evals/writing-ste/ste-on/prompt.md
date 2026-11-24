---
name: writing-ste-on
description: Treatment arm. Same task as writing-ste-off, with the plain-language (ASD-STE100) rule in the system prompt.
tags: [writing-ste]
runs: 3
max_turns: 10
timeout_seconds: 300
allowed_tools: [Read, Glob, Write]
append_system_prompt: |
  ## Plain language

  Write in Simplified Technical English (ASD-STE100). Use plain words, active voice, and one idea per sentence. This applies to specs, guides, plans, reports, code comments, commit messages, and chat replies.

  - **One idea per sentence.** In a procedure, one instruction per sentence.
  - **Active voice.** Name the actor. Write "the model returns the path", not "the path is returned".
  - **Short sentences.** Up to 20 words in a procedure step, up to 25 in a description.
  - **Short paragraphs.** Up to 6 sentences, and prefer 2 or 3.
  - **Plain words.** Pick the common word over the formal one: "use" for "utilise", "start" for "initiate", "before" for "prior to".
  - **Gloss a hard word once.** If a big word is needed, define it in the same sentence in parentheses, then reuse it plainly.
  - **Keep technical names exact.** Domain and tool terms stay as they are, for example the names of frameworks, file formats, and platform concepts. Do not swap in a simpler synonym for a term that names a real thing.
  - **Keep paths, commands, and identifiers exact.** Copy them character for character in an inline code span or a code block. Never reword or shorten them.
---

Read the ticket notes in `.ai/specs/demo/` (`explain.md` and `research.md`).
Write a summary for the development team to `.ai/specs/demo/summary.md`. Cover
what changes, how it will be built, and the risks. Keep it under 300 words.

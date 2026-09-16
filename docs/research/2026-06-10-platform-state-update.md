# Platform State Update — 2026-06-10

Two-week delta to [2026-05-29-platform-state-update.md](2026-05-29-platform-state-update.md).
Covers Claude Code **v2.1.156 → v2.1.170**, and the **Claude Fable 5 / Mythos-class**
model launch (2026-06-09).

> **Committed 2026-09-17, three months after it was written.** This file sat uncommitted
> in a working copy, which is why `docs/todo/TODO.md` #171 recorded the newest snapshot as
> `2026-05-29` and why `CLAUDE.md` still pointed two snapshots back. It is committed as the
> historical record of the v2.1.156 → v2.1.170 window. **Its proposals were never intaken
> and the numbers it reserves are no longer free** — see the note in §2 before acting on
> anything below. Content is unchanged from 2026-06-10 and has not been re-verified against
> the platform as it stands today; TODO #171 (the overdue September sweep) supersedes it.

**Scope discipline (unchanged):** this snapshot filters the changelog for things that
change *our four plugins* (Markdown skills/agents/hooks/manifests). UI/terminal/Windows/
voice/remote-control polish is acknowledged once and ignored.

**Verification note — the headline almost got mislabeled as fake news.** "Claude Fable 5,
a Mythos-class model" reads like a hallucinated changelog entry (it breaks the
Opus/Sonnet/Haiku naming we've used for two years). It is **real**: launched 2026-06-09,
confirmed by Anthropic's newsroom plus independent coverage (TechCrunch, NBC, CNBC, Yahoo
Finance, 9to5Mac). The official `code.claude.com` changelog corroborated every other item
below verbatim against the GitHub mirror — so the changelog data here is trustworthy. The
lesson cuts the way the user flagged: the *unusual-sounding* item was the one real thing,
and the disciplined move was to verify both directions rather than dismiss it.

---

## TL;DR — the five things that matter

1. **A new model *tier above Opus* now exists: Mythos-class, shipped publicly as
   `claude-fable-5` (2026-06-09; Claude Code v2.1.170).** $10/M in, $50/M out. This is the
   first capability tier above Opus 4.8 — but for *our plugins* it is **evaluate, not
   adopt (yet)**: the docs give an API name (`claude-fable-5`), **not** a confirmed Claude
   Code `model:` selector token, and say nothing about Bedrock/Vertex — which is where
   `dx-automation`'s Lambda runtime likely lives. Adopting it into tier tables today would
   be reasoning from a one-day-old headline. See §4.

2. **Stop / SubagentStop hooks can return `hookSpecificOutput.additionalContext`
   (v2.1.163)** — feed Claude guidance and *keep the turn going* without being flagged as
   a hook error. **Verified narrowing:** this does **not** improve our `stop-guard.sh`,
   whose job is to *block* (`decision:"block"` is the correct tool there). It's a real win
   only for **non-blocking nudges** — e.g. `next-step.sh` (SubagentStop) injecting "next
   pending step is X" instead of staying silent.

3. **`--safe-mode` / `CLAUDE_CODE_SAFE_MODE` (v2.1.169)** starts Claude Code with *all*
   customizations disabled (CLAUDE.md, plugins, skills, hooks, MCP). This is a genuine
   diagnostic primitive for `dx-doctor` and contributor docs: "is this our plugin or
   core?" in one flag. Doc-only, low effort, real value.

4. **`disableBundledSkills` setting + `claude plugin init` + `.claude/skills` auto-load
   (v2.1.157/169).** Plugins in `.claude/skills/` now load with no marketplace. This
   touches our skill-shadowing override system and `dx-eject` story (a team can drop an
   ejected skill into `.claude/skills/` and have it picked up). `disableBundledSkills` is a
   context-cost lever worth one line in the footprint audit (#113).

5. **`fallbackModel` setting — up to 3 fallbacks tried in order (v2.1.166).** Reliability
   for *interactive* dev sessions when the primary is overloaded. Not an automation win:
   `dx-automation` runs via the Agent SDK in Lambda, not the Claude Code CLI, so this
   setting doesn't reach it.

Everything else is bug-fixes-we-didn't-hit, UX polish, or already tracked.

---

## 1. Releases by tool (v2.1.156 → v2.1.170)

Grouped by our surface area. Version in parens. Verified against both the GitHub mirror
and the official `code.claude.com/docs/en/changelog`.

### Models
- **`claude-fable-5` (Mythos-class), v2.1.170 / 2026-06-09.** New tier above Opus.
  $10/M input · $50/M output ("less than half the price of Mythos Preview"). Safeguards
  route a minority of sessions (Anthropic: ">95% involve no fallback") to **Opus 4.8** —
  triggered on offensive-cyber, most bio/chem, and large-scale capability-distillation
  requests. `claude-mythos-5` is the same model with safeguards lifted, restricted to
  vetted cyberdefenders/infrastructure (Project Glasswing) — **irrelevant to us**.
- **`fallbackModel` setting (v2.1.166)** — up to three fallback models tried in order when
  primary is overloaded/unavailable; `--fallback-model` now also applies to interactive
  sessions.
- **`MAX_THINKING_TOKENS=0` + thinking toggles disable thinking on default-thinking models
  (v2.1.166).**
- **Auto mode on Bedrock/Vertex/Foundry for Opus 4.7 & 4.8 (v2.1.158)**, opt-in via
  `CLAUDE_CODE_ENABLE_AUTO_MODE=1`.

### Hooks
- **Stop & SubagentStop can return `hookSpecificOutput.additionalContext` (v2.1.163)** —
  give feedback and continue the turn without a hook-error label.
- **`post-session` lifecycle hook (v2.1.169, self-hosted runners)** — runs after the
  session ends, before the workspace is deleted (snapshot uncommitted work / export logs).
  Configurable SIGTERM→SIGKILL window (default 5s). Niche — only matters if we ship a
  self-hosted-runner story.
- **Fix: hooks with `Bash(...)` `if` conditions no longer fire on every command with
  substitutions (v2.1.161).** Directly relevant to our `branch-guard.sh` (`if:
  "Bash(git commit*)"`-style gates) — they were over-firing; now fixed. **No action, good
  news.** Also: deny rules on `$HOME` paths now enforced; glob `"*"` in deny tool names.

### Skills & slash commands
- **`disableBundledSkills` setting + `CLAUDE_CODE_DISABLE_BUNDLED_SKILLS` (v2.1.169)** —
  hide bundled skills/workflows/built-in slash commands from the model (context-cost lever).
- **Skills `\$` escape syntax for a literal `$` before digits (v2.1.163)** — relevant only
  if a SKILL.md body needs a literal `$1`/`$2` that today gets eaten by arg substitution.
- **`.claude/skills` plugins auto-load with no marketplace (v2.1.157)** +
  **`claude plugin init <name>` scaffolds there.** Intersects our `.claude/skills/<name>/`
  shadow-override convention and the `dx-eject` flow.

### Plugins
- **`/plugin list` with `--enabled`/`--disabled` filters (v2.1.163)**; autocomplete for
  `/plugin` args (v2.1.157).
- (Carryover, still un-adopted) `defaultEnabled: false` and plugin `dependencies` — already
  tracked from the 2026-05-29 snapshot.

### Subagents / agents
- **`--tools` listing Grep/Glob grants dedicated search tools (v2.1.162).**
- **`EnterWorktree` can switch between Claude-managed worktrees mid-session (v2.1.157).**
- `claude agents --json` adds `waitingFor` (v2.1.162); fixes for completed-subagent-stuck-
  as-running, background-subagent output corrupting `claude -p` stdout (v2.1.161).

### Troubleshooting / session
- **`--safe-mode` / `CLAUDE_CODE_SAFE_MODE` (v2.1.169)** — disable all customizations.
- **`/cd` to relocate a session without breaking the prompt cache (v2.1.169).**
- `requiredMinimumVersion`/`requiredMaximumVersion` managed settings (v2.1.163).

### Workflows
- No material change since 2026-05-29. Dynamic workflows remain a **strategic watch**, not
  a task (rationale unchanged — see prior snapshot §4 and TODO #45).

---

## 2. Gap-closure scorecard (delta from 2026-05-29)

### Still open from last snapshot (no platform change)
| TODO | Item | Status |
|------|------|--------|
| #113 | Concise-body audit | Open — `disableBundledSkills` adds a measurement angle, not a fix. |
| #45  | Parallel aem-verify + fe-verify (workflows pilot) | Open — still the one credible workflows pilot. |
| #104 | Forked-skill standalone UX | Open — `MessageDisplay` (v2.1.152) still the lever to evaluate. |
| —    | Declare plugin `dependencies` / `defaultEnabled:false` | Marked Done in prior snapshot; verify shipped. |

### Newly opened (this snapshot) — proposed TODOs #154–#159

> **These numbers are stale — do not use them.** Because this file was never committed, the
> proposals below were not intaken, and #154–#159 were later assigned to unrelated items:
> #154–156 to the universal ADO skill trigger series (2026-06-06) and #157–159 to the dev
> agency harness review, Microsoft CodeAct and the `Stop` → verification loop (2026-06-15).
> Renumbering the tracker is exactly what TODO #172 had to clean up once already, so nothing
> here was renumbered into it. Anything below that still has value should be re-checked
> against the current platform and filed fresh as part of the #171 September sweep — several
> items (`--safe-mode` docs, the hook-table refresh, `disableBundledSkills` as a #113
> measurement lever) are cheap and probably still stand. The Fable 5 tier evaluation is **not**
> answered by `CLAUDE.md` § Model Tier Strategy — Fable 5 appears there exactly once, in passing,
> as an example of a model whose default effort is pinned. The tier table is still
> Opus / Sonnet / Haiku, the instruction is still `model: opus | sonnet | haiku`, and all three
> gating unknowns from §3 Tier 2 are open: the Claude Code `model:` selector token, Bedrock/Vertex
> availability for the `dx-automation` Lambda runtime, and the verified price delta vs Opus 4.8.
| # | Item | Trigger | Proposed priority |
|---|------|---------|-------------------|
| 154 | **Evaluate `claude-fable-5` for the `xhigh` escalation tier** — verify CC `model:` token + Bedrock/Vertex availability + price vs Opus 4.8 *before* touching tier tables | v2.1.170 | **Medium — evaluate, gated on availability** |
| 155 | **Adopt Stop/SubagentStop `additionalContext` in `next-step.sh`** (non-blocking nudge) — explicitly NOT in `stop-guard.sh` | v2.1.163 | **Low–Medium** |
| 156 | **Document `--safe-mode` in `dx-doctor` + CLAUDE.md "Testing Changes"** ("is it our plugin or core?") | v2.1.169 | **Low (doc-only, real value)** |
| 157 | **Note `.claude/skills` auto-load + `claude plugin init` in the dx-eject / shadow-override docs** | v2.1.157/169 | **Low** |
| 158 | **Add `disableBundledSkills` as a measurement lever to the #113 footprint audit** | v2.1.169 | **Low** |
| 159 | **CLAUDE.md hook-table refresh** — add `additionalContext` return, `post-session` event, note the `Bash(...)` `if`-condition over-fire fix | v2.1.161/163/169 | **Low** |

---

## 3. Recommended actions

### Tier 1 — Real value, low risk (do these)

1. **Adopt `additionalContext` in `next-step.sh` only (#155).** Today `next-step.sh`
   (SubagentStop) is silent or blocks. The clean pattern is a *non-blocking* nudge:
   return `{"hookSpecificOutput":{"additionalContext":"Next pending step: <id>. Run
   /dx-step to continue."}}` and let the turn proceed. **Leave `stop-guard.sh` on
   `decision:"block"`** — verification confirmed its intent is to *halt*, which
   `additionalContext` does not do. This is a scoped, correct adoption, not a blanket
   migration.

2. **Document `--safe-mode` (#156).** Add to `dx-doctor`'s output and the CLAUDE.md
   "Testing Changes" section: `claude --safe-mode` to confirm whether a misbehavior is our
   plugin or core. Replaces the current "disable plugins one at a time" guesswork with a
   single flag. Pure docs.

3. **Refresh the CLAUDE.md hook reference (#159).** Add `additionalContext` to the Stop/
   SubagentStop return fields, add `post-session` to the events list (flag as
   self-hosted-runner-only), and append a one-liner that the v2.1.161 fix resolved the
   `Bash(...)` `if`-condition over-fire that affected `branch-guard.sh`. Keeps our hook
   tables authoritative.

### Tier 2 — Evaluate before committing

4. **Scope a `claude-fable-5` evaluation (#154) — do not edit tier tables yet.** Three
   facts must be nailed down first, because all three are currently *unknown*, not
   *favorable*:
   - **Claude Code selector.** Docs give the API name `claude-fable-5`; they do **not**
     confirm a CC `model:` frontmatter token. Until that exists, no skill/agent can target
     it.
   - **Bedrock/Vertex availability.** `dx-automation` runs in Lambda via the Agent SDK.
     If Fable is API-only, the automation tier *cannot* use it regardless of merit.
   - **Real price delta.** Fable is $10/$50. Confirm current Opus 4.8 pricing before
     claiming Fable is "cheaper *and* better" — that comparison is plausible but unverified
     here, and it's the entire basis for any tier change.
   If all three land favorably, the candidate use is **replacing `effort: xhigh` Opus on
   the two hardest-reasoning skills** (`dx-step-verify`, `dx-pr-review` escalation) — *not*
   a global default. Note the safeguard: Fable silently falls back to Opus 4.8 on
   offensive-cyber and bio/chem prompts, which could surprise a security-review skill
   (`dx-security`) — test that path explicitly before adopting there.

5. **`.claude/skills` auto-load in the eject story (#157).** Verify whether an ejected
   skill dropped into a consumer's `.claude/skills/<name>/` is now auto-loaded without a
   marketplace entry (v2.1.157). If so, it simplifies the `dx-eject` "own your files
   locally" pitch — one doc note, no code.

### Tier 3 — Measurement & watch

6. **Fold `disableBundledSkills` into #113 (#158).** When baselining footprint, measure
   with bundled skills on vs off to separate *our* token cost from Anthropic's bundled
   skills/workflows. One row in the audit, not a standalone task.

7. **Watch `fallbackModel`.** Real reliability lever for interactive dx work, but it's a
   user-level `settings.json` choice, not a plugin asset. Mention in `dx-init`'s optional
   settings guidance at most; do not ship as a default.

### Explicitly NOT recommended (marketing / non-actionable for us)

- **"Fable 5 exceeds any model we've ever made generally available."** True and genuinely
  significant industry news — but **not** a reason to rewrite our tier tables on day one.
  The Claude Code integration story (selector token, Bedrock) is undocumented; adopting now
  would be chasing the headline, exactly the failure mode flagged for this review. Revisit
  when #154's three unknowns resolve.
- **Claude Mythos 5 / Project Glasswing.** Cyberdefender + US-gov-only. Zero plugin surface.
- **`post-session` hook** beyond a one-line mention — we have no self-hosted-runner story;
  adopting it would be infrastructure we don't run.
- **Dynamic workflows** — unchanged since last snapshot; still a watch, not a task.
- **`/cd`, `/plugin list` filters, fallback-model UI, effort-label renames, worktree
  switching, all terminal/Windows/voice/remote-control fixes** — no Markdown-asset impact.

---

## 4. On Claude Fable 5 — separating signal from headline

The honest read for *this repo*:

- **What's real:** a model tier above Opus, public as `claude-fable-5`, priced $10/$50,
  with conservative auto-fallback to Opus 4.8 on a minority of sensitive prompts. If it's
  cheaper *and* stronger than Opus 4.8, it's a legitimate candidate for our `xhigh`
  escalation tier (deep verification, multi-file review).
- **Why it's "evaluate" not "adopt":** the two things that decide whether our plugins can
  use it at all are **undocumented today** — the Claude Code `model:` selector token, and
  Bedrock/Vertex availability (the `dx-automation` runtime). A tier-table edit before those
  resolve would be writing against a name we can't yet target.
- **The one caveat a security plugin must test:** Fable's silent fallback to Opus 4.8 on
  offensive-cyber and bio/chem prompts means `dx-security` could get *different* reasoning
  than it asked for, invisibly. If we ever route `dx-security` to Fable, that fallback path
  needs an explicit test, not an assumption.
- **Recommended posture:** open #154 as a *gated evaluation*. Re-baseline tiers only after
  the selector token and Bedrock availability are confirmed and the Opus-4.8 price delta is
  verified. Until then, Opus 4.8 `high`/`xhigh` remains our top tier.

---

## 5. Sources

- Claude Code: [CHANGELOG.md](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md) · [changelog docs](https://code.claude.com/docs/en/changelog) (cross-verified verbatim) · [skills docs](https://code.claude.com/docs/en/skills) · [hooks docs](https://code.claude.com/docs/en/hooks)
- Fable 5 / Mythos 5: [Anthropic newsroom](https://www.anthropic.com/news/claude-fable-5-mythos-5) · [TechCrunch](https://techcrunch.com/2026/06/09/anthropic-released-claude-fable-5-its-most-powerful-model-publicly-days-after-warning-ai-is-getting-too-dangerous/) · [NBC News](https://www.nbcnews.com/tech/security/fable-5-anthropic-release-public-mythos-claude-model-rcna349104) · [CNBC](https://www.cnbc.com/2026/06/09/anthropic-mythos-claude-fable-5.html)
- Skill best practices (no material shift, reconfirms #113 direction): [Skill authoring best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices) · [Equipping agents with Agent Skills](https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills)

## 6. Related docs

- [2026-05-29-platform-state-update.md](2026-05-29-platform-state-update.md) — prior snapshot (v2.1.126→156)
- [2026-05-15-google-skills-best-practices.md](2026-05-15-google-skills-best-practices.md) — skill-authoring conventions (still current; this snapshot adds no new authoring guidance — the official best-practices page reconfirms <500-line bodies, progressive disclosure, subagents-for-isolation)
- [`docs/todo/TODO.md`](../todo/TODO.md) — proposed #154–#159; existing #113, #45, #104

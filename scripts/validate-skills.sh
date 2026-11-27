#!/usr/bin/env bash
# validate-skills.sh — Verify skill naming consistency across all plugins
#
# Checks:
# 1. SKILL.md name: field matches directory name
# 2. Name format: lowercase, numbers, hyphens only, max 64 chars
# 3. No collisions across plugins (including automation)
# 4. No collisions with known Claude Code built-in commands
# 5. description: field exists, is non-empty, and is at most 1024 chars (platform cap)
# 6. SKILL.md body (frontmatter excluded) under 500 lines — WARN, ratcheted
# 7. No reasoning-echo instructions in skills (incl. references/) or agents — ERROR
# 8. Inline-chain context budget — WARN, ratcheted
# 9. model: opus in a skill or agent sets effort: explicitly — ERROR
# 10. No recursive rm whose target is a variable or substitution in skills/agents — ERROR
# 11. Skill-listing size (model-invocable descriptions) — ratcheted
# 12. A model-invocable description names a dmi skill only as a /command — ERROR
# 13. Frontmatter plain scalars parse under strict YAML (Copilot CLI) — ERROR
# 14. A context: fork skill carries the Isolation check paragraph (Copilot CLI) — ERROR

set -euo pipefail

# Overridable so the test suite can point the validator at a fixture tree.
REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
ERRORS=0
WARNINGS=0
TOTAL=0

# Known built-in Claude Code commands (avoid collisions)
BUILTINS="help doctor init compact debug clear config review commit status memory cost login logout permissions"

# Anthropic skill-authoring limits.
#   DESC_MAX  — hard platform validation rule. ERROR.
#   BODY_MAX  — authoring guidance, not a platform rule. WARN + ratchet:
#               error only when the number of oversized skills grows past the
#               recorded baseline, so #108/#113 stay planned work instead of
#               becoming a day-one merge blocker.
DESC_MAX=${DESC_MAX:-1024}
BODY_MAX=${BODY_MAX:-500}
# Measured 2026-09-19 across 77 skills. Lower this when a skill is trimmed.
BODY_OVER_BASELINE=${BODY_OVER_BASELINE:-13}
BODY_OVER=0

# A skill that invokes another skill with no `context: fork` loads that
# skill's whole body into its own context, and so on down the chain. Sum what
# lands in one context and warn over CHAIN_MAX_TOK (chars/4). Ratcheted like
# BODY_OVER: error only when more skills go over. TODO #241; fix is #240.
CHAIN_MAX_TOK=${CHAIN_MAX_TOK:-15000}
# Measured 2026-09-29: dx-agent-all ~29.6k, dx-bug-all ~22.9k, dx-pr-review-all ~16.5k.
CHAIN_OVER_BASELINE=${CHAIN_OVER_BASELINE:-3}
CHAIN_OVER=0

# Asking the model to reproduce its reasoning in the response can make Claude 5
# models refuse (`stop_reason: "refusal"`, category `reasoning_extraction`), and
# server-side fallback does not retry it — a failed pipeline run. Source:
# Anthropic prompting pages for Fable 5 / Opus 5.5 / Sonnet 5.5. TODO #239.
# Targets instructions to *output* reasoning; asking the model to think
# ("think step by step") is not extraction and is not matched.
REASONING_ECHO='(explain|show|print|write out|output|include|echo|transcribe|reproduce|narrate) (out )?your (internal )?(reasoning|thinking|thought process|chain[- ]of[- ]thought)|show your work|reasoning trace|your reasoning (in|into) (the|your) (response|answer|output|reply)'

# Opus 5.5 / Sonnet 5.5 / Haiku 5.5 default to effort `medium`; Opus 5 defaulted
# to `high` (code.claude.com/docs/en/model-config). A `model: opus` file with no
# `effort:` silently dropped a level when the alias moved. Opus is the tier we
# pay for depth, so it must say which effort it wants. TODO #222.

# Each check below is answered from one parse of every file (facts_awk) and two
# greps over all prompt files, not from a grep/awk/sed per check per file: each
# process costs tens of ms under endpoint security on macOS, and the validator
# used to start ~40 of them per skill. The patterns are the ones the per-file
# commands used; scripts/validate-skills.test.sh proves each check still fires.

# Copilot CLI ignores `context: fork`, so a fork skill must isolate itself: an
# "Isolation check" paragraph tells an inline run to delegate to one subagent
# (TODO-269). Verified on Copilot CLI 1.0.109 with dx-step-build.

# Since Claude Code v2.1.281 a recursive `rm` whose target comes from command
# substitution asks for permission even under bypassPermissions + an allow rule
# (v2.1.288: inside `bash -c` too); unanswered it waits 2 min, then denies. The
# dx-automation pipelines run in bypass mode with nobody to answer, so a skill
# that writes `rm -rf "$DIR"` or `rm -rf $(...)` stalls them. Skills and agents
# name literal paths instead. Helper scripts are exempt: the model runs them as
# `bash x.sh`, so the guard never sees their `rm`. TODO #223.
# Matches -rf/-fr/-r -f/--recursive, `--`, and a `$` anywhere in the target
# (`./"$X"`, `.ai/specs/$ID`). A backtick counts only at the start of the
# target, so markdown like `rm -rf state/<id>` is not a hit. Literal targets
# may come first (`rm -rf a "$X"`). `git rm` only unstages/deletes tracked files
# through git, which the guard does not prompt for.
RM_DYNAMIC='(^|[^[:alnum:]_.-])rm([[:space:]]+(-[a-zA-Z]+|--[a-z-]*))*[[:space:]]+(-[a-zA-Z]*[rR][a-zA-Z]*|--recursive)([[:space:]]+(-[a-zA-Z]+|--[a-z-]*))*[[:space:]]+(["'"'"']?`|([^;&|[:space:]`$]+[[:space:]]+)*[^;&|[:space:]`]*\$)'

# Claude Code reads frontmatter leniently; Copilot CLI uses a strict YAML parser
# and drops the whole skill with "mapping values are not allowed in this context"
# when an unquoted value holds `: ` (seen on dx-estimate's description in 3.4.2).
# A plain (unquoted) top-level value must not contain `: `, end in `:`, or start
# with a character YAML reserves — each is a parse error. ` #` parses, but starts
# a comment and silently cuts the value short. Quote the value instead.

# One record per file, each field ended by \036 (fields may hold newlines):
#   1 name         the first ^name: line, "name: *" removed
#   2 description  the full frontmatter value — the line's own text plus any
#                  indented continuation lines, block indicators dropped; a
#                  blank line inside the block is a paragraph break ("\n"), not
#                  the end of the value; the first non-indented line ends it
#   3 when_to_use  the same, for when_to_use:
#   4-7            1 when the frontmatter has model: opus / effort: <level> /
#                  context: fork / disable-model-invocation: true, else 0
#   8 chain fork   1 when a frontmatter line starts "context: fork", else empty
#   9 isolation    1 when a line starts with **Isolation check.**
#  10 body lines   lines after the closing --- (frontmatter excluded)
#  11 yaml lines   numbers of frontmatter lines holding a strict-YAML trap
#  12 invocations  skills it invokes (`Skill(/x)`, `Invoke /x`, "Invoke `/x`",
#                  "Invoke the `/x` skill"), one per line, in order, repeats kept
# The frontmatter is line 2 up to the next ---, when line 1 is ---. Awk skips an
# empty file: callers give it non-empty files only and default the rest.
facts_awk() {
  awk -v q="'" '
    function reset() {
      name = ""; gotname = 0; fm = 0; done = 0
      dout = ""; dc = 0; dgap = 0; dstop = 0
      wout = ""; wc = 0; wgap = 0; wstop = 0
      opus = 0; effort = 0; fork = 0; dmi = 0; cfork = ""; iso = 0
      body = 0; bstate = 0; yaml = ""; tg = ""
    }
    function emit() {
      printf "%s\036%s\036%s\036%d\036%d\036%d\036%d\036%s\036%d\036%d\036%s\036%s\036", \
        name, dout, wout, opus, effort, fork, dmi, cfork, iso, body, yaml, tg
    }
    FNR == 1 { if (NR > 1) emit(); reset() }
    {
      line = $0
      if (!gotname && line ~ /^name:/) { v = line; sub(/^name: */, "", v); name = v; gotname = 1 }
      if (line ~ /^\*\*Isolation check\.\*\*/) iso = 1
      s = line
      while (match(s, "(Skill\\([[:space:]]*/?|[Ii]nvoke (the )?`?/)[a-z][a-z0-9-]+")) {
        m = substr(s, RSTART, RLENGTH); s = substr(s, RSTART + RLENGTH)
        sub(".*[(`/ ]", "", m); tg = tg (tg == "" ? "" : "\n") m
      }
      if (FNR == 1) { if (line == "---") { bstate = 1; fm = 1 }; next }
      if (bstate == 1 && line == "---") bstate = 2
      else if (bstate == 2) body++
      if (fm != 1 || done) next
      if (line == "---") { done = 1; next }
      if (line ~ /^model:[[:space:]]*opus[[:space:]]*$/) opus = 1
      if (line ~ /^effort:[[:space:]]*[a-z]+/) effort = 1
      if (line ~ /^context:[[:space:]]*fork[[:space:]]*$/) fork = 1
      if (line ~ /^disable-model-invocation:[[:space:]]*(true|True|TRUE)/) dmi = 1
      if (cfork == "" && line ~ /^context:[ \t]*fork/) cfork = 1
      if (line ~ /^[A-Za-z_][A-Za-z0-9_-]*:[ \t]+[^ \t]/) {
        v = line; sub(/^[A-Za-z_][A-Za-z0-9_-]*:[ \t]+/, "", v); sub(/[ \t]+$/, "", v)
        if (!index("\"" q "[{|>&*!#", substr(v, 1, 1)))
          if (v ~ /: / || v ~ /:$/ || v ~ /[ \t]#/ || v ~ /^[@`%]/ || v ~ /^- /) yaml = yaml (yaml == "" ? "" : "\n") FNR
      }
      if (!dstop) {
        if (line ~ /^description:/) {
          v = line; sub(/^description:[ \t]*/, "", v)
          if (v ~ /^[|>][-+0-9]*$/) v = ""
          dout = v; dc = 1
        }
        else if (dc && line ~ /^[ \t]*$/) dgap = 1
        else if (dc && line ~ /^[ \t]/) { l = line; sub(/^[ \t]+/, "", l); dout = (dout == "" ? l : dout (dgap ? "\n" : " ") l); dgap = 0 }
        else if (dc) dstop = 1
      }
      if (!wstop) {
        if (line ~ /^when_to_use:/) {
          v = line; sub(/^when_to_use:[ \t]*/, "", v)
          if (v ~ /^[|>][-+0-9]*$/) v = ""
          wout = v; wc = 1
        }
        else if (wc && line ~ /^[ \t]*$/) wgap = 1
        else if (wc && line ~ /^[ \t]/) { l = line; sub(/^[ \t]+/, "", l); wout = (wout == "" ? l : wout (wgap ? "\n" : " ") l); wgap = 0 }
        else if (wc) wstop = 1
      }
    }
    END { if (NR > 0) emit() }
  ' "$@"
}

# Claude Code sends one skill listing per turn: `- <plugin>:<name>: <description
# - when_to_use>` per model-invocable skill, each capped at 1536 chars. Its budget
# is 1% of the context window at 4 chars/token (v2.1.301 bundle). Measured live
# with all four plugins: ~7k used on a 200k model, ~28k on the 5.5 models. Over
# budget, the least-used skills lose their description and route on name alone
# (on 5.5, 30 of our 73). So the total may shrink, never grow. `disable-model-invocation: true` drops a skill
# from the listing. TODO #238.
LISTING_ENTRY_CAP=1536
LISTING_BUDGET_200K=8000
# Measured 2026-10-17: 56 model-invocable skills (36,795 / 73 before #238). Lower it in the same PR that shrinks
# the listing; raise it only for a deliberate addition. 11,670 after /auto-eval was removed, +303 on 2026-10-17:
# trigger phrases the #238 trim dropped ('analyze ticket', 'validate plan', 'open PR', ...) and the scm.provider note.
# 11,740 on 2026-11-26: post-merge consolidation (5 skills out, 3 in — aem-demo-page, dx-qa-handoff, dx-post-merge).
LISTING_BASELINE=${LISTING_BASELINE:-11740}
LISTING_CHARS=0
LISTING_SKILLS=0
# Count characters, not bytes (descriptions carry em dashes): pick a UTF-8
# locale that exists here, proven on a two-byte character. Probed from the C
# locale in a subshell, so a name that does not exist leaves it at C (2 chars).
UTF8_LOCALE=""
for _loc in C.UTF-8 C.utf8 en_US.UTF-8 en_US.utf8; do
  if [ "$(LC_ALL=C; { LC_ALL=$_loc; } 2>/dev/null; x=é; echo ${#x})" = 1 ]; then UTF8_LOCALE=$_loc; break; fi
done
# listing_value <text> — the YAML scalar as Claude Code sees it: outer quotes off
listing_value() {
  local v="$1"
  case "$v" in
    \"*\") v="${v#\"}"; v="${v%\"}"; v="${v//\\\"/\"}" ;;
    \'*\') v="${v#\'}"; v="${v%\'}"; v="$(unescape_single "$v")" ;;
  esac
  printf '%s' "$v"
}
# unescape_single <text> — '' becomes ', left to right. Not ${v//\'\'/\'}: bash
# 3.2 (macOS /bin/bash) keeps the backslash in that replacement.
unescape_single() {
  local rest="$1" out=""
  while [[ "$rest" == *"''"* ]]; do out="$out${rest%%"''"*}'"; rest="${rest#*"''"}"; done
  printf '%s' "$out$rest"
}
strlen() {
  if [ -n "$UTF8_LOCALE" ]; then (LC_ALL=$UTF8_LOCALE; printf %s "${#1}"); else printf '%s' "${#1}"; fi
}
# bytes <file> — wc -c, read in the shell.
bytes() {
  local c=""
  IFS= read -r -d '' c < "$1" || true
  (LC_ALL=C; printf %s "${#c}")
}
# any_line_matches <text> <ERE> — grep -qE over the lines of text.
any_line_matches() {
  local line
  while IFS= read -r line || [ -n "$line" ]; do
    [[ "$line" =~ $2 ]] && return 0
  done <<EOF_TEXT
$1
EOF_TEXT
  return 1
}

# --- facts for every skill, agent and agent template: one awk run -----------
SKILL_DIRS=() FACT_FILES=()
for plugin_dir in "$REPO_ROOT"/plugins/*/skills/*/; do
  [ -d "$plugin_dir" ] || continue
  SKILL_DIRS+=("$plugin_dir")
  [ -f "$plugin_dir/SKILL.md" ] && FACT_FILES+=("${plugin_dir}SKILL.md")
done
NSKILLFILES=${#FACT_FILES[@]}
AGENT_FILES=()
for agent_file in "$REPO_ROOT"/plugins/*/agents/*.md; do
  [ -f "$agent_file" ] && AGENT_FILES+=("$agent_file") && FACT_FILES+=("$agent_file")
done
TEMPLATE_FILES=()
for tpl in "$REPO_ROOT"/plugins/*/templates/agents/*.agent.md.template; do
  [ -f "$tpl" ] && TEMPLATE_FILES+=("$tpl") && FACT_FILES+=("$tpl")
done

F_NAME=() F_DESC=() F_WTU=() F_OPUS=() F_EFFORT=() F_FORK=() F_DMI=() F_CFORK=() F_ISO=() F_BODY=() F_YAML=() F_TG=()
NONEMPTY=()
for f in ${FACT_FILES[@]+"${FACT_FILES[@]}"}; do [ -s "$f" ] && NONEMPTY+=("$f"); done
if [ "${#NONEMPTY[@]}" -gt 0 ]; then
  exec 3< <(facts_awk "${NONEMPTY[@]}")
fi
i=0
for f in ${FACT_FILES[@]+"${FACT_FILES[@]}"}; do
  a="" b="" c="" d="0" e="0" g="0" h="0" k="" l="0" m="0" y="" t=""
  if [ -s "$f" ]; then
    IFS= read -r -d $'\036' a <&3; IFS= read -r -d $'\036' b <&3; IFS= read -r -d $'\036' c <&3
    IFS= read -r -d $'\036' d <&3; IFS= read -r -d $'\036' e <&3; IFS= read -r -d $'\036' g <&3
    IFS= read -r -d $'\036' h <&3; IFS= read -r -d $'\036' k <&3; IFS= read -r -d $'\036' l <&3
    IFS= read -r -d $'\036' m <&3; IFS= read -r -d $'\036' y <&3; IFS= read -r -d $'\036' t <&3
  fi
  F_NAME[i]="$a" F_DESC[i]="$b" F_WTU[i]="$c" F_OPUS[i]="$d" F_EFFORT[i]="$e" F_FORK[i]="$g"
  F_DMI[i]="$h" F_CFORK[i]="$k" F_ISO[i]="$l" F_BODY[i]="$m" F_YAML[i]="$y" F_TG[i]="$t"
  i=$((i + 1))
done
[ "${#NONEMPTY[@]}" -gt 0 ] && exec 3<&-

# fact_index <file> — the index of a file in FACT_FILES ("" if absent).
fact_index() {
  local j=0 f
  for f in ${FACT_FILES[@]+"${FACT_FILES[@]}"}; do
    [ "$f" = "$1" ] && { printf '%s' "$j"; return 0; }
    j=$((j + 1))
  done
}

# --- the prompt files of every skill (SKILL.md and references/) and agent ----
# find | sort once for all skills; a skill's files keep the order a per-skill
# `find <dir> | sort` gives (same strings, same comparison).
SKILLS_WITH_FILE=()
for plugin_dir in ${SKILL_DIRS[@]+"${SKILL_DIRS[@]}"}; do
  [ -f "$plugin_dir/SKILL.md" ] && SKILLS_WITH_FILE+=("$plugin_dir")
done
SKILL_MDS=""
if [ "${#SKILLS_WITH_FILE[@]}" -gt 0 ]; then
  SKILL_MDS=$(find "${SKILLS_WITH_FILE[@]}" -name '*.md' -type f | sort)
fi
PROMPT_FILES=()
while IFS= read -r md; do [ -n "$md" ] && PROMPT_FILES+=("$md"); done <<< "$SKILL_MDS"
PROMPT_FILES+=(${AGENT_FILES[@]+"${AGENT_FILES[@]}"})
ECHO_HITS="" RM_HITS=""
if [ "${#PROMPT_FILES[@]}" -gt 0 ]; then
  ECHO_HITS=$(grep -HniE -- "$REASONING_ECHO" "${PROMPT_FILES[@]}" || true)
  RM_HITS=$(grep -HnE -- "$RM_DYNAMIC" "${PROMPT_FILES[@]}" || true)
fi

# hits_of <hits> <file> — that file's "N:text" lines of a grep -Hn output
hits_of() {
  local hit
  [ -n "$1" ] || return 0
  while IFS= read -r hit; do
    case "$hit" in "$2:"*) printf '%s\n' "${hit#"$2:"}" ;; esac
  done <<< "$1"
}

# check_reasoning_echo <file> <rel-path> — one ERROR per offending line
check_reasoning_echo() {
  local hits
  hits=$(hits_of "$ECHO_HITS" "$1")
  [ -z "$hits" ] && return 0
  while IFS= read -r hit; do
    echo "ERROR: $2:${hit%%:*} — reasoning-echo instruction (Claude 5 may refuse; see TODO #239)"
    ERRORS=$((ERRORS + 1))
  done <<< "$hits"
}

# check_rm_target <file> <rel-path> — one ERROR per offending line
check_rm_target() {
  local hits hit
  hits=$(hits_of "$RM_HITS" "$1")
  [ -z "$hits" ] && return 0
  while IFS= read -r hit; do
    [[ "$hit" =~ ^[0-9]+:.*git[[:space:]]+rm[[:space:]] ]] && continue
    echo "ERROR: $2:${hit%%:*} — recursive rm on a variable/substitution target; name a literal path (stalls bypass-mode pipelines; see TODO #223)"
    ERRORS=$((ERRORS + 1))
  done <<< "$hits"
}

# check_opus_effort <fact index> <rel-path>
check_opus_effort() {
  if [ "${F_OPUS[$1]}" = 1 ] && [ "${F_EFFORT[$1]}" != 1 ]; then
    echo "ERROR: $2 — model: opus without effort: (Opus 5.5 defaults to medium; set effort: high or another level explicitly, TODO #222)"
    ERRORS=$((ERRORS + 1))
  fi
}

# check_fork_isolation <fact index> <rel-path>
check_fork_isolation() {
  if [ "${F_FORK[$1]}" = 1 ] && [ "${F_ISO[$1]}" != 1 ]; then
    echo "ERROR: $2 — context: fork without an **Isolation check.** paragraph (Copilot CLI runs it inline; copy the paragraph from another fork skill, TODO-269)"
    ERRORS=$((ERRORS + 1))
  fi
}

# check_yaml_plain <fact index> <rel-path> — one ERROR per offending line
check_yaml_plain() {
  local ln
  [ -z "${F_YAML[$1]}" ] && return 0
  while IFS= read -r ln; do
    echo "ERROR: $2:$ln — unquoted frontmatter value is a strict-YAML parse error (Copilot CLI drops the file) or is cut at ' #'; wrap it in double quotes"
    ERRORS=$((ERRORS + 1))
  done <<< "${F_YAML[$1]}"
}

# Collision detection: "name<TAB>rel-path" per line
NAMES=""

echo "=== Skill Validation ==="
echo

k=-1
for plugin_dir in ${SKILL_DIRS[@]+"${SKILL_DIRS[@]}"}; do
  p="${plugin_dir%/}"
  skill_name="${p##*/}"
  skill_file="$plugin_dir/SKILL.md"
  p="${p%/*}"; p="${p%/*}"; plugin="${p##*/}"
  rel_path="plugins/$plugin/skills/$skill_name"
  TOTAL=$((TOTAL + 1))

  # Check SKILL.md exists
  if [ ! -f "$skill_file" ]; then
    echo "ERROR: $rel_path — missing SKILL.md"
    ERRORS=$((ERRORS + 1))
    continue
  fi
  k=$((k + 1))

  # Check name: frontmatter matches directory name. A file with no `name:` line
  # reports '' — it must not stop the scan.
  file_name="${F_NAME[$k]}"
  if [ "$file_name" != "$skill_name" ]; then
    echo "ERROR: $rel_path — name: '$file_name' does not match directory '$skill_name'"
    ERRORS=$((ERRORS + 1))
  fi

  # Check description: exists
  # Read the whole frontmatter value, not just the first line: a folded/block
  # scalar (`description: >-`) or a plain continued one carries its text on the
  # following indented lines, and `grep | head -1` measured none of it — an
  # 1,800-char wrapped description passed the cap check as 0 chars.
  file_desc="${F_DESC[$k]}"
  if [ -z "$file_desc" ]; then
    echo "ERROR: $rel_path — missing or empty description: field"
    ERRORS=$((ERRORS + 1))
  elif [ ${#file_desc} -gt "$DESC_MAX" ]; then
    echo "ERROR: $rel_path — description too long (${#file_desc} chars, max $DESC_MAX)"
    ERRORS=$((ERRORS + 1))
  fi

  check_opus_effort "$k" "$rel_path"
  check_fork_isolation "$k" "$rel_path"
  check_yaml_plain "$k" "$rel_path/SKILL.md"

  # Listing entry, exactly as Claude Code builds it (see LISTING_BASELINE)
  if [ "${F_DMI[$k]}" != 1 ]; then
    listing_text=$(listing_value "$file_desc")
    file_wtu="${F_WTU[$k]}"
    [ -n "$file_wtu" ] && listing_text="$listing_text - $(listing_value "$file_wtu")"
    listing_len=$(strlen "$listing_text")
    [ "$listing_len" -gt "$LISTING_ENTRY_CAP" ] && listing_len=$LISTING_ENTRY_CAP
    entry="- $plugin:$skill_name: "
    [ "$LISTING_SKILLS" -gt 0 ] && LISTING_CHARS=$((LISTING_CHARS + 1))
    LISTING_CHARS=$((LISTING_CHARS + ${#entry} + listing_len))
    LISTING_SKILLS=$((LISTING_SKILLS + 1))
  fi

  # Skill body and its references/ are both loaded into the model's context
  while IFS= read -r md; do
    case "$md" in "$plugin_dir"*) ;; *) continue ;; esac
    check_reasoning_echo "$md" "plugins/$plugin/skills/$skill_name/${md#"$plugin_dir"}"
    check_rm_target "$md" "plugins/$plugin/skills/$skill_name/${md#"$plugin_dir"}"
  done <<< "$SKILL_MDS"

  # Check body length (frontmatter excluded) against the authoring threshold
  body_lines="${F_BODY[$k]}"
  if [ "$body_lines" -gt "$BODY_MAX" ]; then
    echo "WARN: $rel_path — body is $body_lines lines (over $BODY_MAX; see TODO #108/#113)"
    WARNINGS=$((WARNINGS + 1))
    BODY_OVER=$((BODY_OVER + 1))
  fi

  # Check format: lowercase, numbers, hyphens only
  case "$skill_name" in
    [abcdefghijklmnopqrstuvwxyz]*) valid_format=1 ;;
    *) valid_format="" ;;
  esac
  case "$skill_name" in *[!abcdefghijklmnopqrstuvwxyz0123456789-]*) valid_format="" ;; esac
  if [ -z "$valid_format" ]; then
    echo "ERROR: $rel_path — invalid format (must be lowercase, numbers, hyphens, start with letter)"
    ERRORS=$((ERRORS + 1))
  fi

  # Check max length
  if [ ${#skill_name} -gt 64 ]; then
    echo "ERROR: $rel_path — name too long (${#skill_name} chars, max 64)"
    ERRORS=$((ERRORS + 1))
  fi

  # Check for cross-plugin collisions
  prev=""
  while IFS= read -r name_row; do
    case "$name_row" in "$skill_name"$'\t'*) prev="${name_row#*$'\t'}"; prev="${prev%%$'\t'*}"; break ;; esac
  done <<< "$NAMES"
  if [ -n "$prev" ]; then
    echo "ERROR: COLLISION — '$skill_name' in $rel_path AND $prev"
    ERRORS=$((ERRORS + 1))
  else
    NAMES="$NAMES$skill_name"$'\t'"$rel_path"$'\n'
  fi

  # Check for built-in command collisions
  for builtin in $BUILTINS; do
    if [ "$skill_name" = "$builtin" ]; then
      echo "ERROR: $rel_path — collides with built-in command '/$builtin'"
      ERRORS=$((ERRORS + 1))
    fi
  done
done

# Agents are prompts too
k=$NSKILLFILES
for agent_file in ${AGENT_FILES[@]+"${AGENT_FILES[@]}"}; do
  check_reasoning_echo "$agent_file" "${agent_file#"$REPO_ROOT"/}"
  check_rm_target "$agent_file" "${agent_file#"$REPO_ROOT"/}"
  check_opus_effort "$k" "${agent_file#"$REPO_ROOT"/}"
  check_yaml_plain "$k" "${agent_file#"$REPO_ROOT"/}"
  k=$((k + 1))
done

# Copilot agent templates are parsed by the same strict YAML
for tpl in ${TEMPLATE_FILES[@]+"${TEMPLATE_FILES[@]}"}; do
  check_yaml_plain "$k" "${tpl#"$REPO_ROOT"/}"
  k=$((k + 1))
done

# Inline chains. Invocation forms used in skills: `Skill(/x)`, `Invoke /x`,
# "Invoke `/x`", "Invoke the `/x` skill". Human hints ("Run /x manually") and
# external skills (superpowers:*) are not counted.
# One row per skill: name, ~tokens, forked(1/0), invoked skills. awk does the
# graph walk (portable — no bash-4 associative arrays; macOS ships bash 3.2).
# A skill's invoked skills are sorted and deduplicated (sort -u) in one sort run
# for all skills: "<row><TAB><skill>" lines, keyed on the row number.
CHAIN_FILES=() CHAIN_IDX=()
for skill_file in "$REPO_ROOT"/plugins/*/skills/*/SKILL.md; do
  CHAIN_FILES+=("$skill_file")
  CHAIN_IDX+=("$(fact_index "$skill_file")")
done
TG_LINES=""
r=0
for skill_file in ${CHAIN_FILES[@]+"${CHAIN_FILES[@]}"}; do
  j="${CHAIN_IDX[$r]}"
  if [ -n "$j" ] && [ -n "${F_TG[$j]}" ]; then
    while IFS= read -r t; do TG_LINES="$TG_LINES$r"$'\t'"$t"$'\n'; done <<< "${F_TG[$j]}"
  fi
  r=$((r + 1))
done
TG_SORTED=""
[ -n "$TG_LINES" ] && TG_SORTED=$(printf '%s' "$TG_LINES" | sort -t "$(printf '\t')" -k1,1n -k2,2 -u)
CHAIN_ROWS=""
r=0
for skill_file in ${CHAIN_FILES[@]+"${CHAIN_FILES[@]}"}; do
  n="${skill_file%/SKILL.md}"; n="${n##*/}"
  j="${CHAIN_IDX[$r]}"
  tok=$(( $(bytes "$skill_file") / 4 ))
  fork=""; [ -n "$j" ] && fork="${F_CFORK[$j]}"
  targets=""
  while IFS= read -r row; do
    case "$row" in "$r"$'\t'*) t="${row#*$'\t'}"; [ "$t" = "$n" ] || targets="$targets$t " ;; esac
  done <<< "$TG_SORTED"
  CHAIN_ROWS="$CHAIN_ROWS$n ${tok} ${fork:-0} $targets"$'\n'
  r=$((r + 1))
done

# Prints "name tokens inline-targets..." for each skill over the budget.
CHAIN_HITS=$(printf '%s' "$CHAIN_ROWS" | awk -v max="$CHAIN_MAX_TOK" '
  { tok[$1]=$2; fork[$1]=$3; tg[$1]=""; for (i=4; i<=NF; i++) tg[$1]=tg[$1] " " $i }
  function inl(n,   a, k, i, out) {
    k=split(tg[n], a, " "); out=""
    for (i=1; i<=k; i++) if ((a[i] in tok) && fork[a[i]]=="0") out=out " " a[i]
    return out
  }
  END {
    for (n in tok) {
      direct=inl(n); if (direct=="") continue
      split("", seen); sp=1; st[1]=n; total=0
      while (sp>0) {
        cur=st[sp]; sp--
        if (cur in seen) continue
        seen[cur]=1; total+=tok[cur]
        k=split(inl(cur), a, " "); for (i=1; i<=k; i++) st[++sp]=a[i]
      }
      if (total>max) print n, total, direct
    }
  }')

while read -r n tok inline; do
  [ -z "$n" ] && continue
  echo "WARN: $n — ~${tok} tok in one context via unforked skills: ${inline} (over $CHAIN_MAX_TOK; see TODO #240/#241)"
  WARNINGS=$((WARNINGS + 1))
  CHAIN_OVER=$((CHAIN_OVER + 1))
done <<< "$CHAIN_HITS"

if [ "$CHAIN_OVER" -gt "$CHAIN_OVER_BASELINE" ]; then
  echo
  echo "ERROR: $CHAIN_OVER skills over the $CHAIN_MAX_TOK-tok inline-chain budget, baseline is $CHAIN_OVER_BASELINE — fork the worker (context: fork) instead"
  ERRORS=$((ERRORS + 1))
elif [ "$CHAIN_OVER" -lt "$CHAIN_OVER_BASELINE" ]; then
  echo
  echo "NOTE: only $CHAIN_OVER skills over the inline-chain budget (baseline $CHAIN_OVER_BASELINE)"
  echo "      lower CHAIN_OVER_BASELINE in scripts/validate-skills.sh to lock the win in"
fi

# Ratchet: the count of oversized bodies may shrink, never grow
if [ "$BODY_OVER" -gt "$BODY_OVER_BASELINE" ]; then
  echo
  echo "ERROR: $BODY_OVER skills over $BODY_MAX body lines, baseline is $BODY_OVER_BASELINE — do not add more"
  ERRORS=$((ERRORS + 1))
elif [ "$BODY_OVER" -lt "$BODY_OVER_BASELINE" ]; then
  echo
  echo "NOTE: only $BODY_OVER skills over $BODY_MAX body lines (baseline $BODY_OVER_BASELINE)"
  echo "      lower BODY_OVER_BASELINE in scripts/validate-skills.sh to lock the win in"
fi

# --- 12. no routing to a skill the model cannot invoke -----------------------
# A description that says "Not for X (dx-foo)" invites the model to call
# dx-foo. If dx-foo has disable-model-invocation, the Skill tool refuses it
# and tells the model not to work around it — a dead end. Name such skills
# as the user's slash command ("/dx-foo") instead. TODO #238.
DMI_NAMES=""
r=0
for f in ${CHAIN_FILES[@]+"${CHAIN_FILES[@]}"}; do
  j="${CHAIN_IDX[$r]}"; r=$((r + 1))
  if [ -n "$j" ] && [ "${F_DMI[$j]}" = 1 ]; then n="${f%/SKILL.md}"; DMI_NAMES="$DMI_NAMES ${n##*/}"; fi
done
r=0
for f in ${CHAIN_FILES[@]+"${CHAIN_FILES[@]}"}; do
  j="${CHAIN_IDX[$r]}"; r=$((r + 1))
  d=" "
  if [ -n "$j" ]; then
    [ "${F_DMI[$j]}" = 1 ] && continue
    d="${F_DESC[$j]} ${F_WTU[$j]}"
  fi
  for n in $DMI_NAMES; do
    if any_line_matches "$d" "(^|[^/[:alnum:]_-])$n([^[:alnum:]_-]|\$)"; then
      echo "ERROR: ${f#"$REPO_ROOT"/} — description or when_to_use routes to $n, which has disable-model-invocation; write it as /$n (the user's command)"
      ERRORS=$((ERRORS + 1))
    fi
  done
done

# Ratchet: the skill listing may shrink, never grow
echo
echo "Skill listing: $LISTING_SKILLS model-invocable skills, $LISTING_CHARS chars (Claude Code budget: $LISTING_BUDGET_200K on a 200k context; baseline $LISTING_BASELINE)"
if [ "$LISTING_CHARS" -gt "$LISTING_BASELINE" ]; then
  echo "ERROR: skill listing grew to $LISTING_CHARS chars, baseline is $LISTING_BASELINE — shorten a description, or raise LISTING_BASELINE in this script if the growth is deliberate (say why in the commit). Use disable-model-invocation only for skills nothing chains to (TODO #238)"
  ERRORS=$((ERRORS + 1))
elif [ "$LISTING_CHARS" -lt "$LISTING_BASELINE" ]; then
  echo "NOTE: skill listing is below the baseline — lower LISTING_BASELINE in scripts/validate-skills.sh to $LISTING_CHARS to lock the win in"
  # Visible on the PR in CI: slack left here lets any description grow unnoticed.
  [ -n "${GITHUB_ACTIONS:-}" ] && echo "::warning file=scripts/validate-skills.sh::Skill listing is $LISTING_CHARS chars, below LISTING_BASELINE $LISTING_BASELINE — lower the baseline in this PR"
fi

# Summary
echo
echo "=== Summary ==="
echo "Skills scanned: $TOTAL"
echo "Errors: $ERRORS"
echo "Warnings: $WARNINGS"

if [ $ERRORS -gt 0 ]; then
  echo
  echo "FAIL — $ERRORS error(s) found"
  exit 1
else
  echo
  echo "PASS — all skills valid"
  exit 0
fi

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

# Asking the model to print its reasoning can make Claude 5 models refuse
# (`stop_reason: "refusal"`), and server-side fallback does not retry it — a
# failed pipeline run. Source: Anthropic prompting pages for Fable 5 /
# Opus 5.5 / Sonnet 5.5. TODO #239.
REASONING_ECHO='explain your reasoning|show your (thinking|reasoning|work)|think step[- ]by[- ]step|reasoning trace|chain[- ]of[- ]thought|print your reasoning'

# check_reasoning_echo <file> <rel-path> — one ERROR per offending line
check_reasoning_echo() {
  local hits
  hits=$(grep -niE "$REASONING_ECHO" "$1" || true)
  [ -z "$hits" ] && return 0
  while IFS= read -r hit; do
    echo "ERROR: $2:${hit%%:*} — reasoning-echo instruction (Claude 5 may refuse; see TODO #239)"
    ERRORS=$((ERRORS + 1))
  done <<< "$hits"
}

# Extracts the full `description:` value from frontmatter — the line's own text
# plus any indented continuation lines, block indicators dropped.
DESC_AWK='
  NR==1 && $0=="---" {fm=1; next}
  fm!=1 {next}
  $0=="---" {exit}
  /^description:/ {
    v=$0; sub(/^description:[ \t]*/, "", v)
    if (v ~ /^[|>][-+0-9]*$/) v=""
    out=v; c=1; next
  }
  c && /^[ \t]/ { l=$0; sub(/^[ \t]+/, "", l); out=(out=="" ? l : out " " l); next }
  c { exit }
  END { print out }
'

# Temp file for collision detection
NAMES_FILE=$(mktemp)
trap 'rm -f "$NAMES_FILE"' EXIT

echo "=== Skill Validation ==="
echo

for plugin_dir in "$REPO_ROOT"/plugins/*/skills/*/; do
  [ -d "$plugin_dir" ] || continue

  skill_name=$(basename "$plugin_dir")
  skill_file="$plugin_dir/SKILL.md"
  plugin=$(basename "$(dirname "$(dirname "$plugin_dir")")")
  rel_path="plugins/$plugin/skills/$skill_name"
  TOTAL=$((TOTAL + 1))

  # Check SKILL.md exists
  if [ ! -f "$skill_file" ]; then
    echo "ERROR: $rel_path — missing SKILL.md"
    ERRORS=$((ERRORS + 1))
    continue
  fi

  # Check name: frontmatter matches directory name
  # `|| true`: under `set -euo pipefail` a file with no `name:` line makes the
  # pipeline return 1 and kills the script mid-scan, silently — the check below
  # never runs and nothing is printed.
  file_name=$(grep "^name:" "$skill_file" | head -1 | sed 's/^name: *//') || true
  if [ "$file_name" != "$skill_name" ]; then
    echo "ERROR: $rel_path — name: '$file_name' does not match directory '$skill_name'"
    ERRORS=$((ERRORS + 1))
  fi

  # Check description: exists
  # Read the whole frontmatter value, not just the first line: a folded/block
  # scalar (`description: >-`) or a plain continued one carries its text on the
  # following indented lines, and `grep | head -1` measured none of it — an
  # 1,800-char wrapped description passed the cap check as 0 chars.
  file_desc=$(awk "$DESC_AWK" "$skill_file")
  if [ -z "$file_desc" ]; then
    echo "ERROR: $rel_path — missing or empty description: field"
    ERRORS=$((ERRORS + 1))
  elif [ ${#file_desc} -gt "$DESC_MAX" ]; then
    echo "ERROR: $rel_path — description too long (${#file_desc} chars, max $DESC_MAX)"
    ERRORS=$((ERRORS + 1))
  fi

  # Skill body and its references/ are both loaded into the model's context
  while IFS= read -r md; do
    check_reasoning_echo "$md" "plugins/$plugin/skills/$skill_name/${md#"$plugin_dir"}"
  done < <(find "$plugin_dir" -name '*.md' -type f | sort)

  # Check body length (frontmatter excluded) against the authoring threshold
  body_lines=$(awk 'NR==1 && $0=="---" {fm=1; next} fm==1 && $0=="---" {fm=2; next} fm==2 {n++} END {print n+0}' "$skill_file")
  if [ "$body_lines" -gt "$BODY_MAX" ]; then
    echo "WARN: $rel_path — body is $body_lines lines (over $BODY_MAX; see TODO #108/#113)"
    WARNINGS=$((WARNINGS + 1))
    BODY_OVER=$((BODY_OVER + 1))
  fi

  # Check format: lowercase, numbers, hyphens only
  if ! echo "$skill_name" | grep -qE '^[a-z][a-z0-9-]*$'; then
    echo "ERROR: $rel_path — invalid format (must be lowercase, numbers, hyphens, start with letter)"
    ERRORS=$((ERRORS + 1))
  fi

  # Check max length
  if [ ${#skill_name} -gt 64 ]; then
    echo "ERROR: $rel_path — name too long (${#skill_name} chars, max 64)"
    ERRORS=$((ERRORS + 1))
  fi

  # Check for cross-plugin collisions
  prev=$(grep "^${skill_name}	" "$NAMES_FILE" 2>/dev/null | head -1 | cut -f2) || true
  if [ -n "$prev" ]; then
    echo "ERROR: COLLISION — '$skill_name' in $rel_path AND $prev"
    ERRORS=$((ERRORS + 1))
  else
    printf '%s\t%s\n' "$skill_name" "$rel_path" >> "$NAMES_FILE"
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
for agent_file in "$REPO_ROOT"/plugins/*/agents/*.md; do
  [ -f "$agent_file" ] || continue
  check_reasoning_echo "$agent_file" "${agent_file#"$REPO_ROOT"/}"
done

# Inline chains. Invocation forms used in skills: `Skill(/x)`, `Invoke /x`,
# "Invoke `/x`", "Invoke the `/x` skill". Human hints ("Run /x manually") and
# external skills (superpowers:*) are not counted.
# One row per skill: name, ~tokens, forked(1/0), invoked skills. awk does the
# graph walk (portable — no bash-4 associative arrays; macOS ships bash 3.2).
CHAIN_TABLE=$(mktemp)
trap 'rm -f "$NAMES_FILE" "$CHAIN_TABLE"' EXIT
for skill_file in "$REPO_ROOT"/plugins/*/skills/*/SKILL.md; do
  n=$(basename "$(dirname "$skill_file")")
  tok=$(( $(wc -c < "$skill_file") / 4 ))
  fork=$(awk 'NR==1 && $0=="---" {fm=1; next} fm && $0=="---" {exit} fm && /^context:[ \t]*fork/ {print 1; exit}' "$skill_file")
  targets=$(grep -oE '(Skill\([[:space:]]*/?|[Ii]nvoke (the )?`?/)[a-z][a-z0-9-]+' "$skill_file" \
    | sed -E 's/.*[(`/ ]//' | sort -u | grep -vx "$n" | tr '\n' ' ' || true)
  echo "$n ${tok} ${fork:-0} $targets" >> "$CHAIN_TABLE"
done

# Prints "name tokens inline-targets..." for each skill over the budget.
CHAIN_HITS=$(awk -v max="$CHAIN_MAX_TOK" '
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
  }' "$CHAIN_TABLE")

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

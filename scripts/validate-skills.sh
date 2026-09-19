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

#!/usr/bin/env bash
# validate-skills.sh — Verify skill naming consistency across all plugins
#
# Checks:
# 1. SKILL.md name: field matches directory name
# 2. Name format: lowercase, numbers, hyphens only, max 64 chars
# 3. No collisions across plugins (including automation)
# 4. No collisions with known Claude Code built-in commands
# 5. description: field exists and is non-empty

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ERRORS=0
WARNINGS=0
TOTAL=0

# Known built-in Claude Code commands (avoid collisions)
BUILTINS="help doctor init compact debug clear config review commit status memory cost login logout permissions"

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
  file_name=$(grep "^name:" "$skill_file" | head -1 | sed 's/^name: *//')
  if [ "$file_name" != "$skill_name" ]; then
    echo "ERROR: $rel_path — name: '$file_name' does not match directory '$skill_name'"
    ERRORS=$((ERRORS + 1))
  fi

  # Check description: exists
  file_desc=$(grep "^description:" "$skill_file" | head -1 | sed 's/^description: *//')
  if [ -z "$file_desc" ]; then
    echo "ERROR: $rel_path — missing or empty description: field"
    ERRORS=$((ERRORS + 1))
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

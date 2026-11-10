#!/usr/bin/env bash
# validate-agents.sh — Verify agent definitions across all plugins
#
# Checks:
# 1. Required frontmatter: name, description, tools (or disallowedTools), model
# 2. Model is a valid tier (opus, sonnet, haiku)
# 3. No name collisions across plugins
# 4. No frontmatter that Claude Code ignores on plugin-shipped agents:
#    hooks, mcpServers, permissionMode ("for security reasons… not supported",
#    code.claude.com/docs/en/plugins-reference). The agent loads fine and the
#    field silently does nothing — e.g. `permissionMode: plan` never made a
#    reviewer read-only. Use tools/disallowedTools instead.

set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
ERRORS=0
TOTAL=0

NAMES_FILE=$(mktemp)
trap 'rm -f "$NAMES_FILE"' EXIT

echo "=== Agent Validation ==="
echo

for agent_file in "$REPO_ROOT"/plugins/*/agents/*.md; do
  [ -f "$agent_file" ] || continue

  plugin=$(basename "$(dirname "$(dirname "$agent_file")")")
  filename=$(basename "$agent_file")
  rel_path="plugins/$plugin/agents/$filename"
  TOTAL=$((TOTAL + 1))

  # Extract frontmatter fields (|| true to prevent set -e exit on no match)
  agent_name=$(grep "^name:" "$agent_file" | head -1 | sed 's/^name: *//' || true)
  agent_desc=$(grep "^description:" "$agent_file" | head -1 | sed 's/^description: *//' || true)
  agent_tools=$(grep "^tools:" "$agent_file" | head -1 | sed 's/^tools: *//' || true)
  agent_model=$(grep "^model:" "$agent_file" | head -1 | sed 's/^model: *//' || true)

  # Check required fields
  if [ -z "$agent_name" ]; then
    echo "ERROR: $rel_path — missing name: field"
    ERRORS=$((ERRORS + 1))
  fi

  if [ -z "$agent_desc" ]; then
    echo "ERROR: $rel_path — missing description: field"
    ERRORS=$((ERRORS + 1))
  fi

  agent_disallowed=$(grep "^disallowedTools:" "$agent_file" | head -1 | sed 's/^disallowedTools: *//' || true)
  if [ -z "$agent_tools" ] && [ -z "$agent_disallowed" ]; then
    echo "ERROR: $rel_path — missing tools: or disallowedTools: field"
    ERRORS=$((ERRORS + 1))
  fi

  # Fields Claude Code ignores on plugin agents (check 4). Frontmatter only.
  ignored=$(awk 'NR==1 && $0=="---" {fm=1; next} fm && $0=="---" {exit} fm' "$agent_file" \
    | grep -oE '^(hooks|mcpServers|permissionMode):' | tr -d ':' | tr '\n' ' ' || true)
  if [ -n "$ignored" ]; then
    echo "ERROR: $rel_path — ${ignored% }: ignored on plugin agents by Claude Code (use tools/disallowedTools)"
    ERRORS=$((ERRORS + 1))
  fi

  if [ -z "$agent_model" ]; then
    echo "ERROR: $rel_path — missing model: field"
    ERRORS=$((ERRORS + 1))
  elif ! echo "$agent_model" | grep -qE '^(opus|sonnet|haiku)$'; then
    echo "ERROR: $rel_path — invalid model: '$agent_model' (must be opus, sonnet, or haiku)"
    ERRORS=$((ERRORS + 1))
  fi

  # Check for cross-plugin collisions
  if [ -n "$agent_name" ]; then
    prev=$(grep "^${agent_name}	" "$NAMES_FILE" 2>/dev/null | head -1 | cut -f2) || true
    if [ -n "$prev" ]; then
      echo "ERROR: COLLISION — '$agent_name' in $rel_path AND $prev"
      ERRORS=$((ERRORS + 1))
    else
      printf '%s\t%s\n' "$agent_name" "$rel_path" >> "$NAMES_FILE"
    fi
  fi
done

echo
echo "=== Summary ==="
echo "Agents scanned: $TOTAL"
echo "Errors: $ERRORS"

if [ $ERRORS -gt 0 ]; then
  echo
  echo "FAIL — $ERRORS error(s) found"
  exit 1
else
  echo
  echo "PASS — all agents valid"
  exit 0
fi

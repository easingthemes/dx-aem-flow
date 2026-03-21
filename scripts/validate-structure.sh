#!/usr/bin/env bash
# validate-structure.sh — Verify plugin structure, versions, and cross-references
#
# Checks:
# 1. Version sync across all 4 JSON files
# 2. Plugin manifests don't have agents/skills fields (breaks Claude Code)
# 3. MCP tool prefixes use correct plugin-prefixed names
# 4. Skills referencing agents that exist
# 5. No hardcoded sensitive patterns
# 6. Shell scripts are executable

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ERRORS=0
WARNINGS=0

echo "=== Structure Validation ==="
echo

# --- Version sync ---
echo "Checking version sync..."
VERSIONS=$(grep '"version"' \
  "$REPO_ROOT/plugins/dx-core/.claude-plugin/plugin.json" \
  "$REPO_ROOT/plugins/dx-aem/.claude-plugin/plugin.json" \
  "$REPO_ROOT/plugins/dx-automation/.claude-plugin/plugin.json" \
  "$REPO_ROOT/.claude-plugin/marketplace.json" \
  | sed 's/.*"version": *"\([^"]*\)".*/\1/' | sort -u)

VERSION_COUNT=$(echo "$VERSIONS" | wc -l | tr -d ' ')
if [ "$VERSION_COUNT" -ne 1 ]; then
  echo "ERROR: Version mismatch across plugin files:"
  grep '"version"' \
    "$REPO_ROOT/plugins/dx-core/.claude-plugin/plugin.json" \
    "$REPO_ROOT/plugins/dx-aem/.claude-plugin/plugin.json" \
    "$REPO_ROOT/plugins/dx-automation/.claude-plugin/plugin.json" \
    "$REPO_ROOT/.claude-plugin/marketplace.json"
  ERRORS=$((ERRORS + 1))
else
  echo "  All versions: $VERSIONS"
fi

# --- Plugin manifest safety ---
echo
echo "Checking plugin manifests for forbidden fields..."
for pj in "$REPO_ROOT"/plugins/*/.claude-plugin/plugin.json; do
  plugin=$(basename "$(dirname "$(dirname "$pj")")")
  for field in '"agents"' '"skills"'; do
    if grep -q "$field" "$pj"; then
      echo "ERROR: plugins/$plugin/plugin.json — contains $field field (breaks Claude Code auto-discovery)"
      ERRORS=$((ERRORS + 1))
    fi
  done
done

# --- MCP tool prefix check ---
echo
echo "Checking MCP tool prefixes..."
# Wrong: mcp__figma__ (should be mcp__plugin_dx-core_figma__)
# Wrong: mcp__AEM__ (should be mcp__plugin_dx-aem_AEM__)
BAD_PREFIXES="mcp__figma__|mcp__axe-mcp-server__|mcp__AEM__|mcp__chrome-devtools-mcp__"
bad_files=$(grep -rl "$BAD_PREFIXES" "$REPO_ROOT/plugins/" 2>/dev/null || true)
if [ -n "$bad_files" ]; then
  echo "ERROR: Found unprefixed MCP tool names (should use mcp__plugin_<name>_ prefix):"
  echo "$bad_files" | sed "s|$REPO_ROOT/||"
  ERRORS=$((ERRORS + 1))
else
  echo "  All MCP tool prefixes correct"
fi

# --- Agent references in skills ---
echo
echo "Checking skill agent references..."
for skill_file in "$REPO_ROOT"/plugins/*/skills/*/SKILL.md; do
  agent_ref=$(grep "^agent:" "$skill_file" 2>/dev/null | head -1 | sed 's/^agent: *//' || true)
  if [ -n "$agent_ref" ]; then
    found=0
    for agent_file in "$REPO_ROOT"/plugins/*/agents/*.md; do
      agent_name=$(grep "^name:" "$agent_file" 2>/dev/null | head -1 | sed 's/^name: *//' || true)
      if [ "$agent_name" = "$agent_ref" ]; then
        found=1
        break
      fi
    done
    if [ $found -eq 0 ]; then
      plugin=$(basename "$(dirname "$(dirname "$skill_file")")")
      skill=$(basename "$(dirname "$skill_file")")
      echo "ERROR: plugins/$plugin/skills/$skill — references agent '$agent_ref' which does not exist"
      ERRORS=$((ERRORS + 1))
    fi
  fi
done

# --- Shell script permissions ---
echo
echo "Checking shell script permissions..."
for sh_file in $(find "$REPO_ROOT/plugins" "$REPO_ROOT/scripts" -name "*.sh" 2>/dev/null); do
  if [ ! -x "$sh_file" ]; then
    rel=$(echo "$sh_file" | sed "s|$REPO_ROOT/||")
    echo "ERROR: $rel — not executable (run chmod +x)"
    ERRORS=$((ERRORS + 1))
  fi
done

# --- Hardcoded sensitive patterns ---
echo
echo "Checking for hardcoded sensitive values..."
SENSITIVE_PATTERNS='sk-ant-api|xai-[A-Za-z0-9]{20}|AKIA[A-Z0-9]{16}'
sensitive_hits=$(grep -rlE "$SENSITIVE_PATTERNS" "$REPO_ROOT/plugins/" "$REPO_ROOT/website/src/" 2>/dev/null || true)
if [ -n "$sensitive_hits" ]; then
  echo "ERROR: Found potentially hardcoded sensitive values:"
  echo "$sensitive_hits" | sed "s|$REPO_ROOT/||"
  ERRORS=$((ERRORS + 1))
else
  echo "  No sensitive patterns found"
fi

# --- Summary ---
echo
echo "=== Summary ==="
echo "Errors: $ERRORS"
echo "Warnings: $WARNINGS"

if [ $ERRORS -gt 0 ]; then
  echo
  echo "FAIL — $ERRORS error(s) found"
  exit 1
else
  echo
  echo "PASS — all structure checks valid"
  exit 0
fi

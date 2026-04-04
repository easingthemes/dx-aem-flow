#!/usr/bin/env bash
# validate-stats.sh — Verify website/src/config/stats.ts matches actual plugin counts
#
# Counts skill directories and agent files per plugin, then compares
# against the centralized stats in website/src/config/stats.ts.
# Fails if any number is out of sync.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STATS_FILE="$REPO_ROOT/website/src/config/stats.ts"
ERRORS=0

echo "=== Stats Validation ==="
echo

if [ ! -f "$STATS_FILE" ]; then
  echo "ERROR: $STATS_FILE not found"
  exit 1
fi

# Helper: extract a numeric value from stats.ts by key name
get_stat() {
  local key="$1"
  grep "${key}:" "$STATS_FILE" | head -1 | sed 's/.*: *//' | tr -d ',' | tr -d ' '
}

# Helper: count directories matching a glob
count_dirs() {
  local pattern="$1"
  local count=0
  for d in $pattern; do
    [ -d "$d" ] && count=$((count + 1))
  done
  echo "$count"
}

# Helper: count files matching a glob
count_files() {
  local pattern="$1"
  local count=0
  for f in $pattern; do
    [ -f "$f" ] && count=$((count + 1))
  done
  echo "$count"
}

# Helper: compare expected vs actual
check() {
  local label="$1"
  local stat_key="$2"
  local actual="$3"
  local expected
  expected=$(get_stat "$stat_key")

  if [ "$actual" != "$expected" ]; then
    echo "ERROR: $label — stats.ts says $stat_key: $expected, actual: $actual"
    ERRORS=$((ERRORS + 1))
  else
    echo "  OK: $label — $actual"
  fi
}

# --- Count actual skills per plugin ---
dx_core_skills=$(count_dirs "$REPO_ROOT/plugins/dx-core/skills/*/")
dx_aem_skills=$(count_dirs "$REPO_ROOT/plugins/dx-aem/skills/*/")
dx_hub_skills=$(count_dirs "$REPO_ROOT/plugins/dx-hub/skills/*/")
dx_auto_skills=$(count_dirs "$REPO_ROOT/plugins/dx-automation/skills/*/")
total_skills=$((dx_core_skills + dx_aem_skills + dx_hub_skills + dx_auto_skills))

# --- Count actual agents per plugin ---
dx_core_agents=$(count_files "$REPO_ROOT/plugins/dx-core/agents/*.md")
dx_aem_agents=$(count_files "$REPO_ROOT/plugins/dx-aem/agents/*.md")
claude_agents=$((dx_core_agents + dx_aem_agents))

# --- Count Copilot agent templates ---
copilot_dx_core=$(count_files "$REPO_ROOT/plugins/dx-core/templates/agents/*.md*")
copilot_dx_aem=$(count_files "$REPO_ROOT/plugins/dx-aem/templates/agents/*.md*")
copilot_agents=$((copilot_dx_core + copilot_dx_aem))

# --- Compare against stats.ts ---
echo "Skills:"
check "dx-core skills"      "dxCoreSkills"       "$dx_core_skills"
check "dx-aem skills"       "dxAemSkills"        "$dx_aem_skills"
check "dx-hub skills"       "dxHubSkills"        "$dx_hub_skills"
check "dx-automation skills" "dxAutomationSkills" "$dx_auto_skills"
check "total skills"        "totalSkills"        "$total_skills"

echo
echo "Agents:"
check "dx-core agents"          "dxCoreAgents"        "$dx_core_agents"
check "dx-aem agents"           "dxAemAgents"         "$dx_aem_agents"
check "claude agents (total)"   "claudeAgents"        "$claude_agents"
check "copilot dx-core agents"  "copilotDxCoreAgents" "$copilot_dx_core"
check "copilot dx-aem agents"   "copilotDxAemAgents"  "$copilot_dx_aem"
check "copilot agents (total)"  "copilotAgents"       "$copilot_agents"

# --- Summary ---
echo
echo "=== Summary ==="
echo "Errors: $ERRORS"

if [ $ERRORS -gt 0 ]; then
  echo
  echo "FAIL — stats.ts is out of sync. Update website/src/config/stats.ts to match actual counts."
  exit 1
else
  echo
  echo "PASS — stats.ts matches all plugin counts"
  exit 0
fi

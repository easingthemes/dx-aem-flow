#!/usr/bin/env bash
# install-copilot-agents.sh — Batch-copy Copilot agent templates with transforms
#
# Usage: install-copilot-agents.sh [--force] [PLUGIN_DIR ...]
# Output: One line per action to stdout
#
# Copies templates/agents/*.agent.md.template → .github/agents/*.agent.md
# Post-copy transforms:
#   - Fixes tool aliases (editFiles → edit)
#   - Fixes MCP server prefixes (chrome-devtools/ → chrome-devtools-mcp/)
#   - Injects allowed-tools into YAML frontmatter if not present
#
# Flags:
#   --force    Overwrite existing files (used by dx-upgrade for stale fixes)

set -euo pipefail

# --- Post-copy transforms ---
copilot_agent_transform() {
  local file="$1"

  # NOTE: editFiles is the VS Code Chat tool name, edit is the Copilot CLI name.
  # Templates now include BOTH for cross-platform compatibility. No transform needed.

  # Fix MCP prefix: chrome-devtools/ → chrome-devtools-mcp/ (matches .mcp.json server name)
  if grep -q "'chrome-devtools/" "$file" 2>/dev/null; then
    sed -i '' "s|'chrome-devtools/|'chrome-devtools-mcp/|g" "$file"
  fi

  # Inject allowed-tools into YAML frontmatter if not present
  # Inserts before the closing --- (second occurrence) using awk
  if ! grep -q 'allowed-tools:' "$file" 2>/dev/null; then
    awk '/^---$/{c++; if(c==2){print "allowed-tools: [\"read\", \"edit\", \"execute\", \"search\", \"write\", \"agent\"]"}}1' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
  fi
}

# --- Parse flags ---
FORCE=false
PLUGIN_DIRS=()
for arg in "$@"; do
  case "$arg" in
    --force) FORCE=true ;;
    *) PLUGIN_DIRS+=("$arg") ;;
  esac
done

# Resolve plugin directory — from argument or script location
if [ ${#PLUGIN_DIRS[@]} -eq 0 ]; then
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  PLUGIN_DIRS=("$(cd "$SCRIPT_DIR/../../.." && pwd)")
fi

# --- Create target directory ---
mkdir -p .github/agents

# --- Copy agent templates from each plugin ---
installed=0
updated=0
skipped=0

for PLUGIN_DIR in "${PLUGIN_DIRS[@]}"; do
  # Verify templates/agents/ exists
  if [ ! -d "$PLUGIN_DIR/templates/agents" ]; then
    echo "no agent templates found in $PLUGIN_DIR/templates/agents/"
    continue
  fi

  for f in "$PLUGIN_DIR"/templates/agents/*.agent.md.template; do
    [ -f "$f" ] || continue
    # Strip .template suffix: DxCodeReview.agent.md.template → DxCodeReview.agent.md
    target=".github/agents/$(basename "$f" .template)"
    if [ ! -f "$target" ]; then
      cp "$f" "$target"
      copilot_agent_transform "$target"
      echo "installed $target"
      installed=$((installed + 1))
    elif [ "$FORCE" = true ]; then
      cp "$f" "$target"
      copilot_agent_transform "$target"
      echo "updated $target"
      updated=$((updated + 1))
    else
      echo "skipped $target (already exists)"
      skipped=$((skipped + 1))
    fi
  done
done

echo "---"
echo "total: $installed installed, ${updated:-0} updated, $skipped skipped"

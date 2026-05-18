#!/usr/bin/env bash
# Swap a probe skill's `allowed-tools:` value to a named variant.
# Backs up originals to <SKILL.md>.bak (only on first swap).
# Usage:
#   ./swap.sh list                       # show probes and variants
#   ./swap.sh <probe> <variant>          # apply variant
#   ./swap.sh restore                    # restore all originals from .bak
#   ./swap.sh status                     # show current allowed-tools per probe
#
# Variants:
#   baseline          — original (restores from .bak; same as `restore` for that probe)
#   pascal            — Claude Code shape (PascalCase + mcp__server__* / mcp__plugin_<plugin>_<server>__*)
#   lowercase-slash   — Copilot tip-#29 shape (lowercase + server/tool slash MCP wildcard)
#   lowercase-paren   — Copilot doc-research shape (lowercase + server(*) parentheses MCP wildcard)
#
# This script is intentionally chatty so the user knows exactly what changed.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$REPO_ROOT"

# probe -> SKILL.md path
declare -A PROBE_PATHS=(
  [dx-help]="plugins/dx-core/skills/dx-help/SKILL.md"
  [dx-pr-review]="plugins/dx-core/skills/dx-pr-review/SKILL.md"
  [aem-init]="plugins/dx-aem/skills/aem-init/SKILL.md"
  [auto-status]="plugins/dx-automation/skills/auto-status/SKILL.md"
)

# probe -> variant -> allowed-tools VALUE (everything after `allowed-tools: `)
# Each probe defines what tools+MCPs make sense for IT (auto-status uses bash+aws, no MCP).
declare -A VARIANTS=(
  # dx-help — uses ado MCP (project-level)
  [dx-help::pascal]='["Read", "Edit", "Write", "Grep", "Glob", "Bash", "Agent", "mcp__ado__*"]'
  [dx-help::lowercase-slash]='["read", "edit", "write", "grep", "glob", "bash", "agent", "ado/*"]'
  [dx-help::lowercase-paren]='["read", "edit", "write", "grep", "glob", "bash", "agent", "ado(*)"]'

  # dx-pr-review — uses ado MCP (project-level), opus/high
  [dx-pr-review::pascal]='["Read", "Edit", "Write", "Grep", "Glob", "Bash", "Agent", "mcp__ado__*"]'
  [dx-pr-review::lowercase-slash]='["read", "edit", "write", "grep", "glob", "bash", "agent", "ado/*"]'
  [dx-pr-review::lowercase-paren]='["read", "edit", "write", "grep", "glob", "bash", "agent", "ado(*)"]'

  # aem-init — uses AEM MCP (plugin-scoped) + chrome-devtools (plugin-scoped)
  [aem-init::pascal]='["Read", "Edit", "Write", "Grep", "Glob", "Bash", "Agent", "mcp__plugin_dx-aem_AEM__*", "mcp__plugin_dx-aem_chrome-devtools-mcp__*"]'
  [aem-init::lowercase-slash]='["read", "edit", "write", "grep", "glob", "bash", "agent", "AEM/*", "chrome-devtools-mcp/*"]'
  [aem-init::lowercase-paren]='["read", "edit", "write", "grep", "glob", "bash", "agent", "AEM(*)", "chrome-devtools-mcp(*)"]'

  # auto-status — bash-heavy (aws CLI), no MCP. Tests bash+read pre-approval only.
  [auto-status::pascal]='["Read", "Grep", "Glob", "Bash"]'
  [auto-status::lowercase-slash]='["read", "grep", "glob", "bash"]'
  [auto-status::lowercase-paren]='["read", "grep", "glob", "bash"]'
)

cmd_list() {
  echo "Probes:"
  for p in "${!PROBE_PATHS[@]}"; do
    echo "  $p -> ${PROBE_PATHS[$p]}"
  done | sort
  echo ""
  echo "Variants: baseline | pascal | lowercase-slash | lowercase-paren"
}

cmd_status() {
  for p in "${!PROBE_PATHS[@]}"; do
    local f="${PROBE_PATHS[$p]}"
    local cur
    cur="$(grep -E '^allowed-tools:' "$f" || echo '(none)')"
    local bak="(no .bak)"
    [[ -f "$f.bak" ]] && bak="(.bak present)"
    printf '%-15s %s %s\n' "$p" "$bak" "$cur"
  done | sort
}

cmd_restore() {
  local restored=0
  for p in "${!PROBE_PATHS[@]}"; do
    local f="${PROBE_PATHS[$p]}"
    if [[ -f "$f.bak" ]]; then
      mv "$f.bak" "$f"
      echo "restored: $f"
      restored=1
    fi
  done
  if [[ $restored -eq 0 ]]; then
    echo "no .bak files found — nothing to restore"
  fi
}

apply_variant() {
  local probe="$1" variant="$2"
  local file="${PROBE_PATHS[$probe]:-}"
  [[ -z "$file" ]] && { echo "unknown probe: $probe"; exit 1; }
  [[ ! -f "$file" ]] && { echo "file not found: $file"; exit 1; }

  if [[ "$variant" == "baseline" ]]; then
    if [[ -f "$file.bak" ]]; then
      mv "$file.bak" "$file"
      echo "restored baseline: $file"
    else
      echo "$probe is already at baseline (no .bak file)"
    fi
    return
  fi

  local key="${probe}::${variant}"
  local value="${VARIANTS[$key]:-}"
  [[ -z "$value" ]] && { echo "unknown variant '$variant' for probe '$probe'"; exit 1; }

  # Backup once
  if [[ ! -f "$file.bak" ]]; then
    cp "$file" "$file.bak"
    echo "backup created: $file.bak"
  fi

  # If allowed-tools line exists, replace it; else insert before the closing --- of frontmatter.
  if grep -q '^allowed-tools:' "$file"; then
    # Use awk to replace exactly the allowed-tools line (avoids sed escaping pain with brackets/quotes).
    awk -v val="allowed-tools: $value" '
      BEGIN { replaced = 0 }
      /^allowed-tools:/ && !replaced { print val; replaced = 1; next }
      { print }
    ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
  else
    # Insert before the second --- (end of frontmatter)
    awk -v val="allowed-tools: $value" '
      BEGIN { dashes = 0; inserted = 0 }
      /^---$/ {
        dashes++
        if (dashes == 2 && !inserted) { print val; inserted = 1 }
      }
      { print }
    ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
  fi

  echo "$probe -> $variant"
  grep -E '^allowed-tools:' "$file" || echo "(no allowed-tools line — insertion may have failed)"
}

case "${1:-}" in
  list|"")        cmd_list ;;
  status)         cmd_status ;;
  restore)        cmd_restore ;;
  *)
    [[ $# -lt 2 ]] && { echo "usage: $0 <probe> <variant>"; exit 1; }
    apply_variant "$1" "$2"
    ;;
esac

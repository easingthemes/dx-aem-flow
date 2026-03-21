#!/usr/bin/env bash
# eject.sh — Copy all plugin assets into the consumer project
#
# Usage: eject.sh <dx-plugin-dir> [aem-plugin-dir] [auto-plugin-dir]
# Output: One line per action to stdout, summary at end
#
# Copies skills, agents, rules, shared files, data, templates, hooks,
# and MCP config from plugin directories into the consumer project so
# it can operate without plugins installed.
#
# Claude Code assets → .claude/skills/, .claude/agents/ (local overrides)
# Copilot assets → .github/agents/
# Shared/data → .ai/lib/, .ai/templates/, .ai/shared/
# Rules → .ai/rules/, .claude/rules/
# Hooks → .claude/hooks/
# MCP → .mcp.json (merged)

set -euo pipefail

DX_DIR=""
AEM_DIR=""
AUTO_DIR=""

for arg in "$@"; do
  if [ -z "$DX_DIR" ]; then
    DX_DIR="$arg"
  elif [ -z "$AEM_DIR" ]; then
    AEM_DIR="$arg"
  else
    AUTO_DIR="$arg"
  fi
done

if [ -z "$DX_DIR" ]; then
  echo "error: dx plugin directory required as first argument"
  exit 1
fi

INSTALLED=0
SKIPPED=0
UPDATED=0

copy_file() {
  local src="$1" dst="$2" label="$3" make_exec="${4:-false}"
  local dst_dir
  dst_dir="$(dirname "$dst")"
  mkdir -p "$dst_dir"
  if [ ! -f "$dst" ]; then
    cp "$src" "$dst"
    [ "$make_exec" = "true" ] && chmod +x "$dst"
    echo "installed $label"
    INSTALLED=$((INSTALLED + 1))
  else
    # File exists — overwrite (eject is a one-time destructive copy)
    cp "$src" "$dst"
    [ "$make_exec" = "true" ] && chmod +x "$dst"
    echo "updated  $label"
    UPDATED=$((UPDATED + 1))
  fi
}

strip_template_ext() {
  # Remove .template suffix from filename
  echo "${1%.template}"
}

# =========================================================
# 1. Claude Code Skills — plugin skills/ → .claude/skills/
# =========================================================
echo ""
echo "=== Claude Code Skills ==="

for plugin_dir in "$DX_DIR" "$AEM_DIR" "$AUTO_DIR"; do
  [ -z "$plugin_dir" ] && continue
  [ ! -d "$plugin_dir/skills" ] && continue
  plugin_name="$(basename "$plugin_dir")"

  for skill_md in "$plugin_dir"/skills/*/SKILL.md; do
    [ -f "$skill_md" ] || continue
    skill_name="$(basename "$(dirname "$skill_md")")"
    copy_file "$skill_md" ".claude/skills/$skill_name/SKILL.md" ".claude/skills/$skill_name/SKILL.md (from $plugin_name)"

    # Copy any helper scripts inside the skill directory
    if [ -d "$(dirname "$skill_md")/scripts" ]; then
      for script in "$(dirname "$skill_md")"/scripts/*; do
        [ -f "$script" ] || continue
        script_name="$(basename "$script")"
        copy_file "$script" ".claude/skills/$skill_name/scripts/$script_name" \
          ".claude/skills/$skill_name/scripts/$script_name" "true"
      done
    fi
  done
done

# =========================================================
# 2. Claude Code Agents — plugin agents/ → .claude/agents/
# =========================================================
echo ""
echo "=== Claude Code Agents ==="

for plugin_dir in "$DX_DIR" "$AEM_DIR" "$AUTO_DIR"; do
  [ -z "$plugin_dir" ] && continue
  [ ! -d "$plugin_dir/agents" ] && continue
  plugin_name="$(basename "$plugin_dir")"

  for agent_md in "$plugin_dir"/agents/*.md; do
    [ -f "$agent_md" ] || continue
    agent_name="$(basename "$agent_md")"
    copy_file "$agent_md" ".claude/agents/$agent_name" ".claude/agents/$agent_name (from $plugin_name)"
  done
done

# =========================================================
# 3. Plugin Rules — plugin rules/ → .ai/ejected/rules/
#    (these are plugin defaults; .ai/rules/ has project overrides)
# =========================================================
echo ""
echo "=== Plugin Default Rules ==="

for plugin_dir in "$DX_DIR" "$AEM_DIR" "$AUTO_DIR"; do
  [ -z "$plugin_dir" ] && continue
  [ ! -d "$plugin_dir/rules" ] && continue
  plugin_name="$(basename "$plugin_dir")"

  for rule_md in "$plugin_dir"/rules/*.md; do
    [ -f "$rule_md" ] || continue
    rule_name="$(basename "$rule_md")"
    copy_file "$rule_md" ".ai/ejected/plugin-rules/$rule_name" \
      ".ai/ejected/plugin-rules/$rule_name (from $plugin_name)"
  done
done

# =========================================================
# 4. Shared Reference Files — plugin shared/ → .ai/ejected/shared/
# =========================================================
echo ""
echo "=== Shared Reference Files ==="

for plugin_dir in "$DX_DIR" "$AEM_DIR" "$AUTO_DIR"; do
  [ -z "$plugin_dir" ] && continue
  [ ! -d "$plugin_dir/shared" ] && continue
  plugin_name="$(basename "$plugin_dir")"

  for shared_file in "$plugin_dir"/shared/*; do
    [ -f "$shared_file" ] || continue
    fname="$(basename "$shared_file")"
    make_exec="false"
    [[ "$fname" == *.sh ]] && make_exec="true"
    copy_file "$shared_file" ".ai/ejected/shared/$fname" \
      ".ai/ejected/shared/$fname (from $plugin_name)" "$make_exec"
  done
done

# =========================================================
# 5. Data Files — already installed by dx-init, but copy
#    originals to .ai/ejected/data/ for reference
# =========================================================
echo ""
echo "=== Data Files (plugin originals) ==="

for plugin_dir in "$DX_DIR" "$AEM_DIR" "$AUTO_DIR"; do
  [ -z "$plugin_dir" ] && continue
  [ ! -d "$plugin_dir/data" ] && continue
  plugin_name="$(basename "$plugin_dir")"

  # Use find to get all files recursively
  while IFS= read -r -d '' data_file; do
    rel_path="${data_file#"$plugin_dir/data/"}"
    make_exec="false"
    [[ "$data_file" == *.sh ]] && make_exec="true"
    copy_file "$data_file" ".ai/ejected/data/$plugin_name/$rel_path" \
      ".ai/ejected/data/$plugin_name/$rel_path" "$make_exec"
  done < <(find "$plugin_dir/data" -type f -print0)
done

# =========================================================
# 6. Templates — plugin templates/ → .ai/ejected/templates/
#    These are the source-of-truth for rules, instructions,
#    Copilot agents/skills, docs, and config
# =========================================================
echo ""
echo "=== Plugin Templates ==="

for plugin_dir in "$DX_DIR" "$AEM_DIR" "$AUTO_DIR"; do
  [ -z "$plugin_dir" ] && continue
  [ ! -d "$plugin_dir/templates" ] && continue
  plugin_name="$(basename "$plugin_dir")"

  while IFS= read -r -d '' tmpl_file; do
    rel_path="${tmpl_file#"$plugin_dir/templates/"}"
    make_exec="false"
    [[ "$tmpl_file" == *.sh ]] && make_exec="true"
    copy_file "$tmpl_file" ".ai/ejected/templates/$plugin_name/$rel_path" \
      ".ai/ejected/templates/$plugin_name/$rel_path" "$make_exec"
  done < <(find "$plugin_dir/templates" -type f -print0)
done

# =========================================================
# 7. Hooks — plugin hooks/ → .ai/ejected/hooks/
# =========================================================
echo ""
echo "=== Plugin Hooks ==="

for plugin_dir in "$DX_DIR" "$AEM_DIR" "$AUTO_DIR"; do
  [ -z "$plugin_dir" ] && continue
  [ ! -d "$plugin_dir/hooks" ] && continue
  plugin_name="$(basename "$plugin_dir")"

  for hook_file in "$plugin_dir"/hooks/*; do
    [ -f "$hook_file" ] || continue
    fname="$(basename "$hook_file")"
    copy_file "$hook_file" ".ai/ejected/hooks/$plugin_name/$fname" \
      ".ai/ejected/hooks/$plugin_name/$fname"
  done
done

# =========================================================
# 8. Plugin Manifests — for version tracking post-eject
# =========================================================
echo ""
echo "=== Plugin Manifests ==="

for plugin_dir in "$DX_DIR" "$AEM_DIR" "$AUTO_DIR"; do
  [ -z "$plugin_dir" ] && continue
  [ ! -f "$plugin_dir/.claude-plugin/plugin.json" ] && continue
  plugin_name="$(basename "$plugin_dir")"

  copy_file "$plugin_dir/.claude-plugin/plugin.json" \
    ".ai/ejected/manifests/$plugin_name.json" \
    ".ai/ejected/manifests/$plugin_name.json"
done

# =========================================================
# 9. Copilot Agents
# =========================================================
echo ""
echo "=== Copilot Agents (template → .github/agents/) ==="

if [ -f "$DX_DIR/skills/dx-init/scripts/install-copilot-agents.sh" ]; then
  bash "$DX_DIR/skills/dx-init/scripts/install-copilot-agents.sh" --force "$DX_DIR"
else
  echo "skipped: install-copilot-agents.sh not found"
fi

# Also handle AEM plugin Copilot agents
if [ -n "$AEM_DIR" ] && [ -d "$AEM_DIR/templates/agents" ]; then
  bash "$DX_DIR/skills/dx-init/scripts/install-copilot-agents.sh" --force "$AEM_DIR"
fi

# =========================================================
# Summary
# =========================================================
echo ""
echo "=== Summary ==="
echo "installed: $INSTALLED"
echo "updated:   $UPDATED"
echo "skipped:   $SKIPPED"
echo "total:     $((INSTALLED + UPDATED + SKIPPED))"

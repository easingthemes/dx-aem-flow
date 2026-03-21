#!/usr/bin/env bash
# sync-consumers.sh — Sync plugin updates to all consumer repos
#
# Usage:
#   ./sync-consumers.sh [OPTIONS] [REPO...]
#
# Options:
#   --dry-run       Show what would be done without making changes
#   --no-git        Skip git operations (merge base, commit, push)
#   --no-pr         Skip PR creation
#   --parallel      Sync all selected repos in parallel (backgrounds each repo)
#   --skip-self      Skip the Hub repo — useful when Hub is already synced
#   --version VER   Override the version string (default: read from plugin.json)
#
# Repos:
#   Read from the hub's .ai/config.yaml repos: section.
#   The hub itself is always included automatically.
#
# If no repos are specified, syncs all repos from config (except 'config').
#
# Examples:
#   ./sync-consumers.sh                           # Sync all main repos
#   ./sync-consumers.sh --dry-run                 # Preview all changes
#   ./sync-consumers.sh --skip-self backend        # Sync only backend repo
#   ./sync-consumers.sh --no-git backend           # Sync backend files, skip git

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─── Config ──────────────────────────────────────────────────────────────────
# Current repo: the repo you're running sync FROM.
# Can be any consumer repo with plugins installed — no "hub" assumption.
CURRENT_REPO="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# Plugin directories: resolve from script location (works for both
# installed plugins cache and local source checkout).
DX_PLUGIN="$(cd "$SCRIPT_DIR/../../.." && pwd)"
# Resolve AEM plugin: try sibling (local source), then versioned cache layout
if [ -d "$DX_PLUGIN/../dx-aem" ]; then
  AEM_PLUGIN="$(cd "$DX_PLUGIN/../dx-aem" && pwd)"
elif [ -d "$DX_PLUGIN/../../dx-aem" ]; then
  # Cache layout: dx-core/<ver>/ → ../../dx-aem/<ver>/
  _DX_VER="$(basename "$DX_PLUGIN")"
  if [ -d "$DX_PLUGIN/../../dx-aem/$_DX_VER" ]; then
    AEM_PLUGIN="$(cd "$DX_PLUGIN/../../dx-aem/$_DX_VER" && pwd)"
  else
    # Fall back to latest available version
    AEM_PLUGIN="$(ls -d "$DX_PLUGIN/../../dx-aem"/*/ 2>/dev/null | sort -V | tail -1)"
    AEM_PLUGIN="${AEM_PLUGIN%/}"
  fi
  unset _DX_VER
else
  AEM_PLUGIN=""
fi
INSTALL_AGENTS="$DX_PLUGIN/skills/dx-init/scripts/install-copilot-agents.sh"
MIGRATE_CONFIG="$SCRIPT_DIR/migrate-config.sh"
source "$MIGRATE_CONFIG"

CONFIG="$CURRENT_REPO/.ai/config.yaml"
if [[ ! -f "$CONFIG" ]]; then
  echo "ERROR: No .ai/config.yaml found at $CURRENT_REPO"
  echo "Run /dx-init first to generate project config."
  exit 1
fi

# Read scm.base-branch as default for repos without explicit base-branch
DEFAULT_BASE_BRANCH=$(grep 'base-branch:' "$CONFIG" | head -1 | awk '{print $2}' | tr -d '"')

# ─── Parse repos: from config.yaml ─────────────────────────────────────────
# Builds CONSUMERS array with format: name|path|base_branch|work_branch|fe|be|sling
# Capabilities auto-detected from directory structure if not specified in config.

CONSUMERS=()

flush_entry() {
  local name="$1" path="$2" base="$3" caps="$4"

  # Resolve path relative to hub repo
  local abs_path
  if [[ "$path" == /* ]]; then
    abs_path="$path"
  else
    abs_path="$(cd "$CURRENT_REPO" && cd "$path" 2>/dev/null && pwd)" || abs_path="$CURRENT_REPO/$path"
  fi

  # Default base branch
  base="${base:-$DEFAULT_BASE_BRANCH}"

  # Parse capabilities or auto-detect
  local has_fe="no" has_be="no" has_sling="no"
  if [[ -n "$caps" ]]; then
    [[ "$caps" == *"fe"* ]] && has_fe="yes"
    [[ "$caps" == *"be"* ]] && has_be="yes"
    [[ "$caps" == *"sling"* ]] && has_sling="yes"
  elif [[ -d "$abs_path" ]]; then
    [[ -d "$abs_path/ui.frontend" ]] && has_fe="yes"
    [[ -d "$abs_path/core" || -d "$abs_path/bundle" ]] && has_be="yes"
  fi

  CONSUMERS+=("${name}|${abs_path}|${base}|feature/ai-tools-sync|${has_fe}|${has_be}|${has_sling}")
}

parse_repos_from_config() {
  local in_repos=false in_aem=false
  local cur_name="" cur_path="" cur_base="" cur_caps=""

  while IFS= read -r line; do
    # Track if we're inside the aem: section (to skip aem.repos if it still exists)
    if [[ "$line" =~ ^aem: ]]; then in_aem=true; continue; fi
    if $in_aem && [[ "$line" =~ ^[a-z] && ! "$line" =~ ^[[:space:]] ]]; then in_aem=false; fi
    if $in_aem; then continue; fi

    # Detect top-level repos: section
    if [[ "$line" =~ ^repos: ]]; then
      in_repos=true
      continue
    fi

    # Exit repos section on next top-level key (non-indented, non-comment, non-empty)
    if $in_repos && [[ "$line" =~ ^[a-z] ]]; then
      [[ -n "$cur_name" ]] && flush_entry "$cur_name" "$cur_path" "$cur_base" "$cur_caps"
      break
    fi

    if $in_repos; then
      if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*name:[[:space:]]*(.*) ]]; then
        [[ -n "$cur_name" ]] && flush_entry "$cur_name" "$cur_path" "$cur_base" "$cur_caps"
        cur_name=$(echo "${BASH_REMATCH[1]}" | tr -d '"' | xargs)
        cur_path="" cur_base="" cur_caps=""
      elif [[ "$line" =~ ^[[:space:]]*path:[[:space:]]*(.*) ]]; then
        cur_path=$(echo "${BASH_REMATCH[1]}" | tr -d '"' | xargs)
      elif [[ "$line" =~ ^[[:space:]]*base-branch:[[:space:]]*(.*) ]]; then
        cur_base=$(echo "${BASH_REMATCH[1]}" | tr -d '"' | xargs)
      elif [[ "$line" =~ ^[[:space:]]*capabilities:[[:space:]]*\[(.*)\] ]]; then
        cur_caps="${BASH_REMATCH[1]}"
      fi
    fi
  done < "$CONFIG"

  # Flush last entry if file ends inside repos section
  [[ -n "$cur_name" ]] && flush_entry "$cur_name" "$cur_path" "$cur_base" "$cur_caps"
}

parse_repos_from_config

# Add hub itself as first consumer
SELF_NAME=$(basename "$CURRENT_REPO")
SELF_FE="no" SELF_BE="no" SELF_SLING="no"
[[ -d "$CURRENT_REPO/ui.frontend" ]] && SELF_FE="yes"
[[ -d "$CURRENT_REPO/core" || -d "$CURRENT_REPO/bundle" ]] && SELF_BE="yes"
CONSUMERS=("self|${CURRENT_REPO}|${DEFAULT_BASE_BRANCH}|feature/ai-tools-sync|${SELF_FE}|${SELF_BE}|${SELF_SLING}" "${CONSUMERS[@]}")

if [[ ${#CONSUMERS[@]} -le 1 ]]; then
  echo "NOTE: No sibling repos found in $CONFIG repos: section. Only the hub will be synced."
fi

# ─── Parse args ──────────────────────────────────────────────────────────────
DRY_RUN=false
NO_GIT=false
NO_PR=false
PARALLEL=false
SKIP_SELF=false
VERSION=""
SELECTED_REPOS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)   DRY_RUN=true; shift ;;
    --no-git)    NO_GIT=true; shift ;;
    --no-pr)     NO_PR=true; shift ;;
    --parallel)  PARALLEL=true; shift ;;
    --skip-self)  SKIP_SELF=true; shift ;;
    --version)   VERSION="$2"; shift 2 ;;
    -*)          echo "Unknown option: $1" >&2; exit 1 ;;
    *)           SELECTED_REPOS+=("$1"); shift ;;
  esac
done

# Default: all repos from config (excluding 'config' unless explicitly named)
if [ ${#SELECTED_REPOS[@]} -eq 0 ]; then
  for entry in "${CONSUMERS[@]}"; do
    repo_name="${entry%%|*}"
    if [[ "$repo_name" != "config" ]]; then
      SELECTED_REPOS+=("$repo_name")
    fi
  done
fi

# Remove hub if --skip-self
if $SKIP_SELF; then
  SELECTED_REPOS=("${SELECTED_REPOS[@]/self/}")
fi

# Read version from plugin.json if not overridden
if [ -z "$VERSION" ]; then
  VERSION=$(grep '"version"' "$DX_PLUGIN/.claude-plugin/plugin.json" | sed 's/.*"version": *"\([^"]*\)".*/\1/')
fi

# ─── Helpers ─────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
DIM='\033[2m'
RESET='\033[0m'

log()      { echo -e "${GREEN}[sync]${RESET} $*"; }
log_warn() { echo -e "${YELLOW}[warn]${RESET} $*"; }
log_info() { echo -e "${BLUE}[info]${RESET} $*"; }
log_err()  { echo -e "${RED}[error]${RESET} $*"; }
log_dry()  { echo -e "${DIM}[dry-run]${RESET} $*"; }

run() {
  if $DRY_RUN; then
    log_dry "$*"
  else
    "$@"
  fi
}

# Copy file with logging
sync_file() {
  local src="$1" dst="$2"
  if [ ! -f "$src" ]; then
    log_warn "source not found: $src"
    return 1
  fi
  local dst_dir
  dst_dir=$(dirname "$dst")
  if $DRY_RUN; then
    if [ -f "$dst" ]; then
      if diff -q "$src" "$dst" >/dev/null 2>&1; then
        return 0  # identical, skip
      fi
      log_dry "update $dst"
    else
      log_dry "create $dst"
    fi
  else
    mkdir -p "$dst_dir"
    if [ -f "$dst" ] && diff -q "$src" "$dst" >/dev/null 2>&1; then
      return 0  # identical, skip
    fi
    cp "$src" "$dst"
  fi
}

# Copy file, stripping .template extension
sync_template() {
  local src="$1" dst="$2"
  sync_file "$src" "$dst"
}

# Diff a template against target, return 0 if different
diff_template() {
  local src="$1" dst="$2"
  if [ ! -f "$dst" ]; then
    echo "  NEW: $dst"
    return 0
  fi
  if diff -q "$src" "$dst" >/dev/null 2>&1; then
    return 1  # identical
  fi
  echo "  CHANGED: $dst"
  diff --color=auto -u "$dst" "$src" | head -30 || true
  return 0
}

# ─── Parse consumer record ──────────────────────────────────────────────────
parse_consumer() {
  local record="$1"
  IFS='|' read -r C_NAME C_PATH C_BASE C_BRANCH C_FE C_BE C_SLING <<< "$record"
  # Derived: is this an AEM repo at all? (has FE or BE)
  C_IS_AEM="no"
  if [ "$C_FE" = "yes" ] || [ "$C_BE" = "yes" ]; then C_IS_AEM="yes"; fi
}

# ─── Sync functions ─────────────────────────────────────────────────────────

step_0_setup_worktree() {
  local repo_path="$1" base="$2" branch="$3"
  if $NO_GIT; then return 0; fi
  if [ -z "$branch" ]; then
    log_warn "  no work branch configured, skipping git ops"
    return 0
  fi

  log "  Step 0: Setup worktree for $branch (from $base)"
  (
    cd "$repo_path"

    if $DRY_RUN; then
      log_dry "  git fetch origin $base"
      log_dry "  git worktree add /tmp/dx-sync-<name> $branch (create from $base if needed)"
      return 0
    fi

    # Fetch base branch
    git fetch origin "$base" 2>&1 | sed 's/^/    /'

    # Create the sync branch if it doesn't exist
    if ! git show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null; then
      log_info "  creating branch '$branch' from origin/$base"
      git branch "$branch" "origin/$base" 2>&1 | sed 's/^/    /'
    fi

    # Create worktree
    local wt_path="/tmp/dx-sync-$(basename "$repo_path")"
    if [ -d "$wt_path" ]; then
      # Remove stale worktree
      git worktree remove "$wt_path" --force 2>/dev/null || rm -rf "$wt_path"
    fi
    git worktree add "$wt_path" "$branch" 2>&1 | sed 's/^/    /'

    # Merge base into sync branch in the worktree
    cd "$wt_path"
    if ! git merge "origin/$base" --no-edit 2>&1 | sed 's/^/    /'; then
      log_err "  Merge conflicts detected — resolve in $wt_path, then re-run"
      git merge --abort 2>/dev/null || true
      return 1
    fi

    log_info "  worktree ready at $wt_path"
  )
}

step_1_lib_scripts() {
  local repo_path="$1"
  log "  Step 1: Utility scripts (.ai/lib/)"
  local count=0
  for f in audit.sh dx-common.sh gather-context.sh plan-metadata.sh pre-review-checks.sh; do
    if sync_file "$DX_PLUGIN/data/lib/$f" "$repo_path/.ai/lib/$f"; then
      ((count++)) || true
    fi
  done
  sync_file "$DX_PLUGIN/data/hooks/stop-guard.sh" "$repo_path/.claude/hooks/stop-guard.sh"
  log_info "  lib scripts synced"
}

step_2_templates() {
  local repo_path="$1"
  log "  Step 2: Output templates (.ai/templates/)"
  for subdir in spec wiki ado-comments; do
    local src_dir="$DX_PLUGIN/data/templates/$subdir"
    [ -d "$src_dir" ] || continue
    for f in "$src_dir"/*.template; do
      [ -f "$f" ] || continue
      local base
      base=$(basename "$f")
      sync_file "$f" "$repo_path/.ai/templates/$subdir/$base"
    done
  done
  log_info "  templates synced"
}

step_3_copilot_agents() {
  local repo_path="$1" is_aem="$2"
  log "  Step 3: Copilot agents (.github/agents/)"
  (
    cd "$repo_path"
    if $DRY_RUN; then
      log_dry "  bash $INSTALL_AGENTS --force $DX_PLUGIN"
      if [ "$is_aem" = "yes" ]; then
        log_dry "  bash $INSTALL_AGENTS --force $AEM_PLUGIN"
      fi
    else
      bash "$INSTALL_AGENTS" --force "$DX_PLUGIN" 2>&1 | sed 's/^/    /'
      if [ "$is_aem" = "yes" ]; then
        bash "$INSTALL_AGENTS" --force "$AEM_PLUGIN" 2>&1 | sed 's/^/    /'
      fi
    fi
  )
}

step_5_migrate_config() {
  local repo_path="$1"
  local config="$repo_path/.ai/config.yaml"

  if [[ ! -f "$config" ]]; then
    log "  Step 5: Config migration"
    if $DRY_RUN; then
      log_dry "  would create minimal .ai/config.yaml with dx.version $VERSION"
      return 0
    fi
    # Create minimal config so dx.version is tracked
    mkdir -p "$repo_path/.ai"
    cat > "$config" <<MINCONF
dx:
  version: "$VERSION"
MINCONF
    log_info "  created minimal .ai/config.yaml (dx.version: $VERSION)"
    return 0
  fi

  log "  Step 5: Config migration"

  if $DRY_RUN; then
    local current_ver
    current_ver=$(get_config_version "$config")
    if version_lt "$current_ver" "$VERSION"; then
      log_dry "  would migrate config from $current_ver → $VERSION"
    else
      log_info "  config up to date ($current_ver)"
    fi
    return 0
  fi

  if run_migrations "$config" "$VERSION"; then
    log_info "  config migrated"
  else
    log_info "  config up to date"
  fi
}

step_6_claude_rules() {
  local repo_path="$1" has_fe="$2" has_be="$3" has_sling="$4"
  log "  Step 6: Claude rules (.claude/rules/)"

  # Always synced — universal rules
  sync_template "$DX_PLUGIN/templates/rules/universal-reuse-first.md.template" "$repo_path/.claude/rules/reuse-first.md"

  # Always synced — general AEM rules
  for name in audit.md qa-basic-auth.md; do
    local src="$AEM_PLUGIN/templates/rules/${name}.template"
    [ -f "$src" ] && sync_template "$src" "$repo_path/.claude/rules/$name"
  done

  # Frontend rules (fe=yes)
  if [ "$has_fe" = "yes" ]; then
    for name in fe-javascript.md fe-styles.md fe-clientlibs.md naming.md accessibility.md; do
      local src="$AEM_PLUGIN/templates/rules/${name}.template"
      [ -f "$src" ] && sync_template "$src" "$repo_path/.claude/rules/$name"
    done
  fi

  # Backend rules (be=yes)
  if [ "$has_be" = "yes" ]; then
    for name in be-components.md be-testing.md; do
      local src="$AEM_PLUGIN/templates/rules/${name}.template"
      [ -f "$src" ] && sync_template "$src" "$repo_path/.claude/rules/$name"
    done
  fi

  # Sling rules (sling=yes)
  if [ "$has_sling" = "yes" ]; then
    local src="$AEM_PLUGIN/templates/rules/be-sling-models.md.template"
    [ -f "$src" ] && sync_template "$src" "$repo_path/.claude/rules/be-sling-models.md"
  fi

  log_info "  claude rules synced"
}

step_7_ai_rules() {
  local repo_path="$1"
  log "  Step 7: Shared rules (.ai/rules/)"

  for f in "$DX_PLUGIN"/templates/rules/*.template; do
    [ -f "$f" ] || continue
    local base
    base=$(basename "$f" .template)
    # Skip universal rules (handled in step 6)
    [[ "$base" == universal-* ]] && continue
    sync_template "$f" "$repo_path/.ai/rules/$base"
  done

  log_info "  ai rules synced"
}

step_8_instructions() {
  local repo_path="$1" is_aem="$2"
  if [ "$is_aem" != "yes" ]; then return 0; fi
  log "  Step 8: Instructions (.github/instructions/)"
  for f in "$AEM_PLUGIN"/templates/instructions/*.template; do
    [ -f "$f" ] || continue
    local base
    base=$(basename "$f" .template)
    sync_template "$f" "$repo_path/.github/instructions/$base"
  done
  log_info "  instructions synced"
}

step_8b_vscode_mcp() {
  local repo_path="$1"
  log "  Step 8b: VS Code MCP config (.vscode/mcp.json)"

  local root_mcp="$repo_path/.mcp.json"
  local vscode_mcp="$repo_path/.vscode/mcp.json"

  if [ ! -f "$root_mcp" ]; then
    log_warn "  no .mcp.json found — skipping VS Code MCP sync"
    return 0
  fi

  # Extract server entries from root .mcp.json (mcpServers key) and convert to VS Code format (servers key)
  # Only sync ado and atlassian — leave other entries (playwright, browsermcp) untouched
  if $DRY_RUN; then
    log_dry "  would sync ADO/Atlassian from .mcp.json → .vscode/mcp.json"
    return 0
  fi

  mkdir -p "$repo_path/.vscode"

  if [ ! -f "$vscode_mcp" ]; then
    # Create new .vscode/mcp.json from .mcp.json
    # Convert mcpServers → servers
    sed 's/"mcpServers"/"servers"/' "$root_mcp" > "$vscode_mcp"
    log_info "  created .vscode/mcp.json from .mcp.json"
  else
    # Check if ado server exists in .vscode/mcp.json
    if ! grep -q 'azure-devops' "$vscode_mcp" 2>/dev/null; then
      if grep -q 'azure-devops' "$root_mcp" 2>/dev/null; then
        log_warn "  ADO MCP missing from .vscode/mcp.json — add manually"
      fi
    else
      log_info "  .vscode/mcp.json already has ADO server"
    fi
  fi
}

step_8c_vscode_settings() {
  local repo_path="$1"
  log "  Step 8c: VS Code Chat settings (.vscode/settings.json)"

  local vscode_settings="$repo_path/.vscode/settings.json"

  if $DRY_RUN; then
    if [ -f "$vscode_settings" ]; then
      local has_skills has_instr
      has_skills=$(grep -c "agentSkillsLocations" "$vscode_settings" 2>/dev/null | tail -1 || echo 0)
      has_instr=$(grep -c "instructionsFilesLocations" "$vscode_settings" 2>/dev/null | tail -1 || echo 0)
      [ "$has_skills" -eq 0 ] && log_dry "  would add chat.agentSkillsLocations"
      [ "$has_instr" -eq 0 ] && log_dry "  would add chat.instructionsFilesLocations"
    else
      log_dry "  would create .vscode/settings.json with VS Code Chat settings"
    fi
    return 0
  fi

  if [ ! -f "$vscode_settings" ]; then
    mkdir -p "$repo_path/.vscode"
    cat > "$vscode_settings" << 'SETTINGS_EOF'
{
    "chat.instructionsFilesLocations": {
        ".claude/rules": true
    },
    "chat.agentSkillsLocations": {
        ".claude/skills": true
    }
}
SETTINGS_EOF
    log_info "  created .vscode/settings.json"
  else
    # Check if settings already have our entries
    local needs_update=false
    if ! grep -q "instructionsFilesLocations" "$vscode_settings" 2>/dev/null; then
      needs_update=true
    fi
    if ! grep -q "agentSkillsLocations" "$vscode_settings" 2>/dev/null; then
      needs_update=true
    fi
    if $needs_update; then
      log_warn "  .vscode/settings.json exists but missing VS Code Chat settings — add manually"
      log_info '  Add: "chat.instructionsFilesLocations": { ".claude/rules": true }'
      log_info '  Add: "chat.agentSkillsLocations": { ".claude/skills": true }'
    else
      log_info "  .vscode/settings.json already has VS Code Chat settings"
    fi
  fi
}

step_9_cleanup() {
  local repo_path="$1" has_fe="$2" has_be="$3" has_sling="$4"
  log "  Step 9: Cleanup"

  # Remove universal-reuse-first.md if both it and reuse-first.md exist
  if [ -f "$repo_path/.claude/rules/universal-reuse-first.md" ] && [ -f "$repo_path/.claude/rules/reuse-first.md" ]; then
    if $DRY_RUN; then
      log_dry "  remove .claude/rules/universal-reuse-first.md (duplicate)"
    else
      rm "$repo_path/.claude/rules/universal-reuse-first.md"
      log_info "  removed duplicate universal-reuse-first.md"
    fi
  fi

  # Remove FE rules from repos without frontend
  if [ "$has_fe" != "yes" ]; then
    for pattern in fe-*.md naming.md accessibility.md; do
      for f in "$repo_path"/.claude/rules/$pattern; do
        [ -f "$f" ] || continue
        if $DRY_RUN; then
          log_dry "  remove $f (no frontend)"
        else
          rm "$f"
          log_info "  removed $(basename "$f") (no frontend)"
        fi
      done
    done
  fi

  # Remove BE rules from repos without Java backend
  if [ "$has_be" != "yes" ]; then
    for pattern in be-components.md be-testing.md; do
      for f in "$repo_path"/.claude/rules/$pattern; do
        [ -f "$f" ] || continue
        if $DRY_RUN; then
          log_dry "  remove $f (no backend)"
        else
          rm "$f"
          log_info "  removed $(basename "$f") (no backend)"
        fi
      done
    done
  fi

  # Remove Sling rules from repos without Sling
  if [ "$has_sling" != "yes" ]; then
    if [ -f "$repo_path/.claude/rules/be-sling-models.md" ]; then
      if $DRY_RUN; then
        log_dry "  remove be-sling-models.md (no sling)"
      else
        rm "$repo_path/.claude/rules/be-sling-models.md"
        log_info "  removed be-sling-models.md (no sling)"
      fi
    fi
  fi
}

step_10_commit_push() {
  local repo_path="$1" branch="$2"
  if $NO_GIT; then return 0; fi
  if [ -z "$branch" ]; then return 0; fi

  log "  Step 10: Commit and push"
  (
    cd "$repo_path"

    # Check for changes
    if git diff --quiet HEAD -- .ai/ .claude/ .github/ 2>/dev/null && \
       [ -z "$(git ls-files --others --exclude-standard .ai/ .claude/ .github/)" ]; then
      log_info "  no changes to commit"
      return 0
    fi

    if $DRY_RUN; then
      log_dry "  git add .ai/ .claude/ .github/"
      log_dry "  git commit -m '[NO TICKET] Sync consumer with dx plugins v$VERSION'"
      log_dry "  git push origin $branch"
    else
      git add .ai/ .claude/ .github/
      # .vscode/ may be gitignored — only add if tracked or has changes
      git add .vscode/ 2>/dev/null || true
      git commit --no-verify -m "[NO TICKET] Sync consumer with dx plugins v$VERSION" 2>&1 | sed 's/^/    /'
      git push origin "$branch" 2>&1 | sed 's/^/    /'
    fi
  )
}

step_11_create_pr() {
  local repo_path="$1" base="$2" branch="$3" name="$4"
  if $NO_GIT || $NO_PR; then return 0; fi
  if [ -z "$branch" ]; then return 0; fi

  log "  Step 11: Create/update PR"
  (
    cd "$repo_path"

    # Check if PR already exists for this branch
    local existing_pr
    existing_pr=$(git ls-remote --refs origin "$branch" 2>/dev/null | head -1)
    if [ -z "$existing_pr" ]; then
      log_warn "  branch not on remote — push first"
      return 0
    fi

    if $DRY_RUN; then
      log_dry "  would create PR: $branch → $base"
      log_dry "  title: [NO TICKET] AI tools sync — dx plugins v$VERSION"
    else
      log_info "  PR creation requires ADO — use /dx-pr or create manually"
      log_info "  Branch: $branch → $base"
      log_info "  Title: [NO TICKET] AI tools sync — dx plugins v$VERSION"
    fi
  )
}

# ─── Repo validation ───────────────────────────────────────────────────────

validate_repo() {
  local name="$1" path="$2" base="$3" branch="$4"

  if [ ! -d "$path" ]; then
    log "✗ $name: directory not found at $path"
    return 1
  fi

  if [ ! -d "$path/.git" ]; then
    log "✗ $name: not a git repository"
    return 1
  fi

  # Check branch exists (warn only — will create if missing)
  if [ -n "$branch" ]; then
    (cd "$path" && git rev-parse --verify "$branch" &>/dev/null) || {
      log "⚠ $name: branch '$branch' not found — will create from $base"
    }
  fi

  # Check base branch exists in remotes
  (cd "$path" && git rev-parse --verify "origin/$base" &>/dev/null) || {
    log "✗ $name: base branch 'origin/$base' not found"
    return 1
  }

  return 0
}

# ─── Per-repo sync wrapper (used by parallel mode) ────────────────────────

sync_one_repo() {
  local c_name="$1" c_path="$2" c_base="$3" c_branch="$4"
  local c_fe="$5" c_be="$6" c_sling="$7" c_is_aem="$8"
  local logfile="$9"

  {
    # Validate repo
    if ! validate_repo "$c_name" "$c_path" "$c_base" "$c_branch"; then
      log "SKIPPING $c_name — validation failed"
      return 1
    fi

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log "Syncing: ${c_name} ($(basename "$c_path"))"
    log_info "  path:   $c_path"
    log_info "  branch: $c_branch (base: $c_base)"
    log_info "  fe: $c_fe | be: $c_be | sling: $c_sling"
    echo ""

    # Use worktree for git operations, original path for --no-git mode
    local work_path="$c_path"
    local wt_path="/tmp/dx-sync-$(basename "$c_path")"

    if ! $NO_GIT; then
      if ! step_0_setup_worktree "$c_path" "$c_base" "$c_branch"; then
        log_err "  Worktree setup failed for $c_name — skipping remaining steps"
        return 1
      fi
      if ! $DRY_RUN; then
        work_path="$wt_path"
      fi
    fi

    step_1_lib_scripts "$work_path"
    step_2_templates "$work_path"
    step_3_copilot_agents "$work_path" "$c_is_aem"
    step_5_migrate_config "$work_path"
    step_6_claude_rules "$work_path" "$c_fe" "$c_be" "$c_sling"
    step_7_ai_rules "$work_path"
    step_8_instructions "$work_path" "$c_is_aem"
    step_8b_vscode_mcp "$work_path"
    step_8c_vscode_settings "$work_path"
    step_9_cleanup "$work_path" "$c_fe" "$c_be" "$c_sling"
    step_10_commit_push "$work_path" "$c_branch"
    step_11_create_pr "$work_path" "$c_base" "$c_branch" "$c_name"

    # Clean up worktree
    if ! $NO_GIT && ! $DRY_RUN && [ -d "$wt_path" ]; then
      log_info "  cleaning up worktree"
      (cd "$c_path" && git worktree remove "$wt_path" --force 2>/dev/null) || rm -rf "$wt_path"
    fi

    echo ""
  } > "$logfile" 2>&1
}

# ─── Main ────────────────────────────────────────────────────────────────────
echo ""
log "Plugin → Consumer Sync v$VERSION"
log "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
if $DRY_RUN; then log_warn "DRY RUN — no changes will be made"; fi
echo ""

synced=0
failed=0

if $PARALLEL; then
  # ─── Parallel mode ────────────────────────────────────────────────────────
  log_info "Running in PARALLEL mode"
  echo ""

  declare -a PIDS=()
  declare -a PID_NAMES=()
  declare -a PID_LOGS=()
  TMPDIR_PARALLEL=$(mktemp -d)

  for consumer in "${CONSUMERS[@]}"; do
    parse_consumer "$consumer"

    # Skip if not in selected repos
    found=false
    for sel in "${SELECTED_REPOS[@]}"; do
      if [ "$sel" = "$C_NAME" ]; then found=true; break; fi
    done
    if ! $found; then continue; fi

    # Skip config repo (needs init first)
    if [ "$C_NAME" = "config" ] && [ -z "$C_BRANCH" ]; then
      log_warn "Skipping $C_NAME — needs /dx-init first"
      continue
    fi

    local_logfile="$TMPDIR_PARALLEL/${C_NAME}.log"

    sync_one_repo "$C_NAME" "$C_PATH" "$C_BASE" "$C_BRANCH" \
      "$C_FE" "$C_BE" "$C_SLING" "$C_IS_AEM" "$local_logfile" &

    PIDS+=($!)
    PID_NAMES+=("$C_NAME")
    PID_LOGS+=("$local_logfile")
    log "  Started $C_NAME (PID $!)"
  done

  echo ""
  log "Waiting for ${#PIDS[@]} repos to finish..."
  echo ""

  for i in "${!PIDS[@]}"; do
    pid="${PIDS[$i]}"
    name="${PID_NAMES[$i]}"
    logfile="${PID_LOGS[$i]}"

    if wait "$pid"; then
      ((synced++)) || true
      log "✓ $name completed"
    else
      ((failed++)) || true
      log_err "✗ $name failed"
    fi

    # Print per-repo log
    if [ -f "$logfile" ]; then
      cat "$logfile"
    fi
  done

  rm -rf "$TMPDIR_PARALLEL"

else
  # ─── Sequential mode ──────────────────────────────────────────────────────
  for consumer in "${CONSUMERS[@]}"; do
    parse_consumer "$consumer"

    # Skip if not in selected repos
    found=false
    for sel in "${SELECTED_REPOS[@]}"; do
      if [ "$sel" = "$C_NAME" ]; then found=true; break; fi
    done
    if ! $found; then continue; fi

    # Skip config repo (needs init first)
    if [ "$C_NAME" = "config" ] && [ -z "$C_BRANCH" ]; then
      log_warn "Skipping $C_NAME — needs /dx-init first"
      continue
    fi

    # Validate repo
    if ! validate_repo "$C_NAME" "$C_PATH" "$C_BASE" "$C_BRANCH"; then
      log "SKIPPING $C_NAME — validation failed"
      ((failed++)) || true
      continue
    fi

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log "Syncing: ${C_NAME} ($(basename "$C_PATH"))"
    log_info "  path:   $C_PATH"
    log_info "  branch: $C_BRANCH (base: $C_BASE)"
    log_info "  fe: $C_FE | be: $C_BE | sling: $C_SLING"
    echo ""

    # Use worktree for git operations, original path for --no-git mode
    WORK_PATH="$C_PATH"
    WT_PATH="/tmp/dx-sync-$(basename "$C_PATH")"

    if ! $NO_GIT; then
      if ! step_0_setup_worktree "$C_PATH" "$C_BASE" "$C_BRANCH"; then
        log_err "  Worktree setup failed for $C_NAME — skipping remaining steps"
        ((failed++)) || true
        continue
      fi
      if ! $DRY_RUN; then
        WORK_PATH="$WT_PATH"
      fi
    fi

    step_1_lib_scripts "$WORK_PATH"
    step_2_templates "$WORK_PATH"
    step_3_copilot_agents "$WORK_PATH" "$C_IS_AEM"
    step_5_migrate_config "$WORK_PATH"
    step_6_claude_rules "$WORK_PATH" "$C_FE" "$C_BE" "$C_SLING"
    step_7_ai_rules "$WORK_PATH"
    step_8_instructions "$WORK_PATH" "$C_IS_AEM"
    step_8b_vscode_mcp "$WORK_PATH"
    step_8c_vscode_settings "$WORK_PATH"
    step_9_cleanup "$WORK_PATH" "$C_FE" "$C_BE" "$C_SLING"
    step_10_commit_push "$WORK_PATH" "$C_BRANCH"
    step_11_create_pr "$WORK_PATH" "$C_BASE" "$C_BRANCH" "$C_NAME"

    # Clean up worktree
    if ! $NO_GIT && ! $DRY_RUN && [ -d "$WT_PATH" ]; then
      log_info "  cleaning up worktree"
      (cd "$C_PATH" && git worktree remove "$WT_PATH" --force 2>/dev/null) || rm -rf "$WT_PATH"
    fi

    ((synced++)) || true
    echo ""
  done
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log "Done: $synced synced, $failed failed"
if [ $failed -gt 0 ]; then
  exit 1
fi

#!/usr/bin/env bash
# dx-common.sh — Shared library for dx plugin skills
#
# Can be used two ways:
#
# 1. As a CLI (from SKILL.md instructions):
#    bash .ai/lib/dx-common.sh find-spec-dir 2416553
#    bash .ai/lib/dx-common.sh slugify 2416553 "Enhance Card Layout Switcher"
#    bash .ai/lib/dx-common.sh yaml-val compile
#
# 2. As a library (from other scripts):
#    source .ai/lib/dx-common.sh
#    SPEC_DIR=$(find_spec_dir "2416553")
#    SLUG=$(slugify "2416553" "Enhance Card Layout Switcher")
#    CMD=$(yaml_val "compile")

set -euo pipefail

SPECS_DIR="${SPECS_DIR:-.ai/specs}"
CONFIG_FILE="${CONFIG_FILE:-.ai/config.yaml}"

# --- Functions ---

# Find the spec directory for a given work item ID, slug, or most recent
# Usage: find_spec_dir [work-item-id-or-slug]
# Output: prints the spec directory path to stdout (trailing slash)
# Exit codes: 0 = found, 1 = not found
find_spec_dir() {
  local input="${1:-}"

  if [[ -n "$input" ]]; then
    # Try numeric ID match first: specs/<id>-*/
    local dir
    dir=$(ls -d "${SPECS_DIR}/${input}"-*/ 2>/dev/null | head -1) || true
    if [[ -n "$dir" ]]; then
      echo "$dir"
      return 0
    fi
    # Try slug match: specs/*<input>*/
    dir=$(ls -d "${SPECS_DIR}/"*"${input}"*/ 2>/dev/null | head -1) || true
    if [[ -n "$dir" ]]; then
      echo "$dir"
      return 0
    fi
    echo "ERROR: No spec directory found for '${input}'" >&2
    return 1
  else
    # Find most recently modified spec file (bug or story flows)
    local latest
    latest=$(ls -t ${SPECS_DIR}/*/raw-bug.md 2>/dev/null | head -1) || true
    if [[ -z "$latest" ]]; then
      latest=$(ls -t ${SPECS_DIR}/*/explain.md 2>/dev/null | head -1) || true
    fi
    if [[ -z "$latest" ]]; then
      latest=$(ls -t ${SPECS_DIR}/*/raw-story.md 2>/dev/null | head -1) || true
    fi
    if [[ -n "$latest" ]]; then
      echo "$(dirname "$latest")/"
      return 0
    fi
    echo "ERROR: No spec directories found" >&2
    return 1
  fi
}

# Generate a concise 2-4 word slug from a work item title
# Usage: slugify <work-item-id> "<title>"
# Output: prints the spec directory name (e.g., "2416553-enhance-component")
slugify() {
  local id="${1:?Usage: slugify <work-item-id> \"<title>\"}"
  local title="${2:?Usage: slugify <work-item-id> \"<title>\"}"

  # Check if a spec directory already exists for this ID — reuse it
  local existing
  existing=$(ls -d "${SPECS_DIR}/${id}"-*/ 2>/dev/null | head -1 || true)
  if [[ -n "$existing" ]]; then
    basename "${existing%/}"
    return 0
  fi

  # Generate slug from title
  local stop_words="a|an|the|to|for|of|in|on|is|it|and|or|with|by|at|from|as|be|this|that|are|was|were|vs|has|have"

  local slug
  slug=$(echo "$title" \
    | sed -E 's/\[[^]]*\]//g' \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E "s/[^a-z0-9 ]/ /g" \
    | tr -s ' ' \
    | sed 's/^ //;s/ $//' \
    | tr ' ' '\n' \
    | grep -v -w -E "${stop_words}" \
    | head -4 \
    | tr '\n' '-' \
    | sed 's/-$//' || true)

  echo "${id}-${slug}"
}

# Simple YAML value reader (key: value on its own line)
# Usage: yaml_val <key>
# Output: prints the value (trimmed, unquoted)
yaml_val() {
  local key="$1"
  if [ -f "$CONFIG_FILE" ]; then
    grep -E "^\s*${key}:" "$CONFIG_FILE" 2>/dev/null | head -1 | sed "s/^[^:]*:\s*//" | sed 's/^"//' | sed 's/"$//' | xargs
  fi
}

# Scalar value under a named top-level block (2-space indented child key).
# Usage: yaml_block_val <block> <key>   e.g. yaml_block_val project platform
# Stops at the next top-level (column-0) key so it never bleeds into siblings.
yaml_block_val() {
  local block="$1" key="$2"
  [ -f "${CONFIG_FILE:-}" ] || return 0
  awk -v blk="$block" -v k="$key" '
    $0 ~ "^"blk":[[:space:]]*$" { inb=1; next }
    inb && /^[^[:space:]#]/ { inb=0 }
    inb && $0 ~ "^[[:space:]]+"k":" {
      sub("^[[:space:]]+"k":[[:space:]]*", ""); sub(/[[:space:]]+#.*$/, ""); gsub(/^"|"$/, ""); print; exit
    }
  ' "$CONFIG_FILE" | xargs
}

# Emit the top-level repos: list as TSV rows: name<TAB>role<TAB>platform<TAB>brand<TAB>ado-project
# Missing fields are emitted empty. List items are `  - name: X` with 4-space child keys.
# Usage: repos_table
repos_table() {
  [ -f "${CONFIG_FILE:-}" ] || return 0
  awk '
    function flush() {
      if (name != "") printf "%s\t%s\t%s\t%s\t%s\n", name, role, platform, brand, adoproj
      name=""; role=""; platform=""; brand=""; adoproj=""
    }
    /^repos:[[:space:]]*$/ { inr=1; next }
    inr && /^[^[:space:]#-]/ { flush(); inr=0 }
    inr && /^[[:space:]]*-[[:space:]]*name:/ { flush(); sub(/^[[:space:]]*-[[:space:]]*name:[[:space:]]*/, ""); sub(/[[:space:]]+#.*$/, ""); gsub(/^"|"$/, ""); name=$0; next }
    inr && /^[[:space:]]+role:/        { v=$0; sub(/^[[:space:]]+role:[[:space:]]*/, "", v); sub(/[[:space:]]+#.*$/, "", v); gsub(/^"|"$/, "", v); role=v; next }
    inr && /^[[:space:]]+platform:/     { v=$0; sub(/^[[:space:]]+platform:[[:space:]]*/, "", v); sub(/[[:space:]]+#.*$/, "", v); gsub(/^"|"$/, "", v); platform=v; next }
    inr && /^[[:space:]]+brand:/        { v=$0; sub(/^[[:space:]]+brand:[[:space:]]*/, "", v); sub(/[[:space:]]+#.*$/, "", v); gsub(/^"|"$/, "", v); brand=v; next }
    inr && /^[[:space:]]+ado-project:/  { v=$0; sub(/^[[:space:]]+ado-project:[[:space:]]*/, "", v); sub(/[[:space:]]+#.*$/, "", v); gsub(/^"|"$/, "", v); adoproj=v; next }
    END { if (inr) flush() }
  ' "$CONFIG_FILE"
}

# Check that a required file exists
# Usage: require_file <path> [label]
# Exit codes: 0 = exists, 1 = missing (prints error)
require_file() {
  local path="$1" label="${2:-$1}"
  if [ ! -f "$path" ]; then
    echo "ERROR: Required file missing: $label ($path)" >&2
    return 1
  fi
}

# Check that a required directory exists
# Usage: require_dir <path> [label]
# Exit codes: 0 = exists, 1 = missing (prints error)
require_dir() {
  local path="$1" label="${2:-$1}"
  if [ ! -d "$path" ]; then
    echo "ERROR: Required directory missing: $label ($path)" >&2
    return 1
  fi
}

# Resolve one AEM instance's URL/user/pass from the AEM_INSTANCES env var.
# AEM_INSTANCES is the single source of truth for AEM credentials — the same
# value the AEM MCP server reads. Format (comma-separated entries):
#   name:url:user:pass        e.g. local:http://localhost:4502:admin:admin,qa:https://qa-author.example.com:user:pass
# The URL contains colons (scheme + port), so we anchor: name = before the
# FIRST colon, pass = after the LAST colon, user = the field before pass, and
# url = everything in between. (A literal ':' in a password is unsupported —
# same limitation as the AEM MCP server's own parser.)
#
# Usage: aem_instance <name> [field]
#   field omitted  -> prints three eval-able lines: AEM_URL=... / AEM_USER=... / AEM_PASS=...
#   field=url|user|pass -> prints just that value
# Exit codes: 0 = found, 1 = AEM_INSTANCES unset or instance not found
aem_instance() {
  local name="${1:-qa}" field="${2:-}"
  local instances="${AEM_INSTANCES:-}"
  if [ -z "$instances" ]; then
    echo "ERROR: AEM_INSTANCES is not set" >&2
    return 1
  fi
  local entry rest userpass url user pass
  local IFS=','
  for entry in $instances; do
    [ "${entry%%:*}" = "$name" ] || continue
    rest="${entry#*:}"        # url:user:pass
    pass="${rest##*:}"        # after last colon
    userpass="${rest%:*}"     # url:user
    user="${userpass##*:}"    # after last colon of url:user
    url="${userpass%:*}"      # url (may contain colons)
    case "$field" in
      url)  echo "$url" ;;
      user) echo "$user" ;;
      pass) echo "$pass" ;;
      "")   printf 'AEM_URL=%s\nAEM_USER=%s\nAEM_PASS=%s\n' "$url" "$user" "$pass" ;;
      *)    echo "ERROR: unknown field '$field' (use url|user|pass)" >&2; return 1 ;;
    esac
    return 0
  done
  echo "ERROR: instance '$name' not found in AEM_INSTANCES" >&2
  return 1
}

# --- CLI dispatch (when run directly, not sourced) ---

# Detect if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  CMD="${1:-}"
  shift || true

  case "$CMD" in
    find-spec-dir)
      find_spec_dir "$@"
      ;;
    slugify)
      slugify "$@"
      ;;
    yaml-val)
      yaml_val "$@"
      ;;
    yaml-block-val)
      yaml_block_val "$@"
      ;;
    repos-table)
      repos_table "$@"
      ;;
    require-file)
      require_file "$@"
      ;;
    require-dir)
      require_dir "$@"
      ;;
    aem-instance)
      aem_instance "$@"
      ;;
    *)
      echo "Usage: dx-common.sh <command> [args...]" >&2
      echo "" >&2
      echo "Commands:" >&2
      echo "  find-spec-dir [id-or-slug]    Find spec directory" >&2
      echo "  slugify <id> \"<title>\"         Generate spec dir name" >&2
      echo "  yaml-val <key>                Read value from config.yaml" >&2
      echo "  require-file <path> [label]   Assert file exists" >&2
      echo "  require-dir <path> [label]    Assert directory exists" >&2
      echo "  aem-instance <name> [field]   Resolve url/user/pass from AEM_INSTANCES" >&2
      exit 1
      ;;
  esac
fi

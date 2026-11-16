#!/usr/bin/env bash
# dx-common.sh — Shared library for dx plugin skills
#
# Can be used two ways:
#
# 1. As a CLI (from SKILL.md instructions):
#    bash .ai/lib/dx-common.sh find-spec-dir 2416553
#    bash .ai/lib/dx-common.sh slugify 2416553 "Enhance Card Layout Switcher"
#    bash .ai/lib/dx-common.sh yaml-val build.compile
#
# 2. As a library (from other scripts):
#    source .ai/lib/dx-common.sh
#    SPEC_DIR=$(find_spec_dir "2416553")
#    SLUG=$(slugify "2416553" "Enhance Card Layout Switcher")
#    CMD=$(yaml_val "build.compile")

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

# Read a scalar value from config.yaml.
# Usage: yaml_val <key>
#   <key> is either a bare key ("compile") — first scalar match at any depth,
#   section headers skipped (prefer dotted paths: bare keys collide) — or a
#   dotted path ("dx-simple.recovery.trigger-token") resolved segment by
#   segment through the indentation tree, so it never bleeds into siblings.
# Output: prints the value, with any inline `# comment` and surrounding
#   quotes stripped. Prints nothing when the key is absent.
yaml_val() {
  local key="${1:-}"
  [ -n "$key" ] || return 0
  [ -f "${CONFIG_FILE:-}" ] || return 0
  awk -v path="$key" '
    function trim(s) { sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s }
    BEGIN { n = split(path, seg, "."); depth = 1; want = seg[1]; parent = -1; expect = -1; q = sprintf("%c", 39) }
    {
      line = $0; sub(/\r$/, "", line)
      if (line ~ /^[[:space:]]*(#|$)/) next          # blank or comment line
      match(line, /^[[:space:]]*/); indent = RLENGTH
      rest = substr(line, indent + 1)
      if (rest !~ /^[^:]+:/) next                    # not a key: line
      if (indent <= parent) exit                     # left the parent block: no match
      if (depth > 1) {                               # past depth 1, only DIRECT children count
        if (expect < 0) expect = indent              # first child of the match sets the level
        else if (indent != expect) next              # deeper: a rejected sibling subtree
      }
      k = rest; sub(/:.*$/, "", k)
      if (trim(k) != want) next
      v = rest; sub(/^[^:]*:/, "", v); v = trim(v)
      if (n == 1 && (v == "" || v ~ /^#/)) next      # bare key: skip section headers, keep looking for a scalar
      if (depth == n) {
        if (substr(v, 1, 1) == "\"") {               # double-quoted: take up to the close
          v = substr(v, 2); i = index(v, "\""); if (i > 0) v = substr(v, 1, i - 1)
        } else if (substr(v, 1, 1) == q) {           # single-quoted: same
          v = substr(v, 2); i = index(v, q); if (i > 0) v = substr(v, 1, i - 1)
        } else {                                     # bare: drop any trailing comment
          sub(/[[:space:]]+#.*$/, "", v); v = trim(v)
        }
        print v; exit
      }
      parent = indent; depth++; want = seg[depth]; expect = -1
    }
  ' "$CONFIG_FILE"
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

# --- Basic Auth for curl, from BASIC_AUTH_SITES ---
#
# BASIC_AUTH_SITES="name:url:user:pass,name2:url2:user2:pass2" — the same
# variable and rules as playwright-basic-auth.cjs (browser side), so the two
# never disagree: name = before first ':', pass = after last ':', user = before
# that, url = the middle (may contain ':'). user/pass accept %3A %2C %25
# escapes. Matching is by origin (scheme+host+port; default port, case and
# path ignored). Malformed entries are skipped, reported by index only.

# Prints the normalised origin of an http(s) URL, or returns 1.
_basic_auth_origin() {
  local url="$1" scheme rest auth
  case "$url" in
    [Hh][Tt][Tt][Pp][Ss]://*) scheme=https; rest="${url:8}" ;;
    [Hh][Tt][Tt][Pp]://*)     scheme=http;  rest="${url:7}" ;;
    *) return 1 ;;
  esac
  auth="${rest%%[/?#]*}"
  auth="${auth##*@}"
  auth="$(printf '%s' "$auth" | tr 'A-Z' 'a-z')"
  auth="${auth%:}"
  [ -n "$auth" ] || return 1
  case "$scheme:$auth" in
    https:*:443) auth="${auth%:443}" ;;
    http:*:80)   auth="${auth%:80}" ;;
  esac
  printf '%s://%s' "$scheme" "$auth"
}

# Percent-decodes $1; returns 1 on a malformed escape. No % means used as-is.
_basic_auth_decode() {
  local s="$1" out="" hex
  case "$s" in *%*) ;; *) printf '%s' "$s"; return 0 ;; esac
  while [ -n "$s" ]; do
    case "$s" in
      %*)
        hex="${s:1:2}"
        case "$hex" in
          [0-9A-Fa-f][0-9A-Fa-f]) ;;
          *) return 1 ;;
        esac
        out="$out$(printf "\\x$hex")"
        s="${s:3}" ;;
      *) out="$out${s:0:1}"; s="${s:1}" ;;
    esac
  done
  printf '%s' "$out"
}

# Usage: curl_basic_auth <url> [curl-args...]
# Runs: curl [curl-args...] [-u user:pass] <url>   (-u only for a listed origin)
# Credentials are never printed. Exit code is curl's.
curl_basic_auth() {
  local url="${1:?curl_basic_auth: url required}"
  shift
  local want entry i=0 first last name pass rest mid eurl user eorigin
  local cred=""
  want="$(_basic_auth_origin "$url")" || want=""
  if [ -n "${BASIC_AUTH_SITES:-}" ]; then
    local IFS=',' had_noglob=0
    case $- in *f*) had_noglob=1 ;; esac
    set -f  # unquoted split below must not glob-expand a '*' or '?' in a value
    for entry in $BASIC_AUTH_SITES; do
      first="${entry%%:*}"; rest="${entry#*:}"
      if [ "$first" = "$entry" ] || [ "${rest%:*}" = "$rest" ]; then
        echo "BASIC_AUTH_SITES: entry $i skipped (expected name:url:user:pass)" >&2; i=$((i+1)); continue
      fi
      name="$first"; pass="${rest##*:}"; rest="${rest%:*}"
      if [ "${rest%:*}" = "$rest" ]; then
        echo "BASIC_AUTH_SITES: entry $i skipped (expected name:url:user:pass)" >&2; i=$((i+1)); continue
      fi
      eurl="${rest%:*}"; user="${rest##*:}"
      if [ -z "$name" ] || ! eorigin="$(_basic_auth_origin "$eurl")" \
         || ! user="$(_basic_auth_decode "$user")" || ! pass="$(_basic_auth_decode "$pass")"; then
        echo "BASIC_AUTH_SITES: entry $i skipped (expected name:url:user:pass)" >&2; i=$((i+1)); continue
      fi
      if [ -z "$cred" ] && [ -n "$want" ] && [ "$eorigin" = "$want" ]; then
        cred="$user:$pass"
      fi
      i=$((i+1))
    done
    [ "$had_noglob" = 1 ] || set +f
  fi
  if [ -n "$cred" ]; then
    # -u in argv is briefly visible in `ps` on this host. Accepted: `-K -`
    # (config on stdin) would break callers that pipe a body to curl. curl
    # does not forward -u to a different host on redirect.
    curl "$@" -u "$cred" "$url"
  else
    curl "$@" "$url"
  fi
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
    curl-basic-auth)
      curl_basic_auth "$@"
      exit $?
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
      echo "  curl-basic-auth <url> [curl-args...]  curl with -u from BASIC_AUTH_SITES when url's origin is listed" >&2
      exit 1
      ;;
  esac
fi

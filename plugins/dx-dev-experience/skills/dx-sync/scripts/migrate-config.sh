#!/usr/bin/env bash
# migrate-config.sh — Versioned config migrations for .ai/config.yaml
#
# Usage:
#   source migrate-config.sh
#   run_migrations "/path/to/.ai/config.yaml" "2.48.0"
#
# Each migrate_to_X_Y_Z() function is idempotent — safe to re-run.
# Returns 0 if changes were made, 1 if already up to date.

# ─── Helpers ────────────────────────────────────────────────────────────────

# Compare semver: returns 0 if $1 < $2
version_lt() {
  local a_major a_minor a_patch b_major b_minor b_patch
  IFS='.' read -r a_major a_minor a_patch <<< "$1"
  IFS='.' read -r b_major b_minor b_patch <<< "$2"
  a_major=$((10#${a_major:-0})); a_minor=$((10#${a_minor:-0})); a_patch=$((10#${a_patch:-0}))
  b_major=$((10#${b_major:-0})); b_minor=$((10#${b_minor:-0})); b_patch=$((10#${b_patch:-0}))
  if [ "$a_major" -lt "$b_major" ]; then return 0; fi
  if [ "$a_major" -gt "$b_major" ]; then return 1; fi
  if [ "$a_minor" -lt "$b_minor" ]; then return 0; fi
  if [ "$a_minor" -gt "$b_minor" ]; then return 1; fi
  if [ "$a_patch" -lt "$b_patch" ]; then return 0; fi
  return 1  # equal or greater
}

# Read dx.version from config (returns "0.0.0" if not set)
get_config_version() {
  local config="$1"
  local ver
  ver=$(awk '/^dx:/{found=1; next} found && /^[a-z]/{found=0} found && /version:/{print $2; exit}' "$config" 2>/dev/null | tr -d '"')
  echo "${ver:-0.0.0}"
}

# Set dx.version in config
set_config_version() {
  local config="$1" version="$2"

  if grep -q '^dx:' "$config" 2>/dev/null; then
    # dx: section exists — check if version line exists
    if awk '/^dx:/{found=1; next} found && /^[a-z]/{exit} found && /version:/{print; exit}' "$config" | grep -q 'version:'; then
      # Update existing version line (only within dx: section)
      local tmpfile="${config}.ver.tmp"
      awk -v ver="$version" '
        /^dx:/ { in_dx=1; print; next }
        in_dx && /^[a-z]/ && !/^[[:space:]]/ { in_dx=0 }
        in_dx && /version:/ { print "  version: \"" ver "\""; next }
        { print }
      ' "$config" > "$tmpfile"
      mv "$tmpfile" "$config"
    else
      # dx: exists but no version line — insert after dx:
      local tmpfile="${config}.ver.tmp"
      awk -v ver="$version" '
        /^dx:/ { print; print "  version: \"" ver "\""; next }
        { print }
      ' "$config" > "$tmpfile"
      mv "$tmpfile" "$config"
    fi
  else
    # No dx: section — insert before project:
    local tmpfile="${config}.ver.tmp"
    awk -v ver="$version" '
      /^project:/ && !done { print "dx:"; print "  version: \"" ver "\""; print ""; done=1 }
      { print }
    ' "$config" > "$tmpfile"
    mv "$tmpfile" "$config"
  fi
}

# ─── Migration: 2.48.0 ─────────────────────────────────────────────────────
# Consolidate aem.repos → top-level repos:
# - Move entries from aem: repos: to top-level repos: section
# - Map local-path → path
# - Preserve platform, ado-project fields
# - Remove aem.repos section and aem.current-repo

migrate_to_2_48_0() {
  local config="$1"

  # ── Check if migration needed ──
  # Look for aem.repos (repos: indented under aem:)
  local has_aem_repos=false
  local in_aem=false
  while IFS= read -r line; do
    [[ "$line" =~ ^aem: ]] && in_aem=true && continue
    $in_aem && [[ "$line" =~ ^[a-z] ]] && in_aem=false
    $in_aem && [[ "$line" =~ ^[[:space:]]+repos: ]] && has_aem_repos=true && break
  done < "$config"

  if ! $has_aem_repos; then
    return 1  # Nothing to migrate
  fi

  echo "    Migrating aem.repos → top-level repos: ..."

  # ── Extract entries from aem.repos ──
  local entries=()
  local in_aem=false in_aem_repos=false
  local cur_name="" cur_path="" cur_platform="" cur_project=""

  flush_aem_entry() {
    if [[ -n "$cur_name" ]]; then
      entries+=("${cur_name}|${cur_path}|${cur_platform}|${cur_project}")
    fi
    cur_name="" cur_path="" cur_platform="" cur_project=""
  }

  while IFS= read -r line; do
    [[ "$line" =~ ^aem: ]] && in_aem=true && continue
    if $in_aem && [[ "$line" =~ ^[a-z] ]]; then
      in_aem=false; in_aem_repos=false
      flush_aem_entry
    fi
    if $in_aem && [[ "$line" =~ ^[[:space:]]+repos: ]]; then
      in_aem_repos=true; continue
    fi
    # End of repos sub-list (next aem-level key)
    if $in_aem_repos && [[ "$line" =~ ^[[:space:]]{2}[a-z] && ! "$line" =~ ^[[:space:]]{4} ]]; then
      in_aem_repos=false; flush_aem_entry
    fi

    if $in_aem_repos; then
      if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*name:[[:space:]]*(.*) ]]; then
        flush_aem_entry
        cur_name=$(echo "${BASH_REMATCH[1]}" | tr -d '"' | xargs)
      elif [[ "$line" =~ ^[[:space:]]*(local-path|path):[[:space:]]*(.*) ]]; then
        cur_path=$(echo "${BASH_REMATCH[2]}" | tr -d '"' | xargs)
      elif [[ "$line" =~ ^[[:space:]]*platform:[[:space:]]*(.*) ]]; then
        cur_platform=$(echo "${BASH_REMATCH[1]}" | tr -d '"' | xargs)
      elif [[ "$line" =~ ^[[:space:]]*ado-project:[[:space:]]*(.*) ]]; then
        cur_project=$(echo "${BASH_REMATCH[1]}" | tr -d '"' | xargs)
      fi
    fi
  done < "$config"
  flush_aem_entry

  if [[ ${#entries[@]} -eq 0 ]]; then
    return 1
  fi

  # ── Build YAML for new top-level repos entries ──
  local new_yaml=""
  for entry in "${entries[@]}"; do
    IFS='|' read -r name path platform project <<< "$entry"
    new_yaml+="  - name: ${name}"$'\n'
    [[ -n "$path" ]] && new_yaml+="    path: ${path}"$'\n'
    new_yaml+="    role: backend"$'\n'
    [[ -n "$platform" ]] && new_yaml+="    platform: ${platform}"$'\n'
    [[ -n "$project" ]] && new_yaml+="    ado-project: \"${project}\""$'\n'
  done

  # ── Check if top-level repos: exists ──
  local has_top_repos=false
  while IFS= read -r line; do
    [[ "$line" =~ ^repos: ]] && has_top_repos=true && break
  done < "$config"

  local tmpfile="${config}.mig.tmp"

  # ── Merge: collect existing top-level repos, enrich with aem data ──
  # Uses pipe-delimited entries (bash 3.2 compatible — no associative arrays).
  # Format: name|path|role|platform|project

  local merged=()

  # Helper: find entry by name, return index or -1
  find_repo() {
    local target="$1" i=0
    for m in "${merged[@]}"; do
      local mname="${m%%|*}"
      [[ "$mname" == "$target" ]] && echo "$i" && return
      i=$((i + 1))
    done
    echo "-1"
  }

  if $has_top_repos; then
    # Parse existing top-level repos
    local in_tr=false tr_name="" tr_path="" tr_role="" tr_platform="" tr_project=""
    while IFS= read -r line; do
      [[ "$line" =~ ^repos: ]] && in_tr=true && continue
      if $in_tr && [[ "$line" =~ ^[a-z] ]]; then
        [[ -n "$tr_name" ]] && merged+=("${tr_name}|${tr_path}|${tr_role}|${tr_platform}|${tr_project}")
        tr_name=""
        break
      fi
      $in_tr && [[ "$line" =~ ^[[:space:]]*# ]] && continue
      if $in_tr && [[ "$line" =~ ^[[:space:]]*-[[:space:]]*name:[[:space:]]*(.*) ]]; then
        [[ -n "$tr_name" ]] && merged+=("${tr_name}|${tr_path}|${tr_role}|${tr_platform}|${tr_project}")
        tr_name=$(echo "${BASH_REMATCH[1]}" | tr -d '"' | xargs)
        tr_path="" tr_role="" tr_platform="" tr_project=""
      elif $in_tr && [[ -n "$tr_name" ]]; then
        if [[ "$line" =~ ^[[:space:]]*path:[[:space:]]*(.*) ]]; then
          tr_path=$(echo "${BASH_REMATCH[1]}" | tr -d '"' | xargs)
        elif [[ "$line" =~ ^[[:space:]]*role:[[:space:]]*(.*) ]]; then
          tr_role=$(echo "${BASH_REMATCH[1]}" | tr -d '"' | xargs)
        elif [[ "$line" =~ ^[[:space:]]*platform:[[:space:]]*(.*) ]]; then
          tr_platform=$(echo "${BASH_REMATCH[1]}" | tr -d '"' | xargs)
        elif [[ "$line" =~ ^[[:space:]]*ado-project:[[:space:]]*(.*) ]]; then
          tr_project=$(echo "${BASH_REMATCH[1]}" | tr -d '"' | xargs)
        fi
      fi
    done < "$config"
    [[ -n "$tr_name" ]] && merged+=("${tr_name}|${tr_path}|${tr_role}|${tr_platform}|${tr_project}")
  fi

  # Merge aem.repos data: enrich existing entries, add new ones
  for entry in "${entries[@]}"; do
    IFS='|' read -r name path platform project <<< "$entry"
    local idx
    idx=$(find_repo "$name")
    if [[ "$idx" -ge 0 ]]; then
      # Enrich existing entry (aem.repos values win for path/platform/project)
      IFS='|' read -r _n _p _r _pl _pr <<< "${merged[$idx]}"
      [[ -n "$path" ]] && _p="$path"
      [[ -n "$platform" ]] && _pl="$platform"
      [[ -n "$project" ]] && _pr="$project"
      [[ -z "$_r" ]] && _r="backend"
      merged[$idx]="${_n}|${_p}|${_r}|${_pl}|${_pr}"
    else
      local role="backend"
      merged+=("${name}|${path}|${role}|${platform}|${project}")
    fi
  done

  # Build merged repos YAML
  local merged_file="${config}.merged.tmp"
  {
    echo "repos:"
    for m in "${merged[@]}"; do
      IFS='|' read -r name path role platform project <<< "$m"
      echo "  - name: ${name}"
      [[ -n "$path" ]] && echo "    path: ${path}"
      [[ -n "$role" ]] && echo "    role: ${role}"
      [[ -n "$platform" ]] && echo "    platform: ${platform}"
      [[ -n "$project" ]] && echo "    ado-project: \"${project}\""
    done
    echo ""
  } > "$merged_file"

  if $has_top_repos; then
    # Remove old top-level repos: section and insert merged version
    awk '
      /^repos:/ { skip=1; next }
      skip && /^[a-z]/ && !/^[[:space:]]/ { skip=0 }
      skip && /^$/ { next }
      skip { next }
      { print }
    ' "$config" > "$tmpfile"
    # Insert merged repos before aem: (or at end if no aem)
    local tmpfile2="${config}.mig2.tmp"
    if grep -q '^aem:' "$tmpfile"; then
      awk '
        /^aem:/ && !inserted {
          while ((getline line < "'"$merged_file"'") > 0) print line
          inserted=1
        }
        { print }
      ' "$tmpfile" > "$tmpfile2"
    else
      cat "$tmpfile" > "$tmpfile2"
      cat "$merged_file" >> "$tmpfile2"
    fi
    mv "$tmpfile2" "$config"
    rm -f "$tmpfile"
  else
    # No top-level repos: — insert before aem:
    awk '
      /^aem:/ && !inserted {
        while ((getline line < "'"$merged_file"'") > 0) print line
        inserted=1
      }
      { print }
    ' "$config" > "$tmpfile"
    mv "$tmpfile" "$config"
  fi
  rm -f "$merged_file"

  # ── Remove aem.repos section ──
  tmpfile="${config}.mig.tmp"
  awk '
    /^aem:/ { in_aem=1 }
    in_aem && /^[a-z]/ && !/^aem:/ { in_aem=0 }
    in_aem && /^  repos:/ { skip=1; next }
    skip && /^  [a-z]/ && !/^    / { skip=0 }
    skip && /^[a-z]/ { skip=0 }
    skip { next }
    { print }
  ' "$config" > "$tmpfile"
  mv "$tmpfile" "$config"

  # ── Remove aem.current-repo ──
  tmpfile="${config}.mig.tmp"
  awk '
    /^aem:/ { in_aem=1 }
    in_aem && /^[a-z]/ && !/^aem:/ { in_aem=0 }
    in_aem && /^  current-repo:/ { next }
    { print }
  ' "$config" > "$tmpfile"
  mv "$tmpfile" "$config"

  # ── Clean up old comment ──
  sed -i.bak '/^# Cross-repo awareness$/d' "$config"
  rm -f "${config}.bak"

  echo "    ✓ Migrated ${#entries[@]} repos to top-level repos:"
  echo "    ✓ Removed aem.repos and aem.current-repo"
  return 0
}

# ─── Migration registry ────────────────────────────────────────────────────
# Add new migrations at the bottom. Format: "version|function_name"

MIGRATIONS=(
  "2.48.0|migrate_to_2_48_0"
)

# ─── Driver ─────────────────────────────────────────────────────────────────

run_migrations() {
  local config="$1" target_version="$2"
  local current_version
  current_version=$(get_config_version "$config")
  local any_changes=false

  for migration in "${MIGRATIONS[@]}"; do
    IFS='|' read -r ver func <<< "$migration"

    # Skip if already at or past this version
    if ! version_lt "$current_version" "$ver"; then
      continue
    fi

    # Skip if beyond target
    if version_lt "$target_version" "$ver"; then
      continue
    fi

    echo "  Migration $ver:"
    if $func "$config"; then
      any_changes=true
    else
      echo "    — already up to date"
    fi
  done

  # Update version stamp
  if $any_changes || version_lt "$current_version" "$target_version"; then
    set_config_version "$config" "$target_version"
    echo "  dx.version → $target_version"
  fi

  $any_changes && return 0 || return 1
}

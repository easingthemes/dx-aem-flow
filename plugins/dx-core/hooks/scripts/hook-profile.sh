#!/usr/bin/env bash
# hook-profile.sh — Shared utility for DX_HOOK_PROFILE support
# Source this file in hook scripts to get profile-aware execution.
#
# Profiles:
#   minimal  — Only blocking safety hooks (branch-guard). Skip informational hooks.
#   standard — Default. All hooks enabled.
#   strict   — All hooks + extra guardrails (future use).
#
# Usage in a hook script:
#   source "$(dirname "$0")/hook-profile.sh"
#   require_profile "standard" || exit 0   # skip if profile is below standard
#
# Environment:
#   DX_HOOK_PROFILE  — minimal | standard | strict (default: standard)

DX_HOOK_PROFILE="${DX_HOOK_PROFILE:-standard}"

# Map profiles to numeric levels for comparison
_dx_profile_level() {
  case "$1" in
    minimal) echo 1 ;;
    standard) echo 2 ;;
    strict) echo 3 ;;
    *) echo 2 ;; # default to standard
  esac
}

# Returns 0 (true) if current profile meets or exceeds required level.
# Returns 1 (false) if current profile is below required level.
require_profile() {
  local required="$1"
  local current_level=$(_dx_profile_level "$DX_HOOK_PROFILE")
  local required_level=$(_dx_profile_level "$required")
  [ "$current_level" -ge "$required_level" ]
}

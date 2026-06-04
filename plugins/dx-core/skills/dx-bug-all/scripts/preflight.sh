#!/usr/bin/env bash
# preflight.sh — Validate the run environment BEFORE any reads or writes.
# /dx-bug-all variant. Checks:
#   1. CLAUDE_PLUGIN_ROOT is set and resolves to a dir containing this script
#      (catches Agent SDK plugin-load misconfig fast).
#   2. .ai/config.yaml exists
#   3. One of build.compile / build.compile-fast / build.command is declared
#      (/dx-bug-fix runs a build).
#   4. .ai/lib/dx-common.sh exists
#   5. (Pipeline mode) AEM_QA_URL/USER/PASSWORD — WARN only (verify is the only
#      AEM consumer and /dx-bug-all treats verify as non-blocking). Never fatal.
#
# Usage: preflight.sh
# Exit codes:
#   0  — all hard checks pass (AEM-env warnings do not fail)
#   6  — config missing or invalid
#   9  — CLAUDE_PLUGIN_ROOT not resolvable

set -uo pipefail

ERRORS=()

# 1. CLAUDE_PLUGIN_ROOT — every other script call in the skill uses this.
if [[ -z "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
  echo "PREFLIGHT-FAILED: CLAUDE_PLUGIN_ROOT not set in environment" >&2
  echo "  - check Agent SDK plugin loader and PLUGIN_BASE_DIR" >&2
  exit 9
fi
if [[ ! -f "$CLAUDE_PLUGIN_ROOT/skills/dx-bug-all/scripts/preflight.sh" ]]; then
  echo "PREFLIGHT-FAILED: CLAUDE_PLUGIN_ROOT='$CLAUDE_PLUGIN_ROOT' does not contain dx-bug-all skill" >&2
  echo "  - expected file: \$CLAUDE_PLUGIN_ROOT/skills/dx-bug-all/scripts/preflight.sh" >&2
  exit 9
fi

# 2. config.yaml
[[ -f .ai/config.yaml ]] || ERRORS+=("missing .ai/config.yaml — run /dx-init")

# 3. Build command available (/dx-bug-fix builds) — accept compile, compile-fast,
#    or command (legacy: many consumer repos only declare build.command).
if [[ -f .ai/config.yaml ]]; then
  if ! grep -qE '^\s*(compile(-fast)?|command):' .ai/config.yaml; then
    ERRORS+=("no build.compile, build.compile-fast, or build.command in .ai/config.yaml")
  fi
fi

# 4. dx-common helper
if [[ ! -f .ai/lib/dx-common.sh ]]; then
  ERRORS+=("missing .ai/lib/dx-common.sh — re-run /dx-init to regenerate")
fi

# 5. Pipeline-mode AEM env — WARNING only (verify degrades to blocked/warn; the
#    fix still proceeds on triage alone, per /dx-bug-all's design).
if [[ "${DX_PIPELINE_MODE:-}" == "true" ]]; then
  for V in AEM_QA_URL AEM_QA_USER AEM_QA_PASSWORD; do
    [[ -n "${!V:-}" ]] || echo "PREFLIGHT-WARN: env $V not set — /dx-bug-verify will degrade to blocked/warn." >&2
  done
fi

if [[ "${#ERRORS[@]}" -gt 0 ]]; then
  echo "PREFLIGHT-FAILED:" >&2
  printf '  - %s\n' "${ERRORS[@]}" >&2
  exit 6
fi

echo "OK: preflight passed" >&2

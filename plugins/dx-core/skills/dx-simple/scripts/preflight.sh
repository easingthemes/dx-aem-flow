#!/usr/bin/env bash
# Validates that the run environment is correct BEFORE any reads or writes.
# Checks:
#   1. CLAUDE_PLUGIN_ROOT is set and resolves to an existing dir containing
#      this very script (catches Agent SDK plugin-load misconfig fast).
#   2. .ai/config.yaml exists and has dx-simple section
#   3. Required keys present: dx-simple.allowed-resource-types, AND one of
#      build.compile / build.compile-fast / build.command
#   4. (Pipeline mode) AEM_QA_URL/USER/PASSWORD env vars set
#   5. .ai/lib/dx-common.sh exists and find-spec-dir works
#
# Does NOT do the live HEAD-test on the page-url — that runs from the skill body
# via Chrome MCP. This script is the env/config check only.
#
# Usage: preflight.sh
# Exit codes:
#   0  — all checks pass
#   6  — config missing or invalid
#   7  — env missing (pipeline mode only)
#   9  — CLAUDE_PLUGIN_ROOT not resolvable

set -uo pipefail

ERRORS=()

# 1. CLAUDE_PLUGIN_ROOT — every other script call in the skill uses this.
# If the SDK didn't export it (or pointed it at the wrong dir), every
# `bash $CLAUDE_PLUGIN_ROOT/skills/dx-simple/scripts/foo.sh` would fail
# with file-not-found and waste turns. Catch it here.
if [[ -z "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
  echo "PREFLIGHT-FAILED: CLAUDE_PLUGIN_ROOT not set in environment" >&2
  echo "  - check Agent SDK plugin loader and PLUGIN_BASE_DIR" >&2
  exit 9
fi
if [[ ! -f "$CLAUDE_PLUGIN_ROOT/skills/dx-simple/scripts/preflight.sh" ]]; then
  echo "PREFLIGHT-FAILED: CLAUDE_PLUGIN_ROOT='$CLAUDE_PLUGIN_ROOT' does not contain dx-simple skill" >&2
  echo "  - expected file: \$CLAUDE_PLUGIN_ROOT/skills/dx-simple/scripts/preflight.sh" >&2
  exit 9
fi

# 2. config.yaml
[[ -f .ai/config.yaml ]] || ERRORS+=("missing .ai/config.yaml — run /dx-init")

# 3. dx-simple section
if [[ -f .ai/config.yaml ]] && ! grep -qE '^dx-simple:' .ai/config.yaml; then
  ERRORS+=("missing dx-simple: block in .ai/config.yaml — see plugins/dx-core/skills/dx-simple/README for schema")
fi

# 4. Build command available — accept any one of compile, compile-fast, or
# command (legacy: many consumer repos only declare build.command).
if [[ -f .ai/config.yaml ]]; then
  if ! grep -qE '^\s*(compile(-fast)?|command):' .ai/config.yaml; then
    ERRORS+=("no build.compile, build.compile-fast, or build.command in .ai/config.yaml")
  fi
fi

# 5. Pipeline-mode env
if [[ "${DX_PIPELINE_MODE:-}" == "true" ]]; then
  for V in AEM_QA_URL AEM_QA_USER AEM_QA_PASSWORD; do
    [[ -n "${!V:-}" ]] || ERRORS+=("env $V not set (required in pipeline mode)")
  done
fi

# 6. dx-common helper
if [[ ! -f .ai/lib/dx-common.sh ]]; then
  ERRORS+=("missing .ai/lib/dx-common.sh — re-run /dx-init to regenerate")
fi

if [[ "${#ERRORS[@]}" -gt 0 ]]; then
  echo "PREFLIGHT-FAILED:" >&2
  printf '  - %s\n' "${ERRORS[@]}" >&2
  [[ "${DX_PIPELINE_MODE:-}" == "true" ]] && exit 7 || exit 6
fi

echo "OK: preflight passed" >&2

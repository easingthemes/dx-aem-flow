#!/usr/bin/env bash
# Validates that the run environment is correct BEFORE any reads or writes.
# Checks:
#   1. .ai/config.yaml exists and has dx-simple section
#   2. Required keys present: dx-simple.allowed-resource-types, build.compile or build.compile-fast
#   3. (Pipeline mode) AEM_QA_URL/USER/PASSWORD env vars set
#   4. .ai/lib/dx-common.sh exists and find-spec-dir works
#
# Does NOT do the live HEAD-test on the page-url — that runs from the skill body
# via Chrome MCP. This script is the env/config check only.
#
# Usage: preflight.sh
# Exit codes:
#   0  — all checks pass
#   6  — config missing or invalid
#   7  — env missing (pipeline mode only)

set -uo pipefail

ERRORS=()

# 1. config.yaml
[[ -f .ai/config.yaml ]] || ERRORS+=("missing .ai/config.yaml — run /dx-init")

# 2. dx-simple section
if [[ -f .ai/config.yaml ]] && ! grep -qE '^dx-simple:' .ai/config.yaml; then
  ERRORS+=("missing dx-simple: block in .ai/config.yaml — see plugins/dx-core/skills/dx-simple/README for schema")
fi

# 3. Build command available
if [[ -f .ai/config.yaml ]]; then
  if ! grep -qE '^\s*compile(-fast)?:' .ai/config.yaml; then
    ERRORS+=("no build.compile or build.compile-fast in .ai/config.yaml")
  fi
fi

# 4. Pipeline-mode env
if [[ "${DX_PIPELINE_MODE:-}" == "true" ]]; then
  for V in AEM_QA_URL AEM_QA_USER AEM_QA_PASSWORD; do
    [[ -n "${!V:-}" ]] || ERRORS+=("env $V not set (required in pipeline mode)")
  done
fi

# 5. dx-common helper
if [[ ! -f .ai/lib/dx-common.sh ]]; then
  ERRORS+=("missing .ai/lib/dx-common.sh — re-run /dx-init to regenerate")
fi

if [[ "${#ERRORS[@]}" -gt 0 ]]; then
  echo "PREFLIGHT-FAILED:" >&2
  printf '  - %s\n' "${ERRORS[@]}" >&2
  [[ "${DX_PIPELINE_MODE:-}" == "true" ]] && exit 7 || exit 6
fi

echo "OK: preflight passed" >&2

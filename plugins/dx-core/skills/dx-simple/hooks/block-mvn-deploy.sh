#!/usr/bin/env bash
# PreToolUse hook on Bash. Blocks mvn invocations that would deploy to AEM
# (autoInstallPackage / clean install with PautoInstallPackage profile) when
# DX_PIPELINE_MODE=true. Allows mvn compile, mvn test, mvn package.
#
# Receives the tool input JSON on stdin; exit 0 = allow, exit 2 = block.

set -uo pipefail

# Hooks receive a JSON object with the tool input. The `command` field is
# the bash command about to be executed.
INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.input.command // ""' 2>/dev/null || echo "")

# If we can't parse, allow (don't block on plumbing failures).
[[ -z "$CMD" ]] && exit 0

# Only restrict in pipeline mode
[[ "${DX_PIPELINE_MODE:-}" != "true" ]] && exit 0

# Look for the dangerous patterns
if echo "$CMD" | grep -qE 'mvn[^|;&]*(-PautoInstallPackage|autoInstallPackage|clean install([^a-zA-Z]|$))' ; then
  echo "BLOCKED: dx-simple does not allow mvn deploy in pipeline mode." >&2
  echo "Detected: $CMD" >&2
  echo "Use build.compile or build.compile-fast (e.g., 'mvn compile -pl ui.frontend,core -am')." >&2
  exit 2
fi

exit 0

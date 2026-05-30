#!/usr/bin/env bash
# Child-side repo identity guard for /dx-simple (TODO #142).
# Compares the ticket's declared target (platform/brand/scope, from the parsed
# simple block) against THIS repo's self-identity (project.role/platform/brand
# in .ai/config.yaml) and decides whether this run should proceed.
#
# Self-identity uses scalar top-level fields only (no repos[] list parsing) —
# this repo is never listed in its own repos[].
#
# Usage: repo-guard.sh <simple-block.yaml> <config.yaml>
# Stdout (key=value, captured by the skill):
#   DECISION=proceed|abort
#   REASON=<human text>          (abort only)
#   AUTHORING_OWNER=true|false   (proceed only)
# Exit codes: 0 = proceed, 3 = abort (wrong target).
set -euo pipefail

BLOCK="${1:?simple-block.yaml required}"
export CONFIG_FILE="${2:?config.yaml path required}"
LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../data/lib" && pwd)/dx-common.sh"
# shellcheck source=/dev/null
source "$LIB"

# --- ticket target (from parsed block; blank if not declared) ---
t_platform=$(grep -E '^platform:' "$BLOCK" 2>/dev/null | head -1 | sed 's/^platform:[[:space:]]*//' | xargs || true)
t_brand=$(grep -E '^brand:' "$BLOCK" 2>/dev/null | head -1 | sed 's/^brand:[[:space:]]*//' | xargs || true)
t_scope=$(grep -E '^scope:' "$BLOCK" 2>/dev/null | head -1 | sed 's/^scope:[[:space:]]*//' | xargs || true)

# --- self identity (scalars) ---
s_role=$(yaml_block_val project role)
s_platform=$(yaml_block_val project platform)
[ -z "$s_platform" ] && s_platform=$(yaml_block_val aem platform)   # fallback to legacy aem.platform
s_brand=$(yaml_block_val project brand)
author_url=$(yaml_block_val aem author-url)

# normalize role -> fe|be|both
case "$s_role" in
  frontend) self_cap=fe ;;
  backend)  self_cap=be ;;
  fullstack) self_cap=both ;;
  *) self_cap=unknown ;;
esac

emit_abort() { echo "DECISION=abort"; echo "REASON=$1"; exit 3; }

# 1. Wrong platform — strongest guard (tickets never span platforms).
if [ -n "$t_platform" ] && [ -n "$s_platform" ] && [ "$t_platform" != "$s_platform" ]; then
  emit_abort "Ticket targets platform '$t_platform' but this repo is platform '$s_platform'. No action taken — trigger the '$t_platform' pipeline."
fi

# 2. Wrong brand — only meaningful for a frontend repo with a declared brand.
if [ "$self_cap" = "fe" ] && [ -n "$t_brand" ] && [ -n "$s_brand" ] && [ "$t_brand" != "$s_brand" ]; then
  emit_abort "Ticket targets brand '$t_brand' but this repo is brand '$s_brand'. No action taken — trigger the '$t_brand' frontend pipeline."
fi

# 3. Wrong role — explicit fe/be scope that this single-capability repo cannot serve.
if [ "$self_cap" = "fe" ] && [ "$t_scope" = "be" ]; then
  emit_abort "Ticket scope is backend-only but this is a frontend repo. No action taken — trigger the backend pipeline."
fi
if [ "$self_cap" = "be" ] && [ "$t_scope" = "fe" ]; then
  emit_abort "Ticket scope is frontend-only but this is a backend repo. No action taken — trigger the frontend pipeline."
fi

# 4. Proceed. Authoring owner = this repo has AEM author access.
if [ -n "$author_url" ]; then echo "DECISION=proceed"; echo "AUTHORING_OWNER=true"
else echo "DECISION=proceed"; echo "AUTHORING_OWNER=false"; fi
exit 0

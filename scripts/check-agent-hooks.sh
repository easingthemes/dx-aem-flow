#!/usr/bin/env bash
# check-agent-hooks.sh — Copilot agent templates that can run a shell carry the branch guard.
#
# Copilot CLI v1.0.97+ runs `hooks:` declared in a custom agent's frontmatter
# while that agent is selected (TODO #245). `.github/hooks/hooks.json` is the
# repo-wide guard, but it only loads in a trusted folder or with an opt-in env
# var; the agent-scoped block travels with the agent file itself.
#
# Rule: a template whose frontmatter grants a shell (`runCommands`, `execute`,
# `terminal`, or no `tools:` key at all = every tool) must contain the canonical
# block from plugins/dx-core/templates/hooks/agent-branch-guard.yaml verbatim.
# Verbatim, because command hooks are fail-closed on Copilot: a drifted copy
# that errors denies every tool call of that agent.
#
# Usage: check-agent-hooks.sh [repo-root]   (default: this repo)

set -uo pipefail

ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
CANON_FILE="$ROOT/plugins/dx-core/templates/hooks/agent-branch-guard.yaml"

if [ ! -f "$CANON_FILE" ]; then
  echo "  ERROR: missing $CANON_FILE"
  exit 1
fi
canon="$(cat "$CANON_FILE")"

errors=0
checked=0
guarded=0
for t in "$ROOT"/plugins/*/templates/agents/*.agent.md.template; do
  [ -f "$t" ] || continue
  checked=$((checked + 1))
  rel="${t#"$ROOT"/}"
  fm="$(awk 'NR==1 && $0=="---" {f=1; next} f && $0=="---" {exit} f' "$t")"

  shell=0
  if ! printf '%s\n' "$fm" | grep -q '^tools:'; then
    shell=1
  elif printf '%s\n' "$fm" | grep -qE "^[[:space:]]*-[[:space:]]*'?(runCommands|execute|terminal)'?[[:space:]]*$"; then
    shell=1
  fi
  [ "$shell" = 1 ] || continue

  case "$fm" in
    *"$canon"*) guarded=$((guarded + 1)) ;;
    *)
      echo "  ERROR: $rel — grants a shell but its frontmatter lacks the branch guard;"
      echo "         paste plugins/dx-core/templates/hooks/agent-branch-guard.yaml verbatim"
      errors=$((errors + 1))
      ;;
  esac
done

echo "  $checked template(s) checked, $guarded shell-capable template(s) carry the branch guard"
[ "$errors" -eq 0 ]

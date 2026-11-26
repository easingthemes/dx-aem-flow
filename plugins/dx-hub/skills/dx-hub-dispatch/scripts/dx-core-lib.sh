#!/usr/bin/env bash
# dx-core-lib.sh — run one of dx-core's data/lib scripts from a dx-hub skill.
#
# A dx-hub skill's ${CLAUDE_PLUGIN_ROOT} is dx-hub's root, and a hub directory has
# no .ai/lib/ copy of dx-core's helpers, so the skill cannot name the script's
# path directly. This finds it, first match wins:
#   1. .ai/lib/<name>                       project copy (/dx-init, /dx-upgrade)
#   2. $DX_CORE_ROOT/data/lib/<name>        explicit override
#   3. $CLAUDE_PLUGIN_ROOT/data/lib/<name>  exported to the shell on Copilot CLI (dx-core's root)
#   4. <plugins>/dx-core/data/lib/<name>    sibling plugin: repo checkout, Copilot's installed-plugins/<marketplace>/
#   5. <cache>/dx-core/<version>/data/lib/<name>  Claude Code plugin cache, highest version
# and runs it with the remaining arguments.
#
# Usage: dx-core-lib.sh <script.sh> [args...]
# Exit: the script's own exit code. Not found → a warning on stderr and exit 0:
# a run result or a progress row must never fail the skill that writes it.

NAME="${1:-}"
[[ "$NAME" =~ ^[a-z0-9][a-z0-9-]*\.sh$ ]] || { echo "dx-core-lib.sh: usage: dx-core-lib.sh <script.sh> [args...]" >&2; exit 2; }
shift

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HUB_ROOT="$(cd "$HERE/../../.." && pwd)"       # scripts -> skill -> skills -> plugin root

candidates=(".ai/lib/$NAME")
[ -n "${DX_CORE_ROOT:-}" ] && candidates+=("$DX_CORE_ROOT/data/lib/$NAME")
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && candidates+=("$CLAUDE_PLUGIN_ROOT/data/lib/$NAME")
candidates+=("$HUB_ROOT/../dx-core/data/lib/$NAME")
# Claude Code cache: <marketplace>/dx-hub/<version>/ next to <marketplace>/dx-core/<version>/.
newest="$(ls -d "$HUB_ROOT"/../../dx-core/*/ 2>/dev/null | sed 's:/*$::' | sort -t/ -k1 -V | tail -1)"
[ -n "$newest" ] && candidates+=("$newest/data/lib/$NAME")

for f in "${candidates[@]}"; do
  [ -f "$f" ] && exec bash "$f" "$@"
done
echo "dx-core-lib.sh: $NAME not found (no .ai/lib copy, no dx-core plugin beside dx-hub) — skipped. Install dx-core or set DX_CORE_ROOT." >&2
exit 0

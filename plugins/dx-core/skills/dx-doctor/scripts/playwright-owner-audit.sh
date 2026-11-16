#!/usr/bin/env bash
# playwright-owner-audit.sh — find (and optionally rewrite) Playwright MCP tool
# names that still point at the dx-aem plugin. The `playwright` server moved
# from dx-aem to dx-core, so its tools are now `mcp__plugin_dx-core_playwright__*`;
# permission allowlists and Copilot agents written before the move still name
# the dx-aem prefix (`mcp__plugin_dx-aem_` + `playwright__*`, or the bare server),
# which match nothing.
#
# Usage:
#   playwright-owner-audit.sh [--fix] [<project-dir>]
#
# Files checked (relative to <project-dir>, default "."):
#   .claude/settings.json, .claude/settings.local.json   (permission allowlists)
#   .github/agents/*.agent.md                            (Copilot agent tools)
#
# Without --fix: read-only. Prints one TSV row per file with old names:
#   <file>\t<count>
# With --fix: rewrites the old owner to dx-core in those files, in place, and
# prints one row per changed file:
#   fixed\t<file>\t<count>
# Nothing else in the file is touched.
#
# Exit: 0 nothing found (or everything fixed), 3 old names found (no --fix)
#       or a --fix rewrite failed (`failed: <file>` on stderr), 2 usage error.
set -uo pipefail

FIX=0
DIR="."
while [ $# -gt 0 ]; do
  case "$1" in
    --fix) FIX=1 ;;
    -h|--help) sed -n '2,24p' "$0"; exit 0 ;;
    -*) echo "unknown option: $1" >&2; exit 2 ;;
    *) DIR="$1" ;;
  esac
  shift
done
[ -d "$DIR" ] || { echo "not a directory: $DIR" >&2; exit 2; }

# Split so a repo-wide grep for the retired name finds only history.
OLD='mcp__plugin_dx-aem''_playwright'
NEW='mcp__plugin_dx-core_playwright'
# Match the old server name only as a whole server name: followed by the `__`
# tool separator, a non-name character, or end of line. So `…_playwright` and
# `…_playwright__tool` match, but other servers such as `…_playwright-extra` or
# `…_playwright_beta` do not.
TAIL='(__|[^A-Za-z0-9_-]|$)'
PATTERN="${OLD}${TAIL}"

count() { grep -oE "$PATTERN" "$1" 2>/dev/null | wc -l | tr -d ' '; }

FOUND=0
shopt -s nullglob
for f in "$DIR/.claude/settings.json" "$DIR/.claude/settings.local.json" "$DIR"/.github/agents/*.agent.md; do
  [ -f "$f" ] || continue
  n="$(count "$f")"
  [ "$n" -gt 0 ] || continue
  rel="${f#"$DIR"/}"
  if [ "$FIX" -eq 1 ]; then
    # Portable in-place edit (GNU and BSD sed differ on -i). Report `fixed` only
    # when the file was rewritten and no old name is left in it.
    if tmp="$(mktemp "${f}.XXXXXX")" \
      && sed -E "s/${OLD}${TAIL}/${NEW}\\1/g" "$f" > "$tmp" \
      && cat "$tmp" > "$f" \
      && [ "$(count "$f")" -eq 0 ]; then
      rm -f "$tmp"
      printf 'fixed\t%s\t%s\n' "$rel" "$n"
    else
      rm -f "${tmp:-}"
      echo "failed: $rel" >&2
      FOUND=1
    fi
  else
    printf '%s\t%s\n' "$rel" "$n"
    FOUND=1
  fi
done

[ "$FOUND" -eq 1 ] && exit 3
exit 0

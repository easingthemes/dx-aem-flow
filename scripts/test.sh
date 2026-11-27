#!/usr/bin/env bash
# test.sh — Run only the test suites a change can affect (local; CI runs everything).
#
# Suites are DISCOVERED with the same globs as .github/workflows/validate.yml:
#   *.test.js                       under plugins/ and cli/
#   run-tests.sh, *.test.sh         under plugins/ and scripts/
#   scripts/validate-{skills,agents,structure,stats}.sh   when present
# A changed path that maps to no rule runs EVERYTHING — never silently skips a suite.
#
# Usage:
#   scripts/test.sh --list -      # read changed paths on stdin, print the selection
#                                 #   (<suite><TAB><reason>, sorted); nothing runs
#   scripts/test.sh -h            # this help
#
# Env: DX_TEST_ROOT overrides the repo root (used by scripts/test.test.sh).
# Exit: 0 = ok.  2 = usage error.

set -uo pipefail

usage() { sed -n '2,15p' "$0"; }

MODE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --list)
      shift
      if [ "${1:-}" = "-" ]; then MODE="list-stdin"; shift
      else echo "--list needs '-' (paths on stdin)" >&2; exit 2; fi ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
[ -n "$MODE" ] || { usage >&2; exit 2; }

ROOT="${DX_TEST_ROOT:-$(git rev-parse --show-toplevel)}"
cd "$ROOT" || { echo "cannot cd to $ROOT" >&2; exit 2; }

# discover_suites — every suite path relative to root, sorted, one per line.
discover_suites() {
  {
    find plugins cli -type f -name '*.test.js' 2>/dev/null
    find plugins scripts -type f \( -name 'run-tests.sh' -o -name '*.test.sh' \) 2>/dev/null
    local v
    for v in skills agents structure stats; do
      [ -f "scripts/validate-$v.sh" ] && echo "scripts/validate-$v.sh"
    done
  } | LC_ALL=C sort -u
}

# suite_home <suite> — prefix (ends in /) a path must start with to belong to the suite,
# or the exact file for scripts/ suites.
suite_home() {
  local s="$1" d
  case "$s" in
    scripts/validate-*.sh) echo "$s"; return ;;   # a validator is its own home
    scripts/*.test.sh)
      case "${s#scripts/}" in */*) ;; *) echo "${s%.test.sh}.sh"; return ;; esac ;;
  esac
  case "$s" in
    plugins/*/skills/*/*)
      local rest="${s#plugins/}" p sk
      p="${rest%%/*}"; rest="${rest#*/}"          # rest = skills/<s>/...
      sk="${rest#skills/}"; sk="${sk%%/*}"
      echo "plugins/$p/skills/$sk/"; return ;;
  esac
  d="${s%/*}"
  case "$d" in
    */scripts/__tests__) d="${d%/scripts/__tests__}" ;;
    */tests)             d="${d%/tests}" ;;
    */__tests__)         d="${d%/__tests__}" ;;
    */test)              d="${d%/test}" ;;
  esac
  echo "$d/"
}

# select_suites — changed paths on stdin -> "<suite>\t<reason>" lines, sorted by suite,
# one per suite, first matching reason wins. Unmapped path -> every suite, "fallback: <path>".
select_suites() {
  local suites homes s h p b matched out="" fallback=""
  local TAB; TAB=$(printf '\t')
  suites=$(discover_suites)
  homes=""
  while IFS= read -r s; do
    [ -n "$s" ] || continue
    homes="$homes$s$TAB$(suite_home "$s")
"
  done <<EOF_SUITES
$suites
EOF_SUITES

  while IFS= read -r p; do
    [ -n "$p" ] || continue
    matched=0

    # Rule 1 — path is inside the suite's home, or is the suite file itself.
    while IFS="$TAB" read -r s h; do
      [ -n "$s" ] || continue
      if [ "$p" = "$s" ]; then out="$out$s${TAB}home
"; matched=1; continue; fi
      case "$h" in
        */) case "$p" in "$h"*) out="$out$s${TAB}home
"; matched=1 ;; esac ;;
        *)  [ "$p" = "$h" ] && { out="$out$s${TAB}home
"; matched=1; } ;;
      esac
    done <<EOF_HOMES
$homes
EOF_HOMES

    # Rule 2 — scripts/X.sh pairs with scripts/X.test.sh (a validator also selects itself).
    case "$p" in
      scripts/*.test.sh) ;;
      scripts/*.sh)
        case "${p#scripts/}" in */*) ;; *)
          if printf '%s\n' "$suites" | grep -qxF "${p%.sh}.test.sh"; then
            out="$out${p%.sh}.test.sh${TAB}pair
"; matched=1
          fi
          case "$p" in scripts/validate-*.sh)
            if printf '%s\n' "$suites" | grep -qxF "$p"; then out="$out$p${TAB}pair
"; matched=1; fi ;;
          esac ;;
        esac ;;
    esac

    # Rule 3 — shared libs/hooks/shared docs: every suite whose home mentions the basename.
    case "$p" in
      plugins/*/data/lib/*|plugins/*/data/hooks/*|plugins/*/shared/*)
        matched=1; b="${p##*/}"
        while IFS="$TAB" read -r s h; do
          [ -n "$s" ] || continue
          case "$h" in
            */) grep -rqF -- "$b" "$h" 2>/dev/null && out="$out$s${TAB}uses $b
" ;;
            *)  grep -qF -- "$b" "$h" 2>/dev/null && out="$out$s${TAB}uses $b
" ;;
          esac
        done <<EOF_HOMES3
$homes
EOF_HOMES3
        ;;
    esac

    # Rule 4 — scaffold inputs: the CLI suites read templates and data at runtime.
    case "$p" in
      plugins/*/templates/*|plugins/*/data/*)
        matched=1
        while IFS= read -r s; do
          case "$s" in cli/test/*.test.js) out="$out$s${TAB}scaffold input
" ;; esac
        done <<EOF_S4
$suites
EOF_S4
        ;;
    esac

    # Rule 5 — structural validators.
    local sk=0 ag=0 st=0
    case "$p" in
      plugins/*/skills/*) sk=1 ;;
    esac
    case "$p" in
      plugins/*/agents/*|plugins/*/templates/agents/*) ag=1 ;;
    esac
    case "$p" in
      plugins/*|.claude-plugin/*|.cursor-plugin/*|gemini-extension.json|website/src/config/stats.ts) st=1 ;;
    esac
    if [ $((sk + ag + st)) -gt 0 ]; then
      matched=1
      [ $sk -eq 1 ] && printf '%s\n' "$suites" | grep -qxF scripts/validate-skills.sh && out="${out}scripts/validate-skills.sh${TAB}validator
"
      [ $ag -eq 1 ] && printf '%s\n' "$suites" | grep -qxF scripts/validate-agents.sh && out="${out}scripts/validate-agents.sh${TAB}validator
"
      if [ $st -eq 1 ]; then
        for s in scripts/validate-structure.sh scripts/validate-stats.sh; do
          printf '%s\n' "$suites" | grep -qxF "$s" && out="$out$s${TAB}structural
"
        done
      fi
    fi

    # Rule 6 — inert paths select nothing and are not "unmapped".
    if [ $matched -eq 0 ]; then
      case "$p" in
        docs/*|website/*) matched=1 ;;
        */*) ;;
        *.md) matched=1 ;;
      esac
    fi

    # Rule 7 — anything else is unmapped: run everything.
    if [ $matched -eq 0 ] && [ -z "$fallback" ]; then fallback="$p"; fi
  done

  if [ -n "$fallback" ]; then
    while IFS= read -r s; do
      [ -n "$s" ] && printf '%s\tfallback: %s\n' "$s" "$fallback"
    done <<EOF_FB
$suites
EOF_FB
    return 0
  fi
  [ -n "$out" ] && printf '%s' "$out" | awk -F'\t' '!seen[$1]++' | LC_ALL=C sort -t "$TAB" -k1,1
  return 0
}

case "$MODE" in
  list-stdin)
    sel=$(select_suites)
    if [ -z "$sel" ]; then echo "No suites affected."; else printf '%s\n' "$sel"; fi ;;
esac

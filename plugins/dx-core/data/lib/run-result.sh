#!/usr/bin/env bash
# run-result.sh — write the machine-readable result of a coordinator skill run.
#
# Coordinator skills (dx-agent-all, dx-bug-all, dx-pr-review, dx-prep) call this
# once at the end of every run — also when they stop or fail — so a tool that
# started the run (a dashboard, a script) can show done / blocked / next step
# without parsing terminal text. Schema: docs/reference/run-result.md.
#
# Usage:
#   run-result.sh --skill <name> --id <id> --status <done|blocked|failed>
#                 [--verdict <v>] [--vote <v>] [--next <one line>]
#                 [--pr <url>] [--wiki <url>] [--work-item <url>]
#                 [--summary <one line>] [--dir <output dir>]
#
# Writes <dir>/<skill>-<id>.json (default dir: .ai/run-results), overwriting the
# previous run's file (latest wins). Empty or missing optional values become null.
# Prints the path written. Exit 2 on a usage error (nothing written).

set -uo pipefail

SKILL="" ID="" STATUS="" VERDICT="" VOTE="" NEXT="" PR="" WIKI="" WI="" SUMMARY=""
DIR=".ai/run-results"

usage() { echo "run-result.sh: $1" >&2; exit 2; }

while [ $# -gt 0 ]; do
  [ $# -ge 2 ] || usage "missing value for $1"
  case "$1" in
    --skill) SKILL="$2" ;;
    --id) ID="$2" ;;
    --status) STATUS="$2" ;;
    --verdict) VERDICT="$2" ;;
    --vote) VOTE="$2" ;;
    --next) NEXT="$2" ;;
    --pr) PR="$2" ;;
    --wiki) WIKI="$2" ;;
    --work-item) WI="$2" ;;
    --summary) SUMMARY="$2" ;;
    --dir) DIR="$2" ;;
    *) usage "unknown option $1" ;;
  esac
  shift 2
done

# skill and id become the file name: keep them to a safe character set.
[[ "$SKILL" =~ ^[a-z0-9][a-z0-9-]*$ ]] || usage "--skill must be a skill name like dx-pr-review"
[[ "$ID" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]] || usage "--id must be a work item or PR id (letters, digits, - or _)"
case "$STATUS" in done|blocked|failed) ;; *) usage "--status must be done, blocked or failed" ;; esac

# One line only: newlines, tabs and other control characters become spaces.
one_line() { printf '%s' "$1" | tr '\000-\037\177' ' ' | sed -e 's/  */ /g' -e 's/^ //' -e 's/ $//'; }

# JSON string, or null when empty.
json() {
  local s
  s="$(one_line "$1")"
  if [ -z "$s" ]; then printf 'null'; return; fi
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  printf '"%s"' "$s"
}

mkdir -p "$DIR" || usage "cannot create $DIR"
OUT="$DIR/$SKILL-$ID.json"
TMP="$OUT.tmp.$$"

{
  printf '{\n'
  printf '  "schema": 1,\n'
  printf '  "skill": %s,\n' "$(json "$SKILL")"
  printf '  "id": %s,\n' "$(json "$ID")"
  printf '  "status": %s,\n' "$(json "$STATUS")"
  printf '  "verdict": %s,\n' "$(json "$VERDICT")"
  printf '  "vote": %s,\n' "$(json "$VOTE")"
  printf '  "next_action": %s,\n' "$(json "$NEXT")"
  printf '  "links": { "pr": %s, "wiki": %s, "work_item": %s },\n' "$(json "$PR")" "$(json "$WIKI")" "$(json "$WI")"
  printf '  "summary": %s,\n' "$(json "$SUMMARY")"
  printf '  "finished_at": "%s"\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '}\n'
} > "$TMP" && mv -f "$TMP" "$OUT" || { rm -f "$TMP"; echo "run-result.sh: cannot write $OUT" >&2; exit 1; }

echo "$OUT"

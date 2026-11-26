#!/usr/bin/env bash
# run-result.sh — write the machine-readable result of a coordinator skill run.
#
# dx skills (the coordinators and the ones a tool may start on their own) call this
# once at the start (--start) and once at the end of every run — also when they
# stop or fail — so a tool that started the run (a dashboard, a script, a hub)
# can show running / done / blocked / next step without parsing terminal text.
# Schema: docs/reference/run-result.md.
#
# Usage:
#   run-result.sh --start --skill <name> --id <id>
#                 [--run-id <id>] [--progress-file <file name>] [--spec-dir <dir>]
#                 [--dir <output dir>]
#   run-result.sh --skill <name> --id <id> --status <done|blocked|failed>
#                 [--run-id <id>] [--verdict <v>] [--vote <v>] [--next <one line>]
#                 [--pr <url>] [--wiki <url>] [--work-item <url>]
#                 [--summary <one line>] [--metric <key>=<value>]...
#                 [--engine <claude|copilot|...>] [--mode <automation|interactive>]
#                 [--mode-reason <env|flag|args|no-ask|none>] [--dir <output dir>]
#
# --metric adds a key to "metrics" (key [a-z][a-z0-9_]{0,31}; an integer value
# becomes a number, true/false a boolean, anything else a one-line string of at
# most 80 chars; a repeated key keeps the last value). A bad metric is skipped
# with a warning, never fails the write. "env" records dx_version (this
# plugin's manifest), engine (--engine, else $DX_ENGINE, else "copilot" when
# COPILOT_AGENT_SESSION_ID is set or COPILOT_CLI=1, else "claude" when
# CLAUDECODE=1), mode and mode_reason.
#
# --start writes <dir>/<skill>-<id>.running.json (status "running"). The final
# call writes <dir>/<skill>-<id>.json (latest wins), carries run_id and
# started_at over from the running marker, adds duration_s, removes the marker
# and appends the result as one line to <dir>/history.jsonl (trimmed to the
# last HISTORY_KEEP lines once it passes HISTORY_MAX).
# run_id: --run-id, else $DX_RUN_ID, else the marker's; an id outside
# [A-Za-z0-9._:-]{1,64} is dropped (null) with a warning.
# Manual runs (none of those): "<session id>.<n>" — the engine session id
# ($DX_SESSION_ID, else $CLAUDE_CODE_SESSION_ID on claude, $COPILOT_AGENT_SESSION_ID
# on copilot; lowercased, [a-z0-9_:-]{1,60}, else null) and n, a counter per
# session kept in <dir>/.sessions/<session id>. Minted by --start, or by a final
# call that has no marker.
# Empty or missing optional values become null. Prints the path written.
# Exit 2 on a usage error (nothing written).

set -uo pipefail

SKILL="" ID="" STATUS="" VERDICT="" VOTE="" NEXT="" PR="" WIKI="" WI="" SUMMARY=""
START=0 RUN_ID="${DX_RUN_ID:-}" RUN_ID_SET=0 PROGRESS_FILE="" SPEC_DIR=""
ENGINE="${DX_ENGINE:-}" MODE="" MODE_REASON=""
METRIC_KEYS=() METRIC_VALS=()
DIR=".ai/run-results"
HISTORY_MAX="${DX_RUN_HISTORY_MAX:-2000}" HISTORY_KEEP="${DX_RUN_HISTORY_KEEP:-1000}"

usage() { echo "run-result.sh: $1" >&2; exit 2; }

while [ $# -gt 0 ]; do
  if [ "$1" = "--start" ]; then START=1; shift; continue; fi
  [ $# -ge 2 ] || usage "missing value for $1"
  case "$1" in
    --run-id) RUN_ID="$2"; RUN_ID_SET=1 ;;
    --progress-file) PROGRESS_FILE="$2" ;;
    --spec-dir) SPEC_DIR="$2" ;;
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
    --metric) if [[ "$2" == *=* ]]; then METRIC_KEYS+=("${2%%=*}"); METRIC_VALS+=("${2#*=}"); else METRIC_KEYS+=("!"); METRIC_VALS+=(""); fi ;;
    --engine) ENGINE="$2" ;;
    --mode) MODE="$2" ;;
    --mode-reason) MODE_REASON="$2" ;;
    --dir) DIR="$2" ;;
    *) usage "unknown option $1" ;;
  esac
  shift 2
done

# skill and id become the file name: keep them to a safe character set.
[[ "$SKILL" =~ ^[a-z0-9][a-z0-9-]*$ ]] || usage "--skill must be a skill name like dx-pr-review"
[[ "$ID" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]] || usage "--id must be a work item or PR id (letters, digits, - or _)"
if [ "$START" = 1 ]; then
  [ -z "$STATUS" ] || usage "--start takes no --status"
else
  case "$STATUS" in done|blocked|failed) ;; *) usage "--status must be done, blocked or failed" ;; esac
fi

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

valid_run_id() { [[ "$1" =~ ^[A-Za-z0-9._:-]{1,64}$ ]]; }

# Engine: --engine / DX_ENGINE, else what the shell says. A Copilot session started
# from a Claude Code shell inherits CLAUDECODE=1, so Copilot's own variable wins.
if [ -z "$ENGINE" ]; then
  if [ -n "${COPILOT_AGENT_SESSION_ID:-}" ] || [ "${COPILOT_CLI:-}" = 1 ]; then ENGINE=copilot
  elif [ "${CLAUDECODE:-}" = 1 ]; then ENGINE=claude; fi
fi

# Manual run (no caller id): "<engine session id>.<n>", n counting the runs of
# that session, so a tool can link the run to its session exactly.
mint_run_id() {
  local sid="${DX_SESSION_ID:-}" f lock n _
  if [ -z "$sid" ]; then
    case "$ENGINE" in
      claude) sid="${CLAUDE_CODE_SESSION_ID:-}" ;;
      copilot) sid="${COPILOT_AGENT_SESSION_ID:-}" ;;
    esac
  fi
  [ -n "$sid" ] || return 0
  sid="$(printf '%s' "$sid" | tr '[:upper:]' '[:lower:]')"
  if ! [[ "$sid" =~ ^[a-z0-9_:-]{1,60}$ ]]; then
    echo "run-result.sh: ignoring session id outside [a-z0-9_:-]{1,60}" >&2; return 0
  fi
  mkdir -p "$DIR/.sessions" 2>/dev/null || return 0
  f="$DIR/.sessions/$sid" lock="$DIR/.sessions/$sid.lock"
  # mkdir is atomic: two runs starting together never get the same n. A lock left
  # by a killed run is taken over after ~5 s.
  for _ in $(seq 1 50); do mkdir "$lock" 2>/dev/null && break; sleep 0.1; done
  n="$(head -1 "$f" 2>/dev/null)"
  [[ "$n" =~ ^[0-9]{1,9}$ ]] || n=0
  n=$((10#$n + 1))
  { printf '%s\n' "$n" > "$f.tmp.$$" && mv -f "$f.tmp.$$" "$f"; } 2>/dev/null || rm -f "$f.tmp.$$"
  rmdir "$lock" 2>/dev/null
  RUN_ID="$sid.$n"
}

# Value of a top-level string field in a file this script wrote ("key": "value"); empty if absent or null.
field() { sed -n "s/^  \"$2\": \"\\(.*\\)\",\{0,1\}\$/\\1/p" "$1" 2>/dev/null | head -1; }

# ISO 8601 UTC (as this script writes it) to epoch seconds; empty if the date cannot be parsed.
epoch() {
  date -u -d "$1" +%s 2>/dev/null || date -u -j -f '%Y-%m-%dT%H:%M:%SZ' "$1" +%s 2>/dev/null || true
}

NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
mkdir -p "$DIR" || usage "cannot create $DIR"
MARKER="$DIR/$SKILL-$ID.running.json"

write_atomic() { # target ; content on stdin
  local tmp="$1.tmp.$$"
  cat > "$tmp" && mv -f "$tmp" "$1" || { rm -f "$tmp"; echo "run-result.sh: cannot write $1" >&2; exit 1; }
}

if [ "$START" = 1 ]; then
  [ "$RUN_ID_SET" = 1 ] || [ -n "$RUN_ID" ] || mint_run_id
  if [ -n "$RUN_ID" ] && ! valid_run_id "$RUN_ID"; then
    echo "run-result.sh: ignoring run id outside [A-Za-z0-9._:-]{1,64}" >&2; RUN_ID=""
  fi
  {
    printf '{\n'
    printf '  "schema": 1,\n'
    printf '  "skill": %s,\n' "$(json "$SKILL")"
    printf '  "id": %s,\n' "$(json "$ID")"
    printf '  "status": "running",\n'
    printf '  "run_id": %s,\n' "$(json "$RUN_ID")"
    printf '  "started_at": "%s",\n' "$NOW"
    printf '  "progress_file": %s,\n' "$(json "$PROGRESS_FILE")"
    printf '  "spec_dir": %s\n' "$(json "$SPEC_DIR")"
    printf '}\n'
  } | write_atomic "$MARKER"
  echo "$MARKER"
  exit 0
fi

STARTED_AT=""
if [ -f "$MARKER" ]; then
  STARTED_AT="$(field "$MARKER" started_at)"
  [ "$RUN_ID_SET" = 1 ] || [ -n "$RUN_ID" ] || RUN_ID="$(field "$MARKER" run_id)"
else
  [ "$RUN_ID_SET" = 1 ] || [ -n "$RUN_ID" ] || mint_run_id
fi
if [ -n "$RUN_ID" ] && ! valid_run_id "$RUN_ID"; then
  echo "run-result.sh: ignoring run id outside [A-Za-z0-9._:-]{1,64}" >&2; RUN_ID=""
fi
DURATION=null
if [ -n "$STARTED_AT" ]; then
  S="$(epoch "$STARTED_AT")" E="$(epoch "$NOW")"
  if [ -n "$S" ] && [ -n "$E" ] && [ "$E" -ge "$S" ]; then DURATION=$((E - S)); fi
fi

# metrics: validated, last value per key wins, insertion order of first appearance.
METRICS="{}"
if [ "${#METRIC_KEYS[@]}" -gt 0 ]; then
  keys=() vals=()
  for i in "${!METRIC_KEYS[@]}"; do
    k="${METRIC_KEYS[$i]}" v="${METRIC_VALS[$i]}"
    if ! [[ "$k" =~ ^[a-z][a-z0-9_]{0,31}$ ]]; then
      echo "run-result.sh: skipping bad --metric (want key=value, key [a-z][a-z0-9_]{0,31})" >&2; continue
    fi
    if [[ "$v" =~ ^-?[0-9]{1,15}$ ]]; then v="$((10#${v#-}))"; [[ "${METRIC_VALS[$i]}" == -* ]] && v="-$v"
    elif [ "$v" = true ] || [ "$v" = false ]; then :
    else v="$(json "$(one_line "$v" | cut -c1-80)")"; fi
    found=""
    for j in "${!keys[@]}"; do [ "${keys[$j]}" = "$k" ] && { vals[$j]="$v"; found=1; }; done
    [ -n "$found" ] || { keys+=("$k"); vals+=("$v"); }
  done
  if [ "${#keys[@]}" -gt 0 ]; then
    METRICS="{"
    for j in "${!keys[@]}"; do METRICS+="$([ "$j" -gt 0 ] && printf ', ')\"${keys[$j]}\": ${vals[$j]}"; done
    METRICS+="}"
  fi
fi

# env: plugin version from this script's own plugin manifest; engine as detected above.
MANIFEST="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)/.claude-plugin/plugin.json"
DX_VERSION="$(sed -n 's/^[[:space:]]*"version":[[:space:]]*"\([^"]*\)".*/\1/p' "$MANIFEST" 2>/dev/null | head -1)"
ENV_OBJ="{ \"dx_version\": $(json "$DX_VERSION"), \"engine\": $(json "$ENGINE"), \"mode\": $(json "$MODE"), \"mode_reason\": $(json "$MODE_REASON") }"

OUT="$DIR/$SKILL-$ID.json"
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
  printf '  "run_id": %s,\n' "$(json "$RUN_ID")"
  printf '  "started_at": %s,\n' "$(json "$STARTED_AT")"
  printf '  "duration_s": %s,\n' "$DURATION"
  printf '  "metrics": %s,\n' "$METRICS"
  printf '  "env": %s,\n' "$ENV_OBJ"
  printf '  "finished_at": "%s"\n' "$NOW"
  printf '}\n'
} | write_atomic "$OUT"
rm -f "$MARKER"

# History: the same object on one line. Never fail the run over it.
HIST="$DIR/history.jsonl"
{ tr '\n' ' ' < "$OUT" | sed -e 's/  */ /g' -e 's/ $//'; printf '\n'; } >> "$HIST" 2>/dev/null \
  || echo "run-result.sh: cannot append to $HIST" >&2
if [ -f "$HIST" ] && [ "$(wc -l < "$HIST")" -gt "$HISTORY_MAX" ]; then
  tail -n "$HISTORY_KEEP" "$HIST" > "$HIST.tmp.$$" && mv -f "$HIST.tmp.$$" "$HIST" || rm -f "$HIST.tmp.$$"
fi

echo "$OUT"

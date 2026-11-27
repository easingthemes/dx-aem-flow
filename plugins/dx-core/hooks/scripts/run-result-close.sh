#!/usr/bin/env bash
# SessionEnd hook — close dx runs the session left open.
#
# A dx skill writes .ai/run-results/<skill>-<id>.running.json at its start and
# replaces it with <skill>-<id>.json at its end (data/lib/run-result.sh). When
# the session ends first (Ctrl+C, terminal closed, crash, the model stopping
# early), the marker stays and the tool that started the run never learns the
# outcome. This hook writes the missing result: status failed, "interrupted",
# metrics.interrupted true, and — when the marker names a progress file — the
# step that was in progress ("interrupted: <step>", metrics.fail_at <step>).
#
# Only runs this session owns are touched:
#   - markers whose run_id equals this process's DX_RUN_ID (set by the tool that
#     started the session, e.g. a dashboard or /dx-hub-dispatch);
#   - manual runs of this session: markers whose run_id is "<session id>.<n>"
#     (run-result.sh mints those when DX_RUN_ID is unset) and whose part before
#     the first "." equals the ending session's id (stdin "session_id" on Claude
#     Code, "sessionId" on Copilot CLI).
# Markers of other sessions, and markers with no run id, are left alone: another
# session in the same repo may still be working on them.
# Never fails the session: always exits 0.

RUN_ID="${DX_RUN_ID:-}"
INPUT=""
[ -t 0 ] || IFS= read -r -d '' INPUT || true
# Values are read in the shell, not with sed/head/tr: each process costs tens of
# ms under endpoint security on macOS. Same matches as the sed they replace.
# jstr: the last "key": "value" on the first input line that has one.
jstr() {
  local line re=".*\"$1\" *: *\"([^\"]*)\""
  while IFS= read -r line || [ -n "$line" ]; do
    if [[ "$line" =~ $re ]]; then printf '%s\n' "${BASH_REMATCH[1]}"; return 0; fi
  done <<EOF_INPUT
$INPUT
EOF_INPUT
}
lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }
SID="$(jstr session_id)"
[ -n "$SID" ] || SID="$(jstr sessionId)"
case "$SID" in *[[:upper:]]*) SID="$(lower "$SID")" ;; esac
[[ "$SID" =~ ^[a-z0-9_:-]{1,60}$ ]] || SID=""
[ -n "$RUN_ID" ] || [ -n "$SID" ] || exit 0

PROJECT="${CLAUDE_PROJECT_DIR:-}"
[ -n "$PROJECT" ] || PROJECT="$(jstr cwd)"
[ -n "$PROJECT" ] || PROJECT="$PWD"
DIR="$PROJECT/.ai/run-results"
[ -d "$DIR" ] || exit 0

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RR="$HERE/../../data/lib/run-result.sh"
[ -f "$RR" ] || exit 0

# val: the first ^  "key": "(.*)",?$ of a file run-result.sh wrote.
val() {
  local line re="^  \"$2\": \"(.*)\",?\$"
  [ -r "$1" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    if [[ "$line" =~ $re ]]; then printf '%s\n' "${BASH_REMATCH[1]}"; return 0; fi
  done < "$1"
}

# The step a run was on: the last in_progress row of the marker's progress file
# (in its spec_dir, else the one .ai/specs/<id>-*/). Empty when there is none.
last_step() { # marker id
  local pf sd f
  pf="$(val "$1" progress_file)" sd="$(val "$1" spec_dir)"
  [ -n "$pf" ] || return 0
  case "$pf" in */*|..*) return 0 ;; esac
  if [ -n "$sd" ]; then
    case "$sd" in /*) f="$sd/$pf" ;; *) f="$PROJECT/$sd/$pf" ;; esac
  else
    set -- "$PROJECT"/.ai/specs/"$2"-*/"$pf"
    [ $# -eq 1 ] || return 0
    f="$1"
  fi
  [ -f "$f" ] || return 0
  awk -F'|' '$3 ~ /^ *in_progress *$/ { s = $2 } END { gsub(/^ +| +$/, "", s); print s }' "$f" \
    | tr '\000-\037\177' ' ' | cut -c1-80
}

for m in "$DIR"/*.running.json; do
  [ -f "$m" ] || continue
  rid="$(val "$m" run_id)"
  [ -n "$rid" ] || continue
  if [ "$rid" = "$RUN_ID" ]; then :
  elif [ -n "$SID" ] && { r="${rid%%.*}"; case "$r" in *[[:upper:]]*) r="$(lower "$r")" ;; esac; [ "$r" = "$SID" ]; }; then :
  else continue; fi
  skill="$(val "$m" skill)" id="$(val "$m" id)"
  [ -n "$skill" ] && [ -n "$id" ] || continue
  step="$(last_step "$m" "$id")"
  if [ -n "$step" ]; then
    bash "$RR" --dir "$DIR" --skill "$skill" --id "$id" --status failed --run-id "$rid" \
      --summary "interrupted: $step" --next "/$skill $id" \
      --metric interrupted=true --metric fail_at="$step" >/dev/null 2>&1 || true
  else
    bash "$RR" --dir "$DIR" --skill "$skill" --id "$id" --status failed --run-id "$rid" \
      --summary "interrupted: the session ended before the skill wrote its result" \
      --next "/$skill $id" --metric interrupted=true >/dev/null 2>&1 || true
  fi
done

# Run counters of sessions idle for 30 days. The current one stays: a resumed
# session keeps its id and must not restart at 1.
[ -d "$DIR/.sessions" ] && find "$DIR/.sessions" -type f -mtime +30 -delete 2>/dev/null
exit 0

#!/usr/bin/env bash
# SessionEnd hook — close dx runs the session left open.
#
# A dx skill writes .ai/run-results/<skill>-<id>.running.json at its start and
# replaces it with <skill>-<id>.json at its end (data/lib/run-result.sh). When
# the session ends first (Ctrl+C, terminal closed, crash, the model stopping
# early), the marker stays and the tool that started the run never learns the
# outcome. This hook writes the missing result: status failed, "interrupted".
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
[ -t 0 ] || INPUT="$(cat)"
jstr() { printf '%s' "$INPUT" | sed -n "s/.*\"$1\" *: *\"\([^\"]*\)\".*/\1/p" | head -1; }
SID="$(jstr session_id)"
[ -n "$SID" ] || SID="$(jstr sessionId)"
SID="$(printf '%s' "$SID" | tr '[:upper:]' '[:lower:]')"
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

val() { sed -n "s/^  \"$2\": \"\\(.*\\)\",\\{0,1\\}\$/\\1/p" "$1" 2>/dev/null | head -1; }

for m in "$DIR"/*.running.json; do
  [ -f "$m" ] || continue
  rid="$(val "$m" run_id)"
  [ -n "$rid" ] || continue
  if [ "$rid" = "$RUN_ID" ]; then :
  elif [ -n "$SID" ] && [ "$(printf '%s' "${rid%%.*}" | tr '[:upper:]' '[:lower:]')" = "$SID" ]; then :
  else continue; fi
  skill="$(val "$m" skill)" id="$(val "$m" id)"
  [ -n "$skill" ] && [ -n "$id" ] || continue
  bash "$RR" --dir "$DIR" --skill "$skill" --id "$id" --status failed --run-id "$rid" \
    --summary "interrupted: the session ended before the skill wrote its result" \
    --next "/$skill $id" --metric interrupted=true >/dev/null 2>&1 || true
done

# Run counters of sessions idle for 30 days. The current one stays: a resumed
# session keeps its id and must not restart at 1.
[ -d "$DIR/.sessions" ] && find "$DIR/.sessions" -type f -mtime +30 -delete 2>/dev/null
exit 0

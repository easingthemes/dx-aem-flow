#!/usr/bin/env bash
# SessionEnd hook — close dx runs the session left open.
#
# A dx skill writes .ai/run-results/<skill>-<id>.running.json at its start and
# replaces it with <skill>-<id>.json at its end (data/lib/run-result.sh). When
# the session ends first (Ctrl+C, terminal closed, crash, the model stopping
# early), the marker stays and the tool that started the run never learns the
# outcome. This hook writes the missing result: status failed, "interrupted".
#
# Only runs this session can own are touched: markers whose run_id equals this
# process's DX_RUN_ID (set by the tool that started the session, e.g. a
# dashboard or /dx-hub-dispatch). Without DX_RUN_ID it does nothing — another
# session in the same repo may still be working on a marker without one.
# Never fails the session: always exits 0.

RUN_ID="${DX_RUN_ID:-}"
[ -n "$RUN_ID" ] || exit 0

PROJECT="${CLAUDE_PROJECT_DIR:-}"
if [ -z "$PROJECT" ] && [ ! -t 0 ]; then
  PROJECT="$(sed -n 's/.*"cwd" *: *"\([^"]*\)".*/\1/p' | head -1)"
fi
[ -n "$PROJECT" ] || PROJECT="$PWD"
DIR="$PROJECT/.ai/run-results"
[ -d "$DIR" ] || exit 0

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RR="$HERE/../../data/lib/run-result.sh"
[ -f "$RR" ] || exit 0

val() { sed -n "s/^  \"$2\": \"\\(.*\\)\",\{0,1\}\$/\\1/p" "$1" 2>/dev/null | head -1; }

for m in "$DIR"/*.running.json; do
  [ -f "$m" ] || continue
  [ "$(val "$m" run_id)" = "$RUN_ID" ] || continue
  skill="$(val "$m" skill)" id="$(val "$m" id)"
  [ -n "$skill" ] && [ -n "$id" ] || continue
  bash "$RR" --dir "$DIR" --skill "$skill" --id "$id" --status failed --run-id "$RUN_ID" \
    --summary "interrupted: the session ended before the skill wrote its result" \
    --next "/$skill $id" --metric interrupted=true >/dev/null 2>&1 || true
done
exit 0

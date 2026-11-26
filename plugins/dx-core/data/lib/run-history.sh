#!/usr/bin/env bash
# run-history.sh — summarize dx run results from .ai/run-results/.
#
# Reads history.jsonl (every finished run) and *.running.json (runs in progress
# or interrupted) written by run-result.sh, and prints a per-skill summary:
# runs, done / blocked / failed, success rate, median duration, the most common
# fail_at, and running / stale markers. Schema: docs/reference/run-result.md.
#
# Usage:
#   run-history.sh [--json] [--days N] [--skill NAME] [--stale-hours H] [--dir DIR]
#
#   --json         one JSON object instead of the table (for tools)
#   --days N       only runs finished in the last N days (default: all)
#   --skill NAME   only this skill
#   --stale-hours  a running marker older than this is reported as stale
#                  (likely interrupted; default 6)
#   --dir          results dir (default .ai/run-results)
#
# Needs jq. Exit 0 with an empty summary when there is no history.
# Exit 2 on a usage error.

set -uo pipefail

JSON=0 DAYS="" SKILL="" STALE_H=6 DIR=".ai/run-results"
usage() { echo "run-history.sh: $1" >&2; exit 2; }
while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON=1; shift; continue ;;
  esac
  [ $# -ge 2 ] || usage "missing value for $1"
  case "$1" in
    --days) DAYS="$2" ;;
    --skill) SKILL="$2" ;;
    --stale-hours) STALE_H="$2" ;;
    --dir) DIR="$2" ;;
    *) usage "unknown option $1" ;;
  esac
  shift 2
done
[ -z "$DAYS" ] || [[ "$DAYS" =~ ^[0-9]+$ ]] || usage "--days must be a number"
[[ "$STALE_H" =~ ^[0-9]+$ ]] || usage "--stale-hours must be a number"
[ -z "$SKILL" ] || [[ "$SKILL" =~ ^[a-z0-9][a-z0-9-]*$ ]] || usage "--skill must be a skill name"
command -v jq >/dev/null 2>&1 || { echo "run-history.sh: jq is required" >&2; exit 1; }

NOW=$(date -u +%s)
SINCE=0
[ -n "$DAYS" ] && SINCE=$((NOW - DAYS * 86400))

# Finished runs: skip lines that do not parse; keep only objects with a skill and status.
HIST="$DIR/history.jsonl"
RUNS='[]'
if [ -f "$HIST" ]; then
  RUNS=$(jq -R -c 'fromjson? | select(type == "object" and (.skill | type) == "string" and (.status | type) == "string")' "$HIST" 2>/dev/null | jq -s -c '.')
  [ -n "$RUNS" ] || RUNS='[]'
fi

# Running markers.
MARKERS='[]'
if [ -d "$DIR" ]; then
  MARKERS=$(for f in "$DIR"/*.running.json; do [ -f "$f" ] && cat "$f" && echo; done 2>/dev/null \
    | jq -s -c '[.[] | select(type == "object" and (.skill | type) == "string")]' 2>/dev/null)
  [ -n "$MARKERS" ] || MARKERS='[]'
fi

SUMMARY=$(jq -n -c --argjson runs "$RUNS" --argjson markers "$MARKERS" \
  --argjson since "$SINCE" --argjson now "$NOW" --argjson stale "$((STALE_H * 3600))" --arg skill "$SKILL" '
  def ts: (try (sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601) catch null);
  def median: sort | if length == 0 then null elif length % 2 == 1 then .[length / 2 | floor]
              else ((.[length / 2 - 1] + .[length / 2]) / 2) end;
  ($runs | map(select(($skill == "" or .skill == $skill) and ((.finished_at | ts) // 0) >= $since))) as $r
  | ($markers | map(select($skill == "" or .skill == $skill))
      | map(. + { age_s: ($now - ((.started_at | ts) // $now)) })
      | map(. + { stale: (.age_s > $stale) })) as $m
  | {
      generated_at: ($now | todateiso8601),
      since: (if $since > 0 then ($since | todateiso8601) else null end),
      total: ($r | length),
      skills: (
        ($r | map(.skill)) + ($m | map(.skill)) | unique | map(. as $s |
          ($r | map(select(.skill == $s))) as $x
          | ($x | map(select(.status == "done")) | length) as $done
          | {
              skill: $s,
              runs: ($x | length),
              done: $done,
              blocked: ($x | map(select(.status == "blocked")) | length),
              failed: ($x | map(select(.status == "failed")) | length),
              success_pct: (if ($x | length) > 0 then ($done * 100 / ($x | length) | floor) else null end),
              median_duration_s: ($x | map(.duration_s | numbers) | median),
              top_fail_at: ($x | map(select(.status != "done") | .metrics.fail_at? | strings) | group_by(.) | map({ at: .[0], count: length })
                            | sort_by(-.count) | .[0] // null),
              last_finished_at: ($x | map(.finished_at) | max),
              running: ($m | map(select(.skill == $s and (.stale | not))) | length),
              stale: ($m | map(select(.skill == $s and .stale)) | length)
            })),
      running: ($m | map({ skill, id, run_id, started_at, age_s, stale }))
    }')

if [ "$JSON" = 1 ]; then
  echo "$SUMMARY"
  exit 0
fi

echo "$SUMMARY" | jq -r '
  def dur: if . == null then "-" elif . >= 3600 then "\(. / 3600 | floor)h\((. % 3600) / 60 | floor)m"
           elif . >= 60 then "\(. / 60 | floor)m\(. % 60 | floor)s" else "\(. | floor)s" end;
  if (.skills | length) == 0 then "No dx runs recorded yet (.ai/run-results/history.jsonl)."
  else
    "dx runs\(if .since then " since \(.since)" else "" end): \(.total)",
    "",
    "| Skill | Runs | Done | Blocked | Failed | Success | Median time | Most common stop | Running | Stale |",
    "|---|---|---|---|---|---|---|---|---|---|",
    (.skills[] | "| \(.skill) | \(.runs) | \(.done) | \(.blocked) | \(.failed) | \(if .success_pct == null then "-" else "\(.success_pct)%" end) | \(.median_duration_s | dur) | \(if .top_fail_at then "\(.top_fail_at.at) (\(.top_fail_at.count))" else "-" end) | \(.running) | \(.stale) |"),
    (if any(.running[]; .stale) then "", "Stale markers (started, no result; likely interrupted):",
      (.running[] | select(.stale) | "- \(.skill) \(.id) — started \(.started_at)") else empty end)
  end'

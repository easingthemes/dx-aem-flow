#!/usr/bin/env bash
# pr-answer-gate.sh — cheap, NO-AI triage for the scheduled PR-answer pipeline.
#
# The PR-answer cron fires hourly, but booting the LLM agent just to discover
# "nothing changed" burns tokens on dead PRs. This gate answers one question
# with plain REST (curl + jq, zero tokens):
#
#   "Has a reviewer added a NEW comment on any of my Active PRs since the last
#    time this pipeline ran?"
#
# It prints exactly one line to STDOUT — `NEW=1` (run the agent) or `NEW=0`
# (end the pipeline). All diagnostics go to STDERR.
#
# "Last run" needs no external state: it's the start time of this pipeline
# definition's previous COMPLETED run, read from the ADO Builds API. Using
# startTime (not finishTime) means comments that arrived while the previous run
# was executing are still re-evaluated — and /dx-pr-answer is idempotent
# (skips already-answered threads), so a re-check is harmless.
#
# Self-trigger guard: the agent posts its replies via this PAT's service
# account. Those replies must NOT count as "new comments" or the pipeline would
# answer its own answers forever. We resolve the PAT's own identity at runtime
# (connectionData) and exclude it AND MY_IDENTITIES (the PR author). Only a
# comment authored by someone OUTSIDE that set — a genuine reviewer — trips the
# gate.
#
# Usage:
#   pr-answer-gate.sh <orgUrl> <projectId> <repo> <definitionId>
#
#   projectId  MUST be the project GUID ($(System.TeamProjectId)), NOT the name —
#              a project name containing spaces (common in ADO) breaks the REST URL.
#
# Env:
#   ADO_PAT        (required) PAT with Code (Read) + Build (Read) — basic-auth ":$PAT"
#   MY_IDENTITIES  (required) comma-separated identities (email or display name)
#                  that own the PRs — e.g. "a@x.com, Jane Doe"
#   DX_SINCE       (optional) ISO-8601 override for the watermark (testing/backfill)
#
# Dependencies: curl, jq.
set -euo pipefail

ORG_URL="${1:?orgUrl required}"
PROJECT_ID="${2:?projectId (GUID) required}"
REPO="${3:?repo required}"
DEF_ID="${4:?definitionId required}"
ORG_URL="${ORG_URL%/}"

: "${ADO_PAT:?ADO_PAT env required}"
: "${MY_IDENTITIES:?MY_IDENTITIES env required}"

API="api-version=7.1"
CURL=(curl -fsS -u ":${ADO_PAT}" -H "Accept: application/json")

emit() { echo "$1"; exit 0; }   # write the single STDOUT marker and stop

# --- 1. Watermark = previous SUCCEEDED SCHEDULED run's startTime -------------
# resultFilter=succeeded: "completed" alone includes failed/canceled runs. If a
#   tick trips the gate but then crashes downstream, that failed run must NOT
#   advance the watermark — otherwise the comment that triggered it falls behind
#   the watermark and is never answered. Only a clean run moves the marker, so a
#   failed run's triggering comment is retried next tick.
# reasonFilter=schedule: the watermark must track only the scheduled SWEEP. A
#   manual prUrl run answers a single PR; if it advanced the shared watermark it
#   would silently skip earlier comments on other Active PRs next tick.
if [ -n "${DX_SINCE:-}" ]; then
  WATERMARK="$DX_SINCE"
  echo "Watermark (override): $WATERMARK" >&2
else
  BUILDS_URL="${ORG_URL}/${PROJECT_ID}/_apis/build/builds?definitions=${DEF_ID}&statusFilter=completed&resultFilter=succeeded&reasonFilter=schedule&\$top=1&queryOrder=finishTimeDescending&${API}"
  BUILDS=$("${CURL[@]}" "$BUILDS_URL") || { echo "WARN: builds query failed — running agent to be safe" >&2; emit "NEW=1"; }
  WATERMARK=$(jq -r '.value[0].startTime // .value[0].queueTime // empty' <<<"$BUILDS")
  if [ -z "$WATERMARK" ]; then
    echo "No previous succeeded scheduled run (first run?) — running agent" >&2
    emit "NEW=1"
  fi
  echo "Watermark (prev succeeded scheduled run startTime): $WATERMARK" >&2
fi

# Normalise to second precision so lexicographic compare is safe across
# differing fractional-second widths (all ADO times are UTC 'Z').
norm() { sed -E 's/\.[0-9]+Z$/Z/; s/\+00:00$/Z/'; }
WATERMARK=$(printf '%s' "$WATERMARK" | norm)

# --- 2. Exclusion set = MY_IDENTITIES ∪ the PAT's own identity ----------------
CONN=$("${CURL[@]}" "${ORG_URL}/_apis/connectionData?${API}" 2>/dev/null || echo '{}')
BOT_JSON=$(jq -c '
  [ .authenticatedUser.providerDisplayName?,
    .authenticatedUser.properties.Account."$value"?,
    .authenticatedUser.customDisplayName? ]
  | map(select(. != null) | ascii_downcase)' <<<"$CONN")
# MY_IDENTITIES is a raw string, NOT JSON — pass it via --arg (so jq treats it as
# a string), never as stdin. Piping it in would make jq parse it as a JSON
# document and fail ("Invalid numeric literal …") on the first bare token.
EXCLUDE_JSON=$(jq -nc --arg ids "$MY_IDENTITIES" --argjson bot "$BOT_JSON" '
  ($ids | split(",") | map(gsub("^\\s+|\\s+$";"") | ascii_downcase) | map(select(length > 0)))
  + $bot | unique')
echo "Excluded authors (self/author-side): $EXCLUDE_JSON" >&2

MY_JSON=$(jq -nc --arg ids "$MY_IDENTITIES" '
  $ids | split(",") | map(gsub("^\\s+|\\s+$";"") | ascii_downcase) | map(select(length > 0))')

# --- 3. My Active PRs ---------------------------------------------------------
PRS_URL="${ORG_URL}/${PROJECT_ID}/_apis/git/repositories/${REPO}/pullrequests?searchCriteria.status=active&\$top=200&${API}"
PRS=$("${CURL[@]}" "$PRS_URL") || { echo "WARN: PR list failed — running agent to be safe" >&2; emit "NEW=1"; }
# Bind createdBy fields to $u/$d BEFORE any(): inside `$mine | any(...)` the `.`
# rebinds to each string element of $mine, so `.createdBy.uniqueName` there would
# try to index a string ("Cannot index string with string \"createdBy\""). Same
# bind-first pattern as the thread loop below.
MY_PRS=$(jq -r --argjson mine "$MY_JSON" '
  .value[]
  | (.createdBy.uniqueName // "" | ascii_downcase) as $u
  | (.createdBy.displayName // "" | ascii_downcase) as $d
  | select( ($mine | any(. == $u)) or ($mine | any(. == $d)) )
  | .pullRequestId' <<<"$PRS")

if [ -z "$MY_PRS" ]; then
  echo "No Active PRs authored by MY_IDENTITIES" >&2
  emit "NEW=0"
fi

# --- 4. Any reviewer comment newer than the watermark? -----------------------
while read -r PRID; do
  [ -n "$PRID" ] || continue
  THREADS_URL="${ORG_URL}/${PROJECT_ID}/_apis/git/repositories/${REPO}/pullRequests/${PRID}/threads?${API}"
  THREADS=$("${CURL[@]}" "$THREADS_URL") || { echo "WARN: threads query failed for PR $PRID — skipping" >&2; continue; }
  HIT=$(jq -r --argjson exclude "$EXCLUDE_JSON" --arg since "$WATERMARK" '
    def normd: (. // "") | sub("\\.[0-9]+Z$";"Z") | sub("\\+00:00$";"Z");
    [ .value[]?.comments[]?
      | select( (.commentType // "text") == "text" )
      | select( (.isDeleted // false) | not )
      | (.author.uniqueName // "" | ascii_downcase) as $u
      | (.author.displayName // "" | ascii_downcase) as $d
      | select( ($exclude | any(. == $u)) or ($exclude | any(. == $d)) | not )
      | select( (.publishedDate | normd) > $since )
    ] | length' <<<"$THREADS")
  if [ "${HIT:-0}" -gt 0 ]; then
    echo "PR $PRID: $HIT new reviewer comment(s) since $WATERMARK" >&2
    emit "NEW=1"
  fi
  echo "PR $PRID: no new reviewer comments" >&2
done <<<"$MY_PRS"

emit "NEW=0"

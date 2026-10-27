#!/usr/bin/env bash
# discover-review-queue.sh — find Active PRs to review for the autonomous
# reviewer-queue pipeline (TODO #148).
#
# Emits (stdout) one PR web URL per line for every Active PR where a
# REVIEWER_IDENTITIES identity is an assigned reviewer with NO vote yet.
# Own PRs (authored by a REVIEWER_IDENTITIES identity) are excluded unless
# DX_REVIEW_OWN_PRS=true. Diagnostics go to stderr.
#
# A PR is also skipped when a REVIEWER_IDENTITIES identity has posted an
# "[AI Review]" comment since the PR's last push (newest iteration). Vote 0
# alone does not mean "not reviewed": automation casts NoVote for a MUST-FIX
# verdict, so without this check every sweep re-reviews the same commit. The
# check lives on ADO, not in the workspace, because each run starts fresh.
# If the threads or iterations can't be fetched, the PR is kept (fail-open).
#
# Usage:
#   discover-review-queue.sh <orgUrl> <project> <repo>
#
# Env:
#   ADO_PAT                 (required) PAT with Code (Read) — basic-auth ":$PAT"
#   REVIEWER_IDENTITIES     (required) comma-separated identities — email or
#                           display name, e.g. "a@x.com, Jane Doe"
#   DX_REVIEW_OWN_PRS       "true" → keep PRs authored by a reviewer identity
#
# Dependencies: curl, jq.
set -euo pipefail

ORG_URL="${1:?orgUrl required}"
PROJECT="${2:?project required}"
REPO="${3:?repo required}"
ORG_URL="${ORG_URL%/}"

# URL-encode the project + repo path segments (project names often contain
# spaces, e.g. "My Team Project") so the REST URL is well-formed.
PROJECT_ENC=$(printf '%s' "$PROJECT" | jq -sRr @uri)
REPO_ENC=$(printf '%s' "$REPO" | jq -sRr @uri)

: "${ADO_PAT:?ADO_PAT env required}"
: "${REVIEWER_IDENTITIES:?REVIEWER_IDENTITIES env required}"
REVIEW_OWN="0"
[ "${DX_REVIEW_OWN_PRS:-}" = "true" ] && REVIEW_OWN="1"

# Build a JSON array of lowercased, trimmed identity tokens.
IDS_JSON=$(printf '%s' "$REVIEWER_IDENTITIES" \
  | jq -R -c 'split(",") | map(gsub("^\\s+|\\s+$";"") | ascii_downcase) | map(select(length > 0))')
echo "Reviewer identities: $IDS_JSON (review_own=$REVIEW_OWN)" >&2

# List Active PRs in the repo. $top=200 is well beyond any real reviewer queue;
# if a repo ever exceeds it, paginate with $skip (documented limitation).
API="${ORG_URL}/${PROJECT_ENC}/_apis/git/repositories/${REPO_ENC}/pullrequests?searchCriteria.status=active&\$top=200&api-version=7.1"
RESP=$(curl -fsS -u ":${ADO_PAT}" -H "Accept: application/json" "$API") || {
  echo "ERROR: failed to list PRs for ${PROJECT}/${REPO}" >&2
  exit 1
}

# Keep PRs where some reviewer identity is assigned AND has vote == 0;
# drop own PRs unless the override is on. Emit pullRequestId per line.
jq -r --argjson ids "$IDS_JSON" --arg own "$REVIEW_OWN" '
  def lc: (. // "") | ascii_downcase;
  def mine($u; $d): ($ids | any(. == $u)) or ($ids | any(. == $d));
  .value[]
  | . as $pr
  | ([ $pr.reviewers[]?
       | (.uniqueName | lc) as $u | (.displayName | lc) as $d
       | select( mine($u; $d) ) | select( (.vote // 0) == 0 ) ] | length > 0) as $assignedNoVote
  | mine($pr.createdBy.uniqueName | lc; $pr.createdBy.displayName | lc) as $isOwn
  | select( $assignedNoVote and ( ($own == "1") or ($isOwn | not) ) )
  | .pullRequestId
' <<<"$RESP" | while read -r PRID; do
  [ -n "$PRID" ] || continue
  PR_API="${ORG_URL}/${PROJECT_ENC}/_apis/git/repositories/${REPO_ENC}/pullRequests/${PRID}"
  if ITER=$(curl -fsS -u ":${ADO_PAT}" -H "Accept: application/json" "${PR_API}/iterations?api-version=7.1") \
     && THREADS=$(curl -fsS -u ":${ADO_PAT}" -H "Accept: application/json" "${PR_API}/threads?api-version=7.1"); then
    # Both timestamps in epoch seconds; ADO's fractional seconds vary in
    # length, so string comparison of the raw ISO values is not safe.
    # Piped, not --argjson: a busy PR's threads payload can exceed ARG_MAX.
    REVIEWED=$(printf '%s\n%s\n' "$ITER" "$THREADS" | jq -rs --argjson ids "$IDS_JSON" '
      def lc: (. // "") | ascii_downcase;
      def epoch: sub("\\.[0-9]+"; "") | sub("Z$"; "") + "Z" | fromdateiso8601;
      .[0] as $iter | .[1] as $threads
      | ([ $iter.value[]?.createdDate | select(.) | epoch ] | max) as $push
      | ([ $threads.value[]?.comments[]?
           | select((.content // "") | contains("[AI Review]"))
           | select((.author.uniqueName | lc) as $u | (.author.displayName | lc) as $d
                    | ($ids | any(. == $u or . == $d)))
           | .publishedDate | select(.) | epoch ] | max) as $review
      | if $push != null and $review != null and $review >= $push then "yes" else "no" end
    ') || REVIEWED="no"
    if [ "$REVIEWED" = "yes" ]; then
      echo "skip PR ${PRID}: already reviewed since its last push" >&2
      continue
    fi
  else
    echo "WARN: could not read iterations/threads for PR ${PRID}; queueing it" >&2
  fi
  # Emit the web PR URL with the encoded project segment (it may contain
  # spaces); /dx-pr-review URL-decodes it back when it parses the PR URL.
  echo "${ORG_URL}/${PROJECT_ENC}/_git/${REPO}/pullrequest/${PRID}"
done

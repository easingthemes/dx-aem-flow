#!/usr/bin/env bash
# rules-freshness.sh — report how stale the committed AI rules and seed data are.
#
# For each file under .ai/rules/ and .ai/project/ prints one tab-separated line:
#   <status>  <file>  <last-change YYYY-MM-DD|->  <age-days|->  <code-commits-since|->
# status: fresh | stale | untracked
#
# A file is stale when BOTH its age exceeds --max-days AND more than --max-commits
# commits touched the rest of the repo since its last change. Either alone is normal:
# an old rule in a quiet repo is fine, and a busy week does not outdate a rule.
# "Rest of the repo" excludes .ai/ and .claude/ so rule edits don't count as code churn.
#
# Read-only, git only, no network. Exit 0 with a report, 2 on usage error or no git repo.
#
# Usage: rules-freshness.sh [--max-days N] [--max-commits N] [--repo DIR]
set -u

MAX_DAYS=90
MAX_COMMITS=200
REPO="."

while [ $# -gt 0 ]; do
  case "$1" in
    --max-days)    MAX_DAYS="${2:-}"; shift 2 ;;
    --max-commits) MAX_COMMITS="${2:-}"; shift 2 ;;
    --repo)        REPO="${2:-}"; shift 2 ;;
    -h|--help)     sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "rules-freshness: unknown argument: $1" >&2; exit 2 ;;
  esac
done

for n in "$MAX_DAYS" "$MAX_COMMITS"; do
  case "$n" in ''|*[!0-9]*) echo "rules-freshness: thresholds must be non-negative integers" >&2; exit 2 ;; esac
done

cd "$REPO" 2>/dev/null || { echo "rules-freshness: cannot cd to $REPO" >&2; exit 2; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "rules-freshness: not a git repository" >&2; exit 2; }
git rev-parse --verify -q HEAD >/dev/null || { echo "rules-freshness: repository has no commits" >&2; exit 2; }
cd "$(git rev-parse --show-toplevel)" || exit 2

NOW="${DX_NOW:-$(date +%s)}"

for dir in .ai/rules .ai/project; do
  [ -d "$dir" ] || continue
  find "$dir" -type f | LC_ALL=C sort | while IFS= read -r f; do
    sha=$(git log -1 --format=%H -- "$f" 2>/dev/null)
    if [ -z "$sha" ]; then
      printf 'untracked\t%s\t-\t-\t-\n' "$f"
      continue
    fi
    ct=$(git log -1 --format=%ct "$sha")
    day=$(git log -1 --format=%cs "$sha")
    age=$(( (NOW - ct) / 86400 ))
    [ "$age" -lt 0 ] && age=0
    since=$(git rev-list --count "$sha"..HEAD -- . ':(exclude).ai' ':(exclude).claude')
    status=fresh
    if [ "$age" -gt "$MAX_DAYS" ] && [ "$since" -gt "$MAX_COMMITS" ]; then
      status=stale
    fi
    printf '%s\t%s\t%s\t%s\t%s\n' "$status" "$f" "$day" "$age" "$since"
  done
done
exit 0

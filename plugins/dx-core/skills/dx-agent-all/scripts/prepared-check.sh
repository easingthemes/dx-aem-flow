#!/usr/bin/env bash
# prepared-check.sh — Report which spec files a ticket already has, so
# dx-agent-all can continue a plan prepared earlier (by an architect via
# /dx-prep, or by anyone, days ago) instead of regenerating it.
#
# Usage: prepared-check.sh <spec-dir> [<review-tag>]
#
# Prints KEY=VALUE lines (stdout), one per key, always all keys:
#   REQ=prepared|partial|none        raw-story.md + explain.md + research.md
#   PLAN=prepared|in-progress|done|none
#                                    implement.md step statuses: all pending →
#                                    prepared; all done → done; else in-progress
#   PLAN_WIKI=yes|no                 docs/plan-wiki.md (written by /dx-prep)
#   PLAN_BY=self|other|unknown       last committer of implement.md vs git user.email
#   REVIEW=yes|no|n/a                <review-tag> in raw-story.md **Tags:**
#                                    (n/a when no tag is given)
# Exit 0 always; a missing spec dir reports everything as none.

set -uo pipefail

SPEC_DIR="${1:-}"
REVIEW_TAG="${2:-}"

req_count=0
for f in raw-story.md explain.md research.md; do
  [ -n "$SPEC_DIR" ] && [ -f "$SPEC_DIR/$f" ] && req_count=$((req_count + 1))
done
case "$req_count" in
  3) echo "REQ=prepared" ;;
  0) echo "REQ=none" ;;
  *) echo "REQ=partial" ;;
esac

IMPL="$SPEC_DIR/implement.md"
if [ -n "$SPEC_DIR" ] && [ -f "$IMPL" ]; then
  # **Status:** lines under ### Step headings. Lowercase, first word only.
  statuses=$(grep -E '^\*\*Status:\*\*' "$IMPL" | sed -E 's/^\*\*Status:\*\*[[:space:]]*//' \
    | awk '{print tolower($1)}')
  total=$(printf '%s\n' "$statuses" | grep -c .)
  pending=$(printf '%s\n' "$statuses" | grep -cx 'pending')
  done_n=$(printf '%s\n' "$statuses" | grep -cx 'done')
  if [ "$total" -eq 0 ]; then echo "PLAN=in-progress"      # unparseable: never treat as fresh
  elif [ "$pending" -eq "$total" ]; then echo "PLAN=prepared"
  elif [ "$done_n" -eq "$total" ]; then echo "PLAN=done"
  else echo "PLAN=in-progress"; fi

  me=$(git config user.email 2>/dev/null || true)
  by=$(git log -1 --format=%ae -- "$IMPL" 2>/dev/null || true)
  if [ -z "$by" ] || [ -z "$me" ]; then echo "PLAN_BY=unknown"
  elif [ "$(printf '%s' "$by" | tr 'A-Z' 'a-z')" = "$(printf '%s' "$me" | tr 'A-Z' 'a-z')" ]; then echo "PLAN_BY=self"
  else echo "PLAN_BY=other"; fi
else
  echo "PLAN=none"
  echo "PLAN_BY=unknown"
fi

if [ -n "$SPEC_DIR" ] && [ -f "$SPEC_DIR/docs/plan-wiki.md" ]; then echo "PLAN_WIKI=yes"; else echo "PLAN_WIKI=no"; fi

if [ -z "$REVIEW_TAG" ]; then
  echo "REVIEW=n/a"
else
  tags=$( { [ -n "$SPEC_DIR" ] && grep -m1 -E '^\*\*Tags:\*\*' "$SPEC_DIR/raw-story.md" 2>/dev/null; } \
    | sed -E 's/^\*\*Tags:\*\*[[:space:]]*//')
  hit=no
  IFS=';' read -ra parts <<< "$tags"
  for t in "${parts[@]}"; do
    t=$(printf '%s' "$t" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
    if [ -n "$t" ] && [ "$(printf '%s' "$t" | tr 'A-Z' 'a-z')" = "$(printf '%s' "$REVIEW_TAG" | tr 'A-Z' 'a-z')" ]; then
      hit=yes
    fi
  done
  echo "REVIEW=$hit"
fi

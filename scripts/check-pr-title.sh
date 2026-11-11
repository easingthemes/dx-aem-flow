#!/usr/bin/env bash
# check-pr-title.sh — fail a PR title semantic-release cannot classify.
#
# PRs are squash-merged and the PR title becomes the commit on main. A title
# without a conventional type (`fix:`, `feat:`, …) is ignored by
# semantic-release: the change ships to consumers (they track main) but no
# version, tag or CHANGELOG entry is made. That happened once (3.14.0 → nothing).
#
# Usage: check-pr-title.sh "<title>"   — exit 0 ok, 1 not conventional
set -euo pipefail
title="${1-}"
types='feat|fix|perf|refactor|docs|chore|ci|test|style|build|revert'
if printf '%s' "$title" | grep -qE "^($types)(\([a-z0-9._-]+\))?!?: [^ ]"; then
  exit 0
fi
echo "PR title is not a conventional commit: \"$title\""
echo "Use <type>(<scope>): <summary>, type one of: ${types//|/, }. feat → minor, fix/perf/refactor → patch, the rest → no release."
exit 1

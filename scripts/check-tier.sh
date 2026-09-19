#!/usr/bin/env bash
# check-tier.sh — Classify changed files by consumer blast radius.
#
# Consumers install via `/plugin marketplace add easingthemes/dx-aem-flow`, which
# resolves plugins through relative paths in .claude-plugin/marketplace.json with no
# git ref pinned — so they track `main`, not the released tag. A `docs:` commit that
# edits a SKILL.md therefore reaches real projects with no version bump and no
# changelog entry. Commit type is not a safety valve; the PATH is.
#
#   Tier A  inert    — nothing a consumer's agent loads at runtime
#   Tier B  ships    — loaded by every consumer project on their next refresh
#
# Tier C (needs a live ADO / AEM / Copilot CLI / Figma / pipeline to verify) is a
# property of the WORK, not of the diff, so it cannot be detected here. It is called
# out in CONTRIBUTING.md and reviewed by a human.
#
# Usage:
#   scripts/check-tier.sh                 # classify the diff vs origin/main
#   scripts/check-tier.sh --base <ref>    # classify the diff vs <ref>
#   scripts/check-tier.sh -               # classify newline-separated paths on stdin
#
# Exit: 0 = Tier A only.  1 = at least one Tier B path.  2 = usage error.

set -uo pipefail

BASE="${BASE:-origin/main}"
MODE="diff"

while [ $# -gt 0 ]; do
  case "$1" in
    --base) BASE="${2:?--base needs a ref}"; shift 2 ;;
    -)      MODE="stdin"; shift ;;
    -h|--help) sed -n '2,24p' "$0"; exit 0 ;;
    *)      echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

# Paths that ship to consumers. Anchored, so a match means the real thing and not a
# lookalike deeper in the tree.
SHIPS='^plugins/[^/]+/(skills|agents|rules|templates|data|hooks)/
^plugins/[^/]+/\.(claude|cursor)-plugin/plugin\.json$
^plugins/[^/]+/\.mcp\.json$
^\.claude-plugin/marketplace\.json$
^gemini-extension\.json$'

# Carve-outs INSIDE the shipping paths. These files are distributed but never loaded
# by an agent — they are test scaffolding, so changing them cannot alter a consumer's
# behaviour.
#
# `evals/` is deliberately NOT listed: plugins/*/evals/ does not match SHIPS in the
# first place, so an entry here would be unreachable. A pattern that can never fire is
# how a validator goes blind without anyone noticing.
INERT='(^|/)(__tests__|tests)/
\.test\.(js|sh)$
(^|/)run-tests\.sh$'

ships_re=$(printf '%s' "$SHIPS" | paste -sd'|' -)
inert_re=$(printf '%s' "$INERT" | paste -sd'|' -)

if [ "$MODE" = "stdin" ]; then
  files=$(cat)
else
  if ! git rev-parse --verify --quiet "$BASE" >/dev/null; then
    echo "ERROR: base ref '$BASE' not found. Fetch it first, or pass --base." >&2
    exit 2
  fi
  # A stale base is the most confusing way to get a wrong answer: a local `main` that
  # is behind origin replays old commits into the diff and reports Tier B on a
  # docs-only branch. Default is origin/main for this reason; warn when an override
  # has a remote counterpart that is ahead.
  upstream="origin/${BASE##*/}"
  if [ "$BASE" != "$upstream" ] && git rev-parse --verify --quiet "$upstream" >/dev/null; then
    behind=$(git rev-list --count "$BASE".."$upstream" 2>/dev/null || echo 0)
    if [ "${behind:-0}" -gt 0 ]; then
      echo "WARNING: '$BASE' is $behind commit(s) behind '$upstream'." >&2
      echo "         The diff below may include commits already on $upstream." >&2
      echo "         Run: git fetch origin && bash $0 --base $upstream" >&2
      echo >&2
    fi
  fi

  # Committed on this branch, PLUS anything still in the working tree. Diffing only
  # BASE...HEAD is commit-to-commit, so an uncommitted edit to a SKILL.md reported
  # "PASS — cannot change behaviour in a consumer project", which is the exact false
  # negative this script exists to prevent. CONTRIBUTING tells people to run it BEFORE
  # pushing, so the dirty tree is the normal case, not the edge case.
  files=$(
    {
      git diff --name-only "$BASE"...HEAD
      git diff --name-only HEAD          # staged + unstaged
      git ls-files --others --exclude-standard   # untracked
    } | sort -u
  )
fi

# Drop blanks so an empty diff does not count as one unnamed file.
files=$(printf '%s\n' "$files" | sed '/^[[:space:]]*$/d')

if [ -z "$files" ]; then
  echo "No changed files. Tier A."
  exit 0
fi

tier_b=$(printf '%s\n' "$files" \
  | grep -E "$ships_re" 2>/dev/null \
  | grep -Ev "$inert_re" 2>/dev/null)

total=$(printf '%s\n' "$files" | wc -l | tr -d ' ')

if [ -z "$tier_b" ]; then
  echo "=== Tier A — inert ==="
  echo "$total file(s) changed, none loaded by a consumer's agent."
  echo
  echo "PASS — this diff cannot change behaviour in a consumer project."
  exit 0
fi

count=$(printf '%s\n' "$tier_b" | wc -l | tr -d ' ')
echo "=== Tier B — ships to consumers ==="
printf '%s\n' "$tier_b" | sed 's/^/  /'
echo
echo "$count of $total changed file(s) are loaded by every consumer project."
echo
echo "This is not a failure by itself — Tier B changes are normal and expected."
echo "It means the diff needs validation in a real consumer project before merge,"
echo "and must not be labelled 'tier/a'. See CONTRIBUTING.md § 1."
exit 1

#!/usr/bin/env bash
# Tier-0 of the dx-discover-repos cascade — explicit repo override.
#
# Reads a "repos: a, b, c" directive from the trigger comment (the text a human
# typed after the @kai-<agent> tag) and maps each alias to its registry entry.
# Deterministic, no LLM. First tier to run; a non-empty result wins the cascade.
#
# Usage: parse-explicit-repos.sh <comment-file|-> <repos.json>
#   <comment-file>  path to a file holding the comment text, or "-" for stdin
#   <repos.json>    the repo registry (alias -> metadata)
#
# Stdout: JSON array [{alias, repoId, adoProject, cloneUrl, branch, reason}]
#         (empty array [] when no `repos:` directive is present)
# Exit codes:
#   0  — parsed (array may be empty)
#   2  — bad arguments / registry not readable
#
# Unknown aliases (not keys in repos.json) are skipped with a stderr warning —
# the cascade never invents repos. If a `repos:` directive lists ONLY unknown
# aliases, the result is an empty array and the cascade falls through.
set -euo pipefail

SRC="${1:?comment-file or - required}"
REG="${2:?repos.json required}"
[ -f "$REG" ] || { echo "ERROR: repos registry not found: $REG" >&2; exit 2; }

if [ "$SRC" = "-" ]; then COMMENT=$(cat); else
  [ -f "$SRC" ] || { echo "ERROR: comment file not found: $SRC" >&2; exit 2; }
  COMMENT=$(cat "$SRC")
fi

# Pull the first `repos:` directive (case-insensitive) and take the rest of that
# line. Comment may be HTML (ADO System.History) — strip tags first so
# "repos:&nbsp;a,&nbsp;b" and "<div>repos: a</div>" both parse.
PLAIN=$(printf '%s' "$COMMENT" | sed -E 's/<[^>]+>/ /g; s/&nbsp;/ /g')
LINE=$(printf '%s\n' "$PLAIN" | grep -ioE 'repos:[^<]*' | head -1 || true)

if [ -z "$LINE" ]; then
  echo "[]"
  exit 0
fi

# Everything after "repos:". Split on commas; for each piece take the first
# whitespace-delimited token (so "b please" -> "b"). Aliases are single kebab tokens.
RAW=$(printf '%s' "$LINE" | sed -E 's/^[Rr][Ee][Pp][Oo][Ss]:[[:space:]]*//')
ALIASES=()
IFS=',' read -ra PARTS <<<"$RAW"
for p in "${PARTS[@]}"; do
  tok=$(printf '%s' "$p" | xargs | awk '{print $1}')
  [ -n "$tok" ] && ALIASES+=("$tok")
done

OUT='[]'
for a in "${ALIASES[@]}"; do
  ENTRY=$(jq -c --arg a "$a" --arg reason "explicit 'repos:' directive in trigger comment" '
    .[$a] as $r
    | if $r == null then empty
      else {alias:$a, repoId:$r.repoId, adoProject:$r.adoProject, cloneUrl:$r.cloneUrl, branch:$r.defaultBranch, reason:$reason}
      end' "$REG")
  if [ -z "$ENTRY" ]; then
    echo "WARN: alias '$a' not in repos registry — skipping (never invent repos)." >&2
    continue
  fi
  OUT=$(printf '%s' "$OUT" | jq -c --argjson e "$ENTRY" '. += [$e]')
done

echo "$OUT"

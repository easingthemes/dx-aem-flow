#!/usr/bin/env bash
# PreToolUse(Bash) guard for contributors to this repo: before a commit, push,
# or GitHub PR/issue write, run scripts/check-customer-data.sh over what is
# about to be published. Exit 2 blocks the call and shows stderr to Claude.
# Inert when no denylist is configured (see the script header).
set -uo pipefail
CMD=$(jq -r '.tool_input.command // empty' 2>/dev/null)
[ -n "$CMD" ] || exit 0
grep -qE '(^|[;&|(]|[[:space:]])(git (commit|push)|gh (pr|issue) (create|edit|comment|review))\b' <<<"$CMD" || exit 0

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
CHECK="$ROOT/scripts/check-customer-data.sh"
[ -x "$CHECK" ] || exit 0
OUT=""; RC=0
scan() { local o; o=$("$CHECK" "$@" 2>/dev/null); local r=$?; [ $r -eq 1 ] && { OUT+="$o"$'\n'; RC=1; }; }

# The command text carries -m messages, heredoc bodies and --body values.
scan text "command" <<<"$CMD"
grep -qE 'git commit' <<<"$CMD" && scan worktree
if grep -qE 'git push' <<<"$CMD"; then
  BASE=$(git -C "$ROOT" merge-base HEAD origin/main 2>/dev/null) && scan diff "$BASE"
fi
# Files passed as --body-file / -F (commit message file or PR body file).
while read -r f; do
  [ -f "$f" ] && scan files "$f"
done < <(grep -oE '(--body-file|-F|--file)[= ]+[^ ;&|]+' <<<"$CMD" | sed -E 's/^(--body-file|-F|--file)[= ]+//')

if [ "$RC" -eq 1 ]; then
  { printf '%s' "$OUT"
    echo "Blocked: this repo is public and the text above would publish a denylisted consumer identifier."
    echo "Replace it with a placeholder (my-org, my-project, 12345, bot@example.com) and retry. Do not quote the term."
  } >&2
  exit 2
fi
exit 0

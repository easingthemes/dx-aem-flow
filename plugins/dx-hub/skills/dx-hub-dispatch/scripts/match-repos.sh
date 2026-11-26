#!/usr/bin/env bash
# match-repos.sh — pick hub repos for a ticket by name and keyword, before any
# fe/be capability guess.
#
# Usage: match-repos.sh <config.yaml> <ticket-text-file>
#   ticket-text-file: the ticket's title, area path and tags (one per line).
#   Leave the description out: it often names other products in passing.
#
# A repo matches when the text contains, as a whole word (case-insensitive):
#   1. its full name                                   → reason "name"
#   2. one of its repos[].keywords                     → reason "keyword:<kw>"
#   3. a distinctive token of its name                 → reason "name-token:<tok>"
#      Tokens split the name on - _ . and space. A token counts only if it has
#      3+ characters, is not all digits, is not a generic word (stoplist below)
#      and appears in no other repo's name — so a shared prefix or suffix
#      never matches every repo at once.
#
# Stdout: <repo-name>\t<reason> per matched repo (first reason wins).
# Exit codes: 0 matched, 8 nothing matched, 2/3 from hub-config.sh.

set -uo pipefail

CFG="${1:?config.yaml required}"
TEXT_FILE="${2:?ticket text file required}"
[ -f "$TEXT_FILE" ] || { echo "error: ticket text file not found: $TEXT_FILE" >&2; exit 2; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
resolved="$(bash "$HERE/hub-config.sh" "$CFG" 2>/dev/null)"
rc=$?
[ "$rc" = 2 ] || [ "$rc" = 3 ] && exit "$rc"

STOP=" experience platform core global common shared main base web site sites app apps api service services repo frontend backend aem cms digital ui fe be the and new "

text="$(tr -s '[:space:]' ' ' < "$TEXT_FILE")"
has_word() { printf '%s' "$text" | grep -qiwF -- "$1"; }

repo_lines="$(printf '%s\n' "$resolved" | grep '^repo=' || true)"
[ -z "$repo_lines" ] && exit 8

tokens_of() { printf '%s' "$1" | tr '_. ' '---' | tr '-' '\n' | tr 'A-Z' 'a-z' | sed '/^$/d'; }

# Count how many repos each token appears in.
all_tokens="$(while IFS=$'\t' read -r first _rest; do tokens_of "${first#repo=}" | sort -u; done <<< "$repo_lines" | sort | uniq -c)"
token_repo_count() { printf '%s\n' "$all_tokens" | awk -v t="$1" '$2 == t { print $1; found=1 } END { if (!found) print 0 }'; }

matched=0
while IFS=$'\037' read -r first _path _proj _caps kws; do
  name="${first#repo=}"
  reason=""
  if has_word "$name"; then
    reason="name"
  fi
  if [ -z "$reason" ] && [ -n "$kws" ]; then
    IFS=',' read -r -a kw_arr <<< "$kws"
    for kw in "${kw_arr[@]}"; do
      [ -n "$kw" ] && has_word "$kw" && { reason="keyword:$kw"; break; }
    done
  fi
  if [ -z "$reason" ]; then
    while IFS= read -r tok; do
      [ "${#tok}" -lt 3 ] && continue
      printf '%s' "$tok" | grep -Eq '^[0-9]+$' && continue
      case "$STOP" in *" $tok "*) continue ;; esac
      [ "$(token_repo_count "$tok")" != 1 ] && continue
      has_word "$tok" && { reason="name-token:$tok"; break; }
    done < <(tokens_of "$name" | sort -u)
  fi
  if [ -n "$reason" ]; then
    printf '%s\t%s\n' "$name" "$reason"
    matched=1
  fi
done < <(printf '%s\n' "$repo_lines" | tr '\t' '\037')

[ "$matched" = 1 ] || exit 8

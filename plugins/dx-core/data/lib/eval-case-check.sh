#!/usr/bin/env bash
# eval-case-check.sh — check `claude plugin eval` case folders before a billed run.
#
# The eval runner validates graders with strict schemas: an unknown frontmatter
# key, a wrong grader type or a missing field fails the case only when it runs.
# This checks the same rules for free. Contract: docs/reference/eval-cases.md.
#
# Usage: eval-case-check.sh <dir>...
#   <dir> is a case folder (has prompt.md or case.yaml) or a folder holding
#   case folders at any depth (e.g. plugins/dx-core/evals).
#
# Prints one line per problem: "<file>: <message>". Exit 0 = no problems,
# 1 = problems found, 2 = usage error. No network, no eval run.

set -uo pipefail

[ $# -gt 0 ] || { echo "usage: eval-case-check.sh <dir>..." >&2; exit 2; }

PROBLEMS=0
problem() { echo "$1: $2"; PROBLEMS=$((PROBLEMS + 1)); }

# Top-level frontmatter keys of a markdown file, one per line (between the first two --- lines).
fm_keys() { awk 'NR==1 && $0!="---" {exit} NR==1 {next} /^---[[:space:]]*$/ {exit} /^[A-Za-z_][A-Za-z0-9_-]*[[:space:]]*:/ {sub(/[[:space:]]*:.*/, ""); print}' "$1"; }
# Raw value of one top-level frontmatter key (rest of the line, trimmed, quotes kept).
fm_val() { awk -v k="$2" 'NR==1 && $0!="---" {exit} NR==1 {next} /^---[[:space:]]*$/ {exit} index($0, k":")==1 {sub(/^[^:]*:[[:space:]]*/, ""); sub(/[[:space:]]+$/, ""); print; exit}' "$1"; }
has_fm() { [ "$(head -1 "$1")" = "---" ] && [ "$(awk 'NR>1 && /^---[[:space:]]*$/ {print "y"; exit}' "$1")" = y ]; }
# Body after the frontmatter, non-blank lines only.
body() { awk 'NR==1 && $0=="---" {f=1; next} f==1 && /^---[[:space:]]*$/ {f=2; next} f!=1' "$1" | grep -v '^[[:space:]]*$'; }
unq() { local v="$1"; v="${v#\"}"; v="${v%\"}"; v="${v#\'}"; v="${v%\'}"; printf '%s' "$v"; }

allowed_keys() {
  case "$1" in
    regex) echo "type name target pattern flags match weight arm" ;;
    file_exists) echo "type name path exists weight arm" ;;
    tool_used) echo "type name tool input_match min max weight arm" ;;
    tool_order) echo "type name before after weight arm" ;;
    llm) echo "type name criteria focus weight arm" ;;
    baseline) echo "type name baseline_file criteria weight arm" ;;
  esac
}

check_target() { # file key value
  local v; v="$(unq "$3")"
  case "$v" in
    last_message|trace|files|mock_calls) ;;
    \{*source:*file*path:*\}) ;;
    *) problem "$1" "$2 must be last_message, trace, files, mock_calls or {source: file, path: <path>} (got: $3)" ;;
  esac
}

check_grader() {
  local f="$1" type k keys v
  has_fm "$f" || { problem "$f" "grader needs a --- frontmatter block"; return; }
  type="$(unq "$(fm_val "$f" type)")"
  if [ -z "$(allowed_keys "$type")" ]; then
    problem "$f" "type must be regex, file_exists, tool_used, tool_order, llm or baseline (got: ${type:-none})"; return
  fi
  keys="$(allowed_keys "$type")"
  while IFS= read -r k; do
    [ -n "$k" ] || continue
    case " $keys " in *" $k "*) ;; *) problem "$f" "unknown key '$k' for type $type (allowed: $keys)" ;; esac
  done < <(fm_keys "$f")

  v="$(fm_val "$f" weight)"; [ -z "$v" ] || [[ "$v" =~ ^[0-9]*\.?[0-9]+$ ]] && [ "$v" != 0 ] || problem "$f" "weight must be a positive number"
  v="$(unq "$(fm_val "$f" arm)")"; [ -z "$v" ] || [ "$v" = with-only ] || [ "$v" = both ] || problem "$f" "arm must be with-only or both"

  case "$type" in
    regex)
      [ -n "$(fm_val "$f" pattern)" ] || [ -n "$(body "$f")" ] || problem "$f" "regex needs a pattern (frontmatter pattern: or the body)"
      v="$(fm_val "$f" target)"; [ -z "$v" ] || check_target "$f" target "$v"
      v="$(unq "$(fm_val "$f" match)")"; [ -z "$v" ] || [ "$v" = contains ] || [ "$v" = not_contains ] || [[ "$v" =~ ^count:[0-9]+$ ]] \
        || problem "$f" "match must be contains, not_contains or count:N (got: $v)"
      v="$(unq "$(fm_val "$f" flags)")"; [[ "$v" =~ ^[dgimsuvy]*$ ]] || problem "$f" "flags must be JS RegExp flags (d g i m s u v y)" ;;
    file_exists)
      [ -n "$(fm_val "$f" path)" ] || problem "$f" "file_exists needs path:"
      v="$(fm_val "$f" exists)"; [ -z "$v" ] || [ "$v" = true ] || [ "$v" = false ] || problem "$f" "exists must be true or false" ;;
    tool_used)
      [ -n "$(fm_val "$f" tool)" ] || problem "$f" "tool_used needs tool:"
      for k in min max; do v="$(fm_val "$f" $k)"; [ -z "$v" ] || [[ "$v" =~ ^[0-9]+$ ]] || problem "$f" "$k must be a non-negative integer"; done ;;
    tool_order)
      { fm_keys "$f" | grep -qx before && fm_keys "$f" | grep -qx after; } || problem "$f" "tool_order needs before: and after:" ;;
    llm)
      [ -n "$(fm_val "$f" criteria)" ] || [ -n "$(body "$f")" ] || problem "$f" "llm needs criteria (frontmatter criteria: or the body)"
      v="$(fm_val "$f" focus)"; [ -z "$v" ] || check_target "$f" focus "$v" ;;
    baseline)
      [ -n "$(fm_val "$f" baseline_file)" ] || problem "$f" "baseline needs baseline_file:"
      [ -n "$(fm_val "$f" criteria)" ] || [ -n "$(body "$f")" ] || problem "$f" "baseline needs criteria (frontmatter criteria: or the body)" ;;
  esac
}

check_case() {
  local d="$1" g n=0
  if [ -f "$d/prompt.md" ]; then
    if [ -z "$(body "$d/prompt.md")" ] && ! grep -q '^[[:space:]]*prompt:' "$d/case.yaml" 2>/dev/null; then
      problem "$d/prompt.md" "empty prompt (the body is the prompt)"
    fi
    grep -q '^TODO: describe what the agent should do' "$d/prompt.md" && problem "$d/prompt.md" "still the blank 'init' template"
  elif ! grep -q '^[[:space:]]*prompt:' "$d/case.yaml" 2>/dev/null; then
    problem "$d" "no prompt: add prompt.md (body = prompt) or execution.prompt in case.yaml"
  fi
  if [ -f "$d/case.yaml" ]; then
    grep -q '^schema_version:' "$d/case.yaml" || problem "$d/case.yaml" "needs schema_version"
    v="$(awk '/^[[:space:]]*scaffold_script:/ {sub(/^[^:]*:[[:space:]]*/, ""); print; exit}' "$d/case.yaml")"
    [ -z "$v" ] || [ -f "$d/$(unq "$v")" ] || problem "$d/case.yaml" "scaffold_script not found: $v"
  fi
  for g in "$d"/graders/*.md; do
    [ -f "$g" ] || continue
    n=$((n + 1)); check_grader "$g"
  done
  [ "$n" -gt 0 ] || problem "$d" "no graders (graders/*.md)"
}

for root in "$@"; do
  [ -d "$root" ] || { echo "eval-case-check.sh: not a directory: $root" >&2; exit 2; }
  found=0
  while IFS= read -r c; do
    found=1; check_case "$c"
  done < <(find "$root" -type f \( -name prompt.md -o -name case.yaml \) -not -path '*/results/*' -not -path '*/resources/*' -exec dirname {} \; | sort -u)
  [ "$found" = 1 ] || problem "$root" "no eval cases found (prompt.md or case.yaml)"
done

[ "$PROBLEMS" -eq 0 ] && exit 0 || exit 1

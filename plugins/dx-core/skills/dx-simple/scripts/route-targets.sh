#!/usr/bin/env bash
# Router resolver for /dx-simple multi-repo routing (TODO #142).
# Resolves a ticket's declared (platform,brand,scope) to the set of child
# pipelines to queue. Candidate repos = those present in CROSS_REPO_PIPELINE_MAP.
#
# Usage: route-targets.sh <simple-block.yaml> <config.yaml> <cross-repo-map-json>
# Stdout: JSON array of {repo, pipelineId, scope, authoring}
# Exit codes:
#   0 — resolved (array may be emitted)
#   3 — ambiguous: a required field (platform/brand) is missing
#   8 — no candidate repo matched
set -euo pipefail

BLOCK="${1:?simple-block.yaml required}"
export CONFIG_FILE="${2:?config.yaml required}"
MAP="${3:?CROSS_REPO_PIPELINE_MAP json required}"
LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../data/lib" && pwd)/dx-common.sh"
# shellcheck source=/dev/null
source "$LIB"

t_platform=$(grep -E '^platform:' "$BLOCK" | head -1 | sed 's/^platform:[[:space:]]*//' | xargs || true)
t_brand=$(grep -E '^brand:' "$BLOCK" | head -1 | sed 's/^brand:[[:space:]]*//' | xargs || true)
t_scope=$(grep -E '^scope:' "$BLOCK" | head -1 | sed 's/^scope:[[:space:]]*//' | xargs || true)
[ -z "$t_scope" ] && t_scope=both

# Candidate rows = repos_table rows whose name is a key in MAP.
# `repos_table || true` guards against an empty/repos-less config that returns
# non-zero under set -e. ROWS may be empty (single-repo project with no repos[]).
ROWS=()
while IFS= read -r line; do ROWS+=("$line"); done < <(repos_table | while IFS=$'\t' read -r name role platform brand adoproj; do
  if echo "$MAP" | jq -e --arg n "$name" 'has($n)' >/dev/null; then
    printf '%s\t%s\t%s\t%s\t%s\n' "$name" "$role" "$platform" "$brand" "$adoproj"
  fi
done || true)

# Reachable platforms among candidates. `printf '%s\n' "${ROWS[@]}"` on an empty
# array under set -u prints a single blank line; `awk NF` drops blanks so the
# count is 0, not 1.
if [ "${#ROWS[@]}" -gt 0 ]; then
  platforms=$(printf '%s\n' "${ROWS[@]}" | awk -F'\t' 'NF{print $3}' | sort -u | sed '/^$/d')
else
  platforms=""
fi
nplat=$(printf '%s\n' "$platforms" | sed '/^$/d' | wc -l | xargs)

# Conditional-required: platform needed only when >1 reachable platform.
if [ -z "$t_platform" ]; then
  if [ "$nplat" -gt 1 ]; then
    echo "ERROR: this project spans $nplat platforms — add 'platform:' to the simple block (one of: $(echo $platforms | tr '\n' ' '))." >&2
    exit 3
  fi
  t_platform="$platforms"   # single platform (or empty) -> infer
fi

# Filter candidates to the target platform (config-role repos excluded).
if [ "${#ROWS[@]}" -gt 0 ]; then
  INPLAT=()
  while IFS= read -r line; do INPLAT+=("$line"); done < <(printf '%s\n' "${ROWS[@]}" | awk -F'\t' -v p="$t_platform" 'NF && $3==p && $2!="config"')
else
  INPLAT=()
fi

# Brands present among frontend candidates of this platform.
if [ "${#INPLAT[@]}" -gt 0 ]; then
  brands=$(printf '%s\n' "${INPLAT[@]}" | awk -F'\t' '$2=="frontend" && $4!=""{print $4}' | sort -u)
else
  brands=""
fi
nbrand=$(printf '%s\n' "$brands" | sed '/^$/d' | wc -l | xargs)

# Conditional-required: brand needed only when >1 brand FE repo and scope includes fe.
if { [ "$t_scope" = "fe" ] || [ "$t_scope" = "both" ]; } && [ -z "$t_brand" ] && [ "$nbrand" -gt 1 ]; then
  echo "ERROR: platform '$t_platform' has $nbrand brand frontends — add 'brand:' (one of: $(echo $brands | tr '\n' ' '))." >&2
  exit 3
fi

# Role capability helpers. A `fullstack` repo serves frontend, backend, AND
# authoring — so it matches every scope. `frontend`/`backend` serve only their
# own half. Brand filtering is applied separately (only to fe-serving repos).
serves_fe() { [ "$1" = "frontend" ] || [ "$1" = "fullstack" ]; }
serves_be() { [ "$1" = "backend" ]  || [ "$1" = "fullstack" ]; }

# Select repos by scope.
out='[]'
add() { # row-tsv
  local name role platform brand adoproj pid auth
  IFS=$'\t' read -r name role platform brand adoproj <<<"$1"
  pid=$(echo "$MAP" | jq -r --arg n "$name" '.[$n]')
  # authoring owner heuristic at route level: backend repos do not carry AEM
  # authoring; frontend AND fullstack repos do. (Child re-confirms via
  # aem.author-url.)
  if [ "$role" = "backend" ]; then auth=false; else auth=true; fi
  out=$(echo "$out" | jq -c --arg r "$name" --arg p "$pid" --arg s "$t_scope" --argjson a "$auth" \
    '. += [{repo:$r, pipelineId:$p, scope:$s, authoring:$a}]')
}

if [ "${#INPLAT[@]}" -gt 0 ]; then
  for row in "${INPLAT[@]}"; do
    IFS=$'\t' read -r name role platform brand adoproj <<<"$row"
    # Brand filter applies to fe-serving repos (frontend + fullstack); a repo
    # with no declared brand passes when the ticket sets no brand.
    brand_ok() { [ -z "$t_brand" ] || [ -z "$brand" ] || [ "$brand" = "$t_brand" ]; }
    case "$t_scope" in
      fe)   serves_fe "$role" && brand_ok && add "$row" ;;
      be)   serves_be "$role" && add "$row" ;;
      both) if serves_be "$role" && ! serves_fe "$role"; then add "$row";
            elif serves_fe "$role" && brand_ok; then add "$row"; fi ;;
    esac
  done
fi

# A project whose only repo is itself (no repos[] list) has nothing to route —
# emit an empty array and exit 0 rather than treating it as "no match".
if [ "${#ROWS[@]}" -eq 0 ]; then
  echo "$out"
  exit 0
fi

[ "$(echo "$out" | jq 'length')" = "0" ] && { echo "ERROR: no candidate repo matched platform=$t_platform scope=$t_scope brand=$t_brand" >&2; exit 8; }
echo "$out"

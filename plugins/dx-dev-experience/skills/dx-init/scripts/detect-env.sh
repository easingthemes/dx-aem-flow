#!/usr/bin/env bash
# detect-env.sh — Detect git, SCM, and sibling repo environment
#
# Usage: detect-env.sh
# Output: JSON to stdout with detected environment values
#
# Fields:
#   remote_url      — git remote origin URL (or "")
#   scm_provider    — "ado" | "github" | "unknown"
#   base_branch     — detected default branch (or "unknown")
#   ado_org         — ADO organization name (or "")
#   ado_project     — ADO project name (or "")
#   sibling_repos   — array of sibling repo names with git dirs

set -euo pipefail

# --- Git remote ---
remote_url=$(git remote get-url origin 2>/dev/null || echo "")

# --- SCM provider ---
scm_provider="unknown"
if [[ "$remote_url" == *"visualstudio.com"* || "$remote_url" == *"dev.azure.com"* ]]; then
  scm_provider="ado"
elif [[ "$remote_url" == *"github.com"* ]]; then
  scm_provider="github"
fi

# --- Base branch ---
git remote set-head origin --auto >/dev/null 2>&1 || true
base_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||' || true)

if [[ -z "$base_branch" ]]; then
  # Probe for development/develop/main/master
  base_branch=$(git branch -r 2>/dev/null | grep -oE 'origin/(development|develop|main|master)$' | head -1 | sed 's|origin/||' || true)
fi
base_branch="${base_branch:-unknown}"

# --- ADO org + project extraction ---
ado_org=""
ado_project=""
if [[ "$scm_provider" == "ado" ]]; then
  # Format: https://{org}.visualstudio.com/{project}/_git/{repo}
  if [[ "$remote_url" == *"visualstudio.com"* ]]; then
    ado_org=$(echo "$remote_url" | sed -n 's|https://\([^.]*\)\.visualstudio\.com.*|\1|p')
    ado_project=$(echo "$remote_url" | sed -n 's|https://[^/]*/\([^/]*\)/_git/.*|\1|p')
  fi
  # Format: https://dev.azure.com/{org}/{project}/_git/{repo}
  if [[ "$remote_url" == *"dev.azure.com"* ]]; then
    ado_org=$(echo "$remote_url" | sed -n 's|https://dev\.azure\.com/\([^/]*\)/.*|\1|p')
    ado_project=$(echo "$remote_url" | sed -n 's|https://dev\.azure\.com/[^/]*/\([^/]*\)/_git/.*|\1|p')
  fi
fi

# --- Sibling repos ---
parent_dir="$(dirname "$(pwd)")"
siblings=()
if [[ -d "$parent_dir" ]]; then
  for dir in "$parent_dir"/*/; do
    [[ "$dir" == "$(pwd)/" ]] && continue
    if [[ -d "$dir/.git" ]]; then
      siblings+=("$(basename "$dir")")
    fi
  done
fi

# --- Output JSON ---
# Build siblings array
sibling_json="[]"
if [[ ${#siblings[@]} -gt 0 ]]; then
  sibling_json="["
  first=true
  for s in "${siblings[@]}"; do
    $first || sibling_json+=","
    sibling_json+="\"$s\""
    first=false
  done
  sibling_json+="]"
fi

cat <<EOF
{
  "remote_url": "$remote_url",
  "scm_provider": "$scm_provider",
  "base_branch": "$base_branch",
  "ado_org": "$ado_org",
  "ado_project": "$ado_project",
  "sibling_repos": $sibling_json
}
EOF

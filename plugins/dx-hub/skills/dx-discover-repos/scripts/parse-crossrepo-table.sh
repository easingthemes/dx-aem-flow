#!/usr/bin/env bash
# Tier-2 of the dx-discover-repos cascade — Cross-Repo Scope table.
#
# Extracts repo aliases from the "## Cross-Repo Scope" markdown table that
# triage.md / research.md emit (see dx-core/shared/repo-discovery.md → "How
# Cross-Repo Scope Is Detected"), and maps each to its registry entry.
# Deterministic, no LLM.
#
# Expected section shape:
#   ## Cross-Repo Scope
#
#   **Current repo:** <name> (this fix covers only this repo)
#
#   | Repo | What's needed | Key files |
#   |------|--------------|-----------|
#   | <alias> | Backend exporter update | src/main/java/... |
#
# Usage: parse-crossrepo-table.sh <markdown-file> <repos.json>
# Stdout: JSON array [{alias, repoId, adoProject, cloneUrl, branch, reason}]
#         (empty array [] when no section / no matching aliases)
# Exit codes:
#   0  — parsed (array may be empty)
#   2  — bad arguments / registry not readable
#
# Names in the table's first column are matched (case-insensitively) against
# repos.json keys. Non-matching rows are skipped — the cascade never invents
# repos. The "**Current repo:**" line is not a table row, so it is ignored.
set -euo pipefail

MD="${1:?markdown file required}"
REG="${2:?repos.json required}"
[ -f "$REG" ] || { echo "ERROR: repos registry not found: $REG" >&2; exit 2; }
if [ ! -f "$MD" ]; then echo "[]"; exit 0; fi

# Slice the "## Cross-Repo Scope" section (until the next "## " heading) and pull
# the first column of each table row. Skip the header row (cell == "Repo") and
# the separator row (cell is all -, :, space).
# Heading is matched as a PREFIX (not byte-exact): the upstream contract only
# guarantees the "## Cross-Repo Scope" section exists, so a decorated suffix like
# "## Cross-Repo Scope (auto-detected)" must still enter the section.
# First-column cells are stripped of surrounding markdown (backticks/asterisks/
# underscores) — LLM-authored tables routinely write `| `platform-core` | …`.
NAMES=$(awk '
  /^##[[:space:]]+Cross-Repo Scope/ { insec=1; next }
  insec && /^##[[:space:]]/ { insec=0 }
  insec && /^[[:space:]]*\|/ {
    # field 2 is the first table cell (field 1 is empty, before the leading |)
    cell=$2
    gsub(/^[ \t]+|[ \t]+$/, "", cell)
    gsub(/^[`*_]+|[`*_]+$/, "", cell)   # strip surrounding markdown
    gsub(/^[ \t]+|[ \t]+$/, "", cell)   # re-trim in case markdown wrapped spaces
    if (cell == "" ) next
    if (tolower(cell) == "repo") next
    if (cell ~ /^[-:[:space:]]+$/) next
    print cell
  }
' FS='|' "$MD")

OUT='[]'
while IFS= read -r name; do
  [ -z "$name" ] && continue
  # Case-insensitive match against registry keys.
  ENTRY=$(jq -c --arg n "$name" --arg reason "listed in ## Cross-Repo Scope table" '
    [ to_entries[] | select((.key | ascii_downcase) == ($n | ascii_downcase)) ] as $m
    | if ($m | length) == 0 then empty
      else $m[0] as $e
        | {alias:$e.key, repoId:$e.value.repoId, adoProject:$e.value.adoProject, cloneUrl:$e.value.cloneUrl, branch:$e.value.defaultBranch, reason:$reason}
      end' "$REG" 2>/dev/null || true)
  if [ -z "$ENTRY" ]; then
    echo "WARN: cross-repo table name '$name' not in repos registry — skipping." >&2
    continue
  fi
  OUT=$(printf '%s' "$OUT" | jq -c --argjson e "$ENTRY" '. += [$e]')
done <<<"$NAMES"

# De-dupe by alias — a repo listed twice in the table (or matching two name
# spellings) would otherwise queue two worker runs racing on the same repo.
echo "$OUT" | jq -c 'unique_by(.alias)'

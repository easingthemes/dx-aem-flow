#!/usr/bin/env bash
#
# skill-loc-stats.sh — Report line-of-code stats for every plugin skill.
#
# Scans plugins/*/skills/*/SKILL.md and reports total line count per skill,
# sorted smallest → largest, plus summary statistics.
#
# Usage:
#   scripts/skill-loc-stats.sh            # table, sorted ascending
#   scripts/skill-loc-stats.sh --csv      # CSV output (plugin,skill,lines)
#   scripts/skill-loc-stats.sh --top N    # only show N smallest and N largest
#
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

MODE="table"
TOP=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --csv) MODE="csv"; shift ;;
    --top) TOP="${2:-5}"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

# Collect "lines<TAB>plugin<TAB>skill" for each SKILL.md
rows=""
while IFS= read -r f; do
  lines=$(wc -l < "$f" | tr -d ' ')
  plugin=$(echo "$f" | sed -E 's#plugins/([^/]+)/skills/.*#\1#')
  skill=$(echo "$f" | sed -E 's#plugins/[^/]+/skills/([^/]+)/SKILL.md#\1#')
  rows+="${lines}\t${plugin}\t${skill}\n"
done < <(find plugins -name SKILL.md | sort)

# Sort ascending by line count
sorted=$(printf "%b" "$rows" | sort -n)

if [[ "$MODE" == "csv" ]]; then
  echo "plugin,skill,lines"
  printf "%b" "$sorted" | while IFS=$'\t' read -r lines plugin skill; do
    [[ -z "$lines" ]] && continue
    echo "${plugin},${skill},${lines}"
  done
  exit 0
fi

count=$(printf "%b" "$sorted" | grep -c . || true)
total=$(printf "%b" "$sorted" | awk -F'\t' '{s+=$1} END{print s}')
avg=$(printf "%b" "$sorted" | awk -F'\t' '{s+=$1; n++} END{printf "%.1f", s/n}')
median=$(printf "%b" "$sorted" | awk -F'\t' '{a[NR]=$1} END{m=int((NR+1)/2); if(NR%2) print a[m]; else printf "%.1f",(a[m]+a[m+1])/2}')

print_row() {
  printf "  %5s  %-13s %s\n" "$1" "$2" "$3"
}

echo "=== Skill LOC stats (SKILL.md line counts) ==="
echo "Skills: ${count} | Total lines: ${total} | Avg: ${avg} | Median: ${median}"
echo

if [[ "$TOP" -gt 0 ]]; then
  echo "--- ${TOP} smallest ---"
  printf "  %5s  %-13s %s\n" "LINES" "PLUGIN" "SKILL"
  printf "%b" "$sorted" | grep . | head -n "$TOP" | while IFS=$'\t' read -r l p s; do print_row "$l" "$p" "$s"; done
  echo
  echo "--- ${TOP} largest ---"
  printf "  %5s  %-13s %s\n" "LINES" "PLUGIN" "SKILL"
  printf "%b" "$sorted" | grep . | tail -n "$TOP" | while IFS=$'\t' read -r l p s; do print_row "$l" "$p" "$s"; done
else
  printf "  %5s  %-13s %s\n" "LINES" "PLUGIN" "SKILL"
  printf "%b" "$sorted" | grep . | while IFS=$'\t' read -r l p s; do print_row "$l" "$p" "$s"; done
fi

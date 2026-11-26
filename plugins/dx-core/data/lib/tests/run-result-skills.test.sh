#!/usr/bin/env bash
# Hermetic check: every skill listed in docs/reference/run-result.md § Metrics
# documents both a start (`run-result.sh --start --skill <name>`) and a final
# write (`run-result.sh --skill <name> ... --status`) in its SKILL.md, and calls
# the helper from a path that exists for its plugin: dx-core skills via
# ${CLAUDE_PLUGIN_ROOT}/data/lib/, other plugins via the project's .ai/lib/ copy
# (their ${CLAUDE_PLUGIN_ROOT} is their own root, which has no run-result.sh).
# A tool (dashboard, hub) can only show a run as done when the skill writes it.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGINS="$(cd "$HERE/../../../.." && pwd)"
REPO="$(cd "$PLUGINS/.." && pwd)"
DOC="$REPO/docs/reference/run-result.md"

PASS=0 FAIL=0
ok()   { PASS=$((PASS + 1)); }
fail() { FAIL=$((FAIL + 1)); printf 'FAIL %s\n' "$1"; }

# Skill names from the Metrics table: rows "| `name` | ... |" between "## Metrics" and the next "## ".
skills="$(awk '/^## Metrics/{on=1; next} /^## /{on=0} on && /^\| `[a-z0-9-]+` \|/' "$DOC" \
  | sed -E 's/^\| `([a-z0-9-]+)`.*/\1/')"
[ -n "$skills" ] || { echo "FAIL no skills parsed from $DOC § Metrics"; exit 1; }

for skill in $skills; do
  file="$(ls "$PLUGINS"/*/skills/"$skill"/SKILL.md 2>/dev/null | head -1)"
  if [ -z "$file" ]; then fail "$skill: SKILL.md not found"; continue; fi
  plugin="$(basename "$(dirname "$(dirname "$(dirname "$file")")")")"

  # Plugins other than dx-core have no run-result.sh under their own root.
  if [ "$plugin" != "dx-core" ]; then
    grep -qF '${CLAUDE_PLUGIN_ROOT}/data/lib/run-result.sh' "$file" \
      && fail "$skill ($plugin): calls \${CLAUDE_PLUGIN_ROOT}/data/lib/run-result.sh, which only dx-core has" || ok
    grep -qF 'bash .ai/lib/run-result.sh --start' "$file" \
      && ok || fail "$skill ($plugin): does not call the project copy, bash .ai/lib/run-result.sh"
  fi

  grep -E -- "run-result\.sh\"? --start --skill $skill( |$)" "$file" >/dev/null \
    && ok || fail "$skill: no 'run-result.sh --start --skill $skill' in $file"
  grep -E -- "run-result\.sh\"? --skill $skill --id (<[^>]+>|[^ ]+) --status" "$file" >/dev/null \
    && ok || fail "$skill: no final 'run-result.sh --skill $skill --id <id> --status' in $file"
done

echo "run-result-skills: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]

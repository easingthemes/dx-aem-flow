#!/usr/bin/env bash
# validate-plugin-edit.sh — Post-edit hook to catch accidental deletions in plugin files
# Called by Claude Code PostToolUse hook after Edit tool runs.
# Checks: JSON/YAML syntax, plugin.json field integrity.
set -euo pipefail

FILE="${1:-}"

# Only validate specific file types
case "$FILE" in
  *plugin.json|*marketplace.json)
    # Check JSON is valid
    if ! python3 -c "import json; json.load(open('$FILE'))" 2>/dev/null; then
      echo "ERROR: $FILE is not valid JSON after edit"
      exit 1
    fi
    # For plugin.json: verify required fields still present
    if [[ "$FILE" == *plugin.json ]]; then
      missing=$(python3 -c "
import json, sys
data = json.load(open('$FILE'))
required = ['name']
missing = [f for f in required if f not in data]
if missing:
    print('Missing fields: ' + ', '.join(missing))
    sys.exit(1)
# Warn if agents/skills fields were likely removed (file has them in git)
" 2>&1) || {
        echo "WARNING: $FILE — $missing"
      }
    fi
    # For marketplace.json: verify all plugin entries still present
    if [[ "$FILE" == *marketplace.json ]]; then
      count=$(python3 -c "
import json
data = json.load(open('$FILE'))
plugins = data.get('plugins', [])
print(len(plugins))
" 2>/dev/null || echo "0")
      if [ "$count" -lt 3 ]; then
        echo "WARNING: $FILE has only $count plugin entries (expected 3). Was a plugin accidentally removed?"
      fi
    fi
    ;;
  *.yaml|*.yml)
    # Check YAML is valid (if python3 available)
    if command -v python3 &>/dev/null; then
      if ! python3 -c "import yaml; yaml.safe_load(open('$FILE'))" 2>/dev/null; then
        echo "WARNING: $FILE may have YAML syntax issues after edit"
      fi
    fi
    ;;
esac

exit 0

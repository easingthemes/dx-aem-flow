#!/usr/bin/env bash
# scaffold-prototype.sh — Copy HTML template and create empty CSS/JS in spec prototype dir
#
# Usage: scaffold-prototype.sh <spec-dir> [layout]
#   spec-dir  — path to the spec directory (e.g., .ai/specs/12345-my-story)
#   layout    — "row" (side by side, default) or "col" (stacked)
#
# Creates:
#   <spec-dir>/prototype/index.html   ← from template (only if not already scaffolded)
#   <spec-dir>/prototype/styles.css   ← empty (only if missing)
#   <spec-dir>/prototype/script.js    ← empty (only if missing)
#
# The template contains two placeholders:
#   {{PROTOTYPE_CONTENT}}  — replaced by the skill with component HTML
#   {{FIGMA_REFERENCES}}   — replaced by the skill with <img> tag(s)
#
# Idempotent: skips index.html if it already exists and contains {{PROTOTYPE_CONTENT}}
# (meaning it was scaffolded but not yet filled). If placeholders are already replaced
# (filled by the skill), the file is left untouched.

set -euo pipefail

SPEC_DIR="${1:?Usage: scaffold-prototype.sh <spec-dir> [layout]}"
LAYOUT="${2:-row}"

# Resolve template path from script location
# Script: plugins/dx-core/skills/dx-figma-prototype/scripts/scaffold-prototype.sh
# Template: plugins/dx-core/data/templates/spec/prototype-index.html.template
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
TEMPLATE="$PLUGIN_DIR/data/templates/spec/prototype-index.html.template"

# Also check installed template location (consumer repo)
INSTALLED_TEMPLATE=".ai/templates/spec/prototype-index.html.template"

PROTO_DIR="$SPEC_DIR/prototype"
INDEX="$PROTO_DIR/index.html"
CSS="$PROTO_DIR/styles.css"
JS="$PROTO_DIR/script.js"

# Find the template
if [[ -f "$TEMPLATE" ]]; then
  TPL="$TEMPLATE"
elif [[ -f "$INSTALLED_TEMPLATE" ]]; then
  TPL="$INSTALLED_TEMPLATE"
else
  echo "ERROR: prototype template not found at $TEMPLATE or $INSTALLED_TEMPLATE" >&2
  exit 1
fi

# Create prototype directory
mkdir -p "$PROTO_DIR"

# Scaffold index.html from template (only if missing or still has unfilled placeholders)
if [[ ! -f "$INDEX" ]]; then
  # Fresh copy — apply layout class
  if [[ "$LAYOUT" == "col" ]]; then
    sed 's/prototype-compare--row/prototype-compare--col/' "$TPL" > "$INDEX"
  else
    cp "$TPL" "$INDEX"
  fi
  echo "created $INDEX (layout: $LAYOUT)"
elif grep -q '{{PROTOTYPE_CONTENT}}' "$INDEX" 2>/dev/null; then
  # Template was scaffolded but never filled — update layout if needed
  if [[ "$LAYOUT" == "col" ]]; then
    sed -i '' 's/prototype-compare--row/prototype-compare--col/' "$INDEX"
  fi
  echo "exists  $INDEX (unfilled template, layout: $LAYOUT)"
else
  echo "exists  $INDEX (already filled — skipping)"
fi

# Create empty CSS if missing
if [[ ! -f "$CSS" ]]; then
  touch "$CSS"
  echo "created $CSS"
else
  echo "exists  $CSS"
fi

# Create empty JS if missing
if [[ ! -f "$JS" ]]; then
  touch "$JS"
  echo "created $JS"
else
  echo "exists  $JS"
fi

#!/usr/bin/env bash
# Called by semantic-release via @semantic-release/exec
# Usage: bump-versions.sh <new-version>
set -euo pipefail

VERSION="$1"

for f in \
  plugins/dx-core/.claude-plugin/plugin.json \
  plugins/dx-aem/.claude-plugin/plugin.json \
  plugins/dx-automation/.claude-plugin/plugin.json \
  plugins/dx-core/.cursor-plugin/plugin.json \
  plugins/dx-aem/.cursor-plugin/plugin.json \
  plugins/dx-automation/.cursor-plugin/plugin.json \
  gemini-extension.json \
  .claude-plugin/marketplace.json
do
  # Replace all "version": "X.Y.Z" entries
  sed -i'' -e "s/\"version\": \"[0-9]*\.[0-9]*\.[0-9]*\"/\"version\": \"${VERSION}\"/g" "$f"
done

# Update dx.version in config template (used by /dx-init for new consumers)
sed -i'' -e "s/version: \"[0-9]*\.[0-9]*\.[0-9]*\"/version: \"${VERSION}\"/" \
  plugins/dx-core/templates/config.yaml.template

echo "Bumped all plugin versions to ${VERSION}"

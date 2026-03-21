#!/usr/bin/env bash
# Called by semantic-release via @semantic-release/exec
# Usage: bump-versions.sh <new-version>
set -euo pipefail

VERSION="$1"

for f in \
  plugins/dx-core/.claude-plugin/plugin.json \
  plugins/dx-aem/.claude-plugin/plugin.json \
  plugins/dx-automation/.claude-plugin/plugin.json \
  .claude-plugin/marketplace.json
do
  # Replace all "version": "X.Y.Z" entries
  sed -i'' -e "s/\"version\": \"[0-9]*\.[0-9]*\.[0-9]*\"/\"version\": \"${VERSION}\"/g" "$f"
done

echo "Bumped all plugin versions to ${VERSION}"

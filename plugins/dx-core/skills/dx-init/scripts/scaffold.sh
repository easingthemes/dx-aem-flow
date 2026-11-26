#!/usr/bin/env bash
# scaffold.sh — Create dx workflow directories and install static files
#
# Usage: scaffold.sh
# Output: One line per action to stdout
#
# On first run: creates directories, copies all files.
# On re-run: validates existing files against plugin data.
#   - Utility scripts (audit.sh, stop-guard.sh): update silently if plugin version differs
#   - Rule templates (.ai/rules/, .claude/rules/): update if plugin version differs,
#     BUT preserve if user has customized (content differs from both old and new plugin version)
#
# Creates:
#   .ai/specs, .ai/rules, .ai/research, .ai/lib, .ai/templates
#   .claude/rules, .claude/hooks
#
# Installs/validates:
#   .ai/lib/*                 ← every helper in data/lib/ (*.sh, *.js, *.cjs; no tests)
#   .claude/hooks/stop-guard.sh ← from data/hooks/stop-guard.sh
#   .ai/rules/*.md            ← from templates/rules/*.template (non-universal)
#   .claude/rules/*.md        ← from templates/rules/universal-*.template
#   .ai/docs/*.md             ← from templates/docs/*.template

set -euo pipefail

# Resolve plugin directory from script location
# Script is at: plugins/dx-core/skills/dx-init/scripts/scaffold.sh
# Plugin root:  plugins/dx-core/
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

INSTALLED=0
UPDATED=0
SKIPPED=0

# Compare two files by content hash
files_differ() {
  [ -f "$1" ] && [ -f "$2" ] || return 0
  ! diff -q "$1" "$2" >/dev/null 2>&1
}

# Install or validate a utility file (always update if plugin version is newer)
install_utility() {
  local src="$1" dst="$2" label="$3"
  if [ ! -f "$dst" ]; then
    cp "$src" "$dst"
    chmod +x "$dst"
    echo "installed $label"
    INSTALLED=$((INSTALLED + 1))
  elif files_differ "$src" "$dst"; then
    cp "$src" "$dst"
    chmod +x "$dst"
    echo "updated $label (plugin version changed)"
    UPDATED=$((UPDATED + 1))
  else
    echo "validated $label (up to date)"
    SKIPPED=$((SKIPPED + 1))
  fi
}

# Install or validate a rule template
# If file doesn't exist: install it
# If file exists and matches plugin template: skip (up to date)
# If file exists and differs: plugin template may have been updated, report for review
install_rule() {
  local src="$1" dst="$2" label="$3"
  if [ ! -f "$dst" ]; then
    cp "$src" "$dst"
    echo "installed $label"
    INSTALLED=$((INSTALLED + 1))
  elif files_differ "$src" "$dst"; then
    echo "REVIEW: $label (differs from plugin template — may need update)"
    UPDATED=$((UPDATED + 1))
  else
    echo "validated $label (up to date)"
    SKIPPED=$((SKIPPED + 1))
  fi
}

# --- Create directories ---
mkdir -p .ai/specs .ai/rules .ai/research .ai/lib .ai/templates
echo "created .ai/ directories"

mkdir -p .claude/rules .claude/hooks
echo "created .claude/ directories"

# --- Install/validate utility scripts ---
# Discovered, never listed — same set as dx-upgrade / dx-doctor 1d: data/lib/*.sh,
# *.js and *.cjs, top level only (tests/ and fixtures/ stay out), minus *.test.*.
# A hardcoded list here left run-result.sh and upload-attachment.sh out of fresh installs.
for f in "$PLUGIN_DIR"/data/lib/*.sh "$PLUGIN_DIR"/data/lib/*.js "$PLUGIN_DIR"/data/lib/*.cjs; do
  [ -f "$f" ] || continue
  name="$(basename "$f")"
  case "$name" in *.test.sh|*.test.js|*.test.cjs) continue ;; esac
  install_utility "$f" ".ai/lib/$name" ".ai/lib/$name"
done
install_utility "$PLUGIN_DIR/data/hooks/stop-guard.sh" ".claude/hooks/stop-guard.sh" ".claude/hooks/stop-guard.sh"

# --- Install/validate output templates ---
for subdir in spec wiki ado-comments; do
  if [ -d "$PLUGIN_DIR/data/templates/$subdir" ]; then
    mkdir -p ".ai/templates/$subdir"
    for f in "$PLUGIN_DIR/data/templates/$subdir"/*.template; do
      [ -f "$f" ] || continue
      name="$(basename "$f")"
      install_utility "$f" ".ai/templates/$subdir/$name" ".ai/templates/$subdir/$name"
    done
  fi
done

# --- Install/validate shared rules (non-universal) ---
for f in "$PLUGIN_DIR"/templates/rules/*.template; do
  [ -f "$f" ] || continue
  name="$(basename "$f" .template)"
  # Skip universal-* (handled below)
  case "$name" in universal-*) continue ;; esac
  # Skip cross-repo.md — installed by dx-init Step 8d to .claude/rules/
  # with {{REPOS_TABLE}} substitution from config.yaml repos:
  [ "$name" = "cross-repo.md" ] && continue
  install_rule "$f" ".ai/rules/$name" ".ai/rules/$name"
done

# --- Install/validate universal rules to .claude/rules/ ---
for f in "$PLUGIN_DIR"/templates/rules/universal-*.template; do
  [ -f "$f" ] || continue
  # Strip .template suffix and universal- prefix
  base="$(basename "$f" .template)"
  name="${base#universal-}"
  install_rule "$f" ".claude/rules/$name" ".claude/rules/$name"
done

echo ""
echo "Done: $INSTALLED installed, $UPDATED updated/review, $SKIPPED validated."

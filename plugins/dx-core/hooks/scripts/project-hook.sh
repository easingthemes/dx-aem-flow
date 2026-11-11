#!/usr/bin/env bash
# project-hook.sh — run a hook script that lives in the consumer project.
#
# Usage (from hooks.json):  bash "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/project-hook.sh" <path-relative-to-project>
#
# Plugin hooks.json used "$CLAUDE_PROJECT_DIR/<path>" directly. Claude Code and
# Copilot CLI set CLAUDE_PROJECT_DIR; Codex CLI (0.167) does not, so the path
# became "/<path>", the file test failed and the hook silently did nothing.
# Codex does send the session `cwd` in the hook's stdin JSON, like Claude Code.
#
# Resolution: CLAUDE_PROJECT_DIR → git root of the stdin `cwd` → git root of
# $PWD → $PWD. The resolved dir is exported as CLAUDE_PROJECT_DIR so the project
# script sees the same value on every host. The hook's stdin is passed through
# unchanged, and so is the script's stdout (e.g. the stop guard's decision JSON).
#
# Always exits 0, like the `[ -f … ] && bash … || true` it replaces: a missing or
# failing project script never breaks the session.

rel="${1:-}"
[ -n "$rel" ] || exit 0

input=""
[ -t 0 ] || input="$(cat)"

dx_resolve_project_dir() {
  if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
    printf '%s\n' "$CLAUDE_PROJECT_DIR"; return
  fi
  local start cwd
  start="$PWD"
  cwd="$(printf '%s' "$input" | sed -n 's/.*"cwd" *: *"\([^"]*\)".*/\1/p' | head -1)"
  [ -n "$cwd" ] && [ -d "$cwd" ] && start="$cwd"
  git -C "$start" rev-parse --show-toplevel 2>/dev/null || printf '%s\n' "$start"
}

CLAUDE_PROJECT_DIR="$(dx_resolve_project_dir)"
export CLAUDE_PROJECT_DIR

target="$CLAUDE_PROJECT_DIR/$rel"
[ -f "$target" ] || exit 0

printf '%s' "$input" | bash "$target" "${@:2}"
exit 0

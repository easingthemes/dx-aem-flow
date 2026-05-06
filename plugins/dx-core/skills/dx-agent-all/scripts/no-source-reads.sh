#!/usr/bin/env bash
# no-source-reads.sh — Warn when the dx-agent-all orchestrator reads a source
# or rule file in main context. Such reads belong inside forked sub-skills
# (dx-req, dx-step, etc.). This hook is informational (exit 0) — it does NOT
# block; it surfaces a context-budget concern to the developer.
#
# Wired via skill-scoped hook in plugins/dx-core/skills/dx-agent-all/SKILL.md
# frontmatter (hooks: PreToolUse on Read).

set -euo pipefail

# Hook stdin is JSON with tool input
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null || echo "")

# Empty path — let the tool proceed without comment.
[ -z "$FILE_PATH" ] && exit 0

# Whitelist: orchestrator IS allowed to read these.
case "$FILE_PATH" in
  */dev-all-progress.md|*/run-state.json|*/share-plan.md|*/dor-report.md)
    exit 0 ;;
  */.ai/config.yaml|*/CLAUDE.md|*/AGENTS.md)
    exit 0 ;;
esac

# Block-with-warn (non-fatal): source files, rule files, raw spec internals.
case "$FILE_PATH" in
  *.java|*.js|*.ts|*.tsx|*.jsx|*.html|*.xml|*.scss|*.css|*.json)
    echo "WARN: dx-agent-all is reading $FILE_PATH in main context. This belongs inside a forked sub-skill (dx-step, dx-req, etc.). The read will proceed but counts against the context budget." >&2
    exit 0 ;;
  */.claude/rules/*|.claude/rules/*|*/plugins/*/rules/*|plugins/*/rules/*)
    echo "WARN: dx-agent-all is reading rule file $FILE_PATH in main context. Rule reads belong inside forked sub-skills. The read will proceed but counts against the context budget." >&2
    exit 0 ;;
esac

exit 0

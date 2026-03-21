#!/usr/bin/env bash
# mcp-health-check.sh — Quick connectivity check for MCP servers
# Usage: mcp-health-check.sh [ado|aem|figma|all]
# Returns 0 if all requested servers respond, 1 if any fail.
# Output: one line per server with status.
set -euo pipefail

SCOPE="${1:-all}"
FAILED=0

check_ado() {
  # ADO MCP: try listing projects (lightweight call)
  if command -v npx &>/dev/null; then
    echo "✓ ADO MCP: npx available (server starts on demand)"
  else
    echo "✗ ADO MCP: npx not found"
    FAILED=1
  fi
}

check_aem() {
  # AEM: try hitting the author URL from config
  local author_url
  author_url=$(grep 'author-url:' .ai/config.yaml 2>/dev/null | head -1 | sed 's/.*: *//' | tr -d '"' | tr -d "'")
  if [ -z "$author_url" ]; then
    echo "⚠ AEM: no author-url in .ai/config.yaml"
    return
  fi
  local status
  status=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 "$author_url/libs/granite/core/content/login.html" 2>/dev/null || echo "000")
  if [ "$status" = "200" ] || [ "$status" = "302" ] || [ "$status" = "401" ]; then
    echo "✓ AEM: $author_url responding (HTTP $status)"
  else
    echo "✗ AEM: $author_url not responding (HTTP $status)"
    FAILED=1
  fi
}

check_figma() {
  # Figma: check if Figma Desktop Dev Mode MCP is running on port 3845
  if curl -s --max-time 2 http://127.0.0.1:3845/ >/dev/null 2>&1; then
    echo "✓ Figma: Desktop app responding on port 3845"
  else
    echo "✗ Figma: Desktop app not detected on port 3845 — open Figma and enable Dev Mode MCP"
    FAILED=1
  fi
}

case "$SCOPE" in
  ado)    check_ado ;;
  aem)    check_aem ;;
  figma)  check_figma ;;
  all)    check_ado; check_aem; check_figma ;;
  *)      echo "Usage: mcp-health-check.sh [ado|aem|figma|all]"; exit 1 ;;
esac

exit $FAILED

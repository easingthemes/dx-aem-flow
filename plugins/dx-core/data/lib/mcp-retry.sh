#!/usr/bin/env bash
# mcp-retry.sh — Retry wrapper for MCP-dependent operations
# Usage: source this file, then call mcp_retry <max_attempts> <delay_seconds> <command...>
#
# Example:
#   source .ai/lib/mcp-retry.sh
#   mcp_retry 3 5 curl -s http://localhost:4502/crx/de/index.jsp

mcp_retry() {
  local max_attempts="$1"
  local delay="$2"
  shift 2
  local attempt=1

  while [ $attempt -le $max_attempts ]; do
    if "$@" 2>/dev/null; then
      return 0
    fi
    echo "  Attempt $attempt/$max_attempts failed. Retrying in ${delay}s..."
    sleep "$delay"
    ((attempt++))
  done

  echo "  All $max_attempts attempts failed."
  return 1
}

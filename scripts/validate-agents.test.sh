#!/usr/bin/env bash
# validate-agents.test.sh — prove validate-agents.sh fails on the fields Claude
# Code ignores on plugin-shipped agents (hooks, mcpServers, permissionMode) and
# on an agent that states neither tools: nor disallowedTools:.
#
# Hermetic: throwaway plugin tree under a temp dir, validator pointed at it via
# REPO_ROOT. No network, no git config, no real plugins.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VALIDATOR="$SCRIPT_DIR/validate-agents.sh"
PASS=0
FAIL=0

FIXTURE_ROOT=$(mktemp -d)
trap 'rm -rf "$FIXTURE_ROOT"' EXIT

# run_case <label> <expect: pass|fail> <grep-pattern-or-empty> <<'EOF' agent md EOF
run_case() {
  local label="$1" expect="$2" pattern="$3"
  rm -rf "$FIXTURE_ROOT/plugins"
  mkdir -p "$FIXTURE_ROOT/plugins/dx-test/agents"
  cat > "$FIXTURE_ROOT/plugins/dx-test/agents/dx-test-agent.md"
  local out rc
  out=$(REPO_ROOT="$FIXTURE_ROOT" bash "$VALIDATOR" 2>&1); rc=$?
  local ok=1
  if [ "$expect" = pass ] && [ $rc -ne 0 ]; then ok=0; fi
  if [ "$expect" = fail ] && [ $rc -eq 0 ]; then ok=0; fi
  if [ -n "$pattern" ] && ! grep -qE "$pattern" <<<"$out"; then ok=0; fi
  if [ $ok -eq 1 ]; then
    echo "PASS: $label"; PASS=$((PASS + 1))
  else
    echo "FAIL: $label (rc=$rc)"; echo "$out" | sed 's/^/    /'; FAIL=$((FAIL + 1))
  fi
}

run_case "clean agent with tools: passes" pass "" <<'MD'
---
name: dx-test-agent
description: Test agent
tools: Read, Grep
model: sonnet
---
Body
MD

run_case "disallowedTools: alone satisfies the access check" pass "" <<'MD'
---
name: dx-test-agent
description: Test agent
disallowedTools: Write, Edit
model: opus
---
Body
MD

run_case "permissionMode is rejected" fail "permissionMode: ignored on plugin agents" <<'MD'
---
name: dx-test-agent
description: Test agent
tools: Read
model: sonnet
permissionMode: plan
---
Body
MD

run_case "mcpServers is rejected" fail "mcpServers: ignored on plugin agents" <<'MD'
---
name: dx-test-agent
description: Test agent
tools: Read
model: sonnet
mcpServers: [AEM]
---
Body
MD

run_case "hooks is rejected" fail "hooks: ignored on plugin agents" <<'MD'
---
name: dx-test-agent
description: Test agent
tools: Read
model: sonnet
hooks:
  PreToolUse: []
---
Body
MD

run_case "field named only in the body is not flagged" pass "" <<'MD'
---
name: dx-test-agent
description: Test agent
tools: Read
model: sonnet
---
permissionMode: plan is mentioned here as prose.
MD

run_case "no tools: and no disallowedTools: fails" fail "missing tools: or disallowedTools:" <<'MD'
---
name: dx-test-agent
description: Test agent
model: sonnet
---
Body
MD

echo
echo "validate-agents.test.sh: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ]

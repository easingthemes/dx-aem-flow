#!/usr/bin/env bash
# check-tier.test.sh — Prove scripts/check-tier.sh classifies paths correctly.
#
# CLAUDE.md: "a validator nobody has watched fail is indistinguishable from a blind
# one." This suite feeds known paths on stdin and asserts both the exit code and the
# classification, including the carve-outs. Hermetic — no git, no network, no ambient
# config; stdin mode never shells out.

set -uo pipefail

SCRIPT="$(cd "$(dirname "$0")" && pwd)/check-tier.sh"
PASS=0
FAIL=0

# expect <exit-code> <label> <paths...>
expect() {
  local want="$1" label="$2"; shift 2
  local out got
  out=$(printf '%s\n' "$@" | bash "$SCRIPT" - 2>&1)
  got=$?
  if [ "$got" = "$want" ]; then
    echo "PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $label — expected exit $want, got $got"
    printf '%s\n' "$out" | sed 's/^/      /'
    FAIL=$((FAIL + 1))
  fi
}

# expect_says <substring> <label> <paths...>
expect_says() {
  local want="$1" label="$2"; shift 2
  local out
  out=$(printf '%s\n' "$@" | bash "$SCRIPT" - 2>&1)
  if printf '%s' "$out" | grep -qF -- "$want"; then
    echo "PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $label — output did not contain '$want'"
    printf '%s\n' "$out" | sed 's/^/      /'
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Tier A paths ==="
expect 0 "docs/ is inert"                    "docs/todo/TODO.md"
expect 0 "website/ is inert"                 "website/src/pages/index.mdx"
expect 0 "scripts/ is inert"                 "scripts/validate-skills.sh"
expect 0 "root guides are inert"             "CLAUDE.md" "AGENTS.md" "README.md"
expect 0 "cli source is inert"               "cli/lib/scaffold.js"
expect 0 "several inert files together"      "docs/a.md" "website/b.mdx" "README.md"
expect 0 "empty input is Tier A"             ""

echo
echo "=== Tier B paths ==="
expect 1 "a SKILL.md ships"                  "plugins/dx-core/skills/dx-init/SKILL.md"
expect 1 "an agent ships"                    "plugins/dx-aem/agents/aem-inspector.md"
expect 1 "a rule ships"                      "plugins/dx-core/rules/pr-review.md"
expect 1 "a template ships"                  "plugins/dx-core/templates/config.yaml.template"
expect 1 "hooks ship"                        "plugins/dx-core/hooks/hooks.json"
expect 1 "data ships"                        "plugins/dx-core/data/lib/fetch-raw-story.js"
expect 1 "the claude manifest ships"         "plugins/dx-hub/.claude-plugin/plugin.json"
expect 1 "the cursor manifest ships"         "plugins/dx-hub/.cursor-plugin/plugin.json"
expect 1 "plugin .mcp.json ships"            "plugins/dx-aem/.mcp.json"
expect 1 "the marketplace ships"             ".claude-plugin/marketplace.json"
expect 1 "the gemini manifest ships"         "gemini-extension.json"

echo
echo "=== Carve-outs: distributed but never loaded ==="
expect 0 "evals are inert"                   "plugins/dx-core/evals/plan-validate-finds-gap/README.md"
expect 0 "__tests__ under data/ is inert"    "plugins/dx-automation/data/lambda/__tests__/pr-router.test.js"
expect 0 "tests/ under a skill is inert"     "plugins/dx-core/skills/dx-simple/tests/run-tests.sh"
expect 0 "a .test.sh under a skill is inert" "plugins/dx-core/data/lib/validate-image.test.sh"
# Only the directory rule catches this one — the filename patterns do not match, so
# without `(__tests__|tests)/` in INERT it would read as a shipped change. Added after
# mutation-testing the directory rule away left the suite at 33/33.
expect 0 "a fixture inside a tests dir"      "plugins/dx-core/skills/dx-simple/tests/fixtures/sample.md"
expect 0 "a helper inside __tests__"         "plugins/dx-automation/data/lambda/__tests__/helpers.js"

echo
echo "=== Mixed diffs take the worst tier ==="
expect 1 "one shipped file among inert ones" "docs/todo/TODO.md" "README.md" \
                                             "plugins/dx-core/skills/dx-init/SKILL.md"
expect 0 "a test beside docs stays Tier A"   "docs/todo/TODO.md" \
                                             "plugins/dx-core/skills/dx-simple/tests/run-tests.sh"

echo
echo "=== Near-misses must NOT be flagged ==="
expect 0 "docs path merely naming plugins"   "docs/reference/skill-catalog.md"
expect 0 "a plugin README is inert"          "plugins/dx-core/README.md"
expect 0 "plugin.json outside a manifest dir" "plugins/dx-core/some/other/plugin.json"
# The SHIPS patterns are anchored with ^ on purpose. Without the anchor these three
# match mid-path and a docs file describing the layout would be flagged as shipping.
# Caught by mutation-testing the anchor away — the suite passed 30/30 without them.
expect 0 "a shipped path quoted inside docs" "docs/notes/plugins/dx-core/skills/dx-init/SKILL.md"
expect 0 "a marketplace path inside docs"    "docs/examples/.claude-plugin/marketplace.json"
expect 0 "a backup copy of a manifest"       "backup/plugins/dx-hub/.claude-plugin/plugin.json"

echo
echo "=== Reporting ==="
expect_says "Tier B" "names the tier for a shipped file" "plugins/dx-core/skills/dx-init/SKILL.md"
expect_says "plugins/dx-core/skills/dx-init/SKILL.md" "lists the offending path" \
            "docs/a.md" "plugins/dx-core/skills/dx-init/SKILL.md"
expect_says "Tier A" "names the tier for an inert diff" "docs/todo/TODO.md"

echo
echo "=== Summary: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]

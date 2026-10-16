#!/usr/bin/env bash
# A dx consumer project always says where its code lives; the bare pr-review case has no project at all.
set -euo pipefail
cat > CLAUDE.md <<'MD'
# Project

Source control, pull requests and work items are in Azure DevOps (ADO).
MD

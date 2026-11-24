#!/usr/bin/env bash
# Plants the shared fixture into the empty eval sandbox workspace.
# Runs as: bash resources/setup.sh, with cwd = the sandbox workspace.
set -euo pipefail
cp -r "$(dirname "$0")/../../fixture/." .

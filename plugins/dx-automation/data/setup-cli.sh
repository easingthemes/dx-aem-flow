#!/usr/bin/env bash
# Checks and sets up Azure CLI and AWS CLI for dx-automation.
# Project defaults (org, project) are in .azure/config at repo root.
#
# Run once after cloning: .ai/automation/setup-cli.sh

set -euo pipefail

OK=0
WARN=0

section() { echo "" && echo "=== $1 ===" && echo ""; }

# --- Azure CLI ---
section "Azure CLI"

if ! command -v az &>/dev/null; then
  echo "✗ Azure CLI not found. Install: brew install azure-cli"
  WARN=$((WARN + 1))
else
  echo "✓ az CLI installed ($(az version --query '"azure-cli"' -o tsv 2>/dev/null))"
  OK=$((OK + 1))

  # Check azure-devops extension
  if ! az extension show --name azure-devops &>/dev/null 2>&1; then
    echo "  Installing azure-devops extension..."
    az extension add --name azure-devops
  fi
  echo "✓ azure-devops extension installed"
  OK=$((OK + 1))

  # Check login
  if ! az account show &>/dev/null 2>&1; then
    echo "  Not logged in. Opening browser..."
    az login --allow-no-subscriptions
  fi
  echo "✓ Logged in"
  OK=$((OK + 1))

  echo ""
  echo "  Project defaults from .azure/config:"
  az devops configure --list 2>/dev/null | sed 's/^/    /'
fi

# --- AWS CLI ---
section "AWS CLI"

if ! command -v aws &>/dev/null; then
  echo "✗ AWS CLI not found. Install: brew install awscli"
  WARN=$((WARN + 1))
else
  echo "✓ aws CLI installed ($(aws --version 2>&1 | awk '{print $1}'))"
  OK=$((OK + 1))

  # Check credentials
  if aws sts get-caller-identity &>/dev/null 2>&1; then
    IDENTITY=$(aws sts get-caller-identity --query 'Arn' --output text 2>/dev/null)
    echo "✓ Authenticated as: $IDENTITY"
    OK=$((OK + 1))
  else
    echo "⚠ Not authenticated. Run: aws configure"
    echo "  See CONFIGURATION.md > Prerequisites > AWS CLI for details."
    WARN=$((WARN + 1))
  fi

  # Check default region
  REGION=$(aws configure get region 2>/dev/null || echo "")
  if [ -n "$REGION" ]; then
    echo "✓ Default region: $REGION"
    OK=$((OK + 1))
  else
    echo "⚠ No default region set (deploy.sh reads region from infra.json, so this is optional)"
    WARN=$((WARN + 1))
  fi
fi

# --- Other tools ---
section "Other Tools"

if command -v node &>/dev/null; then
  echo "✓ Node.js $(node --version)"
  OK=$((OK + 1))
else
  echo "✗ Node.js not found. Run: nvm install"
  WARN=$((WARN + 1))
fi

if command -v python3 &>/dev/null; then
  echo "✓ Python $(python3 --version 2>&1 | awk '{print $2}')"
  OK=$((OK + 1))
else
  echo "✗ python3 not found"
  WARN=$((WARN + 1))
fi

if command -v zip &>/dev/null; then
  echo "✓ zip available"
  OK=$((OK + 1))
else
  echo "✗ zip not found"
  WARN=$((WARN + 1))
fi

# --- Summary ---
echo ""
echo "───────────────────────────────"
echo "Setup: $OK passed, $WARN warnings"

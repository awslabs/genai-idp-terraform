#!/usr/bin/env bash
# validate-processing-environment-api.sh — Task 6.3
# Validates processing-environment-api feature flags and GovCloud guard.
# Usage: bash tests/validate-processing-environment-api.sh (from genai-idp-terraform/ root)

set -euo pipefail

PASS=0
FAIL=0
MODULE="modules/processing-environment-api"

check() {
  local desc="$1"
  local result="$2"
  if [ "$result" = "true" ]; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== processing-environment-api Feature Flag Validation ==="

# Feature flag variables exist with correct defaults
echo ""
echo "--- Feature flag variables ---"
check "enable_agent_companion_chat variable (default true)" \
  "$(grep -A5 'variable "enable_agent_companion_chat"' "$MODULE/variables.tf" | grep -q 'default.*true' && echo true || echo false)"

check "enable_test_studio variable (default true)" \
  "$(grep -A5 'variable "enable_test_studio"' "$MODULE/variables.tf" | grep -q 'default.*true' && echo true || echo false)"

check "enable_fcc_dataset variable (default false)" \
  "$(grep -A5 'variable "enable_fcc_dataset"' "$MODULE/variables.tf" | grep -q 'default.*false' && echo true || echo false)"

check "enable_error_analyzer variable (default true)" \
  "$(grep -A5 'variable "enable_error_analyzer"' "$MODULE/variables.tf" | grep -q 'default.*true' && echo true || echo false)"

check "enable_mcp variable (default false)" \
  "$(grep -A5 'variable "enable_mcp"' "$MODULE/variables.tf" | grep -q 'default.*false' && echo true || echo false)"

# Resources are conditional on feature flags
echo ""
echo "--- Conditional resource guards ---"
check "agent_chat_sessions DynamoDB conditional on enable_agent_companion_chat" \
  "$(grep -A2 'aws_dynamodb_table.*agent_chat_sessions' "$MODULE/agent-companion-chat.tf" | grep -q 'enable_agent_companion_chat' && echo true || echo false)"

check "test_sets DynamoDB conditional on enable_test_studio" \
  "$(grep -A2 'aws_dynamodb_table.*test_sets' "$MODULE/test-studio.tf" | grep -q 'enable_test_studio' && echo true || echo false)"

check "fcc_dataset_deployer conditional on enable_fcc_dataset" \
  "$(grep -A2 'aws_lambda_function.*fcc_dataset_deployer' "$MODULE/test-studio.tf" | grep -q 'enable_fcc_dataset' && echo true || echo false)"

check "error_analyzer Lambda conditional on enable_error_analyzer" \
  "$(grep -A2 'aws_lambda_function.*error_analyzer[^_]' "$MODULE/error-analyzer.tf" | grep -q 'enable_error_analyzer' && echo true || echo false)"

check "agentcore_gateway CloudFormation stack conditional on enable_mcp_effective" \
  "$(grep -A2 'aws_cloudformation_stack.*agentcore_gateway' "$MODULE/mcp-integration.tf" | grep -q 'enable_mcp_effective' && echo true || echo false)"

# GovCloud guard
echo ""
echo "--- GovCloud guard ---"
check "enable_mcp_effective local uses startswith us-gov-" \
  "$(grep -q 'startswith.*us-gov-' "$MODULE/mcp-integration.tf" && echo true || echo false)"

check "enable_mcp_effective = enable_mcp AND NOT govcloud" \
  "$(grep -q 'enable_mcp_effective.*=.*var.enable_mcp.*&&.*!startswith\|enable_mcp_effective.*=.*!startswith.*&&.*var.enable_mcp' "$MODULE/mcp-integration.tf" && echo true || echo false)"

# MCP outputs
echo ""
echo "--- MCP outputs ---"
check "mcp_gateway_endpoint output exists" \
  "$(grep -q 'mcp_gateway_endpoint' "$MODULE/outputs.tf" && echo true || echo false)"

check "mcp_oauth_client_id output exists" \
  "$(grep -q 'mcp_oauth_client_id' "$MODULE/outputs.tf" && echo true || echo false)"

check "mcp_oauth_client_secret output is sensitive" \
  "$(grep -A5 'mcp_oauth_client_secret' "$MODULE/outputs.tf" | grep -q 'sensitive.*true' && echo true || echo false)"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1

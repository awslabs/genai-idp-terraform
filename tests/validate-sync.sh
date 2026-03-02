#!/usr/bin/env bash
# validate-sync.sh — Task 6.1
# Verifies source sync completeness for v0.4.8 upgrade.
# Usage: bash tests/validate-sync.sh (from genai-idp-terraform/ root)

set -euo pipefail

PASS=0
FAIL=0

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

echo "=== Source Sync Validation ==="

# IDP_VERSION and VERSION
check "IDP_VERSION=0.4.8" "$([ "$(cat IDP_VERSION 2>/dev/null)" = "0.4.8" ] && echo true || echo false)"
check "VERSION=0.4.8-tf.0" "$([ "$(cat VERSION 2>/dev/null)" = "0.4.8-tf.0" ] && echo true || echo false)"

# 19 new Lambda directories (spot-check key ones)
NEW_LAMBDAS=(
  agent_chat_processor
  agent_chat_resolver
  agentcore_analytics_processor
  agentcore_gateway_manager
  create_chat_session_resolver
  delete_agent_chat_session_resolver
  delete_tests
  error_analyzer
  error_analyzer_resolver
  fcc_dataset_deployer
  get_agent_chat_messages_resolver
  list_agent_chat_sessions_resolver
  post_processing_decompressor
  test_file_copier
  test_results_resolver
  test_runner
  test_set_file_copier
  test_set_resolver
  test_set_zip_extractor
)

echo ""
echo "--- New Lambda directories ---"
for lambda in "${NEW_LAMBDAS[@]}"; do
  check "sources/src/lambda/$lambda exists" "$([ -d "sources/src/lambda/$lambda" ] && echo true || echo false)"
done

# evaluation_function in Pattern 1 and Pattern 3
echo ""
echo "--- evaluation_function in patterns ---"
check "sources/patterns/pattern-1/src/evaluation_function exists" \
  "$([ -d "sources/patterns/pattern-1/src/evaluation_function" ] && echo true || echo false)"
check "sources/patterns/pattern-3/src/evaluation_function exists" \
  "$([ -d "sources/patterns/pattern-3/src/evaluation_function" ] && echo true || echo false)"

# State machine ASL files updated (check for EvaluateDocument state)
echo ""
echo "--- State machine ASL updates ---"
for pattern in pattern-1 pattern-2 pattern-3; do
  asl="sources/patterns/$pattern/statemachine/workflow.asl.json"
  if [ -f "$asl" ]; then
    check "$pattern ASL contains EvaluationStep or EvaluationLambdaArn" \
      "$(grep -q "EvaluationStep\|EvaluationLambdaArn\|EvaluateDocument" "$asl" && echo true || echo false)"
  else
    check "$pattern ASL file exists" "false"
  fi
done

# GraphQL schema updated
echo ""
echo "--- GraphQL schema ---"
check "schema.graphql contains agentChat types" \
  "$(grep -q -i "agentChat\|AgentChat\|chatSession\|ChatSession" sources/src/api/schema.graphql 2>/dev/null && echo true || echo false)"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1

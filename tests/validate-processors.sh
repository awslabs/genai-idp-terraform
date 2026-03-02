#!/usr/bin/env bash
# validate-processors.sh — Tasks 6.4 and 6.5
# Validates bda-processor, sagemaker-udop-processor, and bedrock-llm-processor modules.
# Usage: bash tests/validate-processors.sh (from genai-idp-terraform/ root)

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

# =============================================================================
# Task 6.4: bda-processor and sagemaker-udop-processor
# =============================================================================

echo "=== bda-processor Validation ==="

BDA="modules/processors/bda-processor"

check "ECR repository resource exists" \
  "$(grep -rl 'aws_ecr_repository' "$BDA/" | grep -q . && echo true || echo false)"

check "CodeBuild project resource exists" \
  "$(grep -rl 'aws_codebuild_project' "$BDA/" | grep -q . && echo true || echo false)"

check "CodeBuild privileged_mode = true" \
  "$(grep -r 'privileged_mode.*=.*true' "$BDA/" | grep -q . && echo true || echo false)"

check "evaluation_function Lambda resource exists" \
  "$(grep -rl 'aws_lambda_function.*evaluation_function\|evaluation_function.*aws_lambda_function' "$BDA/" | grep -q . && echo true || echo false)"

check "enable_ecr_image_scanning variable defined" \
  "$(grep -q 'variable "enable_ecr_image_scanning"' "$BDA/variables.tf" && echo true || echo false)"

check "EvaluationLambdaArn referenced in state machine templatefile" \
  "$(grep -r 'EvaluationLambdaArn' "$BDA/" | grep -q . && echo true || echo false)"

echo ""
echo "=== sagemaker-udop-processor Validation ==="

UDOP="modules/processors/sagemaker-udop-processor"

check "ECR repository resource exists" \
  "$(grep -rl 'aws_ecr_repository' "$UDOP/" | grep -q . && echo true || echo false)"

check "CodeBuild project resource exists" \
  "$(grep -rl 'aws_codebuild_project' "$UDOP/" | grep -q . && echo true || echo false)"

check "evaluation_function Lambda resource exists" \
  "$(grep -rl 'aws_lambda_function.*evaluation_function\|evaluation_function.*aws_lambda_function' "$UDOP/" | grep -q . && echo true || echo false)"

check "EvaluationLambdaArn referenced in state machine templatefile" \
  "$(grep -r 'EvaluationLambdaArn' "$UDOP/" | grep -q . && echo true || echo false)"

# Pattern 3: evaluation function always created (D-003)
check "Pattern 3 evaluation_function NOT conditional on baseline bucket (D-003)" \
  "$(! grep -B2 'aws_lambda_function.*evaluation_function' "$UDOP/"*.tf 2>/dev/null | grep -q 'evaluation_baseline_bucket_arn.*!=.*null\|count.*evaluation_baseline' && echo true || echo false)"

# =============================================================================
# Task 6.5: bedrock-llm-processor
# =============================================================================

echo ""
echo "=== bedrock-llm-processor Validation ==="

P2="modules/processors/bedrock-llm-processor"

check "section_splitting_strategy variable defined" \
  "$(grep -q 'variable "section_splitting_strategy"' "$P2/variables.tf" && echo true || echo false)"

check "section_splitting_strategy validation rejects invalid values" \
  "$(grep -A10 'variable "section_splitting_strategy"' "$P2/variables.tf" | grep -q 'validation\|contains' && echo true || echo false)"

check "section_splitting_strategy accepts disabled/page/llm_determined" \
  "$(grep -A15 'variable "section_splitting_strategy"' "$P2/variables.tf" | grep -q '"disabled".*"page".*"llm_determined"\|disabled.*page.*llm_determined' && echo true || echo false)"

check "enable_agentic_extraction variable defined" \
  "$(grep -q 'variable "enable_agentic_extraction"' "$P2/variables.tf" && echo true || echo false)"

check "enable_agentic_extraction wired into config override" \
  "$(grep -r 'ENABLE_AGENTIC_EXTRACTION\|enable_agentic_extraction' "$P2/main.tf" | grep -q . && echo true || echo false)"

check "review_agent_model variable defined" \
  "$(grep -q 'variable "review_agent_model"' "$P2/variables.tf" && echo true || echo false)"

check "evaluation_baseline_bucket_arn variable defined" \
  "$(grep -q 'variable "evaluation_baseline_bucket_arn"' "$P2/variables.tf" && echo true || echo false)"

check "evaluation Lambda has TRACKING_TABLE env var (fix #132)" \
  "$(grep -r 'TRACKING_TABLE' "$P2/" | grep -q . && echo true || echo false)"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1

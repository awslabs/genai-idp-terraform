#!/usr/bin/env bash
# validate-processing-environment.sh — Task 6.2
# Validates processing-environment module HCL for v0.4.8 changes.
# Usage: bash tests/validate-processing-environment.sh (from genai-idp-terraform/ root)

set -euo pipefail

PASS=0
FAIL=0
MODULE="modules/processing-environment"

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

echo "=== processing-environment Module Validation ==="

# lambda_tracing_mode variable exists (D-005: no enable_xray_tracing bool)
check "lambda_tracing_mode variable defined" \
  "$(grep -q 'variable "lambda_tracing_mode"' "$MODULE/variables.tf" && echo true || echo false)"

check "lambda_tracing_mode has Active/PassThrough validation" \
  "$(grep -q '"Active".*"PassThrough"\|"PassThrough".*"Active"' "$MODULE/variables.tf" && echo true || echo false)"

# No enable_xray_tracing bool variable (D-005)
check "no enable_xray_tracing bool variable (D-005)" \
  "$(! grep -q 'variable "enable_xray_tracing"' "$MODULE/variables.tf" && echo true || echo false)"

# post_processing_decompressor Lambda exists
check "post_processing_decompressor Lambda resource exists" \
  "$(grep -q 'aws_lambda_function.*post_processing_decompressor\|post_processing_decompressor.*aws_lambda_function' "$MODULE/lambda_functions.tf" && echo true || echo false)"

check "custom_post_processor_arn variable defined" \
  "$(grep -q 'variable "custom_post_processor_arn"' "$MODULE/variables.tf" && echo true || echo false)"

# lookup_function_arn output
check "lookup_function_arn output exists" \
  "$(grep -q 'lookup_function_arn' "$MODULE/outputs.tf" && echo true || echo false)"

# post_processing_decompressor_function_arn output
check "post_processing_decompressor_function_arn output exists" \
  "$(grep -q 'post_processing_decompressor_function_arn' "$MODULE/outputs.tf" && echo true || echo false)"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1

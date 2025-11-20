#!/bin/bash
// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

# GenAI IDP Accelerator - Source Sync Validation Script
# This script validates that all expected files have been synced from sources/ to assets/

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Base directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCES_DIR="${SCRIPT_DIR}/sources"
MODULES_DIR="${SCRIPT_DIR}/modules"

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Function to check if file exists
check_file() {
    local file_path="$1"
    local description="$2"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if [ -f "$file_path" ]; then
        print_success "$description"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        return 0
    else
        print_error "$description - File not found: $file_path"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        return 1
    fi
}

# Function to check if directory exists and has content
check_directory() {
    local dir_path="$1"
    local description="$2"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if [ -d "$dir_path" ] && [ "$(ls -A "$dir_path" 2>/dev/null)" ]; then
        print_success "$description"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        return 0
    else
        print_error "$description - Directory empty or not found: $dir_path"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        return 1
    fi
}

print_status "Starting source sync validation..."
print_status "Checking synced files and directories in assets/ folders..."

# =============================================================================
# 1. COMMON LIBRARY FILES
# =============================================================================
print_status ""
print_status "Validating common library files..."

check_directory \
    "${MODULES_DIR}/idp-common-layer/assets/lib" \
    "Common library files in idp-common-layer/assets/lib"

# =============================================================================
# 2. PROCESSING ENVIRONMENT LAMBDA FUNCTIONS
# =============================================================================
print_status ""
print_status "Validating processing environment lambda functions..."

declare -a PROCESSING_ENV_LAMBDAS=(
    "lookup_function"
    "queue_sender"
    "update_configuration"
    "workflow_tracker"
)

for lambda_name in "${PROCESSING_ENV_LAMBDAS[@]}"; do
    check_directory \
        "${MODULES_DIR}/processing-environment/assets/lambdas/${lambda_name}" \
        "Processing environment lambda: ${lambda_name}"
done

# =============================================================================
# 3. PROCESSING ENVIRONMENT API LAMBDA FUNCTIONS
# =============================================================================
print_status ""
print_status "Validating processing environment API lambda functions..."

declare -a API_LAMBDAS=(
    "configuration_resolver"
    "copy_to_baseline_resolver"
    "delete_document_resolver"
    "get_file_contents_resolver"
    "query_knowledgebase_resolver"
    "reprocess_document_resolver"
    "upload_resolver"
)

for lambda_name in "${API_LAMBDAS[@]}"; do
    check_directory \
        "${MODULES_DIR}/processing-environment-api/assets/lambdas/${lambda_name}" \
        "API resolver lambda: ${lambda_name}"
done

# =============================================================================
# 4. APPSYNC SCHEMA
# =============================================================================
print_status ""
print_status "Validating AppSync schema..."

check_file \
    "${MODULES_DIR}/processing-environment-api/assets/appsync/schema.graphql" \
    "AppSync GraphQL schema"

# =============================================================================
# 5. WEB UI FILES
# =============================================================================
print_status ""
print_status "Validating web UI files..."

check_directory \
    "${MODULES_DIR}/web-ui/assets/webapp/ui" \
    "Web UI source files"

# =============================================================================
# 6. PATTERN 1 (BDA PROCESSOR) FILES
# =============================================================================
print_status ""
print_status "Validating Pattern 1 (BDA Processor) files..."

declare -a PATTERN1_LAMBDAS=(
    "bda_completion_function"
    "bda_invoke_function"
    "processresults_function"
    "summarization_function"
    "hitl-wait-function"
    "hitl-process-function"
)

for lambda_name in "${PATTERN1_LAMBDAS[@]}"; do
    check_directory \
        "${MODULES_DIR}/processors/bda-processor/assets/lambdas/${lambda_name}" \
        "Pattern 1 lambda: ${lambda_name}"
done

check_file \
    "${MODULES_DIR}/processors/bda-processor/assets/sfn/workflow.asl.json" \
    "Pattern 1 state machine definition"

check_file \
    "${MODULES_DIR}/processors/bda-processor/assets/configs/default/config.yaml" \
    "Pattern 1 default configuration"

# =============================================================================
# 7. PATTERN 2 (BEDROCK LLM PROCESSOR) FILES
# =============================================================================
print_status ""
print_status "Validating Pattern 2 (Bedrock LLM Processor) files..."

declare -a PATTERN2_LAMBDAS=(
    "assessment_function"
    "classification_function"
    "extraction_function"
    "ocr_function"
    "processresults_function"
    "summarization_function"
)

for lambda_name in "${PATTERN2_LAMBDAS[@]}"; do
    check_directory \
        "${MODULES_DIR}/processors/bedrock-llm-processor/assets/lambdas/${lambda_name}" \
        "Pattern 2 lambda: ${lambda_name}"
done

check_file \
    "${MODULES_DIR}/processors/bedrock-llm-processor/assets/sfn/workflow.asl.json" \
    "Pattern 2 state machine definition"

declare -a PATTERN2_CONFIGS=(
    "default"
    "checkboxed_attributes_extraction"
    "few_shot_example_with_multimodal_page_classification"
    "medical_records_summarization"
)

for config_name in "${PATTERN2_CONFIGS[@]}"; do
    check_file \
        "${MODULES_DIR}/processors/bedrock-llm-processor/assets/configs/${config_name}/config.yaml" \
        "Pattern 2 config: ${config_name}"
done

# =============================================================================
# 8. PATTERN 3 (SAGEMAKER UDOP PROCESSOR) FILES
# =============================================================================
print_status ""
print_status "Validating Pattern 3 (SageMaker UDOP Processor) files..."

for lambda_name in "${PATTERN2_LAMBDAS[@]}"; do
    check_directory \
        "${MODULES_DIR}/processors/sagemaker-udop-processor/assets/lambdas/${lambda_name}" \
        "Pattern 3 lambda: ${lambda_name}"
done

check_file \
    "${MODULES_DIR}/processors/sagemaker-udop-processor/assets/sfn/workflow.asl.json" \
    "Pattern 3 state machine definition"

check_file \
    "${MODULES_DIR}/processors/sagemaker-udop-processor/assets/configs/default/config.yaml" \
    "Pattern 3 default configuration"

# =============================================================================
# 9. PROCESSOR ATTACHMENT LAMBDA
# =============================================================================
print_status ""
print_status "Validating processor attachment lambda..."

check_directory \
    "${MODULES_DIR}/processor-attachment/assets/lambdas/queue_processor" \
    "Processor attachment lambda: queue_processor"

# =============================================================================
# SUMMARY
# =============================================================================
print_status ""
print_status "=== VALIDATION SUMMARY ==="
print_status "Total checks: $TOTAL_CHECKS"
print_success "Passed: $PASSED_CHECKS"

if [ $FAILED_CHECKS -gt 0 ]; then
    print_error "Failed: $FAILED_CHECKS"
    print_status ""
    print_error "Some files are missing. Run ./sync-sources.sh to sync files from sources/"
    exit 1
else
    print_status ""
    print_success "All validation checks passed! 🎉"
    print_status "All expected files have been synced to assets/ directories successfully."
fi

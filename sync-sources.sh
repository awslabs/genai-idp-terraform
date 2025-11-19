#!/bin/bash

# GenAI IDP Accelerator - Source File Synchronization Script
# This script copies relevant files from the sources/ directory to the appropriate
# Terraform module assets/ locations, following the CDK implementation pattern.

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

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to create directory if it doesn't exist
ensure_dir() {
    if [ ! -d "$1" ]; then
        mkdir -p "$1"
        print_status "Created directory: $1"
    fi
}

# Function to copy directory with rsync
copy_directory() {
    local src_dir="$1"
    local dest_dir="$2"
    local description="$3"
    
    if [ ! -d "$src_dir" ]; then
        print_warning "Source directory not found: $src_dir"
        return 1
    fi
    
    ensure_dir "$dest_dir"
    rsync -av --delete "$src_dir/" "$dest_dir/"
    print_success "$description"
}

# Function to copy file with status
copy_file() {
    local src="$1"
    local dest="$2"
    local description="$3"
    
    if [ ! -f "$src" ]; then
        print_warning "Source file not found: $src"
        return 1
    fi
    
    ensure_dir "$(dirname "$dest")"
    cp "$src" "$dest"
    print_success "$description"
}

# Check if sources directory exists
if [ ! -d "$SOURCES_DIR" ]; then
    print_error "Sources directory not found: $SOURCES_DIR"
    exit 1
fi

print_status "Starting source file synchronization..."
print_status "Sources directory: $SOURCES_DIR"
print_status "Modules directory: $MODULES_DIR"

# =============================================================================
# 1. COMMON LIBRARY FILES
# =============================================================================
print_status "Syncing common library files..."

copy_directory \
    "${SOURCES_DIR}/lib/idp_common_pkg" \
    "${MODULES_DIR}/idp-common-layer/assets/idp_common_pkg" \
    "Synced idp_common_pkg to idp-common-layer/assets/idp_common_pkg"

# =============================================================================
# 2. PROCESSING ENVIRONMENT LAMBDA FUNCTIONS
# =============================================================================
print_status "Syncing processing environment lambda functions..."

# Define processing environment lambdas
declare -a PROCESSING_ENV_LAMBDAS=(
    "lookup_function"
    "queue_sender" 
    "update_configuration"
    "workflow_tracker"
)

for lambda_name in "${PROCESSING_ENV_LAMBDAS[@]}"; do
    copy_directory \
        "${SOURCES_DIR}/src/lambda/${lambda_name}" \
        "${MODULES_DIR}/processing-environment/assets/lambdas/${lambda_name}" \
        "Synced processing environment lambda: ${lambda_name}"
done

# =============================================================================
# 3. PROCESSING ENVIRONMENT API LAMBDA FUNCTIONS  
# =============================================================================
print_status "Syncing processing environment API lambda functions..."

# Define API resolver lambdas
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
    copy_directory \
        "${SOURCES_DIR}/src/lambda/${lambda_name}" \
        "${MODULES_DIR}/processing-environment-api/assets/lambdas/${lambda_name}" \
        "Synced API resolver lambda: ${lambda_name}"
done

# =============================================================================
# 4. APPSYNC SCHEMA
# =============================================================================
print_status "Syncing AppSync schema..."

copy_file \
    "${SOURCES_DIR}/src/api/schema.graphql" \
    "${MODULES_DIR}/processing-environment-api/assets/appsync/schema.graphql" \
    "Synced AppSync GraphQL schema"

# =============================================================================
# 5. WEB UI FILES
# =============================================================================
print_status "Syncing web UI files..."

copy_directory \
    "${SOURCES_DIR}/src/ui" \
    "${MODULES_DIR}/web-ui/assets/webapp/ui" \
    "Synced UI files to web-ui/assets/webapp/ui"

# =============================================================================
# 6. PATTERN 1 (BDA PROCESSOR) FILES
# =============================================================================
print_status "Syncing Pattern 1 (BDA Processor) files..."

# Pattern 1 lambdas
declare -a PATTERN1_LAMBDAS=(
    "bda_completion_function"
    "bda_invoke_function"
    "processresults_function"
    "summarization_function"
    "hitl-wait-function"
    "hitl-process-function"
)

for lambda_name in "${PATTERN1_LAMBDAS[@]}"; do
    copy_directory \
        "${SOURCES_DIR}/patterns/pattern-1/src/${lambda_name}" \
        "${MODULES_DIR}/processors/bda-processor/assets/lambdas/${lambda_name}" \
        "Synced Pattern 1 lambda: ${lambda_name}"
done

# Pattern 1 state machine
copy_file \
    "${SOURCES_DIR}/patterns/pattern-1/statemachine/workflow.asl.json" \
    "${MODULES_DIR}/processors/bda-processor/assets/sfn/workflow.asl.json" \
    "Synced Pattern 1 state machine definition"

# Pattern 1 default config
copy_file \
    "${SOURCES_DIR}/config_library/pattern-1/default/config.yaml" \
    "${MODULES_DIR}/processors/bda-processor/assets/configs/default/config.yaml" \
    "Synced Pattern 1 default configuration"

# =============================================================================
# 7. PATTERN 2 (BEDROCK LLM PROCESSOR) FILES
# =============================================================================
print_status "Syncing Pattern 2 (Bedrock LLM Processor) files..."

# Pattern 2 lambdas
declare -a PATTERN2_LAMBDAS=(
    "assessment_function"
    "classification_function"
    "extraction_function"
    "ocr_function"
    "processresults_function"
    "summarization_function"
)

for lambda_name in "${PATTERN2_LAMBDAS[@]}"; do
    copy_directory \
        "${SOURCES_DIR}/patterns/pattern-2/src/${lambda_name}" \
        "${MODULES_DIR}/processors/bedrock-llm-processor/assets/lambdas/${lambda_name}" \
        "Synced Pattern 2 lambda: ${lambda_name}"
done

# Pattern 2 state machine
copy_file \
    "${SOURCES_DIR}/patterns/pattern-2/statemachine/workflow.asl.json" \
    "${MODULES_DIR}/processors/bedrock-llm-processor/assets/sfn/workflow.asl.json" \
    "Synced Pattern 2 state machine definition"

# Pattern 2 configs
declare -a PATTERN2_CONFIGS=(
    "default"
    "checkboxed_attributes_extraction"
    "few_shot_example_with_multimodal_page_classification"
    "medical_records_summarization"
)

for config_name in "${PATTERN2_CONFIGS[@]}"; do
    copy_file \
        "${SOURCES_DIR}/config_library/pattern-2/${config_name}/config.yaml" \
        "${MODULES_DIR}/processors/bedrock-llm-processor/assets/configs/${config_name}/config.yaml" \
        "Synced Pattern 2 config: ${config_name}"
done

# =============================================================================
# 8. PATTERN 3 (SAGEMAKER UDOP PROCESSOR) FILES
# =============================================================================
print_status "Syncing Pattern 3 (SageMaker UDOP Processor) files..."

# Pattern 3 lambdas (same as Pattern 2)
for lambda_name in "${PATTERN2_LAMBDAS[@]}"; do
    copy_directory \
        "${SOURCES_DIR}/patterns/pattern-3/src/${lambda_name}" \
        "${MODULES_DIR}/processors/sagemaker-udop-processor/assets/lambdas/${lambda_name}" \
        "Synced Pattern 3 lambda: ${lambda_name}"
done

# Pattern 3 state machine
copy_file \
    "${SOURCES_DIR}/patterns/pattern-3/statemachine/workflow.asl.json" \
    "${MODULES_DIR}/processors/sagemaker-udop-processor/assets/sfn/workflow.asl.json" \
    "Synced Pattern 3 state machine definition"

# Pattern 3 default config
copy_file \
    "${SOURCES_DIR}/config_library/pattern-3/default/config.yaml" \
    "${MODULES_DIR}/processors/sagemaker-udop-processor/assets/configs/default/config.yaml" \
    "Synced Pattern 3 default configuration"

# =============================================================================
# 9. PROCESSOR ATTACHMENT LAMBDA
# =============================================================================
print_status "Syncing processor attachment lambda..."

copy_directory \
    "${SOURCES_DIR}/src/lambda/queue_processor" \
    "${MODULES_DIR}/processor-attachment/assets/lambdas/queue_processor" \
    "Synced processor attachment lambda: queue_processor"

# =============================================================================
# 10. ADDITIONAL LAMBDA FUNCTIONS
# =============================================================================
print_status "Syncing additional lambda functions..."

# Other lambda functions that might be used by various modules
declare -a OTHER_LAMBDAS=(
    "dashboard_merger"
    "evaluation_function"
    "initialize_counter"
    "ipset_updater"
    "start_codebuild"
    "update_settings"
)

for lambda_name in "${OTHER_LAMBDAS[@]}"; do
    src_dir="${SOURCES_DIR}/src/lambda/${lambda_name}"
    if [ -d "$src_dir" ]; then
        # These might be used by monitoring, reporting, or other modules
        copy_directory \
            "$src_dir" \
            "${MODULES_DIR}/lambda-functions/assets/lambdas/${lambda_name}" \
            "Synced additional lambda: ${lambda_name}"
    fi
done

# =============================================================================
# COMPLETION
# =============================================================================
print_success "Source file synchronization completed successfully!"
print_status ""
print_status "Summary:"
print_status "- Common library files synced to idp-common-layer/assets/idp_common_pkg"
print_status "- Processing environment lambdas synced to processing-environment/assets/lambdas/"
print_status "- API resolver lambdas synced to processing-environment-api/assets/lambdas/"
print_status "- AppSync schema synced to processing-environment-api/assets/appsync/"
print_status "- Web UI files synced to web-ui/assets/webapp/ui/"
print_status "- All three processor patterns synced:"
print_status "  * Lambdas to processors/*/assets/lambdas/"
print_status "  * Configs to processors/*/assets/configs/"
print_status "  * State machines to processors/*/assets/sfn/"
print_status "- Processor attachment lambda synced to processor-attachment/assets/lambdas/"

print_status ""
print_status "Next steps:"
print_status "1. Review the synced files for any customizations needed"
print_status "2. Update Terraform configurations to reference assets/ paths"
print_status "3. Test the modules to ensure everything works correctly"
print_status ""
print_success "Sync complete! 🚀"

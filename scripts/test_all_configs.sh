#!/usr/bin/env bash
# =============================================================================
# test_all_configs.sh — end-to-end functional test of a deployed IDP processor
# =============================================================================
#
# WHAT THIS TESTS
#   That a deployed processor actually *processes documents* end-to-end — not
#   just that `terraform apply` succeeded. For each available configuration
#   version it uploads a sample document and confirms the document's Step
#   Function execution reaches SUCCEEDED.
#
# WHERE IT IS VALID (which examples)
#   Only the unified/Pattern-2 *processor* examples that expose the
#   input_bucket / output_bucket / step_function_arn outputs AND seed multiple
#   configuration versions:
#     - bedrock-llm-processor        (primary target — pure Pattern-2)
#     - bedrock-llm-processor-vpc    (same, inside a VPC)
#     - sagemaker-udop-processor     (works, but the UDOP classifier endpoint
#                                     must be healthy and inputs UDOP-suitable)
#   NOT valid for:
#     - bda-processor                (Pattern-1 / BDA-managed: BDA performs its
#                                     own classification+extraction, so per-doc
#                                     config-version routing does not apply)
#     - core-tables, processing-environment, processing-environment-api,
#       user-identity-standalone     (no Step Function pipeline at all — the
#                                     script errors out early on these)
#
# HOW IT WORKS (the config-version mechanism)
#   The processor-configuration module seeds the configuration table at deploy
#   time with:
#     - one ACTIVE version  = the example's config_file_path (tested here as the
#       version name "default")
#     - several MANAGED, non-active versions auto-discovered from
#       sources/config_library/managed_config/<name>/config.yaml
#   The unified-pattern lambdas (extraction_function, assessment_function,
#   rule-validation-function, ...) read the `config-version` S3 object metadata
#   off each uploaded document and call get_config(version=<that>). So tagging an
#   upload with `--metadata config-version=<name>` routes that one document
#   through the named seeded config. This script therefore exercises every
#   seeded version in a single run.
#
#   The version list is discovered DYNAMICALLY from the managed_config directory
#   (plus the implicit "default" active version), so it automatically tracks
#   whatever managed baselines ship in the repo — no hardcoded list to maintain.
#
# Usage:
#   ./scripts/test_all_configs.sh --example <name> [--profile PROFILE] \
#       [--region REGION] [--timeout SECONDS]
#
# Prerequisites:
#   - terraform init + apply already completed in examples/<name>
#   - AWS credentials with S3 write + Step Functions read access
#   - python3 available (used to parse JSON from the AWS CLI)
# =============================================================================

set -uo pipefail

# Defaults
EXAMPLE=""
PROFILE=""
REGION="us-east-1"
TIMEOUT=600  # seconds to wait for all executions
POLL_INTERVAL=15

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --example) EXAMPLE="$2"; shift 2 ;;
    --profile) PROFILE="$2"; shift 2 ;;
    --region)  REGION="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    -h|--help)
      grep '^#' "$0" | grep -v '^#!' | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$EXAMPLE" ]]; then
  echo "ERROR: --example <name> is required (e.g. --example bedrock-llm-processor)" >&2
  exit 1
fi

AWS_OPTS=(--region "$REGION")
if [[ -n "$PROFILE" ]]; then
  AWS_OPTS+=(--profile "$PROFILE")
  export AWS_PROFILE="$PROFILE"
fi

# Resolve repo root from this script's location (scripts/ lives at the root).
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SAMPLES_DIR="$REPO_ROOT/sources/samples"
MANAGED_CONFIG_DIR="$REPO_ROOT/sources/config_library/managed_config"
EXAMPLE_DIR="$REPO_ROOT/examples/$EXAMPLE"

if [[ ! -d "$EXAMPLE_DIR" ]]; then
  echo "ERROR: example directory not found: $EXAMPLE_DIR" >&2
  exit 1
fi
if [[ ! -d "$SAMPLES_DIR" ]]; then
  echo "ERROR: samples directory not found: $SAMPLES_DIR" >&2
  exit 1
fi

# -----------------------------------------------------------------------------
# Sample-document mapping
#
# Maps a config-version name to the sample document best suited to exercise it.
# Any seeded version not listed here falls back to DEFAULT_SAMPLE — so when a
# new managed baseline is added upstream, the test still runs against it (just
# with the generic lending sample) until a more specific mapping is added.
# -----------------------------------------------------------------------------
DEFAULT_SAMPLE="lending_package.pdf"
sample_for_version() {
  case "$1" in
    default)              echo "lending_package.pdf" ;;
    docsplit)             echo "rvl_cdip_package.pdf" ;;
    fake-w2)              echo "w2/W2_XL_input_clean_1000.pdf" ;;
    ocr-benchmark)        echo "lending_package.pdf" ;;
    realkie-fcc-verified) echo "lending_package.pdf" ;;
    *)                    echo "$DEFAULT_SAMPLE" ;;
  esac
}

# -----------------------------------------------------------------------------
# Discover the configuration versions to test.
#   "default"          -> the active config seeded from config_file_path
#   <managed dir name> -> each managed baseline auto-seeded by the module
# -----------------------------------------------------------------------------
CONFIG_VERSIONS=("default")
if [[ -d "$MANAGED_CONFIG_DIR" ]]; then
  for d in "$MANAGED_CONFIG_DIR"/*/; do
    [[ -f "${d}config.yaml" ]] || continue
    CONFIG_VERSIONS+=("$(basename "$d")")
  done
fi

echo "=== Discovered configuration versions (${#CONFIG_VERSIONS[@]}) ==="
printf '  - %s\n' "${CONFIG_VERSIONS[@]}"
echo ""

# Get terraform outputs from the example dir
echo "=== Reading terraform outputs (examples/$EXAMPLE) ==="
INPUT_BUCKET=$(terraform -chdir="$EXAMPLE_DIR" output -json input_bucket 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin)['name'])" 2>/dev/null) || true
OUTPUT_BUCKET=$(terraform -chdir="$EXAMPLE_DIR" output -json output_bucket 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin)['name'])" 2>/dev/null) || true
SFN_ARN=$(terraform -chdir="$EXAMPLE_DIR" output -raw step_function_arn 2>/dev/null) || true

if [[ -z "$INPUT_BUCKET" || -z "$SFN_ARN" ]]; then
  echo "ERROR: could not read input_bucket / step_function_arn from examples/$EXAMPLE." >&2
  echo "       Ensure 'terraform apply' has completed there and the outputs exist." >&2
  echo "       Note: this script targets a unified/Pattern-2 processor example" >&2
  echo "       (bedrock-llm-processor, bedrock-llm-processor-vpc, sagemaker-udop-" >&2
  echo "       processor) — not the core/infra or BDA examples." >&2
  exit 1
fi

echo "  Input bucket:     $INPUT_BUCKET"
echo "  Output bucket:    $OUTPUT_BUCKET"
echo "  Step Function:    $SFN_ARN"
echo ""

# Track upload timestamps to identify our executions
UPLOAD_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TOTAL_UPLOADED=0

echo "=== Uploading test documents ==="
for CONFIG_VERSION in "${CONFIG_VERSIONS[@]}"; do
  SAMPLE_FILE="$(sample_for_version "$CONFIG_VERSION")"
  SOURCE_PATH="$SAMPLES_DIR/$SAMPLE_FILE"

  if [[ ! -f "$SOURCE_PATH" ]]; then
    echo "  [SKIP] $CONFIG_VERSION: sample file not found: $SAMPLE_FILE"
    continue
  fi

  # Upload with unique prefix to avoid collisions; include config-version metadata
  DEST_KEY="test-all-configs/${CONFIG_VERSION}/$(basename "$SAMPLE_FILE")"

  echo "  [UPLOAD] $CONFIG_VERSION -> s3://$INPUT_BUCKET/$DEST_KEY"
  if aws s3 cp "$SOURCE_PATH" "s3://$INPUT_BUCKET/$DEST_KEY" \
      --metadata "config-version=$CONFIG_VERSION" \
      "${AWS_OPTS[@]}" \
      --quiet; then
    TOTAL_UPLOADED=$((TOTAL_UPLOADED + 1))
  else
    echo "  [ERROR] upload failed for $CONFIG_VERSION" >&2
  fi
done

echo ""
echo "  Uploaded $TOTAL_UPLOADED documents"
echo ""

if [[ $TOTAL_UPLOADED -eq 0 ]]; then
  echo "ERROR: No documents uploaded. Check sample files exist under $SAMPLES_DIR." >&2
  exit 1
fi

# Wait a few seconds for EventBridge/SQS to trigger
echo "=== Waiting for processing to start (10s) ==="
sleep 10

# Monitor Step Function executions
echo "=== Monitoring Step Function executions ==="
echo "  Timeout: ${TIMEOUT}s | Poll interval: ${POLL_INTERVAL}s"
echo ""

ELAPSED=0
RUNNING=0
SUCCEEDED=0
FAILED=0
TOTAL_FOUND=0
while [[ $ELAPSED -lt $TIMEOUT ]]; do
  # List recent executions and count by status. Tolerate transient API
  # failures / empty results without aborting the script.
  COUNTS=$(aws stepfunctions list-executions \
    --state-machine-arn "$SFN_ARN" \
    --max-results 50 \
    "${AWS_OPTS[@]}" \
    --output json 2>/dev/null | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    print('0 0 0 0'); sys.exit(0)
upload_time = '$UPLOAD_TIME'
running = succeeded = failed = total = 0
for e in data.get('executions', []):
    if e['startDate'] >= upload_time:
        total += 1
        s = e['status']
        if s == 'RUNNING': running += 1
        elif s == 'SUCCEEDED': succeeded += 1
        elif s in ('FAILED', 'TIMED_OUT', 'ABORTED'): failed += 1
print(f'{total} {running} {succeeded} {failed}')
" 2>/dev/null) || COUNTS="0 0 0 0"
  read -r TOTAL_FOUND RUNNING SUCCEEDED FAILED <<< "$COUNTS"

  printf "\r  [%3ds] Found: %d | Running: %d | Succeeded: %d | Failed: %d    " \
    "$ELAPSED" "$TOTAL_FOUND" "$RUNNING" "$SUCCEEDED" "$FAILED"

  # All executions completed (at least as many as we uploaded)
  if [[ $TOTAL_FOUND -ge $TOTAL_UPLOADED ]] && [[ $RUNNING -eq 0 ]]; then
    echo ""
    echo ""
    break
  fi

  sleep "$POLL_INTERVAL"
  ELAPSED=$((ELAPSED + POLL_INTERVAL))
done

if [[ $ELAPSED -ge $TIMEOUT ]]; then
  echo ""
  echo ""
  echo "WARNING: Timeout reached. Some executions may still be running."
fi

# Final summary
echo "=== Final Results ==="
echo ""

export UPLOAD_TIME
aws stepfunctions list-executions \
  --state-machine-arn "$SFN_ARN" \
  --max-results 20 \
  "${AWS_OPTS[@]}" \
  --output json 2>/dev/null | python3 -c "
import json, sys, os
from datetime import datetime

upload_time = os.environ.get('UPLOAD_TIME', '')
raw = sys.stdin.read()
if not raw.strip():
    print('  (no execution data available)')
    sys.exit(0)

data = json.loads(raw)

print(f\"  {'Execution Name':<55} {'Status':<12} {'Duration'}\")
print('  ' + '-' * 80)

for e in data.get('executions', []):
    start = e['startDate']
    if start < upload_time:
        continue
    name = e['name']
    status = e['status']
    duration = ''
    if 'stopDate' in e:
        try:
            s = datetime.fromisoformat(start.replace('Z', '+00:00'))
            end = datetime.fromisoformat(e['stopDate'].replace('Z', '+00:00'))
            dur = (end - s).total_seconds()
            duration = f'{dur:.0f}s'
        except Exception:
            pass

    indicator = '+' if status == 'SUCCEEDED' else 'x' if status in ('FAILED', 'TIMED_OUT', 'ABORTED') else '.'
    print(f'  {indicator} {name:<53} {status:<12} {duration}')
"

echo ""
echo "=== Check Results ==="
echo "  Output bucket: s3://$OUTPUT_BUCKET/test-all-configs/"
echo ""
echo "  To view execution details:"
echo "    aws stepfunctions list-executions --state-machine-arn $SFN_ARN --max-results 10 ${AWS_OPTS[*]}"
echo ""
echo "  To check a failed execution:"
echo "    aws stepfunctions get-execution-history --execution-arn <ARN> ${AWS_OPTS[*]} --output json | jq '.events[] | select(.type | contains(\"Failed\"))'"
echo ""

if [[ ${SUCCEEDED:-0} -ge $TOTAL_UPLOADED ]]; then
  echo "  ALL $TOTAL_UPLOADED documents processed successfully!"
  exit 0
else
  echo "  WARNING: ${FAILED:-0} execution(s) failed / incomplete out of $TOTAL_UPLOADED uploaded."
  exit 1
fi

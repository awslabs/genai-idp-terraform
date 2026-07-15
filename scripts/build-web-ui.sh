#!/usr/bin/env bash
# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# build-web-ui.sh
#
# Builds the IDP web UI locally and deploys it to S3 + CloudFront.
# Called by null_resource.local_ui_build via local-exec provisioner.
#
# Required environment variables:
#   UI_SOURCE_DIR              - Path to the UI source directory (sources/src/ui)
#   WEB_APP_BUCKET             - S3 bucket name for the web app assets
#
# Optional environment variables:
#   CLOUDFRONT_DISTRIBUTION_ID - CloudFront distribution ID for cache invalidation
#                                (skipped if empty)
#
# VITE_* environment variables (injected as build-time config):
#   VITE_SETTINGS_PARAMETER    - SSM parameter name for web UI settings
#   VITE_USER_POOL_ID          - Cognito User Pool ID
#   VITE_USER_POOL_CLIENT_ID   - Cognito User Pool Client ID
#   VITE_IDENTITY_POOL_ID      - Cognito Identity Pool ID
#   VITE_APPSYNC_GRAPHQL_URL   - AppSync GraphQL API URL
#   VITE_AWS_REGION            - AWS region
#   VITE_SHOULD_HIDE_SIGN_UP   - Whether to hide sign-up in the UI
#   VITE_CLOUDFRONT_DOMAIN     - CloudFront domain URL
#
# Exit codes:
#   0 - Success
#   1 - Build failure (npm ci, npm run build, empty output, or S3 sync failure)

set -euo pipefail

# Validate required variables.
if [ -z "${UI_SOURCE_DIR:-}" ]; then
  echo "ERROR: UI_SOURCE_DIR is not set." >&2
  exit 1
fi

if [ -z "${WEB_APP_BUCKET:-}" ]; then
  echo "ERROR: WEB_APP_BUCKET is not set." >&2
  exit 1
fi

if [ ! -d "$UI_SOURCE_DIR" ]; then
  echo "ERROR: UI source directory does not exist: ${UI_SOURCE_DIR}" >&2
  exit 1
fi

if [ ! -f "${UI_SOURCE_DIR}/package.json" ]; then
  echo "ERROR: No package.json found in ${UI_SOURCE_DIR}" >&2
  exit 1
fi

echo "=== Building Web UI locally ==="
echo "Source: ${UI_SOURCE_DIR}"
echo "Target bucket: s3://${WEB_APP_BUCKET}/"
echo "Node.js: $(node --version)"
echo "npm: $(npm --version)"
echo ""

# Step 1: Install dependencies.
echo "--- Installing dependencies (npm ci) ---"
(cd "$UI_SOURCE_DIR" && npm ci) || {
  echo "ERROR: npm ci failed." >&2
  exit 1
}

# Step 2: Build the application.
# VITE_* env vars are automatically picked up by Vite during build.
echo ""
echo "--- Building application (npm run build) ---"
(cd "$UI_SOURCE_DIR" && npm run build) || {
  echo "ERROR: npm run build failed." >&2
  exit 1
}

# Step 3: Verify build output is non-empty.
BUILD_DIR="${UI_SOURCE_DIR}/build"
if [ ! -d "$BUILD_DIR" ] || [ -z "$(ls -A "$BUILD_DIR" 2>/dev/null)" ]; then
  echo "ERROR: Build produced empty output directory: ${BUILD_DIR}" >&2
  exit 1
fi

echo ""
echo "--- Build output (${BUILD_DIR}) ---"
echo "Files: $(find "$BUILD_DIR" -type f | wc -l | tr -d ' ')"
echo "Size: $(du -sh "$BUILD_DIR" | cut -f1)"

# Step 4: Sync to S3.
echo ""
echo "--- Syncing to s3://${WEB_APP_BUCKET}/ ---"
aws s3 sync "$BUILD_DIR" "s3://${WEB_APP_BUCKET}/" --delete || {
  echo "ERROR: S3 sync failed." >&2
  exit 1
}

# Step 5: Invalidate CloudFront (if distribution ID is provided).
if [ -n "${CLOUDFRONT_DISTRIBUTION_ID:-}" ]; then
  echo ""
  echo "--- Invalidating CloudFront distribution: ${CLOUDFRONT_DISTRIBUTION_ID} ---"
  aws cloudfront create-invalidation \
    --distribution-id "$CLOUDFRONT_DISTRIBUTION_ID" \
    --paths '/*' \
    --output text || {
    echo "WARNING: CloudFront invalidation failed (non-fatal)." >&2
    # Non-fatal: the new content is in S3, it will eventually propagate.
  }
else
  echo ""
  echo "--- No CloudFront distribution ID provided, skipping invalidation ---"
fi

echo ""
echo "=== Web UI build and deploy complete ==="

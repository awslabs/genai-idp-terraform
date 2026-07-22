#!/usr/bin/env bash
# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Validation script for the local-lambda-build feature flag.
#
# Runs terraform validate on the bedrock-llm-processor example with both
# build.lambda_local = false and build.lambda_local = true to confirm
# the dispatcher refactor parses and validates in both modes.
#
# This is a structural test only -- it does NOT run terraform plan
# (which would hit AWS) and does NOT actually build any artifacts.
# Real AWS apply coverage is exercised by the e2e tests against a
# test account; see openspec tasks 13.8 / 13.9.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXAMPLE_DIR="${REPO_ROOT}/examples/bedrock-llm-processor"

if [ ! -d "${EXAMPLE_DIR}" ]; then
  echo "FAIL: example dir missing at ${EXAMPLE_DIR}" >&2
  exit 1
fi

echo "Initializing ${EXAMPLE_DIR}..."
terraform -chdir="${EXAMPLE_DIR}" init -backend=false >/dev/null

echo "Validating with build.lambda_local = false..."
terraform -chdir="${EXAMPLE_DIR}" validate
echo "  PASS"

echo "Validating with build.lambda_local = true (via TF_VAR)..."
# Use TF_VAR_build to override at validate time. Validate doesn't read
# tfvars, but it does read TF_VAR_* env vars.
TF_VAR_build='{"lambda_local":true,"lambda_architecture":"x86_64","container_runtime":"auto","ui_local":false}' \
  terraform -chdir="${EXAMPLE_DIR}" validate
echo "  PASS"

echo
echo "All local-lambda-build structural validations passed."

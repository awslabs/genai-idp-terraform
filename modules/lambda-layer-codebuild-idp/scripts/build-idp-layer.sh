#!/usr/bin/env bash
# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Build a single idp-common Lambda layer zip inside an AWS SAM build
# container. This is the local-build analog of the CodeBuild buildspec in
# modules/lambda-layer-codebuild-idp/main.tf: it accepts a staging dir
# that already contains the requirements tree (one subdir per logical
# layer name, each with requirements.txt and -- for the idp-common layer
# -- a vendored idp_common_pkg/ source tree) and produces one or more
# layer.zip files at predictable paths.
#
# The script reproduces the buildspec's behavior bit-equivalently:
#   * special-cases the idp-common layer, which builds via
#     `pip install -e ./idp_common_pkg[extras]`
#   * for all other layers, plain pip install -r requirements.txt
#   * strips runtime-provided packages (boto3, botocore, awscli, ...)
#   * strips dist-info / egg-info / __pycache__ / tests
#   * leaves layer.zip alongside the staged requirements
#
# Inputs (all via env):
#   LAYER_NAME       logical layer name (subdir under STAGING_DIR/requirements)
#   STAGING_DIR      absolute path; STAGING_DIR/requirements/<layer> contains
#                    the per-layer staging tree
#   SAM_IMAGE        full SAM image tag (e.g. public.ecr.aws/sam/build-python3.12:latest-x86_64)
#   DOCKER_PLATFORM  docker --platform value
#   DOCKER_HOST      optional; passed through to docker CLI
#   IDP_COMMON_EXTRAS comma-separated extras list (only meaningful for the
#                    idp-common layer; ignored otherwise)

set -euo pipefail

: "${LAYER_NAME:?LAYER_NAME is required}"
: "${STAGING_DIR:?STAGING_DIR is required}"
: "${SAM_IMAGE:?SAM_IMAGE is required}"
: "${DOCKER_PLATFORM:?DOCKER_PLATFORM is required}"
IDP_COMMON_EXTRAS="${IDP_COMMON_EXTRAS:-}"

LAYER_DIR="${STAGING_DIR}/requirements/${LAYER_NAME}"
if [ ! -d "${LAYER_DIR}" ]; then
  echo "build-idp-layer: layer staging dir missing at ${LAYER_DIR}" >&2
  exit 1
fi

DOCKER_CLI=docker
export DOCKER_HOST="${DOCKER_HOST:-}"

# Output path inside the staging dir.
OUT_ZIP="${LAYER_DIR}/layer.zip"
rm -f "${OUT_ZIP}"

# Run the buildspec analog inside the SAM container. We mount STAGING_DIR
# directly so the script can read/write under /var/staging.
"${DOCKER_CLI}" run --rm \
  --platform "${DOCKER_PLATFORM}" \
  --user "$(id -u):$(id -g)" \
  -v "${STAGING_DIR}:/var/staging" \
  -w /var/staging \
  -e LAYER_NAME="${LAYER_NAME}" \
  -e IDP_COMMON_EXTRAS="${IDP_COMMON_EXTRAS}" \
  --entrypoint /bin/bash \
  "${SAM_IMAGE}" \
  -c '
    set -euo pipefail

    REQ_DIR="/var/staging/requirements/${LAYER_NAME}"
    OUT_LAYER="/tmp/${LAYER_NAME}"
    rm -rf "${OUT_LAYER}"
    mkdir -p "${OUT_LAYER}/python"

    # Packages already provided by the Lambda Python 3.12 runtime --
    # mirrors the CodeBuild buildspec.
    RUNTIME_PROVIDED_PACKAGES="boto3 botocore s3transfer awscli urllib3 jmespath python_dateutil dateutil"

    if [ "${LAYER_NAME}" = "idp-common" ]; then
      echo "building idp-common layer (extras=${IDP_COMMON_EXTRAS})"
      if [ ! -d "${REQ_DIR}/idp_common_pkg" ]; then
        echo "ERROR: idp_common_pkg directory missing at ${REQ_DIR}/idp_common_pkg" >&2
        exit 1
      fi

      cd "${REQ_DIR}"

      if [ -s requirements.txt ]; then
        pip install -r requirements.txt -t "${OUT_LAYER}/python" --no-cache-dir
      fi

      if [ -n "${IDP_COMMON_EXTRAS}" ]; then
        pip install -e "./idp_common_pkg[${IDP_COMMON_EXTRAS}]" -t "${OUT_LAYER}/python" --no-cache-dir
      else
        pip install -e "./idp_common_pkg" -t "${OUT_LAYER}/python" --no-cache-dir
      fi

      # Copy idp_common source to ensure runtime can import it even when
      # the editable-install link cannot reach back to the source tree.
      mkdir -p "${OUT_LAYER}/python/idp_common"
      cp -a "./idp_common_pkg/idp_common/." "${OUT_LAYER}/python/idp_common/"
    else
      echo "building plain layer ${LAYER_NAME}"
      if [ -s "${REQ_DIR}/requirements.txt" ]; then
        pip install -r "${REQ_DIR}/requirements.txt" -t "${OUT_LAYER}/python" --no-cache-dir
      else
        touch "${OUT_LAYER}/python/__init__.py"
      fi
    fi

    # Trim runtime-provided packages.
    for pkg in $RUNTIME_PROVIDED_PACKAGES; do
      rm -rf "${OUT_LAYER}/python/$pkg" 2>/dev/null || true
      find "${OUT_LAYER}/python" -maxdepth 1 -type d \
        \( -name "${pkg}-*" -o -name "${pkg//-/_}-*" \) \
        -exec rm -rf {} + 2>/dev/null || true
    done

    # Generic build-artifact trim.
    find "${OUT_LAYER}/python" -type d -name "*.dist-info" -exec rm -rf {} + 2>/dev/null || true
    find "${OUT_LAYER}/python" -type d -name "*.egg-info"  -exec rm -rf {} + 2>/dev/null || true
    find "${OUT_LAYER}/python" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
    find "${OUT_LAYER}/python" -type d -name "build"       -exec rm -rf {} + 2>/dev/null || true
    find "${OUT_LAYER}/python" -type d -name "tests"       -exec rm -rf {} + 2>/dev/null || true
    find "${OUT_LAYER}/python" -type f -name "__editable__*" -exec rm -rf {} + 2>/dev/null || true
    find "${OUT_LAYER}/python" -type f -name "*.pyc"       -delete 2>/dev/null || true
    find "${OUT_LAYER}/python" -type f -name "*.pyo"       -delete 2>/dev/null || true

    echo "Post-cleanup size for ${LAYER_NAME}:"
    du -sh "${OUT_LAYER}/python" || true

    cd "${OUT_LAYER}"
    zip -r "${REQ_DIR}/layer.zip" python/ >/dev/null
  '

if [ ! -f "${OUT_ZIP}" ]; then
  echo "build-idp-layer: BUILD FAILED -- ${OUT_ZIP} not produced" >&2
  exit 2
fi

echo "build-idp-layer [${LAYER_NAME}]: emitted ${OUT_ZIP} ($(stat -f%z "${OUT_ZIP}" 2>/dev/null || stat -c%s "${OUT_ZIP}") bytes)"

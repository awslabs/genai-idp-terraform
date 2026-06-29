#!/usr/bin/env bash
# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Build a single Lambda layer zip inside an AWS SAM build container.
#
# Invoked by modules/lambda-layer-local-build/main.tf's null_resource.
# Inputs (all via env):
#   LAYER_NAME       logical layer name (used only for log lines)
#   STAGING_DIR      absolute path; contains requirements.txt; layer.zip
#                    will be written here on success
#   SAM_IMAGE        full SAM image tag (e.g. public.ecr.aws/sam/build-python3.12:latest-x86_64)
#   DOCKER_PLATFORM  docker --platform value (linux/amd64 | linux/arm64)
#   DOCKER_HOST      optional; passed through to docker CLI

set -euo pipefail

: "${LAYER_NAME:?LAYER_NAME is required}"
: "${STAGING_DIR:?STAGING_DIR is required}"
: "${SAM_IMAGE:?SAM_IMAGE is required}"
: "${DOCKER_PLATFORM:?DOCKER_PLATFORM is required}"

if [ ! -f "${STAGING_DIR}/requirements.txt" ]; then
  echo "build-layer: requirements.txt missing at ${STAGING_DIR}/requirements.txt" >&2
  exit 1
fi

# Pick the docker CLI honoring DOCKER_HOST if set.
DOCKER_CLI=docker
export DOCKER_HOST="${DOCKER_HOST:-}"

# Strip local-path refs (./...), inline comments, and blank lines, matching
# the existing CodeBuild buildspec's behavior so the layer contents are
# bit-equivalent across modes.
CLEAN_REQ="${STAGING_DIR}/requirements.clean.txt"
sed 's/#.*//' "${STAGING_DIR}/requirements.txt" \
  | grep -v '^\s*\.' \
  | grep -v '^\s*$' \
  > "${CLEAN_REQ}" || true

echo "build-layer [${LAYER_NAME}]: installable requirements:"
cat "${CLEAN_REQ}" || true

# Empty after cleanup -> still emit a minimal layer (so the s3_object
# upload has something to point at), mirroring the buildspec.
if [ ! -s "${CLEAN_REQ}" ]; then
  echo "build-layer [${LAYER_NAME}]: no installable requirements, creating minimal layer"
  rm -rf "${STAGING_DIR}/python"
  mkdir -p "${STAGING_DIR}/python"
  touch "${STAGING_DIR}/python/__init__.py"
  ( cd "${STAGING_DIR}" && zip -r "layer.zip" "python/" >/dev/null )
  echo "build-layer [${LAYER_NAME}]: emitted ${STAGING_DIR}/layer.zip"
  exit 0
fi

# Real build path. Mount the staging dir into the SAM container and run pip
# install + zip there. Using `--user "$(id -u):$(id -g)"` makes the output
# files owned by the host user, not root.
"${DOCKER_CLI}" run --rm \
  --platform "${DOCKER_PLATFORM}" \
  --user "$(id -u):$(id -g)" \
  -v "${STAGING_DIR}:/var/layer" \
  -w /var/layer \
  --entrypoint /bin/bash \
  "${SAM_IMAGE}" \
  -c '
    set -euo pipefail
    rm -rf /var/layer/python /var/layer/lib /var/layer/layer.zip
    mkdir -p /var/layer/python

    # Pillow needs system libs in the layer if it is in the requirements
    # (mirrors the CodeBuild buildspec). The SAM image already ships
    # libjpeg/libpng/zlib runtime libs; copy them into lib/ so Lambda finds
    # them at /opt/lib without needing yum-installed packages at runtime.
    if grep -q -i "pillow\|PIL" /var/layer/requirements.clean.txt; then
      mkdir -p /var/layer/lib
      for so in /usr/lib64/libjpeg.so* /usr/lib64/libpng.so* \
                /usr/lib64/libz.so* /usr/lib64/libtiff.so* \
                /usr/lib64/libfreetype.so* /usr/lib64/liblcms2.so* \
                /usr/lib64/libwebp.so* ; do
        if [ -e "$so" ]; then cp -P "$so" /var/layer/lib/ || true; fi
      done
    fi

    pip install --no-cache-dir -r /var/layer/requirements.clean.txt -t /var/layer/python

    # Trim test/cache cruft that bloats layer size but is never imported.
    find /var/layer/python -type d -name "__pycache__" -prune -exec rm -rf {} + 2>/dev/null || true
    find /var/layer/python -type d -name "tests" -prune -exec rm -rf {} + 2>/dev/null || true

    # Zip with relative paths so /opt/python is the import root inside Lambda.
    cd /var/layer
    if [ -d lib ]; then
      zip -r layer.zip python/ lib/ >/dev/null
    else
      zip -r layer.zip python/ >/dev/null
    fi
  '

if [ ! -f "${STAGING_DIR}/layer.zip" ]; then
  echo "build-layer [${LAYER_NAME}]: BUILD FAILED -- layer.zip not produced" >&2
  exit 2
fi

echo "build-layer [${LAYER_NAME}]: emitted ${STAGING_DIR}/layer.zip ($(stat -f%z "${STAGING_DIR}/layer.zip" 2>/dev/null || stat -c%s "${STAGING_DIR}/layer.zip") bytes)"

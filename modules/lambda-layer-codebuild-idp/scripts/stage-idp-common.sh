#!/usr/bin/env bash
# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Stage the idp_common source tree into the module build directory. Both build
# paths consume the result: the CodeBuild path zips it and uploads it, the
# local-build path mounts it into the SAM container.
#
# The copy is an rsync --delete mirror with development artifacts excluded, so
# the staged tree contains only what the layer build needs and re-running is
# idempotent.
#
# Inputs (all via env):
#   IDP_COMMON_SOURCE_PATH  directory holding the idp_common package source
#                           (the directory containing idp_common/, setup.py and
#                           pyproject.toml)
#   STAGING_DEST            directory to mirror that source into; created if
#                           absent
#
# Both values are read from the environment rather than being interpolated into
# a command string, so their contents are never parsed by a shell and paths
# containing spaces work correctly.

set -euo pipefail

: "${IDP_COMMON_SOURCE_PATH:?IDP_COMMON_SOURCE_PATH is required}"
: "${STAGING_DEST:?STAGING_DEST is required}"

mkdir -p "${STAGING_DEST}"

if [ ! -d "${IDP_COMMON_SOURCE_PATH}" ]; then
  echo "ERROR: idp_common_source_path not found: ${IDP_COMMON_SOURCE_PATH}" >&2
  exit 1
fi

rsync -a --delete \
  --exclude='__pycache__/' \
  --exclude='*.py[cod]' \
  --exclude='*$py.class' \
  --exclude='*.so' \
  --exclude='.pytest_cache/' \
  --exclude='.mypy_cache/' \
  --exclude='.ruff_cache/' \
  --exclude='.tox/' \
  --exclude='.venv/' \
  --exclude='venv/' \
  --exclude='env/' \
  --exclude='ENV/' \
  --exclude='build/' \
  --exclude='dist/' \
  --exclude='develop-eggs/' \
  --exclude='downloads/' \
  --exclude='eggs/' \
  --exclude='.eggs/' \
  --exclude='sdist/' \
  --exclude='wheels/' \
  --exclude='var/' \
  --exclude='parts/' \
  --exclude='*.egg-info/' \
  --exclude='*.egg' \
  --exclude='.installed.cfg' \
  --exclude='tests/' \
  --exclude='.coverage' \
  --exclude='coverage.xml' \
  --exclude='coverage/' \
  --exclude='coverage_html/' \
  --exclude='htmlcov/' \
  --exclude='nosetests.xml' \
  --exclude='test-results.xml' \
  --exclude='test-reports/' \
  --exclude='uv.lock' \
  --exclude='poetry.lock' \
  --exclude='.git/' \
  --exclude='.gitignore' \
  --exclude='.gitattributes' \
  --exclude='.idea/' \
  --exclude='.vscode/' \
  --exclude='*.swp' \
  --exclude='*.swo' \
  --exclude='.DS_Store' \
  --exclude='Thumbs.db' \
  --exclude='node_modules/' \
  --exclude='clean_build.sh' \
  --exclude='verify_stickler.py' \
  "${IDP_COMMON_SOURCE_PATH}/" "${STAGING_DEST}/"

echo "Staged idp_common source at ${STAGING_DEST}:"
du -sh "${STAGING_DEST}" || true

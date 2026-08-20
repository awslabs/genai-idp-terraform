#!/usr/bin/env bash
# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Stage + zip the chat token-streaming (ChatStreamProcessor) Lambda package.
#
# Mirrors the NON-pip part of the upstream
# sources/src/lambda/chat_stream_processor/Makefile
# (build-ChatStreamProcessorFunction target): it copies app.py, sse.py and
# run.sh to the archive root, flattens the two vendored processor modules to the
# archive root (so they import as top-level `chat_with_document_processor` /
# `agent_chat_processor`), and zips the result. Python dependencies
# (fastapi/uvicorn/boto3) are NOT installed here — they ship in the attached
# deps layer (run.sh puts /opt/python on PYTHONPATH), so this package carries
# first-party code only.
#
# Invoked by chat-stream.tf's null_resource. Inputs (all via env):
#   SRC_DIR    absolute path to sources/src/lambda/chat_stream_processor
#   BUILD_DIR  absolute path to a scratch staging dir (recreated each run)
#   ZIP_OUT    absolute path of the zip to produce

set -euo pipefail

: "${SRC_DIR:?SRC_DIR is required}"
: "${BUILD_DIR:?BUILD_DIR is required}"
: "${ZIP_OUT:?ZIP_OUT is required}"

for f in app.py sse.py run.sh vendored/chat_with_document_processor.py vendored/agent_chat_processor.py; do
  if [ ! -f "${SRC_DIR}/${f}" ]; then
    echo "build-chat-stream-package: missing required source ${SRC_DIR}/${f}" >&2
    exit 1
  fi
done

# Clean + recreate the staging dir and the zip's parent.
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"
mkdir -p "$(dirname "${ZIP_OUT}")"
rm -f "${ZIP_OUT}"

# App entry points at the archive root.
cp "${SRC_DIR}/app.py" "${BUILD_DIR}/app.py"
cp "${SRC_DIR}/sse.py" "${BUILD_DIR}/sse.py"
cp "${SRC_DIR}/run.sh" "${BUILD_DIR}/run.sh"
chmod +x "${BUILD_DIR}/run.sh"

# Vendored processor sources, flattened to importable top-level module names.
cp "${SRC_DIR}/vendored/chat_with_document_processor.py" "${BUILD_DIR}/chat_with_document_processor.py"
cp "${SRC_DIR}/vendored/agent_chat_processor.py" "${BUILD_DIR}/agent_chat_processor.py"

# Deterministic zip from inside the build dir (paths relative to the archive
# root). Use Python's zipfile so we don't depend on the `zip` binary being on
# PATH, matching the agent_chat_processor build's approach.
python3 -c "
import os
import zipfile

build_dir = os.environ['BUILD_DIR']
zip_out = os.environ['ZIP_OUT']

with zipfile.ZipFile(zip_out, 'w', zipfile.ZIP_DEFLATED) as zf:
    for root, _dirs, files in os.walk(build_dir):
        for name in sorted(files):
            if name.endswith('.pyc'):
                continue
            filepath = os.path.join(root, name)
            arcname = os.path.relpath(filepath, build_dir)
            zf.write(filepath, arcname)
print('chat-stream package created: %s' % zip_out)
"

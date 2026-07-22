#!/usr/bin/env bash
# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# detect-node-runtime.sh
#
# Probes the host for Node.js and validates the version is >= 18. Prints a
# single-line JSON object on stdout that Terraform's `data "external"` can
# consume:
#
#   {"available": "true|false", "version": "<semver or empty>"}
#
# "available" is "true" only if node is found AND the major version is >= 18.
# "version" is the detected semver string (e.g. "22.14.0"), or empty if node
# is missing or unusable.
#
# Exit code is ALWAYS 0; detection failure is signaled via the JSON payload
# so Terraform can render a clean `check {}` error.

set -u

# Minimum required Node.js major version.
MIN_MAJOR=18

emit() {
  printf '{"available":"%s","version":"%s"}' "$1" "$2"
}

# Check if node is on PATH.
if ! command -v node >/dev/null 2>&1; then
  emit "false" ""
  exit 0
fi

# Get version string (e.g. "v22.14.0").
raw_version=$(node --version 2>/dev/null || true)

if [ -z "$raw_version" ]; then
  emit "false" ""
  exit 0
fi

# Strip leading 'v' and extract semver.
version="${raw_version#v}"

# Extract major version number.
major=$(echo "$version" | cut -d. -f1)

# Validate it's a number and >= MIN_MAJOR.
if [ -z "$major" ] || ! [ "$major" -eq "$major" ] 2>/dev/null; then
  emit "false" "$version"
  exit 0
fi

if [ "$major" -ge "$MIN_MAJOR" ]; then
  emit "true" "$version"
else
  emit "false" "$version"
fi

exit 0

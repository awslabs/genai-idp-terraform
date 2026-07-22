#!/usr/bin/env bash
# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Unit test for scripts/detect-node-runtime.sh.
#
# Runs the script with a mocked PATH containing fake node binaries to exercise
# each detection branch. Asserts the emitted JSON matches the expected output.
# Exits non-zero on first failure.
#
# Usage:
#   tests/validate-web-ui-build-check.sh
#
# This test does NOT require a real Node.js install. It uses tiny shell stubs
# to simulate node presence/absence and version outputs.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="${REPO_ROOT}/scripts/detect-node-runtime.sh"

if [ ! -x "$SCRIPT" ]; then
  echo "FAIL: $SCRIPT is not executable"
  exit 1
fi

# Workspace for stubs.
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

STUBS="${TMP}/stubs"
mkdir -p "$STUBS"

# Helper: create a node stub that outputs a specific version.
make_node_stub() {
  local version="$1"
  cat > "${STUBS}/node" <<EOF
#!/usr/bin/env bash
if [ "\${1:-}" = "--version" ]; then
  echo "${version}"
  exit 0
fi
exit 0
EOF
  chmod +x "${STUBS}/node"
}

# Helper: create a broken node stub.
make_broken_node_stub() {
  cat > "${STUBS}/node" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
  chmod +x "${STUBS}/node"
}

# Run the detect script with a sanitized PATH so only stubs are visible.
run_detect() {
  PATH="${STUBS}:/usr/bin:/bin" bash "$SCRIPT"
}

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" != "$actual" ]; then
    echo "FAIL [${label}]: expected '${expected}', got '${actual}'"
    exit 1
  fi
  echo "PASS [${label}]"
}

# ----------------------------------------------------------------------------
# Case 1: node not installed -> {"available":"false","version":""}

rm -rf "${STUBS}" && mkdir -p "${STUBS}"
out=$(run_detect)
assert_eq "no-node" '{"available":"false","version":""}' "$out"

# ----------------------------------------------------------------------------
# Case 2: node 22.14.0 (>= 18) -> available

rm -rf "${STUBS}" && mkdir -p "${STUBS}"
make_node_stub "v22.14.0"
out=$(run_detect)
assert_eq "node-22" '{"available":"true","version":"22.14.0"}' "$out"

# ----------------------------------------------------------------------------
# Case 3: node 18.0.0 (boundary) -> available

rm -rf "${STUBS}" && mkdir -p "${STUBS}"
make_node_stub "v18.0.0"
out=$(run_detect)
assert_eq "node-18-boundary" '{"available":"true","version":"18.0.0"}' "$out"

# ----------------------------------------------------------------------------
# Case 4: node 16.20.2 (< 18) -> not available but version reported

rm -rf "${STUBS}" && mkdir -p "${STUBS}"
make_node_stub "v16.20.2"
out=$(run_detect)
assert_eq "node-16-too-old" '{"available":"false","version":"16.20.2"}' "$out"

# ----------------------------------------------------------------------------
# Case 5: node present but broken (exits non-zero) -> not available

rm -rf "${STUBS}" && mkdir -p "${STUBS}"
make_broken_node_stub
out=$(run_detect)
assert_eq "node-broken" '{"available":"false","version":""}' "$out"

# ----------------------------------------------------------------------------
# Case 6: node 20.11.1 (>= 18) -> available

rm -rf "${STUBS}" && mkdir -p "${STUBS}"
make_node_stub "v20.11.1"
out=$(run_detect)
assert_eq "node-20" '{"available":"true","version":"20.11.1"}' "$out"

echo
echo "All Node.js-detection tests passed."

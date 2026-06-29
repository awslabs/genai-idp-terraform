#!/usr/bin/env bash
# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Unit test for scripts/detect-container-runtime.sh.
#
# Runs the script with a mocked PATH containing fake docker/podman/finch
# binaries to exercise each detection branch. Asserts the emitted JSON
# matches the expected runtime + docker_host pair. Exits non-zero on first
# failure.
#
# Usage:
#   tests/validate-build-runtime-check.sh
#
# This test does NOT require a real container runtime. It uses tiny shell
# stubs to simulate runtime presence/absence and to fake socket files via
# `mktemp`.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="${REPO_ROOT}/scripts/detect-container-runtime.sh"

if [ ! -x "$SCRIPT" ]; then
  echo "FAIL: $SCRIPT is not executable"
  exit 1
fi

# Workspace for stubs.
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

STUBS="${TMP}/stubs"
mkdir -p "$STUBS"

# Helper: register a stub for a binary that pretends to succeed with a
# scripted stdout. The first arg is the binary name, the remainder is the
# `case "$1"` body, e.g.:
#   make_stub docker '
#     info) exit 0 ;;
#     *) echo unsupported; exit 2 ;;
#   '
make_stub() {
  local name="$1"
  local body="$2"
  cat > "${STUBS}/${name}" <<EOF
#!/usr/bin/env bash
case "\$1" in
${body}
*) exit 0 ;;
esac
EOF
  chmod +x "${STUBS}/${name}"
}

# Helper: register a stub that always exits non-zero (i.e. "binary absent"
# is modeled by simply NOT registering the stub; this helper models
# "binary present but broken").
make_broken_stub() {
  local name="$1"
  cat > "${STUBS}/${name}" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
  chmod +x "${STUBS}/${name}"
}

# Run the detect script with a sanitized PATH so only stubs are visible.
# Always keep /usr/bin and /bin so basic utilities (id, mktemp) still work.
run_detect() {
  local override="$1"
  PATH="${STUBS}:/usr/bin:/bin" \
    RUNTIME_OVERRIDE="$override" \
    bash "$SCRIPT"
}

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" != "$actual" ]; then
    echo "FAIL [${label}]: expected ${expected!r:-${expected}}, got ${actual!r:-${actual}}"
    return 1
  fi
  echo "PASS [${label}]"
}

# ----------------------------------------------------------------------------
# Case 1: nothing installed -> {"runtime":"none","docker_host":""}

rm -rf "${STUBS}" && mkdir -p "${STUBS}"
out=$(run_detect auto)
assert_eq "auto-none" '{"runtime":"none","docker_host":""}' "$out"

# ----------------------------------------------------------------------------
# Case 2: docker present and `docker info` succeeds -> docker selected.

make_stub docker '  info) exit 0 ;;'
out=$(run_detect auto)
assert_eq "auto-docker" '{"runtime":"docker","docker_host":""}' "$out"

# ----------------------------------------------------------------------------
# Case 3: docker present but `docker info` fails (daemon down), no fallback
# binaries -> none.

rm -rf "${STUBS}" && mkdir -p "${STUBS}"
make_stub docker '  info) exit 1 ;;'
out=$(run_detect auto)
assert_eq "auto-docker-down" '{"runtime":"none","docker_host":""}' "$out"

# ----------------------------------------------------------------------------
# Case 4: explicit RUNTIME_OVERRIDE=docker with no docker -> none (no fallback).

rm -rf "${STUBS}" && mkdir -p "${STUBS}"
make_stub podman '  info) exit 0 ;;'
out=$(run_detect docker)
assert_eq "explicit-docker-missing" '{"runtime":"none","docker_host":""}' "$out"

# ----------------------------------------------------------------------------
# Case 5: unknown override -> none.

out=$(run_detect bogus)
assert_eq "unknown-override" '{"runtime":"none","docker_host":""}' "$out"

# ----------------------------------------------------------------------------
# Case 6: podman with a working socket.
# Create a fake unix socket file and have the podman stub report its path.

PODMAN_SOCK="${TMP}/podman.sock"
# Create a fake unix socket. On macOS `mknod` can't create sockets without
# root, so use Python instead.
python3 -c "import socket; s=socket.socket(socket.AF_UNIX); s.bind('${PODMAN_SOCK}')" 2>/dev/null || {
  # If python3 isn't available, fall back to a regular file. The script
  # checks for -S (socket), so this path will fail; we mark it skipped.
  echo "SKIP [auto-podman]: cannot create fake unix socket without python3"
  PODMAN_SOCK=""
}

if [ -n "$PODMAN_SOCK" ] && [ -S "$PODMAN_SOCK" ]; then
  rm -rf "${STUBS}" && mkdir -p "${STUBS}"
  cat > "${STUBS}/podman" <<EOF
#!/usr/bin/env bash
case "\$1" in
  info)
    if [ "\$2" = "--format" ]; then
      echo "${PODMAN_SOCK}"
    fi
    exit 0
    ;;
  *) exit 0 ;;
esac
EOF
  chmod +x "${STUBS}/podman"

  out=$(run_detect podman)
  assert_eq "explicit-podman" "{\"runtime\":\"podman\",\"docker_host\":\"unix://${PODMAN_SOCK}\"}" "$out"
fi

echo
echo "All container-runtime-detection tests passed."

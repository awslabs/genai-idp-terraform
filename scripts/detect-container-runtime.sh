#!/usr/bin/env bash
# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# detect-container-runtime.sh
#
# Probes the host for an available container runtime in the order docker ->
# podman -> finch (or honors a single explicit RUNTIME_OVERRIDE), and prints a
# single-line JSON object on stdout that Terraform's `data "external"` can
# consume:
#
#   {"runtime": "docker|podman|finch|none", "docker_host": "<value or empty>"}
#
# "runtime" is the selected runtime, "none" if nothing usable was found.
# "docker_host" is the value to set as DOCKER_HOST on the kreuzwerker/docker
# provider. Empty string means "use the provider's built-in default" (which is
# the platform's default Docker socket). Non-empty values are unix:// or
# tcp:// URIs.
#
# Inputs (all via env vars; `data "external"` always passes the `query` map as
# env):
#   RUNTIME_OVERRIDE: one of "auto" (default), "docker", "podman", "finch".
#                    Any value other than "auto" disables fallback and only
#                    probes that one runtime.
#
# Exit code is ALWAYS 0 unless the script itself is malformed; runtime
# detection failure is signaled via `{"runtime":"none",...}` in the JSON
# payload so Terraform can render a clean `check {}` error.

set -u

# Note: we deliberately do NOT use `set -e`. A failed probe (e.g. docker is
# installed but the daemon isn't running) is a normal result, not an error.

# ----------------------------------------------------------------------------
# Helpers

emit() {
  # Emit single-line JSON. No trailing newline so Terraform reads it cleanly.
  printf '{"runtime":"%s","docker_host":"%s"}' "$1" "$2"
}

# Probe docker. Considers docker "available" only if both the CLI exists AND
# the daemon responds to `docker info`. Returns 0 if available, non-zero
# otherwise.
probe_docker() {
  command -v docker >/dev/null 2>&1 || return 1
  docker info >/dev/null 2>&1 || return 1
  return 0
}

# Probe podman. Considers podman "available" if `podman info` succeeds AND a
# Docker-compatible socket is reachable (the kreuzwerker/docker provider
# speaks the Docker API, so it needs `podman system service` or rootful
# socket).
probe_podman() {
  command -v podman >/dev/null 2>&1 || return 1
  podman info >/dev/null 2>&1 || return 1

  # Determine the socket location. `podman info --format '{{.Host.RemoteSocket.Path}}'`
  # works on modern podman; fall back to the user-default path on older
  # versions. The socket file must exist for the provider to use it.
  local sock
  sock=$(podman info --format '{{.Host.RemoteSocket.Path}}' 2>/dev/null || true)
  if [ -z "$sock" ] || [ ! -S "$sock" ]; then
    # Try the conventional rootless path.
    local uid
    uid=$(id -u)
    if [ -S "/run/user/${uid}/podman/podman.sock" ]; then
      sock="/run/user/${uid}/podman/podman.sock"
    elif [ -S "/run/podman/podman.sock" ]; then
      sock="/run/podman/podman.sock"
    else
      return 1
    fi
  fi

  PODMAN_SOCK="$sock"
  return 0
}

# Probe finch. Considers finch "available" if the VM is initialized AND
# running. The kreuzwerker/docker provider can talk to finch via its
# Docker-compatible socket.
probe_finch() {
  command -v finch >/dev/null 2>&1 || return 1

  # `finch vm status` exits 0 with "Running" on stdout when ready. Other
  # states (Stopped, Nonexistent) print non-Running and we treat them as
  # unavailable -- the user is expected to `finch vm init && finch vm start`.
  local status
  status=$(finch vm status 2>/dev/null || true)
  case "$status" in
    *Running*) ;;
    *) return 1 ;;
  esac

  # Finch exposes its docker socket under the limactl directory. The exact
  # path is OS-dependent but `finch info` includes it. As a fallback, the
  # conventional path on macOS is:
  #   ~/.finch/finch.sock
  local sock="${HOME}/.finch/finch.sock"
  if [ ! -S "$sock" ]; then
    return 1
  fi

  FINCH_SOCK="$sock"
  return 0
}

# ----------------------------------------------------------------------------
# Main

# `data "external"` reads its `query` map into env vars. Default to auto if
# unset or empty.
override="${RUNTIME_OVERRIDE:-auto}"

case "$override" in
  docker)
    probe_docker && { emit "docker" ""; exit 0; }
    emit "none" ""
    exit 0
    ;;
  podman)
    probe_podman && { emit "podman" "unix://${PODMAN_SOCK}"; exit 0; }
    emit "none" ""
    exit 0
    ;;
  finch)
    probe_finch && { emit "finch" "unix://${FINCH_SOCK}"; exit 0; }
    emit "none" ""
    exit 0
    ;;
  auto|"")
    # Probe in priority order. First hit wins.
    probe_docker && { emit "docker" ""; exit 0; }
    probe_podman && { emit "podman" "unix://${PODMAN_SOCK}"; exit 0; }
    probe_finch  && { emit "finch"  "unix://${FINCH_SOCK}";  exit 0; }
    emit "none" ""
    exit 0
    ;;
  *)
    # Unknown override -- this is a Terraform-side validation failure, but
    # surface it cleanly anyway.
    emit "none" ""
    exit 0
    ;;
esac

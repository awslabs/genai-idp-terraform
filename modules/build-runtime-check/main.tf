# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Build-runtime detection helper.
#
# Invokes scripts/detect-container-runtime.sh via `data "external"` and
# surfaces the result. When var.lambda_local is true the check {} block
# enforces that a usable runtime exists; otherwise the probe is purely
# informational.

locals {
  # Allow override; default to the repository-relative path. Using path.root
  # so a downstream `examples/foo/` consumer still finds the script in the
  # submodule.
  script_path = var.script_path != "" ? var.script_path : "${path.module}/../../scripts/detect-container-runtime.sh"
}

# Probe the host. `data "external"` runs the program on every refresh, which
# is what we want -- the answer depends on what daemons happen to be running
# at plan time.
data "external" "probe" {
  program = ["bash", local.script_path]

  query = {
    RUNTIME_OVERRIDE = var.container_runtime
  }
}

# Gate plan/apply on a usable runtime, but only when the caller actually
# opted into local builds. The lambda_local = false case must keep
# `data.external.probe` resolvable but non-fatal -- the docker provider is
# never configured, so a "none" result is harmless.
check "container_runtime_available" {
  assert {
    condition     = !var.lambda_local || data.external.probe.result.runtime != "none"
    error_message = <<-EOT
      No usable container runtime detected on the deploy host. With
      build.lambda_local = true the wrapper needs Docker, Podman, or Finch
      to build Lambda layer zips and processor container images locally.

      Install one of:

        macOS:
          Docker Desktop:  https://docs.docker.com/desktop/install/mac-install/
          Podman:          brew install podman && podman machine init && podman machine start
          Finch:           brew install --cask finch && finch vm init && finch vm start

        Linux:
          Docker Engine:   https://docs.docker.com/engine/install/
          Podman:          dnf install -y podman   # or apt install -y podman
                           systemctl --user enable --now podman.socket

        Windows:
          Docker Desktop:  https://docs.docker.com/desktop/install/windows-install/
          Podman Desktop:  https://podman-desktop.io/downloads
          Finch:           https://runfinch.com (preview)

      Then re-run `terraform plan`.

      Alternatively, set build.lambda_local = false to fall back to AWS
      CodeBuild, which builds artifacts in-cloud and has no host runtime
      requirement.
    EOT
  }
}

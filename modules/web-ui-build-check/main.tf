# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
/**
 * # Web UI Build Check Module
 *
 * Node.js detection helper for the local web UI build path.
 *
 * Invokes `scripts/detect-node-runtime.sh` via `data "external"` and surfaces
 * the result. When `var.ui_local` is true the `check {}` block enforces that
 * Node.js >= 18 is available on the deploy host; otherwise the probe is purely
 * informational.
 */

locals {
  script_path = var.script_path != "" ? var.script_path : "${path.module}/../../scripts/detect-node-runtime.sh"
}

# Probe the host for Node.js. Runs on every refresh (plan-time detection).
data "external" "probe" {
  program = ["bash", local.script_path]
}

# Gate plan/apply on a usable Node.js, but only when ui_local = true.
check "node_runtime_available" {
  assert {
    condition     = !var.ui_local || data.external.probe.result.available == "true"
    error_message = <<-EOT
      Node.js >= 18 not detected on the deploy host. With build.ui_local = true
      the wrapper needs Node.js and npm to run `npm ci && npm run build` for the
      web UI locally.

      Install Node.js (>= 18) using one of:

        macOS:
          nvm:   curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash && nvm install 22
          fnm:   brew install fnm && fnm install 22
          brew:  brew install node@22

        Linux:
          nvm:   curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash && nvm install 22
          fnm:   curl -fsSL https://fnm.vercel.app/install | bash && fnm install 22
          apt:   curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - && sudo apt-get install -y nodejs

        Windows:
          nvm-windows:  https://github.com/coreybutler/nvm-windows/releases
          fnm:          winget install Schniz.fnm && fnm install 22

      Then re-run `terraform plan`.

      Alternatively, set build.ui_local = false to use the default AWS CodeBuild
      path, which builds the UI in-cloud with no host Node.js requirement.
    EOT
  }
}

# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# State-migration blocks for the v0.6.4 upgrade.
#
# Upstream IDP v0.6.0 deleted ALB Web UI hosting (`WebUIHosting=ALB` and the
# `nested/alb-hosting/` stack), so `modules/web-ui-alb/` and the root resources
# that wired it are gone from this release. Deleting a module from the
# configuration normally lets Terraform plan the destroy from the module source
# — but the source directory no longer exists, so a deployment upgrading
# straight to this version has state entries Terraform cannot plan against.
#
# These `removed` blocks close that gap: they tell Terraform the addresses have
# left the configuration and that the real infrastructure should be
# DECOMMISSIONED (`destroy = true`), without needing the deleted module source.
#
# Inert for every deployment that never set `web_ui.hosting = "ALB"` — with no
# matching state entries these blocks produce no plan changes.
#
# To KEEP the load balancer instead of destroying it (retire it on your own
# schedule, or reuse it), change `destroy = true` to `destroy = false` here
# before planning: Terraform then drops the resources from state and leaves the
# infrastructure in place, unmanaged.
#
# Requires Terraform >= 1.7 (the `lifecycle` argument inside `removed`); see the
# floor bump in versions.tf and docs/migration-v0.5.16-to-v0.6.4.md.

removed {
  from = module.web_ui_alb

  lifecycle {
    destroy = true
  }
}

removed {
  from = aws_s3_bucket_policy.web_ui_alb

  lifecycle {
    destroy = true
  }
}

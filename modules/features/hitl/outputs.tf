# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
output "contract" {
  description = <<-EOT
    Feature-plugin contract consumed by `processing-environment-api` via its
    `enabled_feature_contracts` input. Mirrors the CDK `api.enable(feature)`
    mechanism: resolver definitions, IAM statement fragments, and environment
    wiring for the inline-HITL `complete_section_review` operations.
  EOT
  value = {
    enabled          = true
    resolvers        = local.hitl_resolvers
    iam_statements   = local.hitl_iam_statements
    environment      = local.hitl_environment
    schema_additions = null
  }
}

# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Outputs for the IdP-federation submodule.
#
# Surfaces the additive user-pool-client supported-identity-providers
# contribution and the feature-plugin `contract` (always emitted). Federation-
# specific wiring the API module / pool owner needs (the group-mapping trigger
# ARN and the identity-provider contribution) is surfaced through dedicated
# outputs rather than stuffed into the core contract, keeping the contract shape
# byte-identical to the MCP/Chat feature modules.

output "enabled" {
  description = "Whether external IdP federation is effectively enabled."
  value       = var.enabled
}

output "provider_name" {
  description = "Name of the external Cognito identity provider, when federation is enabled."
  value       = var.enabled ? aws_cognito_identity_provider.external[0].provider_name : null
}

# ---------------------------------------------------------------------------
# Group-mapping trigger Lambda.
#
# The Cognito user pool is owned outside this module, so the
# pre-token-generation trigger cannot be attached here. These outputs surface
# the group-mapping Lambda so the pool owner (root/pool module) can wire it as
# the `PreTokenGeneration` (V2_0) trigger on the `aws_cognito_user_pool`
# `lambda_config`. Both are null when group mapping is not provisioned
# (federation disabled or no `group_attribute_name`).
# ---------------------------------------------------------------------------

output "group_mapping_function_arn" {
  description = "ARN of the group-mapping pre-token-generation trigger Lambda, for the pool owner to wire as the user pool's PreTokenGeneration trigger. Null when group mapping is not provisioned."
  value       = local.enable_group_mapping ? aws_lambda_function.group_mapping[0].arn : null
}

output "group_mapping_function_name" {
  description = "Name of the group-mapping trigger Lambda. Null when group mapping is not provisioned."
  value       = local.enable_group_mapping ? aws_lambda_function.group_mapping[0].function_name : null
}

# ---------------------------------------------------------------------------
# Additive user-pool-client contribution.
#
# The user-pool client is owned externally; `aws_cognito_user_pool_client` is a
# full resource, not patchable by id, so this module surfaces the provider name
# to append rather than editing the client in place. The pool/client owner (the
# root) merges this into the client's `supported_identity_providers`, KEEPING
# `COGNITO` so direct-Cognito sign-in continues to work. Empty when federation
# is disabled (the owner appends nothing).
# ---------------------------------------------------------------------------

output "supported_identity_providers_contribution" {
  description = <<-EOT
    Identity-provider names to append to the externally-owned user-pool client's
    `supported_identity_providers` (e.g. `["PingOne"]`), keeping the existing
    `COGNITO` provider intact. Empty when federation is disabled. The root merges
    this with `COGNITO` rather than this module owning the full client resource.
  EOT
  value       = local.supported_identity_providers_contribution
}

# ---------------------------------------------------------------------------
# Feature-plugin contract.
#
# ALWAYS emitted regardless of `var.enabled`, because the outputs-contract is
# the wiring architecture itself, not a conditional behavior. The shape matches
# the other feature modules (MCP / Chat-with-Document) exactly so the root
# `enabled_feature_contracts` merge composes it uniformly:
#
#   { enabled, resolvers, iam_statements, environment, schema_additions }
#
# Federation is self-contained on the API surface: it adds no AppSync resolvers
# (`resolvers = {}`), the group-mapping Lambda owns its own scoped execution role
# and environment (so `iam_statements = []` / `environment = {}`), and it injects
# no GraphQL SDL (`schema_additions = null` — the federation flow is Cognito-side,
# not AppSync-side). The federation-specific wiring the pool owner needs (the
# group-mapping trigger ARN and the supported-identity-providers contribution)
# rides on the dedicated outputs above, keeping the core five contract fields
# identical to the other feature modules.
# ---------------------------------------------------------------------------

output "contract" {
  description = <<-EOT
    Feature-plugin contract consumed by `processing-environment-api` via its
    `enabled_feature_contracts` input (mirrors the CDK `api.enable(feature)`
    mechanism). Always emitted. Federation contributes no
    AppSync resolvers, IAM statements, environment, or schema additions — its
    integration is Cognito-side (identity provider + group-mapping trigger) —
    so the core five fields are empty/null with `enabled` reflecting the toggle.
    Federation-specific handles (group-mapping trigger ARN, identity-provider
    contribution) are surfaced via dedicated outputs.
  EOT
  value = {
    enabled          = var.enabled
    resolvers        = {}
    iam_statements   = []
    environment      = {}
    schema_additions = null
  }
}

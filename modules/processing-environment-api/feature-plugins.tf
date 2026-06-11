# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Feature-plugin composition (Requirement 3 — `.enable()`-style wiring)
#
# Mirrors the CDK accelerator's `api.enable(feature)` mechanism: each enabled
# auxiliary-feature submodule (MCP, Chat-with-Document, HITL, …) emits an
# outputs contract that the root forwards into `var.enabled_feature_contracts`.
# This file composes those contracts into the API — attaching their resolvers,
# merging their IAM statements onto the AppSync Lambda role, and merging their
# environment variables into the core configuration resolver Lambda.
#
# Default-off is preserved: when `var.enabled_feature_contracts` is empty (the
# default), every local below resolves to an empty collection and no feature
# resources are added (`for_each = {}` / `count = 0`).

locals {
  # Empty-map guards: `merge([...]...)` with an empty splat errors, so short
  # circuit to an empty map / list when no feature contracts are enabled.
  feature_resolvers = length(var.enabled_feature_contracts) == 0 ? {} : merge([
    for k, c in var.enabled_feature_contracts : try(c.resolvers, {})
  ]...)

  feature_iam = flatten([
    for k, c in var.enabled_feature_contracts : try(c.iam_statements, [])
  ])

  feature_env = length(var.enabled_feature_contracts) == 0 ? {} : merge([
    for k, c in var.enabled_feature_contracts : try(c.environment, {})
  ]...)
}

# =============================================================================
# Composed feature resolvers
# =============================================================================
# Each entry in `local.feature_resolvers` is keyed by GraphQL field name and
# carries the data source plus request/response mapping templates, mirroring the
# resolver style in resolvers.tf. `type` defaults to "Query" and `field`
# defaults to the map key, so a feature contract only has to specify them when
# they differ. Lambda-backed templates fall back to the module's standard
# Invoke/passthrough VTL when a contract omits them.
resource "aws_appsync_resolver" "feature" {
  for_each = local.feature_resolvers

  api_id      = aws_appsync_graphql_api.api.id
  type        = try(each.value.type, "Query")
  field       = try(each.value.field, each.key)
  data_source = each.value.data_source

  request_template  = try(each.value.request_template, "{\"version\": \"2018-05-29\", \"operation\": \"Invoke\", \"payload\": $util.toJson($context)}")
  response_template = try(each.value.response_template, "$util.toJson($context.result)")
}

# =============================================================================
# Composed feature IAM statements
# =============================================================================
# Feature contracts contribute policy-statement objects that are merged onto the
# AppSync Lambda role (the role AppSync assumes to invoke resolver Lambdas).
# Guarded by count so nothing is created when no feature contributes statements.
resource "aws_iam_role_policy" "feature_contracts" {
  count = length(local.feature_iam) > 0 ? 1 : 0
  name  = "FeatureContractsPolicy-${random_string.suffix.result}"
  role  = aws_iam_role.appsync_lambda_role.id

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = local.feature_iam
  })
}

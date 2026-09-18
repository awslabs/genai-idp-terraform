# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Feature-plugin composition (`.enable()`-style wiring)
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

  feature_data_sources = length(var.enabled_feature_contracts) == 0 ? {} : merge([
    for k, c in var.enabled_feature_contracts : try(c.data_sources, {})
  ]...)

  # REST transport composition (IDP v0.6.4). Each contract publishes
  # `field_functions` = { <api field> => <lambda arn> }; they are merged here and
  # folded into the dispatcher's field-function map (dispatcher.tf), replacing the
  # per-field AppSync resolvers this file used to create.
  #
  # `feature_platform_field_functions` is a separate input rather than a contract
  # because the Feature Platform is wired at the root outside
  # `enabled_feature_contracts`.
  feature_field_functions = merge(
    length(var.enabled_feature_contracts) == 0 ? {} : merge([
      for k, c in var.enabled_feature_contracts : try(c.field_functions, {})
    ]...),
    var.feature_platform_field_functions
  )
}

# Feature-contributed IAM, composed onto the configuration resolver's role.
#
# These statements (today only RBAC's reviewer-filtering Users-table read) used to
# be attached to the shared AppSync Lambda role. That role is gone, and the
# correct successor is the configuration resolver: it is the Lambda that already
# receives the matching `local.feature_env` wiring (see lambda.tf), so the env var
# and the permission to use it stay together. The dispatcher deliberately does NOT
# get these — it never reads USERS_TABLE_NAME; it only needs the invoke grant,
# which dispatcher.tf derives from the field-function map.
#
# Gated on `var.has_feature_iam` rather than on `length(local.feature_iam)`:
# the statements interpolate resource ARNs that are unknown at plan on a fresh
# deploy, so counting them would fail the plan with "Invalid count argument".
resource "aws_iam_role_policy" "feature_contracts" {
  count = var.has_feature_iam ? 1 : 0

  name = "${local.api_name}-feature-contracts"
  role = aws_iam_role.configuration_resolver_role.id

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = local.feature_iam
  })
}

# =============================================================================
# NOTE (v0.6.4 REST migration): The AppSync feature data sources, resolvers, and
# the AppSync-Lambda-role policies (feature_datasource_invoke, feature_contracts)
# were removed. Feature-contract composition into the REST dispatcher transport
# (routing feature fields through the field-function map and granting the
# dispatcher role the invoke + IAM statements) is handled in a later sub-step of
# the migration. `local.feature_env` is still merged into the configuration
# resolver Lambda (see lambda.tf), so feature environment wiring is preserved.
# =============================================================================

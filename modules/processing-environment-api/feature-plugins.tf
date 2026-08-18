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

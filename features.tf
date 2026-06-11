# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Feature-plugin wiring (Requirement 3 — .enable()-style composition)
#
# Auxiliary features (MCP, Chat-with-Document, HITL) are modeled as
# self-contained submodules that each emit an outputs contract which
# `modules/processing-environment-api` composes via `for_each`
# (mirroring the CDK accelerator's `api.enable(feature)` mechanism).
#
# This file owns the ROOT side of that wiring:
#   1. `feature_enable` — forwards the legacy `var.api.*` flags to a per-feature
#      enable decision (deprecation-shim discipline: old flags keep working).
#   2. `module.mcp_integration` / `module.chat_with_document` — the count-gated
#      feature submodules.
#   3. `enabled_feature_contracts` — the map of contracts handed to the API
#      module, a guarded merge that resolves to {} when every feature is off.
#
# Default-off is preserved: a feature is enabled only when its forwarded
# `var.api.*` flag resolves to true. `try(..., false)` guards missing
# attributes so an absent flag never enables a feature.

locals {
  # Forward the legacy `var.api.*` feature flags to a per-feature enable map.
  # Real flag names confirmed against the `var.api` object type in variables.tf:
  #   - MCP  : flat   `var.api.enable_mcp`              (default false)
  #   - chat : nested `var.api.chat_with_document.enabled` (default false)
  #   - HITL : flat   `var.api.enable_hitl`             (default true upstream)
  feature_enable = {
    mcp                = try(var.api.enable_mcp, false)
    chat_with_document = try(var.api.chat_with_document.enabled, false)
    hitl               = try(var.api.enable_hitl, false)
  }
}

# =============================================================================
# MCP integration feature submodule (C5, task 10 — root cutover)
# =============================================================================
# Self-contained AgentCore Gateway MCP stack (renamed `agentcore_mcp_handler`,
# gateway manager/execution roles, CFN gateway, Cognito OAuth client + resource
# server). Owns no AppSync resolvers, so its contract is a composition signal
# only. The old MCP stack that previously lived in
# `modules/processing-environment-api/mcp-integration.tf` is removed in this same
# change; the `moved {}` blocks in moved.tf remap the old API-module addresses
# to this module (0 destroy / 0 create).
#
# GovCloud guard + default-off live inside the submodule; the root only decides
# whether to instantiate it at all (forwarded `var.api.enable_mcp`).
module "mcp_integration" {
  source = "./modules/features/mcp-integration"
  count  = local.feature_enable.mcp ? 1 : 0

  enabled     = true
  name_prefix = "${local.name_prefix}-api"

  # Cognito user pool used by the API/web for the MCP OAuth external app client,
  # resource server, and connector client. Same pool the API module used to read
  # via its `user_pool_id` input (sourced from `local.user_pool_id`).
  user_pool_id = local.user_pool_id

  output_bucket_arn = var.output_bucket_arn

  # Layers — same wiring the API module used for the MCP handler.
  base_layer_arn       = module.processing_environment.base_layer_arn
  idp_common_layer_arn = module.idp_common_layer.layer_arn

  encryption_key_arn = var.encryption_key_arn

  log_level           = var.log_level
  log_retention_days  = var.log_retention_days
  lambda_tracing_mode = var.lambda_tracing_mode

  # VPC config for the MCP handler (the gateway-manager is intentionally never
  # placed in a VPC — the AgentCore control plane has no PrivateLink).
  vpc_config = length(var.vpc_subnet_ids) > 0 ? {
    subnet_ids         = var.vpc_subnet_ids
    security_group_ids = var.vpc_security_group_ids
  } : null

  tags = var.tags
}

# =============================================================================
# Chat-with-Document feature submodule (C13, task 11 — root cutover)
# =============================================================================
# Self-contained async streaming chat submodule: owns its Lambdas, session
# table, and AppSync data sources, and emits the two chat resolvers
# (`sendChatDocumentMessage` mutation + `onChatDocumentMessageUpdate`
# subscription) as its contract for the API module to attach.
#
# It consumes the AppSync API id/arn/url from the API module and the shared
# environment table/bucket ARNs. This is NOT a cycle: the chat module depends on
# the API module (for the AppSync ids), and the API module depends on the chat
# module only through `enabled_feature_contracts`, whose `resolvers` values are
# the submodule-owned data-source NAMES (static strings) — Terraform resolves
# the resolver attachment after both the API and the chat data sources exist.
module "chat_with_document" {
  source = "./modules/features/chat-with-document"
  count  = local.feature_enable.chat_with_document ? 1 : 0

  name_prefix = "${local.name_prefix}-api"

  # AppSync wiring from the API module.
  appsync_api_id          = module.processing_environment_api[0].api_id
  appsync_graphql_api_arn = module.processing_environment_api[0].api_arn
  appsync_graphql_url     = module.processing_environment_api[0].graphql_url

  # Shared environment ARNs / names.
  output_bucket_arn        = var.output_bucket_arn
  configuration_table_arn  = module.processing_environment.configuration_table_arn
  configuration_table_name = module.processing_environment.configuration_table_name
  tracking_table_arn       = module.processing_environment.tracking_table_arn
  tracking_table_name      = module.processing_environment.tracking_table_name

  # Layers.
  base_layer_arn       = module.processing_environment.base_layer_arn
  idp_common_layer_arn = module.idp_common_layer.layer_arn

  # Document config (chat: block with summarization.* fallback) + optional
  # guardrail, sourced from the active processor's config and the chat flag.
  config                   = local.chat_with_document_processor_config
  guardrail_id_and_version = local.chat_with_document_config.guardrail_id_and_version

  encryption_key_arn  = var.encryption_key_arn
  data_retention_days = var.data_tracking_retention_days
  log_level           = var.log_level
  log_retention_days  = var.log_retention_days
  lambda_tracing_mode = var.lambda_tracing_mode

  vpc_subnet_ids         = var.vpc_subnet_ids
  vpc_security_group_ids = var.vpc_security_group_ids

  tags = var.tags
}

locals {
  # Document config handed to the chat submodule for chat:/summarization.*
  # resolution. Use the active processor's config object when present.
  #
  # `try()` (not a `? :` chain) is deliberate: the three processor `config`
  # objects are `any`-typed and have heterogeneous attribute sets (e.g. the
  # bedrock-llm config carries a `chat` block the others lack), so a conditional
  # would fail with "inconsistent conditional result types" when Terraform tries
  # to unify the branches. `try()` returns the first expression that succeeds
  # without unifying types; the trailing `{}` is the all-null fallback (the
  # exactly-one-processor validation guarantees one is non-null in practice).
  chat_with_document_processor_config = try(
    var.bedrock_llm_processor.config,
    var.bda_processor.config,
    var.sagemaker_udop_processor.config,
    {}
  )

  # Map of enabled feature-plugin contracts composed by
  # `module.processing_environment_api` (its `enabled_feature_contracts` input,
  # task 6.1). Guarded merge: each per-feature entry contributes its contract
  # only when the feature is enabled, otherwise an empty map, so an all-off
  # configuration resolves to {} (a no-op — default-off preserved).
  #
  # HITL note (resolver double-create avoidance): the HITL feature submodule
  # exists (`modules/features/hitl/`) and emits a contract for the four
  # complete_section_review mutations, but those four AppSync resolvers are
  # ALREADY created directly in `modules/processing-environment-api/hitl.tf`
  # (gated by `var.enable_hitl`). Composing the HITL contract here would create
  # duplicate AppSync resolver addresses for the same fields (and switch them
  # from direct-Lambda to template mode). We therefore keep the resolvers in the
  # API module and intentionally DO NOT compose the HITL contract. The submodule
  # is retained as the inline-HITL contract surface for the design's
  # feature-plugin model; flipping the API module to consume it (and dropping
  # the direct resolvers) is a future, separately-migrated change.
  enabled_feature_contracts = merge(
    local.feature_enable.mcp ? { mcp = module.mcp_integration[0].contract } : {},
    local.feature_enable.chat_with_document ? { chat_with_document = module.chat_with_document[0].contract } : {},
  )
}

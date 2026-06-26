# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Feature-plugin wiring (.enable()-style composition)
#
# Auxiliary features (MCP, Chat-with-Document, HITL) are modeled as
# self-contained submodules that each emit an outputs contract which
# `modules/processing-environment-api` composes via `for_each` (mirroring the
# CDK accelerator's `api.enable(feature)` mechanism). This file owns the ROOT
# side: forwarding the `var.api.*` flags to a per-feature enable map, the
# count-gated feature submodules, and the `enabled_feature_contracts` merge that
# resolves to {} when every feature is off. Default-off is preserved:
# `try(..., false)` guards missing attributes so an absent flag never enables a
# feature.

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
    # Feature plugins. Each is a first-class entry in the enable map and the
    # enabled_feature_contracts merge below — no new boolean is added to the
    # monolithic `var.api` object. Default-off: `try(..., false)` guards a
    # missing object so an absent var never enables.
    rbac       = try(var.rbac.enabled, false)
    federation = try(var.idp_federation.enabled, false)
  }
}

# =============================================================================
# Validation: RBAC requires a Cognito user_identity
# =============================================================================
# Mirrors the CDK `UserManagement` constructor guard, which throws when
# `props.userIdentity` is absent ("UserManagement requires a UserIdentity").
# `local.user_pool_id` is derived from `local.user_pool_arn` and is null when
# neither an external `var.user_identity` nor an internally-created
# `module.user_identity` supplies a Cognito user pool. Enabling RBAC without a
# Cognito user pool therefore fails `terraform plan` before any apply.
#tfsec:ignore:*
check "rbac_requires_cognito" {
  assert {
    condition     = !try(var.rbac.enabled, false) || local.user_pool_id != null
    error_message = "RBAC (var.rbac.enabled = true) requires a Cognito user_identity (user pool). Configure Cognito (set var.user_identity or let the module create a user pool) or disable RBAC."
  }
}

# =============================================================================
# MCP integration feature submodule
# =============================================================================
# Self-contained AgentCore Gateway MCP stack (`agentcore_mcp_handler`, gateway
# manager/execution roles, CFN gateway, Cognito OAuth client + resource server).
# Owns no AppSync resolvers, so its contract is a composition signal only.
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
# Chat-with-Document feature submodule
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

# =============================================================================
# RBAC feature submodule
# =============================================================================
# Self-contained RBAC stack (CDK `UserManagement` analog): the four Cognito
# groups (Admin/Author/Reviewer/Viewer), the `Users` DynamoDB table, the
# user-management Lambda, and the server-side authorization surface. Emits the
# feature-plugin contract that `module.processing_environment_api` composes via
# `enabled_feature_contracts` (below), exactly the way it composes MCP/Chat.
#
# Default-off: instantiated only when `var.rbac.enabled` is true. RBAC requires
# a Cognito user pool; that constraint is enforced at plan time by a root
# `check {}`.
module "rbac" {
  source = "./modules/features/rbac"
  count  = local.feature_enable.rbac ? 1 : 0

  enabled     = true
  name_prefix = "${local.name_prefix}-api"

  # Cognito user pool the four RBAC groups are created on and the
  # user-management Lambda administers (scoped to this pool's ARN).
  user_pool_id  = local.user_pool_id
  user_pool_arn = local.user_pool_arn

  # Group-name overrides — defaults to Admin/Author/Reviewer/Viewer.
  group_names = try(var.rbac.group_names, {})

  allowed_signup_email_domains = try(var.rbac.allowed_signup_email_domains, "")

  # Encryption + data stores: Users-table SSE and the tracking/configuration
  # tables read by the Reviewer-filtering / allowedConfigVersions scoping path.
  encryption_key_arn       = var.encryption_key_arn
  tracking_table_arn       = module.processing_environment.tracking_table_arn
  tracking_table_name      = module.processing_environment.tracking_table_name
  configuration_table_arn  = module.processing_environment.configuration_table_arn
  configuration_table_name = module.processing_environment.configuration_table_name

  # Layers — same wiring the other feature submodules use for the base/idp_common layers.
  base_layer_arn       = module.processing_environment.base_layer_arn
  idp_common_layer_arn = module.idp_common_layer.layer_arn

  # Optional VPC placement for the user-management Lambda (matches the MCP wiring).
  vpc_config = length(var.vpc_subnet_ids) > 0 ? {
    subnet_ids         = var.vpc_subnet_ids
    security_group_ids = var.vpc_security_group_ids
  } : null

  log_level          = var.log_level
  log_retention_days = var.log_retention_days

  tags = var.tags
}

# =============================================================================
# External SAML/OIDC IdP federation feature submodule
# =============================================================================
# Self-contained federation stack: the Cognito identity provider (SAML or
# OIDC), the OIDC client-secret resolver (no plaintext in state), and the
# group-mapping trigger Lambda that maps external groups to the four RBAC
# groups. Always emits the feature-plugin contract; default-off provisioning is
# gated by `var.idp_federation.enabled`.
#
# When RBAC is also enabled, the group-mapping targets the RBAC submodule's
# resolved group names so federated users land in the four roles consistently;
# otherwise it falls back to the configured/default RBAC group names.
module "idp_federation" {
  source = "./modules/features/idp-federation"
  count  = local.feature_enable.federation ? 1 : 0

  enabled = true

  # Provider surface (~12 vars) forwarded from var.idp_federation.
  provider_type          = try(var.idp_federation.provider_type, "SAML")
  provider_name          = try(var.idp_federation.provider_name, "ExternalIdP")
  saml_metadata_url      = try(var.idp_federation.saml_metadata_url, "")
  saml_metadata_file     = try(var.idp_federation.saml_metadata_file, "")
  oidc_issuer            = try(var.idp_federation.oidc_issuer, "")
  oidc_client_id         = try(var.idp_federation.oidc_client_id, "")
  oidc_client_secret_ref = try(var.idp_federation.oidc_client_secret_ref, "")
  oidc_authorize_scopes  = try(var.idp_federation.oidc_authorize_scopes, "openid email profile")
  attribute_mapping      = try(var.idp_federation.attribute_mapping, {})
  group_attribute_name   = try(var.idp_federation.group_attribute_name, "")
  group_mapping          = try(var.idp_federation.group_mapping, {})

  # Cognito wiring.
  user_pool_id        = local.user_pool_id
  user_pool_client_id = local.user_pool_client_id

  # Group-mapping targets the RBAC group names: use the RBAC
  # submodule's resolved names when RBAC is enabled, otherwise the
  # configured/default group names (casing-correct Admin/Author/Reviewer/Viewer
  # keys the federation module expects).
  rbac_group_names = local.feature_enable.rbac ? module.rbac[0].group_names : local.rbac_group_names_fallback

  # Layers.
  base_layer_arn       = module.processing_environment.base_layer_arn
  idp_common_layer_arn = module.idp_common_layer.layer_arn

  encryption_key_arn = var.encryption_key_arn
  log_level          = var.log_level
  log_retention_days = var.log_retention_days

  tags = var.tags
}

locals {
  # Fallback RBAC group names for the federation group-mapping when RBAC is not
  # enabled (when RBAC IS enabled, module.rbac[0].group_names is used instead).
  # The federation submodule expects capitalized role keys
  # (Admin/Author/Reviewer/Viewer); var.rbac.group_names carries lowercase keys
  # with canonical defaults, so map them through here.
  rbac_group_names_fallback = {
    Admin    = try(var.rbac.group_names.admin, "Admin")
    Author   = try(var.rbac.group_names.author, "Author")
    Reviewer = try(var.rbac.group_names.reviewer, "Reviewer")
    Viewer   = try(var.rbac.group_names.viewer, "Viewer")
  }

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
  # `module.processing_environment_api` (its `enabled_feature_contracts` input).
  # Guarded merge: each per-feature entry contributes its contract
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
    local.feature_enable.rbac ? { rbac = module.rbac[0].contract } : {},
    local.feature_enable.federation ? { federation = module.idp_federation[0].contract } : {},
  )
}

# =============================================================================
# Tracking-table GSI backfill (default-off, operator-triggered)
# =============================================================================
# Provisions the `backfill_gsi_attributes` worker Lambda + the Step Functions
# state machine that drives it as a parallel-scan map over the tracking table,
# populating `ItemType`/`InitialEventTime` on items that predate the
# `TypeDateIndex` GSI. The GSI itself (modules/tracking-table) is always created;
# this backfill is independently controllable and gated on
# `var.tracking.enable_gsi_backfill` (default false).
#
# Crucially, even when enabled this module never auto-runs on apply — it creates
# the machinery only. The operator starts the run explicitly via
# `module.tracking_gsi_backfill[0].state_machine_arn`. `try(...)`
# guards a missing object so an absent var never enables the backfill.
module "tracking_gsi_backfill" {
  source = "./modules/tracking-gsi-backfill"
  count  = try(var.tracking.enable_gsi_backfill, false) ? 1 : 0

  name_prefix = local.name_prefix

  # Tracking table the worker scans/updates (name for the scan input, ARN for
  # least-privilege IAM scoped to exactly this table + its indexes).
  tracking_table_name = module.processing_environment.tracking_table_name
  tracking_table_arn  = module.processing_environment.tracking_table_arn

  # KMS key the tracking table + worker log group are encrypted with.
  encryption_key_arn = var.encryption_key_arn

  # Layers — same base/idp_common wiring the other feature submodules use.
  base_layer_arn       = module.processing_environment.base_layer_arn
  idp_common_layer_arn = module.idp_common_layer.layer_arn

  log_level          = var.log_level
  log_retention_days = var.log_retention_days

  tags = var.tags
}

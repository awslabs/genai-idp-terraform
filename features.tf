# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Feature-plugin wiring. Auxiliary features (MCP, Chat, RBAC, federation) are
# count-gated submodules that each emit a contract; processing-environment-api
# composes the enabled ones via enabled_feature_contracts. All default off.

locals {
  # Per-feature enable map. try(..., false) keeps an absent flag from enabling.
  feature_enable = {
    mcp                = try(var.api.enable_mcp, false)
    chat_with_document = try(var.api.chat_with_document.enabled, false)
    hitl               = try(var.api.enable_hitl, false)
    rbac               = try(var.rbac.enabled, false)
    federation         = try(var.idp_federation.enabled, false)
    feature_platform   = try(var.feature_platform.enabled, false)
  }
}

# RBAC requires a Cognito user pool; fail at plan time if it is missing.
#tfsec:ignore:*
check "rbac_requires_cognito" {
  assert {
    condition     = !try(var.rbac.enabled, false) || local.user_pool_id != null
    error_message = "RBAC (var.rbac.enabled = true) requires a Cognito user_identity (user pool). Configure Cognito (set var.user_identity or let the module create a user pool) or disable RBAC."
  }
}

# MCP integration: AgentCore Gateway stack (handler, roles, CFN gateway, Cognito
# OAuth client). Composition signal only, owns no AppSync resolvers.
module "mcp_integration" {
  source = "./modules/features/mcp-integration"
  count  = local.feature_enable.mcp ? 1 : 0

  lambda_architecture = var.build.lambda_architecture

  enabled     = true
  name_prefix = "${local.name_prefix}-api"

  user_pool_id = local.user_pool_id
  # Config-derived; the pool ID itself is unknown at plan on a fresh deploy.
  user_pool_available = local.user_identity_available

  output_bucket_arn = var.output_bucket_arn

  base_layer_arn       = module.processing_environment.base_layer_arn
  idp_common_layer_arn = module.idp_common_layer.layer_arn

  encryption_key_arn = var.encryption_key_arn

  log_level           = var.log_level
  log_retention_days  = var.log_retention_days
  lambda_tracing_mode = var.lambda_tracing_mode

  # gateway-manager is intentionally never placed in a VPC (no AgentCore PrivateLink).
  vpc_config = length(var.vpc_subnet_ids) > 0 ? {
    subnet_ids         = var.vpc_subnet_ids
    security_group_ids = var.vpc_security_group_ids
  } : null

  tags = var.tags
}

# Chat-with-Document: async streaming chat submodule. Emits its
# `sendChatDocumentMessage` field in the contract's `field_functions`; the API
# module folds that into the REST dispatcher's field-function map.
#
# It intentionally takes NO id/arn from the API module (IDP v0.6.4). It creates no
# AppSync resource any more, and staying free of that dependency is what lets the
# API module consume the contract's field_functions without a cycle.
module "chat_with_document" {
  source = "./modules/features/chat-with-document"
  count  = local.feature_enable.chat_with_document ? 1 : 0

  lambda_architecture = var.build.lambda_architecture

  name_prefix = "${local.name_prefix}-api"

  # Empty string selects the DynamoDB-direct write path in the vendored
  # processor code; there is no AppSync endpoint to publish to.
  appsync_graphql_url = ""

  output_bucket_arn        = var.output_bucket_arn
  configuration_table_arn  = module.processing_environment.configuration_table_arn
  configuration_table_name = module.processing_environment.configuration_table_name
  tracking_table_arn       = module.processing_environment.tracking_table_arn
  tracking_table_name      = module.processing_environment.tracking_table_name

  base_layer_arn       = module.processing_environment.base_layer_arn
  idp_common_layer_arn = module.idp_common_layer.layer_arn

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

# RBAC: four Cognito groups, Users table, user-management Lambda, and the
# server-side authorization surface. Requires a Cognito user pool (see check above).
module "rbac" {
  source = "./modules/features/rbac"
  count  = local.feature_enable.rbac ? 1 : 0

  lambda_architecture = var.build.lambda_architecture

  enabled     = true
  name_prefix = "${local.name_prefix}-api"

  user_pool_id  = local.user_pool_id
  user_pool_arn = local.user_pool_arn

  group_names = try(var.rbac.group_names, {})

  allowed_signup_email_domains = try(var.rbac.allowed_signup_email_domains, "")

  encryption_key_arn       = var.encryption_key_arn
  tracking_table_arn       = module.processing_environment.tracking_table_arn
  tracking_table_name      = module.processing_environment.tracking_table_name
  configuration_table_arn  = module.processing_environment.configuration_table_arn
  configuration_table_name = module.processing_environment.configuration_table_name

  base_layer_arn       = module.processing_environment.base_layer_arn
  idp_common_layer_arn = module.idp_common_layer.layer_arn

  vpc_config = length(var.vpc_subnet_ids) > 0 ? {
    subnet_ids         = var.vpc_subnet_ids
    security_group_ids = var.vpc_security_group_ids
  } : null

  log_level          = var.log_level
  log_retention_days = var.log_retention_days

  tags = var.tags
}

# External SAML/OIDC IdP federation: Cognito identity provider, OIDC
# client-secret resolver (no plaintext in state), and the group-mapping trigger.
module "idp_federation" {
  source = "./modules/features/idp-federation"
  count  = local.feature_enable.federation ? 1 : 0

  lambda_architecture = var.build.lambda_architecture

  enabled = true

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

  user_pool_id        = local.user_pool_id
  user_pool_client_id = local.user_pool_client_id

  # Map external groups onto RBAC's resolved names when RBAC is on, else the fallback.
  rbac_group_names = local.feature_enable.rbac ? module.rbac[0].group_names : local.rbac_group_names_fallback

  base_layer_arn       = module.processing_environment.base_layer_arn
  idp_common_layer_arn = module.idp_common_layer.layer_arn

  encryption_key_arn = var.encryption_key_arn
  log_level          = var.log_level
  log_retention_days = var.log_retention_days

  tags = var.tags
}

locals {
  # Fallback group names when RBAC is off. The federation module expects
  # capitalized keys; var.rbac.group_names uses lowercase, so remap here.
  rbac_group_names_fallback = {
    Admin    = try(var.rbac.group_names.admin, "Admin")
    Author   = try(var.rbac.group_names.author, "Author")
    Reviewer = try(var.rbac.group_names.reviewer, "Reviewer")
    Viewer   = try(var.rbac.group_names.viewer, "Viewer")
  }

  # try() (not ? :) is deliberate: the processor config objects are any-typed
  # with different attribute sets, so a conditional fails with inconsistent
  # result types. try() returns the first that resolves; {} is the all-null fallback.
  chat_with_document_processor_config = try(
    var.bedrock_llm_processor.config,
    var.bda_processor.config,
    var.sagemaker_udop_processor.config,
    {}
  )

  # Enabled feature contracts composed by processing-environment-api. All-off resolves to {}.
  #
  # HITL is intentionally NOT composed here: its four complete_section_review
  # resolvers are already created directly in processing-environment-api/hitl.tf
  # (gated by var.enable_hitl). Composing the HITL contract too would create
  # duplicate AppSync resolver addresses.
  enabled_feature_contracts = merge(
    local.feature_enable.mcp ? { mcp = module.mcp_integration[0].contract } : {},
    local.feature_enable.chat_with_document ? { chat_with_document = module.chat_with_document[0].contract } : {},
    local.feature_enable.rbac ? { rbac = module.rbac[0].contract } : {},
    local.feature_enable.federation ? { federation = module.idp_federation[0].contract } : {},
  )
}

# Tracking-table GSI backfill (default off, operator-triggered). Creates the
# worker Lambda + Step Functions state machine that populates ItemType /
# InitialEventTime on items predating the TypeDateIndex GSI. Never auto-runs on
# apply; the operator starts it via module.tracking_gsi_backfill[0].state_machine_arn.
module "tracking_gsi_backfill" {
  source = "./modules/tracking-gsi-backfill"
  count  = try(var.tracking.enable_gsi_backfill, false) ? 1 : 0

  lambda_architecture = var.build.lambda_architecture

  name_prefix = local.name_prefix

  tracking_table_name = module.processing_environment.tracking_table_name
  tracking_table_arn  = module.processing_environment.tracking_table_arn

  encryption_key_arn = var.encryption_key_arn

  base_layer_arn       = module.processing_environment.base_layer_arn
  idp_common_layer_arn = module.idp_common_layer.layer_arn

  log_level          = var.log_level
  log_retention_days = var.log_retention_days

  tags = var.tags
}

# Feature Platform: installable-feature registry + AppSync operations
# (catalog / entitlement / install / uninstall / register + config presets).
# Default-off; requires the API (AppSync) to be enabled. Mirrors upstream v0.5.16.
module "feature_platform" {
  source = "./modules/features/feature-platform"
  count  = local.feature_enable.feature_platform && local.api_enabled ? 1 : 0

  lambda_architecture = var.build.lambda_architecture

  name_prefix     = "${local.name_prefix}-api"
  main_stack_name = local.name_prefix

  # No graphql_api_id (IDP v0.6.4): this module creates no AppSync resource and
  # publishes `field_functions` for the REST dispatcher instead. Keeping it free of
  # any API-module input is what avoids a cycle, since the API module now consumes
  # its output.
  configuration_table_name = module.processing_environment.configuration_table_name
  configuration_table_arn  = module.processing_environment.configuration_table_arn

  encryption_key_arn = var.encryption_key_arn

  configuration_bucket_name      = try(var.feature_platform.configuration_bucket_name, "")
  catalog_key                    = try(var.feature_platform.catalog_key, "feature-platform/catalog.json")
  artifact_region                = try(var.feature_platform.artifact_region, "")
  simulator_entitlement_endpoint = try(var.feature_platform.simulator_endpoint, "")
  subscription_mode              = try(var.feature_platform.subscription_mode, "auto-subscribe")
  default_customer_identifier    = try(var.feature_platform.default_customer_identifier, "")
  default_buyer_account_id       = try(var.feature_platform.default_buyer_account_id, "")
  feature_offer_id_map           = try(var.feature_platform.feature_offer_id_map, "{}")
  admin_group_name               = try(var.feature_platform.admin_group_name, "Admin")
  seller_bucket_object_arns      = try(var.feature_platform.seller_bucket_object_arns, [])

  log_level          = var.log_level
  log_retention_days = var.log_retention_days
  tags               = var.tags
}

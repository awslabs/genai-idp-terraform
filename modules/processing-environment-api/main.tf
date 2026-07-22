# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
/**
 * # Processing Environment API Module
 *
 * This module creates an AppSync GraphQL API for tracking and managing document processing.
 * It provides resolvers for querying document status, managing document processing,
 * accessing document contents, uploading new documents, and querying document knowledge base.
 */

locals {
  api_name = var.name != null ? var.name : "ProcessingEnvironmentApi-${random_string.suffix.result}"

  # Safe authorization config handling
  # Note: authorization_config is required-by-validation to be set to a
  # non-API_KEY auth type. If a caller passes null we still need a sane
  # placeholder for plan-time so the resources don't error before the
  # check fires; we use AWS_IAM as the safest fallback.
  auth_type             = var.authorization_config != null ? try(var.authorization_config.default_authorization.authorization_type, "AWS_IAM") : "AWS_IAM"
  has_cognito_auth      = var.authorization_config != null && try(var.authorization_config.default_authorization.authorization_type, "") == "AMAZON_COGNITO_USER_POOLS"
  has_oidc_auth         = var.authorization_config != null && try(var.authorization_config.default_authorization.authorization_type, "") == "OPENID_CONNECT"
  has_lambda_auth       = var.authorization_config != null && try(var.authorization_config.default_authorization.authorization_type, "") == "AWS_LAMBDA"
  additional_auth_modes = var.authorization_config != null ? coalesce(try(var.authorization_config.additional_authorization_modes, null), []) : []

  # Handle both ARN-based and object-based approaches for resources
  # For each resource, prioritize the ARN variable if provided, otherwise use the object variable

  # S3 Buckets
  input_bucket_name  = element(split(":", var.input_bucket_arn), 5)
  output_bucket_name = element(split(":", var.output_bucket_arn), 5)

  input_bucket_arn  = var.input_bucket_arn
  output_bucket_arn = var.output_bucket_arn

  # Handle evaluation_baseline_bucket which is optional
  evaluation_baseline_bucket_arn  = var.evaluation_enabled && var.evaluation_baseline_bucket_arn != null ? var.evaluation_baseline_bucket_arn : try(var.evaluation_baseline_bucket.bucket_arn, null)
  evaluation_baseline_bucket_name = var.evaluation_enabled && var.evaluation_baseline_bucket_arn != null ? element(split(":", var.evaluation_baseline_bucket_arn), 5) : try(var.evaluation_baseline_bucket.bucket_name, null)

  # DynamoDB Tables
  tracking_table_arn  = var.tracking_table_arn
  tracking_table_name = var.tracking_table_arn != null ? element(split("/", var.tracking_table_arn), 1) : null

  configuration_table_arn  = var.configuration_table_arn
  configuration_table_name = var.configuration_table_arn != null ? element(split("/", var.configuration_table_arn), 1) : null

  # Deterministic flag for configuration table existence
  configuration_table_exists = var.configuration_table_arn != null

  # KMS Key
  encryption_key_arn = var.encryption_key_arn
  encryption_key_id  = var.encryption_key_arn != null ? element(split("/", var.encryption_key_arn), 1) : null

  # Effective ARN for KMS IAM policy Resource fields. When no customer-managed
  # key is supplied, var/local.encryption_key_arn is null, which would render an
  # invalid "Resource": null in a policy document (IAM rejects it). Fall back to
  # a syntactically-valid placeholder key ARN so the policy is well-formed (and
  # grants nothing usable, since the key does not exist). Mirrors the inline
  # guard already used by the appsync_dynamodb_policy KMS statement.
  kms_policy_resource_arn = local.encryption_key_arn != null ? local.encryption_key_arn : "arn:${data.aws_partition.current.partition}:kms:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:key/00000000-0000-0000-0000-000000000000"

  # Knowledge Base - Extract ID from ARN
  knowledge_base_arn = var.knowledge_base.knowledge_base_arn
  knowledge_base_id  = var.knowledge_base.knowledge_base_arn != null ? element(split("/", var.knowledge_base.knowledge_base_arn), 1) : null

  # Guardrail
  guardrail_id  = var.guardrail != null ? var.guardrail.guardrail_id : null
  guardrail_arn = var.guardrail != null ? var.guardrail.guardrail_arn : null

  # Knowledge Base model id for the query_knowledgebase_resolver. That vendored
  # Lambda builds the modelArn as `inference-profile/{MODEL_ID}`, so MODEL_ID must
  # be a BARE inference-profile id (e.g. us.amazon.nova-pro-v1:0), NOT an ARN —
  # passing an ARN produces a nested, invalid modelArn that RetrieveAndGenerate
  # rejects. If given an ARN, use its trailing id segment.
  knowledge_base_model_id = var.knowledge_base.model_id != null ? (
    startswith(var.knowledge_base.model_id, "arn:") ? element(reverse(split("/", var.knowledge_base.model_id)), 0) : var.knowledge_base.model_id
  ) : null

  # Edit Sections Feature
  edit_sections_enabled = var.enable_edit_sections && var.working_bucket_arn != null && var.document_queue_url != null && var.document_queue_arn != null
  working_bucket_arn    = var.working_bucket_arn
  working_bucket_name   = var.working_bucket_arn != null ? element(split(":", var.working_bucket_arn), 5) : null
  document_queue_url    = var.document_queue_url
  document_queue_arn    = var.document_queue_arn

  # Post-processing decompressor (from processing-environment module)
  post_processing_decompressor_arn = var.post_processing_decompressor_arn
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# =============================================================================
# Discovery Sub-module (Optional)
# =============================================================================

module "discovery" {
  count  = var.discovery.enabled ? 1 : 0
  source = "./discovery"

  lambda_architecture = var.lambda_architecture

  name_prefix               = "discovery-${random_string.suffix.result}"
  allowed_cors_origins      = var.discovery_allowed_cors_origins
  input_bucket_arn          = local.input_bucket_arn
  configuration_table_arn   = local.configuration_table_arn
  appsync_api_url           = "https://${aws_appsync_graphql_api.api.uris["GRAPHQL"]}"
  appsync_api_id            = aws_appsync_graphql_api.api.id
  appsync_lambda_role_arn   = aws_iam_role.appsync_lambda_role.arn
  appsync_dynamodb_role_arn = aws_iam_role.appsync_dynamodb_role.arn
  idp_common_layer_arn      = var.idp_common_layer_arn

  # Configuration
  log_level                      = var.log_level
  log_retention_days             = var.log_retention_days
  data_retention_days            = 365 # Default retention for discovery documents
  encryption_key_arn             = local.encryption_key_arn
  lambda_tracing_mode            = var.lambda_tracing_mode
  point_in_time_recovery_enabled = true

  # VPC configuration
  vpc_subnet_ids         = var.vpc_config != null ? var.vpc_config.subnet_ids : []
  vpc_security_group_ids = var.vpc_config != null ? var.vpc_config.security_group_ids : []

  # Presigned-URL-via-VPCE pass-through (discovery upload presigner).
  s3_endpoint_url = var.s3_endpoint_url

  tags = var.tags
}

# =============================================================================
# Chat with Document — relocated to the chat-with-document feature submodule
# =============================================================================
# The legacy synchronous `chatWithDocument` Query and its resolver Lambda were
# removed upstream at v0.5.12. Chat-with-Document is now an async streaming
# feature in `modules/features/chat-with-document`, instantiated at the root
# (features.tf) and composed into this API via `enabled_feature_contracts`.

# =============================================================================
# PROCESS CHANGES SUB-MODULE
# =============================================================================

module "process_changes" {
  count  = var.enable_edit_sections ? 1 : 0
  source = "./process-changes"

  lambda_architecture = var.lambda_architecture

  name_prefix             = "process-changes-${random_string.suffix.result}"
  appsync_api_id          = aws_appsync_graphql_api.api.id
  appsync_lambda_role_arn = aws_iam_role.appsync_lambda_role.arn
  idp_common_layer_arn    = var.idp_common_layer_arn

  # DynamoDB tables
  tracking_table_name = local.tracking_table_name
  tracking_table_arn  = local.tracking_table_arn

  # SQS queue
  queue_url = var.document_queue_url
  queue_arn = var.document_queue_arn

  # Data retention
  data_retention_days = var.data_retention_in_days

  # S3 bucket access
  working_bucket_arn = var.working_bucket_arn
  input_bucket_arn   = local.input_bucket_arn
  output_bucket_arn  = local.output_bucket_arn

  # AppSync GraphQL URL
  appsync_graphql_url = aws_appsync_graphql_api.api.uris["GRAPHQL"]

  # Configuration
  log_level           = var.log_level
  log_retention_days  = var.log_retention_days
  encryption_key_arn  = local.encryption_key_arn
  lambda_tracing_mode = var.lambda_tracing_mode

  # VPC configuration
  vpc_subnet_ids         = var.vpc_config != null ? var.vpc_config.subnet_ids : []
  vpc_security_group_ids = var.vpc_config != null ? var.vpc_config.security_group_ids : []

  tags = var.tags
}

# =============================================================================
# Agent Analytics Sub-Module
# =============================================================================

module "agent_analytics" {
  count  = var.agent_analytics.enabled ? 1 : 0
  source = "./agent-analytics"

  name_prefix               = "agent-analytics-${random_string.suffix.result}"
  reporting_database_name   = var.agent_analytics.reporting_database_name
  athena_results_bucket_arn = var.agent_analytics.reporting_bucket_arn
  reporting_bucket_arn      = var.agent_analytics.reporting_bucket_arn
  appsync_api_url           = aws_appsync_graphql_api.api.uris["GRAPHQL"]
  appsync_api_id            = aws_appsync_graphql_api.api.id
  idp_common_layer_arn      = var.idp_common_layer_arn
  configuration_table_name  = local.configuration_table_name

  # Shared assets bucket for Lambda layers
  lambda_layers_bucket_arn = var.lambda_layers_bucket_arn

  # Configuration
  bedrock_model_id    = var.agent_analytics.model_id
  log_level           = var.log_level
  log_retention_days  = var.log_retention_days
  data_retention_days = var.data_retention_in_days
  encryption_key_arn  = local.encryption_key_arn
  enable_encryption   = var.enable_encryption
  lambda_tracing_mode = var.lambda_tracing_mode

  # VPC configuration
  vpc_subnet_ids         = var.vpc_config != null ? var.vpc_config.subnet_ids : []
  vpc_security_group_ids = var.vpc_config != null ? var.vpc_config.security_group_ids : []

  # Build strategy (see root var.build)
  lambda_local        = var.lambda_local
  lambda_architecture = var.lambda_architecture
  container_runtime   = var.container_runtime

  tags = var.tags
}

# AppSync GraphQL API
resource "aws_appsync_graphql_api" "api" {
  name                = local.api_name
  authentication_type = local.auth_type
  xray_enabled        = var.xray_enabled
  visibility          = var.visibility

  dynamic "log_config" {
    for_each = var.log_config != null ? [var.log_config] : []
    content {
      cloudwatch_logs_role_arn = log_config.value.cloudwatch_logs_role_arn
      exclude_verbose_content  = log_config.value.exclude_verbose_content
      field_log_level          = log_config.value.field_log_level
    }
  }

  dynamic "user_pool_config" {
    for_each = local.has_cognito_auth ? [var.authorization_config.default_authorization.user_pool_config] : []
    content {
      user_pool_id        = user_pool_config.value.user_pool_id
      app_id_client_regex = user_pool_config.value.app_id_client_regex
      aws_region          = user_pool_config.value.aws_region
      default_action      = user_pool_config.value.default_action
    }
  }

  dynamic "openid_connect_config" {
    for_each = local.has_oidc_auth ? [var.authorization_config.default_authorization.openid_connect_config] : []
    content {
      auth_ttl  = openid_connect_config.value.auth_ttl
      client_id = openid_connect_config.value.client_id
      iat_ttl   = openid_connect_config.value.iat_ttl
      issuer    = openid_connect_config.value.issuer
    }
  }

  dynamic "lambda_authorizer_config" {
    for_each = local.has_lambda_auth ? [var.authorization_config.default_authorization.lambda_authorizer_config] : []
    content {
      # authorizer_result_ttl_seconds = lambda_authorizer_config.value.authorizer_result_ttl_seconds
      authorizer_uri                 = lambda_authorizer_config.value.authorizer_uri
      identity_validation_expression = lambda_authorizer_config.value.identity_validation_expression
    }
  }

  dynamic "additional_authentication_provider" {
    for_each = local.additional_auth_modes
    content {
      authentication_type = additional_authentication_provider.value.authorization_type

      dynamic "user_pool_config" {
        for_each = additional_authentication_provider.value.authorization_type == "AMAZON_COGNITO_USER_POOLS" ? [additional_authentication_provider.value.user_pool_config] : []
        content {
          user_pool_id        = user_pool_config.value.user_pool_id
          app_id_client_regex = user_pool_config.value.app_id_client_regex
          aws_region          = user_pool_config.value.aws_region
          # default_action      = user_pool_config.value.default_action
        }
      }

      dynamic "openid_connect_config" {
        for_each = additional_authentication_provider.value.authorization_type == "OPENID_CONNECT" ? [additional_authentication_provider.value.openid_connect_config] : []
        content {
          auth_ttl  = openid_connect_config.value.auth_ttl
          client_id = openid_connect_config.value.client_id
          iat_ttl   = openid_connect_config.value.iat_ttl
          issuer    = openid_connect_config.value.issuer
        }
      }

      dynamic "lambda_authorizer_config" {
        for_each = additional_authentication_provider.value.authorization_type == "AWS_LAMBDA" ? [additional_authentication_provider.value.lambda_authorizer_config] : []
        content {
          # authorizer_result_ttl_seconds = lambda_authorizer_config.value.authorizer_result_ttl_seconds
          authorizer_uri                 = lambda_authorizer_config.value.authorizer_uri
          identity_validation_expression = lambda_authorizer_config.value.identity_validation_expression
        }
      }
    }
  }

  schema = file("${path.module}/../../sources/nested/appsync/src/api/schema.graphql")

  tags = var.tags
}

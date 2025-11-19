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
  auth_type             = var.authorization_config != null ? try(var.authorization_config.default_authorization.authorization_type, "API_KEY") : "API_KEY"
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

  # Knowledge Base - Extract ID from ARN
  knowledge_base_arn = var.knowledge_base.knowledge_base_arn
  knowledge_base_id  = var.knowledge_base.knowledge_base_arn != null ? element(split("/", var.knowledge_base.knowledge_base_arn), 1) : null

  # Guardrail
  guardrail_id  = var.guardrail != null ? var.guardrail.guardrail_id : null
  guardrail_arn = var.guardrail != null ? var.guardrail.guardrail_arn : null

  # Knowledge Base Invokable
  knowledge_base_model_id = var.knowledge_base.model_id
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# AppSync GraphQL API
resource "aws_appsync_graphql_api" "api" {
  name                = local.api_name
  authentication_type = local.auth_type
  xray_enabled        = var.xray_enabled

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

  schema = file("${path.module}/../../sources/src/api/schema.graphql")

  tags = var.tags
}

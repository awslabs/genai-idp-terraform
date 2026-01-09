# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Chat with Document Sub-module for Processing Environment API
# This module creates the Lambda function and GraphQL resolver for document Q&A functionality

# Data sources for cross-partition compatibility
data "aws_partition" "current" {}
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  # Generate unique suffix for resource names
  suffix = random_string.suffix.result

  # Module build directory for Lambda archives
  module_build_dir = "${path.module}/.terraform-build"

  # Extract bucket names from ARNs
  output_bucket_name = element(split(":", var.output_bucket_arn), 5)
}

# Create a random string for unique resource names
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Create module-specific build directory
resource "null_resource" "create_module_build_dir" {
  provisioner "local-exec" {
    command = "mkdir -p ${local.module_build_dir}"
  }
}

# =============================================================================
# Chat with Document Lambda Function
# =============================================================================

# Generate unique build ID for chat resolver
resource "random_id" "chat_resolver_build_id" {
  byte_length = 8
  keepers = {
    content_hash = md5("chat-with-document-resolver")
  }
}

# Source code archive for chat resolver
data "archive_file" "chat_with_document_resolver_code" {
  type        = "zip"
  source_dir  = "${path.module}/../../../sources/src/lambda/chat_with_document_resolver"
  output_path = "${local.module_build_dir}/chat-with-document-resolver.zip_${random_id.chat_resolver_build_id.hex}"

  depends_on = [null_resource.create_module_build_dir]
}

# Chat with Document Resolver Lambda function
resource "aws_lambda_function" "chat_with_document_resolver" {
  function_name = "${var.name_prefix}-chat-with-document-${local.suffix}"

  filename         = data.archive_file.chat_with_document_resolver_code.output_path
  source_code_hash = data.archive_file.chat_with_document_resolver_code.output_base64sha256

  layers = [var.idp_common_layer_arn]

  handler     = "index.handler"
  runtime     = "python3.12"
  timeout     = 120
  memory_size = 512
  role        = aws_iam_role.chat_with_document_resolver_role.arn
  description = "Lambda function to chat with documents via GraphQL API"

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = {
      LOG_LEVEL                = var.log_level
      TRACKING_TABLE_NAME      = var.tracking_table_name
      OUTPUT_BUCKET            = local.output_bucket_name
      CONFIGURATION_TABLE_NAME = var.configuration_table_name
      GUARDRAIL_ID_AND_VERSION = var.guardrail_id_and_version != null ? var.guardrail_id_and_version : ""
    }
  }

  dynamic "vpc_config" {
    for_each = length(var.vpc_subnet_ids) > 0 ? [1] : []
    content {
      subnet_ids         = var.vpc_subnet_ids
      security_group_ids = var.vpc_security_group_ids
    }
  }

  tracing_config {
    mode = var.lambda_tracing_mode
  }

  tags = var.tags
}

# CloudWatch Log Group for chat resolver
resource "aws_cloudwatch_log_group" "chat_with_document_resolver_logs" {
  name              = "/aws/lambda/${aws_lambda_function.chat_with_document_resolver.function_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.encryption_key_arn

  tags = var.tags
}

# =============================================================================
# GraphQL Data Source and Resolver
# =============================================================================

# Chat with Document Lambda Data Source
resource "aws_appsync_datasource" "chat_with_document_lambda" {
  api_id           = var.appsync_api_id
  name             = "ChatWithDocument"
  description      = "Lambda function to chat with documents"
  type             = "AWS_LAMBDA"
  service_role_arn = var.appsync_lambda_role_arn

  lambda_config {
    function_arn = aws_lambda_function.chat_with_document_resolver.arn
  }
}

# Chat with Document Resolver (Query) - matches existing schema
resource "aws_appsync_resolver" "chat_with_document" {
  api_id      = var.appsync_api_id
  type        = "Query"
  field       = "chatWithDocument"
  data_source = aws_appsync_datasource.chat_with_document_lambda.name

  # Direct Lambda invocation - no request/response templates needed
  # The Lambda function handles the GraphQL arguments directly
}
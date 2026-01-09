# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Process Changes Sub-module for Processing Environment API
# This module creates the Lambda function and GraphQL resolver for document editing and reprocessing functionality

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
  working_bucket_name = element(split(":", var.working_bucket_arn), 5)
  input_bucket_name   = element(split(":", var.input_bucket_arn), 5)
  output_bucket_name  = element(split(":", var.output_bucket_arn), 5)
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
# Process Changes Lambda Function
# =============================================================================

# Generate unique build ID for process changes resolver
resource "random_id" "process_changes_resolver_build_id" {
  byte_length = 8
  keepers = {
    content_hash = md5("process-changes-resolver")
  }
}

# Source code archive for process changes resolver
data "archive_file" "process_changes_resolver_code" {
  type        = "zip"
  source_dir  = "${path.module}/../../../sources/src/lambda/process_changes_resolver"
  output_path = "${local.module_build_dir}/process-changes-resolver.zip_${random_id.process_changes_resolver_build_id.hex}"

  depends_on = [null_resource.create_module_build_dir]
}

# Process Changes Resolver Lambda function
resource "aws_lambda_function" "process_changes_resolver" {
  function_name = "${var.name_prefix}-process-changes-${local.suffix}"

  filename         = data.archive_file.process_changes_resolver_code.output_path
  source_code_hash = data.archive_file.process_changes_resolver_code.output_base64sha256

  layers = [var.idp_common_layer_arn]

  handler     = "index.handler"
  runtime     = "python3.12"
  timeout     = 60
  memory_size = 512
  role        = aws_iam_role.process_changes_resolver_role.arn
  description = "Lambda function to process section changes via GraphQL API"

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = {
      LOG_LEVEL              = var.log_level
      TRACKING_TABLE         = var.tracking_table_name
      QUEUE_URL              = var.queue_url
      DATA_RETENTION_IN_DAYS = var.data_retention_days
      WORKING_BUCKET         = local.working_bucket_name
      INPUT_BUCKET           = local.input_bucket_name
      OUTPUT_BUCKET          = local.output_bucket_name
      APPSYNC_API_URL        = var.appsync_graphql_url
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

# CloudWatch Log Group for process changes resolver
resource "aws_cloudwatch_log_group" "process_changes_resolver_logs" {
  name              = "/aws/lambda/${aws_lambda_function.process_changes_resolver.function_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.encryption_key_arn

  tags = var.tags
}

# =============================================================================
# GraphQL Data Source and Resolver
# =============================================================================

# Process Changes Lambda Data Source
resource "aws_appsync_datasource" "process_changes_lambda" {
  api_id           = var.appsync_api_id
  name             = "ProcessChangesDataSource"
  description      = "Lambda function for processing section changes"
  type             = "AWS_LAMBDA"
  service_role_arn = var.appsync_lambda_role_arn

  lambda_config {
    function_arn = aws_lambda_function.process_changes_resolver.arn
  }
}

# Process Changes Resolver (Mutation) - matches existing schema
resource "aws_appsync_resolver" "process_changes" {
  api_id      = var.appsync_api_id
  type        = "Mutation"
  field       = "processChanges"
  data_source = aws_appsync_datasource.process_changes_lambda.name

  # Direct Lambda invocation - no request/response templates needed
  # The Lambda function handles the GraphQL arguments directly
}
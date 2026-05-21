# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

# Lambda function for configuration seeding
resource "aws_lambda_function" "configuration_seeder" {
  filename      = data.archive_file.lambda_zip.output_path
  function_name = "${var.name_prefix}-configuration-seeder"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "index.lambda_handler"
  runtime       = "python3.12"
  timeout       = 120
  memory_size   = 512

  # Pull in `idp_common` so the seeder can merge user config with system
  # defaults (the v0.4.16 runtime expects every config item to be a full
  # IDPConfig). Falling back to the per-processor layer is fine if the
  # dedicated base layer isn't wired (older deployments).
  layers = compact([var.base_layer_arn, var.idp_common_layer_arn])

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = {
      TABLE_NAME = var.configuration_table_name
    }
  }

  # VPC configuration (conditional)
  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  tracing_config {
    mode = var.lambda_tracing_mode
  }

  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  tags = var.tags
}

# Package Lambda function from top-level src directory
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../../src/lambda/configuration-seeder"
  output_path = "${path.module}/lambda.zip"
}

# Seed Default configuration using resource with proper triggers
resource "aws_lambda_invocation" "seed_default" {
  function_name = aws_lambda_function.configuration_seeder.function_name

  input = jsonencode({
    Key   = "Default"
    Value = var.configuration
  })

  triggers = {
    configuration_hash = sha256(jsonencode(var.configuration))
    # Re-invoke when the seeder Lambda source itself changes — this is
    # how we propagate seeder fixes to existing deployments without
    # forcing the operator to taint the resource.
    seeder_source_hash = data.archive_file.lambda_zip.output_base64sha256
  }

  depends_on = [
    aws_lambda_function.configuration_seeder,
    aws_iam_role_policy_attachment.kms_access
  ]
}

# Seed Schema configuration using resource with proper triggers
resource "aws_lambda_invocation" "seed_schema" {
  function_name = aws_lambda_function.configuration_seeder.function_name

  input = jsonencode({
    Key   = "Schema"
    Value = var.schema
  })

  triggers = {
    schema_hash        = sha256(jsonencode(var.schema))
    seeder_source_hash = data.archive_file.lambda_zip.output_base64sha256
  }

  depends_on = [
    aws_lambda_function.configuration_seeder,
    aws_iam_role_policy_attachment.kms_access
  ]
}

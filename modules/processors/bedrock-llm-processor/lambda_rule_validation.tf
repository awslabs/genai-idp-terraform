# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Rule Validation Lambda Functions (v0.4.13+)
# Conditional on var.enable_rule_validation

# =============================================================================
# Archive sources
# =============================================================================

data "archive_file" "rule_validation_lambda" {
  count = var.enable_rule_validation ? 1 : 0

  type        = "zip"
  source_dir  = "${path.module}/../../../sources/patterns/pattern-2/src/rule-validation-function"
  output_path = "${path.module}/rule_validation_function.zip"

  depends_on = [null_resource.create_module_build_dir]
}

data "archive_file" "rule_validation_orchestration_lambda" {
  count = var.enable_rule_validation ? 1 : 0

  type        = "zip"
  source_dir  = "${path.module}/../../../sources/patterns/pattern-2/src/rule-validation-orchestration-function"
  output_path = "${path.module}/rule_validation_orchestration_function.zip"

  depends_on = [null_resource.create_module_build_dir]
}

# =============================================================================
# IAM Role and Policy
# =============================================================================

resource "aws_iam_role" "rule_validation_role" {
  count = var.enable_rule_validation ? 1 : 0

  name = "${local.name_prefix}-rule-validation-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "rule_validation_policy" {
  count = var.enable_rule_validation ? 1 : 0

  name = "${local.name_prefix}-rule-validation-policy"
  role = aws_iam_role.rule_validation_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:${data.aws_partition.current.partition}:logs:*:*:*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:ListBucket"]
        Resource = [local.input_bucket_arn, "${local.input_bucket_arn}/*"]
      },
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
        Resource = [local.output_bucket_arn, "${local.output_bucket_arn}/*",
        local.working_bucket_arn, "${local.working_bucket_arn}/*"]
      },
      {
        Effect = "Allow"
        Action = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:Query", "dynamodb:Scan"]
        Resource = [local.configuration_table_arn, "${local.configuration_table_arn}/index/*",
        local.tracking_table_arn, "${local.tracking_table_arn}/index/*"]
      },
      {
        Effect = "Allow"
        Action = ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream", "bedrock:GetInferenceProfile"]
        Resource = [
          "arn:${data.aws_partition.current.partition}:bedrock:*::foundation-model/*",
          "arn:${data.aws_partition.current.partition}:bedrock:*:${data.aws_caller_identity.current.account_id}:inference-profile/*"
        ]
      },
      {
        Effect    = "Allow"
        Action    = ["cloudwatch:PutMetricData"]
        Resource  = "*"
        Condition = { StringEquals = { "cloudwatch:namespace" = local.metric_namespace } }
      }
    ]
  })
}

resource "aws_iam_role_policy" "rule_validation_orchestration_extras" {
  count = var.enable_rule_validation ? 1 : 0

  name = "${local.name_prefix}-rule-validation-orch-policy"
  role = aws_iam_role.rule_validation_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["lambda:InvokeFunction"]
        Resource = aws_lambda_function.rule_validation_function[0].arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "rule_validation_vpc" {
  count = var.enable_rule_validation && length(local.vpc_subnet_ids) > 0 ? 1 : 0

  role       = aws_iam_role.rule_validation_role[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "rule_validation_kms" {
  count = var.enable_rule_validation && local.encryption_key_arn != null ? 1 : 0

  name = "${local.name_prefix}-rule-validation-kms-policy"
  role = aws_iam_role.rule_validation_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
      Resource = local.encryption_key_arn
    }]
  })
}

# =============================================================================
# Lambda Functions
# =============================================================================

resource "aws_lambda_function" "rule_validation_function" {
  count = var.enable_rule_validation ? 1 : 0

  function_name    = "${local.name_prefix}-rule-validation"
  role             = aws_iam_role.rule_validation_role[0].arn
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 900
  memory_size      = 4096
  filename         = data.archive_file.rule_validation_lambda[0].output_path
  source_code_hash = data.archive_file.rule_validation_lambda[0].output_base64sha256

  layers = [var.base_layer_arn != null ? var.base_layer_arn : var.idp_common_layer_arn]

  kms_key_arn = local.encryption_key_arn

  environment {
    variables = {
      METRIC_NAMESPACE         = local.metric_namespace
      CONFIGURATION_TABLE_NAME = local.configuration_table_name
      LOG_LEVEL                = local.log_level
      WORKING_BUCKET           = local.working_bucket_name
      TRACKING_TABLE           = local.tracking_table_name
      DOCUMENT_TRACKING_MODE   = local.api_id != null ? "appsync" : "dynamodb"
      APPSYNC_API_URL          = local.api_graphql_url != null ? local.api_graphql_url : ""
    }
  }

  dynamic "vpc_config" {
    for_each = length(local.vpc_subnet_ids) > 0 ? [1] : []
    content {
      subnet_ids         = local.vpc_subnet_ids
      security_group_ids = local.vpc_security_group_ids
    }
  }

  tracing_config {
    mode = var.lambda_tracing_mode
  }

  tags = local.common_tags
}

resource "aws_lambda_function" "rule_validation_orchestration_function" {
  count = var.enable_rule_validation ? 1 : 0

  function_name    = "${local.name_prefix}-rule-validation-orchestration"
  role             = aws_iam_role.rule_validation_role[0].arn
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 900
  memory_size      = 4096
  filename         = data.archive_file.rule_validation_orchestration_lambda[0].output_path
  source_code_hash = data.archive_file.rule_validation_orchestration_lambda[0].output_base64sha256

  layers = [var.base_layer_arn != null ? var.base_layer_arn : var.idp_common_layer_arn]

  kms_key_arn = local.encryption_key_arn

  environment {
    variables = {
      METRIC_NAMESPACE             = local.metric_namespace
      CONFIGURATION_TABLE_NAME     = local.configuration_table_name
      LOG_LEVEL                    = local.log_level
      WORKING_BUCKET               = local.working_bucket_name
      TRACKING_TABLE               = local.tracking_table_name
      RULE_VALIDATION_FUNCTION_ARN = aws_lambda_function.rule_validation_function[0].arn
      DOCUMENT_TRACKING_MODE       = local.api_id != null ? "appsync" : "dynamodb"
      APPSYNC_API_URL              = local.api_graphql_url != null ? local.api_graphql_url : ""
    }
  }

  dynamic "vpc_config" {
    for_each = length(local.vpc_subnet_ids) > 0 ? [1] : []
    content {
      subnet_ids         = local.vpc_subnet_ids
      security_group_ids = local.vpc_security_group_ids
    }
  }

  tracing_config {
    mode = var.lambda_tracing_mode
  }

  tags = local.common_tags
}

# =============================================================================
# CloudWatch Log Groups
# =============================================================================

resource "aws_cloudwatch_log_group" "rule_validation_lambda" {
  count = var.enable_rule_validation ? 1 : 0

  name              = "/aws/lambda/${aws_lambda_function.rule_validation_function[0].function_name}"
  retention_in_days = local.log_retention_days
  kms_key_id        = local.encryption_key_arn

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "rule_validation_orchestration_lambda" {
  count = var.enable_rule_validation ? 1 : 0

  name              = "/aws/lambda/${aws_lambda_function.rule_validation_orchestration_function[0].function_name}"
  retention_in_days = local.log_retention_days
  kms_key_id        = local.encryption_key_arn

  tags = local.common_tags
}

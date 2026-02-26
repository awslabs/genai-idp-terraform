# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Error Analyzer sub-feature (v0.3.19+)
# Conditional on var.enable_error_analyzer

# =============================================================================
# IAM Role: error_analyzer
# =============================================================================

resource "aws_iam_role" "error_analyzer" {
  count = var.enable_error_analyzer ? 1 : 0
  name  = "${local.api_name}-error-analyzer"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "error_analyzer" {
  count = var.enable_error_analyzer ? 1 : 0
  name  = "error-analyzer-policy"
  role  = aws_iam_role.error_analyzer[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:${data.aws_partition.current.partition}:logs:*:*:*"
      },
      {
        # CloudWatch Logs read access for error analysis
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:GetLogEvents",
          "logs:FilterLogEvents",
          "logs:StartQuery",
          "logs:GetQueryResults"
        ]
        Resource = "arn:${data.aws_partition.current.partition}:logs:*:*:*"
      },
      {
        # X-Ray read access
        Effect = "Allow"
        Action = [
          "xray:GetTraceSummaries",
          "xray:BatchGetTraces",
          "xray:GetServiceGraph"
        ]
        Resource = "*"
      },
      {
        # Step Functions read access
        Effect = "Allow"
        Action = [
          "states:DescribeExecution",
          "states:GetExecutionHistory",
          "states:ListExecutions"
        ]
        Resource = "*"
      },
      {
        # Bedrock invoke for AI-powered diagnostics
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream"]
        Resource = "arn:${data.aws_partition.current.partition}:bedrock:*::foundation-model/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "error_analyzer_xray" {
  count      = var.enable_error_analyzer ? 1 : 0
  role       = aws_iam_role.error_analyzer[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# =============================================================================
# Lambda: error_analyzer
# =============================================================================

resource "aws_cloudwatch_log_group" "error_analyzer" {
  count             = var.enable_error_analyzer ? 1 : 0
  name              = "/aws/lambda/${local.api_name}-error-analyzer"
  retention_in_days = var.log_retention_days
  kms_key_id        = local.encryption_key_arn
  tags              = var.tags
}

data "archive_file" "error_analyzer" {
  count       = var.enable_error_analyzer ? 1 : 0
  type        = "zip"
  source_dir  = "${path.module}/../../sources/src/lambda/error_analyzer"
  output_path = "${path.module}/../../.terraform/archives/error_analyzer.zip"
}

resource "aws_lambda_function" "error_analyzer" {
  count            = var.enable_error_analyzer ? 1 : 0
  function_name    = "${local.api_name}-error-analyzer"
  role             = aws_iam_role.error_analyzer[0].arn
  filename         = data.archive_file.error_analyzer[0].output_path
  source_code_hash = data.archive_file.error_analyzer[0].output_base64sha256
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 300
  memory_size      = 512
  layers           = compact([var.idp_common_layer_arn])

  environment {
    variables = {
      LOG_LEVEL                = var.log_level
      STATE_MACHINE_ARN        = var.state_machine_arn
      TRACKING_TABLE_NAME      = local.tracking_table_name != null ? local.tracking_table_name : ""
      CONFIGURATION_TABLE_NAME = local.configuration_table_name != null ? local.configuration_table_name : ""
    }
  }

  tracing_config { mode = var.lambda_tracing_mode }

  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  depends_on = [aws_cloudwatch_log_group.error_analyzer]
  tags       = var.tags
}

# =============================================================================
# IAM Role: error_analyzer_resolver
# =============================================================================

resource "aws_iam_role" "error_analyzer_resolver" {
  count = var.enable_error_analyzer ? 1 : 0
  name  = "${local.api_name}-error-analyzer-resolver"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "error_analyzer_resolver" {
  count = var.enable_error_analyzer ? 1 : 0
  name  = "error-analyzer-resolver-policy"
  role  = aws_iam_role.error_analyzer_resolver[0].id

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
        Action   = ["lambda:InvokeFunction"]
        Resource = aws_lambda_function.error_analyzer[0].arn
      }
    ]
  })
}

# =============================================================================
# Lambda: error_analyzer_resolver
# =============================================================================

resource "aws_cloudwatch_log_group" "error_analyzer_resolver" {
  count             = var.enable_error_analyzer ? 1 : 0
  name              = "/aws/lambda/${local.api_name}-error-analyzer-resolver"
  retention_in_days = var.log_retention_days
  kms_key_id        = local.encryption_key_arn
  tags              = var.tags
}

data "archive_file" "error_analyzer_resolver" {
  count       = var.enable_error_analyzer ? 1 : 0
  type        = "zip"
  source_dir  = "${path.module}/../../sources/src/lambda/error_analyzer_resolver"
  output_path = "${path.module}/../../.terraform/archives/error_analyzer_resolver.zip"
}

resource "aws_lambda_function" "error_analyzer_resolver" {
  count            = var.enable_error_analyzer ? 1 : 0
  function_name    = "${local.api_name}-error-analyzer-resolver"
  role             = aws_iam_role.error_analyzer_resolver[0].arn
  filename         = data.archive_file.error_analyzer_resolver[0].output_path
  source_code_hash = data.archive_file.error_analyzer_resolver[0].output_base64sha256
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 30
  layers           = compact([var.idp_common_layer_arn])

  environment {
    variables = {
      LOG_LEVEL          = var.log_level
      ERROR_ANALYZER_ARN = aws_lambda_function.error_analyzer[0].arn
    }
  }

  tracing_config { mode = var.lambda_tracing_mode }

  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  depends_on = [aws_cloudwatch_log_group.error_analyzer_resolver]
  tags       = var.tags
}

# =============================================================================
# AppSync data source for Error Analyzer
# Note: The error_analyzer_resolver Lambda is invoked directly by the
# processing pipeline. There is no dedicated AppSync field for error analysis
# in the GraphQL schema — the Lambda is called internally, not via AppSync.
# =============================================================================

resource "aws_appsync_datasource" "error_analyzer_resolver" {
  count            = var.enable_error_analyzer ? 1 : 0
  api_id           = aws_appsync_graphql_api.api.id
  name             = "ErrorAnalyzerResolverDS"
  type             = "AWS_LAMBDA"
  service_role_arn = aws_iam_role.appsync_lambda_role.arn
  lambda_config { function_arn = aws_lambda_function.error_analyzer_resolver[0].arn }
}

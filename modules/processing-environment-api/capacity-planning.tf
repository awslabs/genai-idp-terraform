# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Capacity Planning sub-feature (v0.4.13+)
# Conditional on var.enable_capacity_planning (default false).
# Two Lambdas: calculate_capacity (engine) + calculate_capacity_resolver (AppSync resolver).

# =============================================================================
# IAM Role: capacity_planning (shared by both Lambdas)
# =============================================================================

resource "aws_iam_role" "capacity_planning" {
  count = var.enable_capacity_planning ? 1 : 0
  name  = "${local.api_name}-capacity-planning"

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

resource "aws_iam_role_policy" "capacity_planning" {
  count = var.enable_capacity_planning ? 1 : 0
  name  = "capacity-planning-policy"
  role  = aws_iam_role.capacity_planning[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:${data.aws_partition.current.partition}:logs:*:*:*"
      },
      {
        # Tracking table read
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:Query", "dynamodb:Scan"]
        Resource = compact([local.tracking_table_arn, "${local.tracking_table_arn}/index/*"])
      },
      {
        # Configuration table read
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:Query", "dynamodb:Scan"]
        Resource = compact([local.configuration_table_arn, "${local.configuration_table_arn}/index/*"])
      },
      {
        # Service Quotas read
        Effect   = "Allow"
        Action   = ["servicequotas:GetServiceQuota", "servicequotas:ListServiceQuotas", "servicequotas:GetAWSDefaultServiceQuota"]
        Resource = "*"
      },
      {
        # Resolver invokes the calculator
        Effect   = "Allow"
        Action   = ["lambda:InvokeFunction"]
        Resource = "arn:${data.aws_partition.current.partition}:lambda:*:*:function:${local.api_name}-calculate-capacity"
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
        Resource = local.encryption_key_arn != null ? local.encryption_key_arn : "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "capacity_planning_xray" {
  count      = var.enable_capacity_planning ? 1 : 0
  role       = aws_iam_role.capacity_planning[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# =============================================================================
# Lambda: calculate_capacity (engine)
# =============================================================================

resource "aws_cloudwatch_log_group" "calculate_capacity" {
  count             = var.enable_capacity_planning ? 1 : 0
  name              = "/aws/lambda/${local.api_name}-calculate-capacity"
  retention_in_days = var.log_retention_days
  kms_key_id        = local.encryption_key_arn
  tags              = var.tags
}

data "archive_file" "calculate_capacity" {
  count       = var.enable_capacity_planning ? 1 : 0
  type        = "zip"
  source_dir  = "${path.module}/../../sources/src/lambda/calculate_capacity"
  output_path = "${path.module}/../../.terraform/archives/calculate_capacity.zip"
}

resource "aws_lambda_function" "calculate_capacity" {
  count            = var.enable_capacity_planning ? 1 : 0
  function_name    = "${local.api_name}-calculate-capacity"
  role             = aws_iam_role.capacity_planning[0].arn
  filename         = data.archive_file.calculate_capacity[0].output_path
  source_code_hash = data.archive_file.calculate_capacity[0].output_base64sha256
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 300
  memory_size      = 1024
  layers           = compact([var.base_layer_arn, var.idp_common_layer_arn])

  environment {
    variables = {
      LOG_LEVEL                                  = var.log_level
      TRACKING_TABLE                             = local.tracking_table_name != null ? local.tracking_table_name : ""
      CONFIGURATION_TABLE_NAME                   = local.configuration_table_name != null ? local.configuration_table_name : ""
      LAMBDA_MEMORY_GB                           = "1.0"
      RECOMMENDATION_HIGH_COMPLEXITY_THRESHOLD   = "0.7"
      RECOMMENDATION_MEDIUM_COMPLEXITY_THRESHOLD = "0.4"
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

  depends_on = [aws_cloudwatch_log_group.calculate_capacity]
  tags       = var.tags
}

# =============================================================================
# Lambda: calculate_capacity_resolver (AppSync resolver)
# =============================================================================

resource "aws_cloudwatch_log_group" "calculate_capacity_resolver" {
  count             = var.enable_capacity_planning ? 1 : 0
  name              = "/aws/lambda/${local.api_name}-calculate-capacity-resolver"
  retention_in_days = var.log_retention_days
  kms_key_id        = local.encryption_key_arn
  tags              = var.tags
}

data "archive_file" "calculate_capacity_resolver" {
  count       = var.enable_capacity_planning ? 1 : 0
  type        = "zip"
  source_dir  = "${path.module}/../../sources/src/lambda/calculate_capacity_resolver"
  output_path = "${path.module}/../../.terraform/archives/calculate_capacity_resolver.zip"
}

resource "aws_lambda_function" "calculate_capacity_resolver" {
  count            = var.enable_capacity_planning ? 1 : 0
  function_name    = "${local.api_name}-calculate-capacity-resolver"
  role             = aws_iam_role.capacity_planning[0].arn
  filename         = data.archive_file.calculate_capacity_resolver[0].output_path
  source_code_hash = data.archive_file.calculate_capacity_resolver[0].output_base64sha256
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 30
  memory_size      = 256
  layers           = compact([var.base_layer_arn, var.idp_common_layer_arn])

  environment {
    variables = {
      LOG_LEVEL                        = var.log_level
      CALCULATE_CAPACITY_FUNCTION_NAME = "${local.api_name}-calculate-capacity"
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

  depends_on = [
    aws_cloudwatch_log_group.calculate_capacity_resolver,
    aws_lambda_function.calculate_capacity,
  ]
  tags = var.tags
}

# =============================================================================
# AppSync data source + resolver
# =============================================================================

resource "aws_appsync_datasource" "calculate_capacity_resolver" {
  count            = var.enable_capacity_planning ? 1 : 0
  api_id           = aws_appsync_graphql_api.api.id
  name             = "CalculateCapacityResolverDS"
  type             = "AWS_LAMBDA"
  service_role_arn = aws_iam_role.appsync_lambda_role.arn
  lambda_config { function_arn = aws_lambda_function.calculate_capacity_resolver[0].arn }
}

resource "aws_appsync_resolver" "calculate_capacity" {
  count       = var.enable_capacity_planning ? 1 : 0
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Query"
  field       = "calculateCapacity"
  data_source = aws_appsync_datasource.calculate_capacity_resolver[0].name
}

resource "aws_iam_policy" "appsync_invoke_capacity_planning" {
  count       = var.enable_capacity_planning ? 1 : 0
  name        = "${local.api_name}-appsync-invoke-capacity-planning"
  description = "Allow AppSync to invoke calculate_capacity_resolver Lambda"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "lambda:InvokeFunction"
      Resource = aws_lambda_function.calculate_capacity_resolver[0].arn
    }]
  })
}

resource "aws_iam_role_policy_attachment" "appsync_invoke_capacity_planning" {
  count      = var.enable_capacity_planning ? 1 : 0
  role       = aws_iam_role.appsync_lambda_role.name
  policy_arn = aws_iam_policy.appsync_invoke_capacity_planning[0].arn
}

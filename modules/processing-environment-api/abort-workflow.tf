# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Abort Workflow sub-feature (v0.4.10+)
# Always-on (no feature flag) — abortWorkflow is a core API operation.
# Sourced from CDK nested appsync tree (DEC-007).

# =============================================================================
# IAM Role: abort_workflow
# =============================================================================

resource "aws_iam_role" "abort_workflow" {
  name = "${local.api_name}-abort-workflow"

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

resource "aws_iam_role_policy" "abort_workflow" {
  name = "abort-workflow-policy"
  role = aws_iam_role.abort_workflow.id

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
        Action   = ["states:StopExecution"]
        Resource = "arn:${data.aws_partition.current.partition}:states:*:*:execution:*"
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:UpdateItem"]
        Resource = [local.tracking_table_arn]
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
        Resource = local.encryption_key_arn != null ? local.encryption_key_arn : "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "abort_workflow_xray" {
  role       = aws_iam_role.abort_workflow.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# =============================================================================
# Lambda: abort_workflow
# =============================================================================

resource "aws_cloudwatch_log_group" "abort_workflow" {
  name              = "/aws/lambda/${local.api_name}-abort-workflow"
  retention_in_days = var.log_retention_days
  kms_key_id        = local.encryption_key_arn
  tags              = var.tags
}

data "archive_file" "abort_workflow" {
  type        = "zip"
  source_dir  = "${path.module}/../../genai-idp/sources/nested/appsync/src/lambda/abort_workflow_resolver"
  output_path = "${path.module}/../../.terraform/archives/abort_workflow.zip"
}

resource "aws_lambda_function" "abort_workflow" {
  function_name    = "${local.api_name}-abort-workflow"
  role             = aws_iam_role.abort_workflow.arn
  filename         = data.archive_file.abort_workflow.output_path
  source_code_hash = data.archive_file.abort_workflow.output_base64sha256
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 30
  memory_size      = 256
  layers           = compact([var.base_layer_arn, var.idp_common_layer_arn])

  environment {
    variables = {
      LOG_LEVEL           = var.log_level
      TRACKING_TABLE_NAME = local.tracking_table_name != null ? local.tracking_table_name : ""
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

  depends_on = [aws_cloudwatch_log_group.abort_workflow]
  tags       = var.tags
}

# =============================================================================
# AppSync data source + resolver
# =============================================================================

resource "aws_appsync_datasource" "abort_workflow" {
  api_id           = aws_appsync_graphql_api.api.id
  name             = "AbortWorkflowDS"
  type             = "AWS_LAMBDA"
  service_role_arn = aws_iam_role.appsync_lambda_role.arn
  lambda_config { function_arn = aws_lambda_function.abort_workflow.arn }
}

resource "aws_appsync_resolver" "abort_workflow" {
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Mutation"
  field       = "abortWorkflow"
  data_source = aws_appsync_datasource.abort_workflow.name
}

resource "aws_iam_policy" "appsync_invoke_abort_workflow" {
  name        = "${local.api_name}-appsync-invoke-abort-workflow"
  description = "Allow AppSync to invoke abort_workflow Lambda"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "lambda:InvokeFunction"
      Resource = aws_lambda_function.abort_workflow.arn
    }]
  })
}

resource "aws_iam_role_policy_attachment" "appsync_invoke_abort_workflow" {
  role       = aws_iam_role.appsync_lambda_role.name
  policy_arn = aws_iam_policy.appsync_invoke_abort_workflow.arn
}

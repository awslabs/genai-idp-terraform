# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Abort Workflow sub-feature (v0.4.10+)
# Always-on (no feature flag) — abortWorkflow is a core API operation.
# Sourced from the CDK nested appsync tree.

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
        Resource = local.encryption_key_arn != null ? local.encryption_key_arn : "arn:${data.aws_partition.current.partition}:kms:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:key/00000000-0000-0000-0000-000000000000"
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
  source_dir  = "${path.module}/../../sources/nested/api-resolvers/src/lambda/abort_workflow_resolver"
  output_path = "${path.module}/../../.terraform/archives/abort_workflow.zip"
}

resource "aws_lambda_function" "abort_workflow" {
  architectures    = [var.lambda_architecture]
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

# AppSync data source/resolver + invoke policy removed in the v0.6.4 REST
# migration. abortWorkflow is now routed to this Lambda by the dispatcher
# (see dispatcher.tf field_function_map); the dispatcher role grants the invoke.

# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# BDA Sync sub-feature (v0.4.10+)
# Always-on — syncBdaIdp is a core API operation when BDA processor is used.
# Sourced from CDK nested appsync tree (DEC-007/DEC-009).

# =============================================================================
# IAM Role: sync_bda_idp
# =============================================================================

resource "aws_iam_role" "sync_bda_idp" {
  name = "${local.api_name}-sync-bda-idp"

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

resource "aws_iam_role_policy" "sync_bda_idp" {
  name = "sync-bda-idp-policy"
  role = aws_iam_role.sync_bda_idp.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:${data.aws_partition.current.partition}:logs:*:*:*"
      },
      {
        # Bedrock Data Automation blueprint CRUD
        Effect = "Allow"
        Action = [
          "bedrock:CreateBlueprint",
          "bedrock:UpdateBlueprint",
          "bedrock:DeleteBlueprint",
          "bedrock:GetBlueprint",
          "bedrock:ListBlueprints",
          "bedrock:GetDataAutomationProject",
          "bedrock:ListDataAutomationProjects"
        ]
        Resource = "*"
      },
      {
        # Configuration table read
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:Query", "dynamodb:Scan"]
        Resource = compact([local.configuration_table_arn, "${local.configuration_table_arn}/index/*"])
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
        Resource = local.encryption_key_arn != null ? local.encryption_key_arn : "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "sync_bda_idp_xray" {
  role       = aws_iam_role.sync_bda_idp.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# =============================================================================
# Lambda: sync_bda_idp
# =============================================================================

resource "aws_cloudwatch_log_group" "sync_bda_idp" {
  name              = "/aws/lambda/${local.api_name}-sync-bda-idp"
  retention_in_days = var.log_retention_days
  kms_key_id        = local.encryption_key_arn
  tags              = var.tags
}

data "archive_file" "sync_bda_idp" {
  type        = "zip"
  source_dir  = "${path.module}/../../genai-idp/sources/nested/appsync/src/lambda/sync_bda_idp_resolver"
  output_path = "${path.module}/../../.terraform/archives/sync_bda_idp.zip"
}

resource "aws_lambda_function" "sync_bda_idp" {
  function_name    = "${local.api_name}-sync-bda-idp"
  role             = aws_iam_role.sync_bda_idp.arn
  filename         = data.archive_file.sync_bda_idp.output_path
  source_code_hash = data.archive_file.sync_bda_idp.output_base64sha256
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 60
  memory_size      = 256
  layers           = compact([var.base_layer_arn, var.idp_common_layer_arn])

  environment {
    variables = {
      LOG_LEVEL                = var.log_level
      BDA_PROJECT_ARN          = var.bda_project_arn
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

  depends_on = [aws_cloudwatch_log_group.sync_bda_idp]
  tags       = var.tags
}

# =============================================================================
# AppSync data source + resolver
# =============================================================================

resource "aws_appsync_datasource" "sync_bda_idp" {
  api_id           = aws_appsync_graphql_api.api.id
  name             = "SyncBdaIdpDS"
  type             = "AWS_LAMBDA"
  service_role_arn = aws_iam_role.appsync_lambda_role.arn
  lambda_config { function_arn = aws_lambda_function.sync_bda_idp.arn }
}

resource "aws_appsync_resolver" "sync_bda_idp" {
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Mutation"
  field       = "syncBdaIdp"
  data_source = aws_appsync_datasource.sync_bda_idp.name
}

resource "aws_iam_policy" "appsync_invoke_sync_bda_idp" {
  name        = "${local.api_name}-appsync-invoke-sync-bda-idp"
  description = "Allow AppSync to invoke sync_bda_idp Lambda"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "lambda:InvokeFunction"
      Resource = aws_lambda_function.sync_bda_idp.arn
    }]
  })
}

resource "aws_iam_role_policy_attachment" "appsync_invoke_sync_bda_idp" {
  role       = aws_iam_role.appsync_lambda_role.name
  policy_arn = aws_iam_policy.appsync_invoke_sync_bda_idp.arn
}

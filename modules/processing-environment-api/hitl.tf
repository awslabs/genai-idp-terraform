# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Built-in HITL sub-feature (v0.4.9+)
# Replaces SageMaker A2I with a single complete_section_review Lambda.
# Conditional on var.enable_hitl (default true).

# =============================================================================
# IAM Role: complete_section_review
# =============================================================================

resource "aws_iam_role" "complete_section_review" {
  count = var.enable_hitl ? 1 : 0
  name  = "${local.api_name}-complete-section-review"

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

resource "aws_iam_role_policy" "complete_section_review" {
  count = var.enable_hitl ? 1 : 0
  name  = "complete-section-review-policy"
  role  = aws_iam_role.complete_section_review[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:${data.aws_partition.current.partition}:logs:*:*:*"
      },
      {
        # Tracking table CRUD
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query"
        ]
        Resource = [
          local.tracking_table_arn,
          "${local.tracking_table_arn}/index/*"
        ]
      },
      {
        # Document bucket read/write (output + working)
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
        Resource = compact([
          local.output_bucket_arn,
          "${local.output_bucket_arn}/*",
          local.working_bucket_arn,
          "${local.working_bucket_arn}/*",
          local.input_bucket_arn,
          "${local.input_bucket_arn}/*",
        ])
      },
      {
        # SQS send for reprocessing trigger
        Effect   = "Allow"
        Action   = ["sqs:SendMessage", "sqs:GetQueueAttributes"]
        Resource = local.document_queue_arn != null ? local.document_queue_arn : "arn:${data.aws_partition.current.partition}:sqs:*:*:*"
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
        Resource = local.encryption_key_arn != null ? local.encryption_key_arn : "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "complete_section_review_xray" {
  count      = var.enable_hitl ? 1 : 0
  role       = aws_iam_role.complete_section_review[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# =============================================================================
# Lambda: complete_section_review
# =============================================================================

resource "aws_cloudwatch_log_group" "complete_section_review" {
  count             = var.enable_hitl ? 1 : 0
  name              = "/aws/lambda/${local.api_name}-complete-section-review"
  retention_in_days = var.log_retention_days
  kms_key_id        = local.encryption_key_arn
  tags              = var.tags
}

data "archive_file" "complete_section_review" {
  count       = var.enable_hitl ? 1 : 0
  type        = "zip"
  source_dir  = "${path.module}/../../sources/src/lambda/complete_section_review"
  output_path = "${path.module}/../../.terraform/archives/complete_section_review.zip"
}

resource "aws_lambda_function" "complete_section_review" {
  count            = var.enable_hitl ? 1 : 0
  function_name    = "${local.api_name}-complete-section-review"
  role             = aws_iam_role.complete_section_review[0].arn
  filename         = data.archive_file.complete_section_review[0].output_path
  source_code_hash = data.archive_file.complete_section_review[0].output_base64sha256
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 60
  memory_size      = 256
  layers           = compact([var.base_layer_arn, var.idp_common_layer_arn])

  environment {
    variables = {
      LOG_LEVEL           = var.log_level
      TRACKING_TABLE_NAME = local.tracking_table_name != null ? local.tracking_table_name : ""
      OUTPUT_BUCKET       = local.output_bucket_name
      INPUT_BUCKET        = local.input_bucket_name
      WORKING_BUCKET      = local.working_bucket_name != null ? local.working_bucket_name : ""
      QUEUE_URL           = local.document_queue_url != null ? local.document_queue_url : ""
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

  depends_on = [aws_cloudwatch_log_group.complete_section_review]
  tags       = var.tags
}

# =============================================================================
# AppSync data source + resolvers for HITL operations
# =============================================================================

resource "aws_appsync_datasource" "complete_section_review" {
  count            = var.enable_hitl ? 1 : 0
  api_id           = aws_appsync_graphql_api.api.id
  name             = "CompleteSectionReviewDS"
  type             = "AWS_LAMBDA"
  service_role_arn = aws_iam_role.appsync_lambda_role.arn
  lambda_config { function_arn = aws_lambda_function.complete_section_review[0].arn }
}

resource "aws_appsync_resolver" "claim_review" {
  count       = var.enable_hitl ? 1 : 0
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Mutation"
  field       = "claimReview"
  data_source = aws_appsync_datasource.complete_section_review[0].name
}

resource "aws_appsync_resolver" "release_review" {
  count       = var.enable_hitl ? 1 : 0
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Mutation"
  field       = "releaseReview"
  data_source = aws_appsync_datasource.complete_section_review[0].name
}

resource "aws_appsync_resolver" "skip_all_sections_review" {
  count       = var.enable_hitl ? 1 : 0
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Mutation"
  field       = "skipAllSectionsReview"
  data_source = aws_appsync_datasource.complete_section_review[0].name
}

resource "aws_appsync_resolver" "complete_section_review" {
  count       = var.enable_hitl ? 1 : 0
  api_id      = aws_appsync_graphql_api.api.id
  type        = "Mutation"
  field       = "completeSectionReview"
  data_source = aws_appsync_datasource.complete_section_review[0].name
}

# Allow AppSync to invoke the complete_section_review Lambda
resource "aws_iam_policy" "appsync_invoke_hitl_policy" {
  count       = var.enable_hitl ? 1 : 0
  name        = "${local.api_name}-appsync-invoke-hitl"
  description = "Allow AppSync to invoke complete_section_review Lambda"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "lambda:InvokeFunction"
      Resource = aws_lambda_function.complete_section_review[0].arn
    }]
  })
}

resource "aws_iam_role_policy_attachment" "appsync_invoke_hitl" {
  count      = var.enable_hitl ? 1 : 0
  role       = aws_iam_role.appsync_lambda_role.name
  policy_arn = aws_iam_policy.appsync_invoke_hitl_policy[0].arn
}

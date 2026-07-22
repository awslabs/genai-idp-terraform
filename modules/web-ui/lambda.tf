# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# UI CodeBuild trigger Lambda (CodeBuild path only).
# All resources in this file are gated on var.ui_local = false.

# Ensure build directory exists
resource "null_resource" "create_lambda_build_dir" {
  count = var.ui_local ? 0 : 1

  provisioner "local-exec" {
    command = "mkdir -p ${local.module_build_dir}"
  }

  triggers = {
    build_id = random_id.build_id.hex
  }
}

# Package Lambda function for UI CodeBuild triggering
data "archive_file" "ui_codebuild_trigger_lambda" {
  count       = var.ui_local ? 0 : 1
  type        = "zip"
  source_dir  = "${path.module}/../../src/lambda/ui-codebuild-trigger"
  output_path = "${local.module_build_dir}/ui-codebuild-trigger-lambda.zip"

  depends_on = [null_resource.create_lambda_build_dir]
}

# IAM role for Lambda function
resource "aws_iam_role" "ui_codebuild_trigger_lambda_role" {
  count = var.ui_local ? 0 : 1
  name  = "${var.name_prefix}-ui-cb-trigger-${random_string.suffix.result}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

# IAM policy for Lambda function
resource "aws_iam_role_policy" "ui_codebuild_trigger_lambda_policy" {
  count = var.ui_local ? 0 : 1
  name  = "UICodeBuildTriggerLambdaPolicy"
  role  = aws_iam_role.ui_codebuild_trigger_lambda_role[0].id

  # The CloudFront invalidation statement is appended via concat() only when a
  # distribution exists (CloudFront hosting). In ALB mode there is no
  # distribution, so the statement is omitted entirely rather than emitted with
  # an empty Resource list (IAM rejects statements without resources).
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:GetLogEvents"
        ]
        Resource = [
          "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.name_prefix}-ui-cb-trigger-*",
          "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/${var.name_prefix}-ui-build-${random_string.suffix.result}",
          "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/${var.name_prefix}-ui-build-${random_string.suffix.result}:*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "codebuild:StartBuild",
          "codebuild:BatchGetBuilds"
        ]
        Resource = [
          aws_codebuild_project.ui_build[0].arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = [
          local.web_app_bucket.bucket_arn,
          "${local.web_app_bucket.bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter"
        ]
        Resource = [
          aws_ssm_parameter.web_ui_settings.arn
        ]
      }
      ],
      local.cloudfront_distribution_id != null ? [
        {
          Effect = "Allow"
          Action = [
            "cloudfront:ListInvalidations",
            "cloudfront:GetInvalidation"
          ]
          Resource = [
            "arn:${data.aws_partition.current.partition}:cloudfront::${data.aws_caller_identity.current.account_id}:distribution/${local.cloudfront_distribution_id}"
          ]
        }
    ] : [])
  })
}

# CloudWatch log group for Lambda function
resource "aws_cloudwatch_log_group" "ui_codebuild_trigger_lambda_logs" {
  count             = var.ui_local ? 0 : 1
  name              = "/aws/lambda/${var.name_prefix}-ui-cb-trigger-${random_string.suffix.result}"
  retention_in_days = 14

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-ui-codebuild-trigger-lambda-logs"
  })
}

# Lambda function for triggering UI CodeBuild
resource "aws_lambda_function" "ui_codebuild_trigger" {
  architectures = [var.lambda_architecture]
  count         = var.ui_local ? 0 : 1
  filename      = data.archive_file.ui_codebuild_trigger_lambda[0].output_path
  function_name = "${var.name_prefix}-ui-cb-trigger-${random_string.suffix.result}"
  role          = aws_iam_role.ui_codebuild_trigger_lambda_role[0].arn
  handler       = "index.lambda_handler"
  runtime       = "python3.12"
  timeout       = 900 # 15 minutes maximum for Lambda
  memory_size   = 256

  source_code_hash = data.archive_file.ui_codebuild_trigger_lambda[0].output_base64sha256

  tracing_config {
    mode = var.lambda_tracing_mode
  }

  depends_on = [
    aws_cloudwatch_log_group.ui_codebuild_trigger_lambda_logs,
    aws_iam_role_policy.ui_codebuild_trigger_lambda_policy
  ]

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-ui-codebuild-trigger"
  })
}

# Invoke Lambda function to trigger UI CodeBuild
resource "aws_lambda_invocation" "trigger_ui_codebuild" {
  count         = var.ui_local ? 0 : 1
  function_name = aws_lambda_function.ui_codebuild_trigger[0].function_name

  input = jsonencode({
    codebuild_project_name     = aws_codebuild_project.ui_build[0].name
    settings_parameter         = aws_ssm_parameter.web_ui_settings.name
    code_location              = "${local.web_app_bucket.bucket_name}/code/ui-source.zip"
    webapp_bucket              = local.web_app_bucket.bucket_name
    cloudfront_distribution_id = local.cloudfront_distribution_id
    settings_hash = sha256(jsonencode({
      user_pool_id               = var.user_identity.user_pool.user_pool_id
      user_pool_client_id        = var.user_identity.user_pool_client.user_pool_client_id
      identity_pool_id           = var.user_identity.identity_pool.identity_pool_id
      appsync_url                = var.api_url
      cloudfront_domain          = local.cloudfront_domain_name
      knowledge_base_enabled     = var.knowledge_base_enabled
      discovery_bucket_name      = var.discovery_bucket_name
      reporting_bucket_name      = var.reporting_bucket_name
      evaluation_baseline_bucket = var.evaluation_baseline_bucket_name
      idp_pattern                = var.idp_pattern
    }))
    buildspec_hash   = md5(aws_codebuild_project.ui_build[0].source[0].buildspec)
    source_code_hash = data.archive_file.ui_source.output_base64sha256
  })

  triggers = {
    # Trigger when UI settings change
    settings_hash = sha256(jsonencode({
      user_pool_id               = var.user_identity.user_pool.user_pool_id
      user_pool_client_id        = var.user_identity.user_pool_client.user_pool_client_id
      identity_pool_id           = var.user_identity.identity_pool.identity_pool_id
      appsync_url                = var.api_url
      cloudfront_domain          = local.cloudfront_domain_name
      knowledge_base_enabled     = var.knowledge_base_enabled
      discovery_bucket_name      = var.discovery_bucket_name
      reporting_bucket_name      = var.reporting_bucket_name
      evaluation_baseline_bucket = var.evaluation_baseline_bucket_name
      idp_pattern                = var.idp_pattern
    }))
    # Trigger when CodeBuild project changes
    codebuild_project = aws_codebuild_project.ui_build[0].name
    # Trigger when source code changes
    source_code_hash = data.archive_file.ui_source.output_base64sha256
    # Trigger when buildspec changes
    buildspec_hash = md5(aws_codebuild_project.ui_build[0].source[0].buildspec)
  }

  depends_on = [
    aws_codebuild_project.ui_build,
    data.archive_file.ui_source,
    aws_s3_object.react_app_source,
    aws_ssm_parameter.web_ui_settings,
    time_sleep.wait_for_iam_propagation
  ]
}

# Parse the Lambda invocation result (CodeBuild path only)
locals {
  ui_build_result  = !var.ui_local ? jsondecode(aws_lambda_invocation.trigger_ui_codebuild[0].result) : { statusCode = 0 }
  ui_build_success = !var.ui_local ? local.ui_build_result.statusCode == 200 : true
}

# Build artifact cleanup is handled in main.tf

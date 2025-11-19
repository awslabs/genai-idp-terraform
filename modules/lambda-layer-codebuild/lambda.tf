# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#

# Ensure build directory exists
resource "null_resource" "create_lambda_build_dir" {
  provisioner "local-exec" {
    command = "mkdir -p ${local.module_build_dir}"
  }

  triggers = {
    build_id = random_id.build_id.hex
  }
}

# Package Lambda function for CodeBuild triggering
data "archive_file" "codebuild_trigger_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/../../src/lambda/layer-codebuild-trigger"
  output_path = "${local.module_build_dir}/codebuild-trigger-lambda.zip"

  depends_on = [null_resource.create_lambda_build_dir]
}

# IAM role for Lambda function
resource "aws_iam_role" "codebuild_trigger_lambda_role" {
  name = "${var.name_prefix}-cb-trigger-${random_string.layer_suffix.result}"

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
}

# IAM policy for Lambda function
resource "aws_iam_role_policy" "codebuild_trigger_lambda_policy" {
  name = "CodeBuildTriggerLambdaPolicy"
  role = aws_iam_role.codebuild_trigger_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
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
          "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.name_prefix}-codebuild-trigger-*",
          "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/${var.name_prefix}-lambda-layers-${random_string.layer_suffix.result}",
          "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/${var.name_prefix}-lambda-layers-${random_string.layer_suffix.result}:*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "codebuild:StartBuild",
          "codebuild:BatchGetBuilds"
        ]
        Resource = [
          aws_codebuild_project.lambda_layers_build.arn
        ]
      }
    ]
  })
}

# CloudWatch log group for Lambda function
resource "aws_cloudwatch_log_group" "codebuild_trigger_lambda_logs" {
  name              = "/aws/lambda/${var.name_prefix}-cb-trigger-${random_string.layer_suffix.result}"
  retention_in_days = 14

  tags = {
    Name = "${var.name_prefix}-codebuild-trigger-lambda-logs"
  }
}

# Lambda function for triggering CodeBuild
resource "aws_lambda_function" "codebuild_trigger" {
  filename      = data.archive_file.codebuild_trigger_lambda.output_path
  function_name = "${var.name_prefix}-cb-trigger-${random_string.layer_suffix.result}"
  role          = aws_iam_role.codebuild_trigger_lambda_role.arn
  handler       = "index.lambda_handler"
  runtime       = "python3.12"
  timeout       = 900 # 15 minutes maximum for Lambda
  memory_size   = 256

  source_code_hash = data.archive_file.codebuild_trigger_lambda.output_base64sha256

  tracing_config {
    mode = var.lambda_tracing_mode
  }

  depends_on = [
    aws_cloudwatch_log_group.codebuild_trigger_lambda_logs,
    aws_iam_role_policy.codebuild_trigger_lambda_policy
  ]

  tags = {
    Name = "${var.name_prefix}-codebuild-trigger"
  }
}

# Invoke Lambda function to trigger CodeBuild
resource "aws_lambda_invocation" "trigger_codebuild" {
  function_name = aws_lambda_function.codebuild_trigger.function_name

  input = jsonencode({
    codebuild_project_name = aws_codebuild_project.lambda_layers_build.name
    requirements_hash = var.requirements_hash != "" ? var.requirements_hash : md5(jsonencode({
      for k, v in var.requirements_files : k => v
    }))
    force_rebuild  = var.force_rebuild
    buildspec_hash = md5(aws_codebuild_project.lambda_layers_build.source[0].buildspec)
    environment_variables = {
      LAMBDA_LAYERS_BUCKET = local.lambda_layers_bucket_name
    }
  })

  triggers = {
    # Only trigger when requirements actually change
    requirements_hash = var.requirements_hash != "" ? var.requirements_hash : md5(jsonencode({
      for k, v in var.requirements_files : k => v
    }))
    # Only use timestamp for force_rebuild if explicitly requested
    force_rebuild = var.force_rebuild ? timestamp() : "static"
    # Trigger when buildspec changes
    buildspec_hash = md5(aws_codebuild_project.lambda_layers_build.source[0].buildspec)
    # Trigger when S3 source changes (key or content)
    s3_source_key = aws_s3_object.requirements_source.key
  }

  depends_on = [
    aws_codebuild_project.lambda_layers_build,
    aws_iam_role_policy.codebuild_policy,
    aws_s3_object.requirements_source,
    time_sleep.wait_for_iam_propagation
  ]
}

# Parse the Lambda invocation result
locals {
  build_result  = jsondecode(aws_lambda_invocation.trigger_codebuild.result)
  build_success = local.build_result.statusCode == 200
}

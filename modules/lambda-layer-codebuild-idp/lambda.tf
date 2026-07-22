# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Trigger Lambda for the CodeBuild path. Every resource gates on
# `local.use_local_build ? 0 : 1`. When local builds are selected, the
# trigger Lambda + IAM + log group + invocation all disappear.

resource "null_resource" "create_lambda_build_dir" {
  count = local.use_local_build ? 0 : 1

  provisioner "local-exec" {
    command = "mkdir -p ${local.module_build_dir}"
  }

  triggers = {
    build_id = random_id.build_id.hex
  }
}

# Unconditional data source -- safe when consumers are absent.
data "archive_file" "codebuild_trigger_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/../../src/lambda/idp-layer-codebuild-trigger"
  output_path = "${local.module_build_dir}/codebuild-trigger-lambda.zip"

  depends_on = [null_resource.create_lambda_build_dir]
}

resource "aws_iam_role" "codebuild_trigger_lambda_role" {
  count = local.use_local_build ? 0 : 1

  name = "${var.layer_prefix}-cb-trigger-${random_string.layer_suffix.result}"

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

resource "aws_iam_role_policy" "codebuild_trigger_lambda_policy" {
  count = local.use_local_build ? 0 : 1

  name = "CodeBuildTriggerLambdaPolicy"
  role = aws_iam_role.codebuild_trigger_lambda_role[0].id

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
          "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.layer_prefix}-codebuild-trigger-*",
          "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/${var.layer_prefix}-lambda-layers-${random_string.layer_suffix.result}",
          "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/${var.layer_prefix}-lambda-layers-${random_string.layer_suffix.result}:*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "codebuild:StartBuild",
          "codebuild:BatchGetBuilds"
        ]
        Resource = [
          aws_codebuild_project.lambda_layers_build[0].arn
        ]
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "codebuild_trigger_lambda_logs" {
  count = local.use_local_build ? 0 : 1

  name              = "/aws/lambda/${var.layer_prefix}-cb-trigger-${random_string.layer_suffix.result}"
  retention_in_days = 14

  tags = {
    Name = "${var.layer_prefix}-codebuild-trigger-lambda-logs"
  }
}

resource "aws_lambda_function" "codebuild_trigger" {
  architectures = [var.lambda_architecture]
  count         = local.use_local_build ? 0 : 1

  filename      = data.archive_file.codebuild_trigger_lambda.output_path
  function_name = "${var.layer_prefix}-cb-trigger-${random_string.layer_suffix.result}"
  role          = aws_iam_role.codebuild_trigger_lambda_role[0].arn
  handler       = "index.lambda_handler"
  runtime       = "python3.12"
  timeout       = 900
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
    Name = "${var.layer_prefix}-codebuild-trigger"
  }
}

resource "aws_lambda_invocation" "trigger_codebuild" {
  count = local.use_local_build ? 0 : 1

  function_name = aws_lambda_function.codebuild_trigger[0].function_name

  input = jsonencode({
    codebuild_project_name = aws_codebuild_project.lambda_layers_build[0].name
    requirements_hash = var.requirements_hash != "" ? var.requirements_hash : md5(jsonencode({
      for k, v in var.requirements_files : k => v
    }))
    idp_common_extras     = var.idp_common_extras
    force_rebuild         = var.force_rebuild
    buildspec_hash        = md5(aws_codebuild_project.lambda_layers_build[0].source[0].buildspec)
    idp_common_files_hash = local.idp_common_files_hash
  })

  triggers = {
    requirements_hash = var.requirements_hash != "" ? var.requirements_hash : md5(jsonencode({
      for k, v in var.requirements_files : k => v
    }))
    force_rebuild         = var.force_rebuild ? timestamp() : "static"
    buildspec_hash        = md5(aws_codebuild_project.lambda_layers_build[0].source[0].buildspec)
    idp_common_extras     = join(",", var.idp_common_extras)
    idp_common_files_hash = local.idp_common_files_hash
  }

  depends_on = [
    aws_codebuild_project.lambda_layers_build,
    aws_iam_role_policy.codebuild_policy,
    aws_s3_object.requirements_source,
    time_sleep.wait_for_iam_propagation
  ]
}

# CodeBuild path result parsing. Locals are gated so the references stay
# valid in local mode.
locals {
  build_result = local.use_local_build ? null : (
    length(aws_lambda_invocation.trigger_codebuild) > 0 ?
    jsondecode(aws_lambda_invocation.trigger_codebuild[0].result) :
    null
  )
  build_success = local.use_local_build ? null : (
    local.build_result != null ? local.build_result.statusCode == 200 : null
  )
}

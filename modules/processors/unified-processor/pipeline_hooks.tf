# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Pipeline Hooks Dispatcher
#
# Invoked by the state machine at post-step extension points (postOcr,
# postClassification, postExtraction, postAssessment, postRuleValidation,
# postSummarization). Reads the active configuration version's
# `<step>.postHook` list from the ConfigurationTable and fans out to the
# registered hook Lambdas in order. Inert by default: with no `postHook`
# config the dispatcher returns after a single config read and the pipeline
# is unchanged. Mirrors upstream IDP v0.5.16 (patterns/unified).

data "archive_file" "pipeline_hooks_dispatcher" {
  type        = "zip"
  source_dir  = "${path.module}/../../../sources/patterns/unified/src/pipeline_hooks_function"
  output_path = "${path.module}/pipeline_hooks_function.zip"

  depends_on = [null_resource.create_module_build_dir]
}

resource "aws_iam_role" "pipeline_hooks_dispatcher" {
  name = "${local.name_prefix}-pipeline-hooks-dispatcher-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.${data.aws_partition.current.dns_suffix}" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "pipeline_hooks_dispatcher_basic" {
  role       = aws_iam_role.pipeline_hooks_dispatcher.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "pipeline_hooks_dispatcher_vpc" {
  count      = length(local.vpc_subnet_ids) > 0 ? 1 : 0
  role       = aws_iam_role.pipeline_hooks_dispatcher.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "pipeline_hooks_dispatcher" {
  name = "${local.name_prefix}-pipeline-hooks-dispatcher-policy"
  role = aws_iam_role.pipeline_hooks_dispatcher.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        # Read the active configuration version and its inline `<step>.postHook`
        # lists. GetItem on any Config#* row plus Scan to find IsActive=true.
        {
          Effect   = "Allow"
          Action   = ["dynamodb:GetItem", "dynamodb:Scan"]
          Resource = local.configuration_table_arn
        },
        # Two parallel allow paths for hook Lambdas (fail closed otherwise):
        #   1. Tag-based ABAC for vertical-product packs (idp:feature-id tag).
        #   2. Name-prefix GENAIIDP-* for admin-managed hook Lambdas.
        {
          Effect   = "Allow"
          Action   = "lambda:InvokeFunction"
          Resource = "arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:function:*"
          Condition = {
            StringLike = { "aws:ResourceTag/idp:feature-id" = "*" }
          }
        },
        {
          Effect   = "Allow"
          Action   = "lambda:InvokeFunction"
          Resource = "arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:function:GENAIIDP-*"
        }
      ],
      var.encryption_key_arn != null ? [{
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:DescribeKey"]
        Resource = var.encryption_key_arn
      }] : []
    )
  })
}

resource "aws_lambda_function" "pipeline_hooks_dispatcher" {
  architectures = [var.lambda_architecture]
  function_name = "${local.name_prefix}-pipeline-hooks-dispatcher"
  role          = aws_iam_role.pipeline_hooks_dispatcher.arn
  handler       = "index.lambda_handler"
  runtime       = "python3.12"
  timeout       = 60
  memory_size   = 256

  filename         = data.archive_file.pipeline_hooks_dispatcher.output_path
  source_code_hash = data.archive_file.pipeline_hooks_dispatcher.output_base64sha256

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = {
      LOG_LEVEL                = local.log_level
      CONFIGURATION_TABLE_NAME = local.configuration_table_name
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

resource "aws_cloudwatch_log_group" "pipeline_hooks_dispatcher" {
  name              = "/aws/lambda/${aws_lambda_function.pipeline_hooks_dispatcher.function_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.encryption_key_arn

  tags = local.common_tags
}

# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# IAM for the BDA branch Lambda functions, gated on use_bda (only the
# bda-processor façade renders these). Mirrors upstream template.yaml policies
# for InvokeBDAFunction / BDAProcessResultsFunction / BDACompletionFunction.

# BDA Invoke Lambda role

resource "aws_iam_role" "bda_invoke_lambda" {
  count = var.use_bda ? 1 : 0

  name = "${local.name_prefix}-bda-invoke-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "bda_invoke_lambda_basic" {
  count = var.use_bda ? 1 : 0

  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.bda_invoke_lambda[0].name
}

resource "aws_iam_role_policy" "bda_invoke_lambda" {
  count = var.use_bda ? 1 : 0

  name = "${local.name_prefix}-bda-invoke-lambda-policy"
  role = aws_iam_role.bda_invoke_lambda[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:ListBucket"
          ]
          Resource = [
            local.input_bucket_arn,
            "${local.input_bucket_arn}/*"
          ]
        },
        {
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:PutObject",
            "s3:ListBucket"
          ]
          Resource = [
            local.output_bucket_arn,
            "${local.output_bucket_arn}/*",
            local.working_bucket_arn,
            "${local.working_bucket_arn}/*"
          ]
        },
        {
          # Task-token tracking record write/read for the async BDA handshake.
          Effect = "Allow"
          Action = [
            "dynamodb:GetItem",
            "dynamodb:PutItem",
            "dynamodb:UpdateItem",
            "dynamodb:DeleteItem"
          ]
          Resource = [
            local.tracking_table_arn,
            "${local.tracking_table_arn}/index/*"
          ]
        },
        {
          # Start the async BDA job, scoped to data-automation project/profile resources.
          Effect = "Allow"
          Action = [
            "bedrock:InvokeDataAutomationAsync"
          ]
          Resource = [
            "arn:${data.aws_partition.current.partition}:bedrock:*:${data.aws_caller_identity.current.account_id}:data-automation-project/*",
            "arn:${data.aws_partition.current.partition}:bedrock:*:${data.aws_caller_identity.current.account_id}:data-automation-profile/*.data-automation-v1"
          ]
        },
        {
          Effect   = "Allow"
          Action   = ["cloudwatch:PutMetricData"]
          Resource = "*"
          Condition = {
            StringEquals = { "cloudwatch:namespace" = local.metric_namespace }
          }
        }
      ],
      var.enable_encryption ? [{
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = local.encryption_key_arn
      }] : []
    )
  })
}

resource "aws_iam_role_policy_attachment" "bda_invoke_lambda_vpc" {
  count = var.use_bda && length(var.vpc_subnet_ids) > 0 ? 1 : 0

  role       = aws_iam_role.bda_invoke_lambda[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# BDA Process Results Lambda role

resource "aws_iam_role" "bda_process_results_lambda" {
  count = var.use_bda ? 1 : 0

  name = "${local.name_prefix}-bda-process-results-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "bda_process_results_lambda_basic" {
  count = var.use_bda ? 1 : 0

  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.bda_process_results_lambda[0].name
}

resource "aws_iam_role_policy" "bda_process_results_lambda" {
  count = var.use_bda ? 1 : 0

  name = "${local.name_prefix}-bda-process-results-lambda-policy"
  role = aws_iam_role.bda_process_results_lambda[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:ListBucket"
          ]
          Resource = [
            local.input_bucket_arn,
            "${local.input_bucket_arn}/*"
          ]
        },
        {
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:PutObject",
            "s3:DeleteObject",
            "s3:ListBucket"
          ]
          Resource = [
            local.output_bucket_arn,
            "${local.output_bucket_arn}/*",
            local.working_bucket_arn,
            "${local.working_bucket_arn}/*"
          ]
        },
        {
          Effect = "Allow"
          Action = [
            "dynamodb:GetItem",
            "dynamodb:PutItem",
            "dynamodb:UpdateItem",
            "dynamodb:Query",
            "dynamodb:Scan"
          ]
          Resource = [
            local.configuration_table_arn,
            "${local.configuration_table_arn}/index/*",
            local.tracking_table_arn,
            "${local.tracking_table_arn}/index/*"
          ]
        },
        {
          Effect = "Allow"
          Action = [
            "appsync:GraphQL"
          ]
          Resource = local.api_arn != null ? [
            "${local.api_arn}/types/Query/*",
            "${local.api_arn}/types/Mutation/*"
          ] : ["*"]
        },
        {
          # process_results reads stack settings via SSM (idp_common settings_helper).
          Effect = "Allow"
          Action = [
            "ssm:GetParameter",
            "ssm:GetParametersByPath"
          ]
          Resource = "arn:${data.aws_partition.current.partition}:ssm:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:parameter/*"
        },
        {
          # Resolve BDA project/blueprint metadata while shaping results.
          Effect = "Allow"
          Action = [
            "bedrock:GetDataAutomationProject",
            "bedrock:ListDataAutomationProjects",
            "bedrock:GetBlueprint",
            "bedrock:GetBlueprintRecommendation"
          ]
          Resource = "*"
        },
        {
          Effect   = "Allow"
          Action   = ["cloudwatch:PutMetricData"]
          Resource = "*"
          Condition = {
            StringEquals = { "cloudwatch:namespace" = local.metric_namespace }
          }
        }
      ],
      var.enable_encryption ? [{
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = local.encryption_key_arn
      }] : []
    )
  })
}

resource "aws_iam_role_policy_attachment" "bda_process_results_lambda_vpc" {
  count = var.use_bda && length(var.vpc_subnet_ids) > 0 ? 1 : 0

  role       = aws_iam_role.bda_process_results_lambda[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# BDA Completion Lambda role
# Resumes the waiting Step Functions task via SendTaskSuccess/Failure.

resource "aws_iam_role" "bda_completion_lambda" {
  count = var.use_bda ? 1 : 0

  name = "${local.name_prefix}-bda-completion-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "bda_completion_lambda_basic" {
  count = var.use_bda ? 1 : 0

  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.bda_completion_lambda[0].name
}

resource "aws_iam_role_policy" "bda_completion_lambda" {
  count = var.use_bda ? 1 : 0

  name = "${local.name_prefix}-bda-completion-lambda-policy"
  role = aws_iam_role.bda_completion_lambda[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          # Resume the waiting BDA_InvokeDataAutomation task token.
          Effect = "Allow"
          Action = [
            "states:SendTaskSuccess",
            "states:SendTaskFailure",
            "states:SendTaskHeartbeat"
          ]
          Resource = aws_sfn_state_machine.document_processing.arn
        },
        {
          Effect = "Allow"
          Action = [
            "dynamodb:GetItem",
            "dynamodb:DeleteItem"
          ]
          Resource = [
            local.tracking_table_arn,
            "${local.tracking_table_arn}/index/*"
          ]
        },
        {
          Effect   = "Allow"
          Action   = ["sqs:SendMessage"]
          Resource = aws_sqs_queue.bda_completion_dlq[0].arn
        },
        {
          Effect   = "Allow"
          Action   = ["cloudwatch:PutMetricData"]
          Resource = "*"
          Condition = {
            StringEquals = { "cloudwatch:namespace" = local.metric_namespace }
          }
        }
      ],
      var.enable_encryption ? [{
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = local.encryption_key_arn
      }] : []
    )
  })
}

resource "aws_iam_role_policy_attachment" "bda_completion_lambda_vpc" {
  count = var.use_bda && length(var.vpc_subnet_ids) > 0 ? 1 : 0

  role       = aws_iam_role.bda_completion_lambda[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

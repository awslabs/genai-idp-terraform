# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

# Registry-compatible build directory approach
locals {
  # Module-specific build directory that works both locally and in registry
  module_build_dir = "${path.module}/.terraform-build"
  # Unique identifier for this module instance
  module_instance_id = substr(md5("${path.module}-evaluation-functions"), 0, 8)
}

# CloudWatch Log Group for Evaluation function
resource "aws_cloudwatch_log_group" "evaluation_log_group" {
  count = var.evaluation_config != null ? 1 : 0

  name              = "/aws/lambda/${aws_lambda_function.evaluation[0].function_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.encryption_key_arn

  tags = var.tags
}

# Source code archive for Evaluation function
# Generate unique build ID for this configuration

# Create temporary directory for build artifacts

# Create module-specific build directory
resource "null_resource" "create_module_build_dir" {
  provisioner "local-exec" {
    command = "mkdir -p ${local.module_build_dir}"
  }
}

# Generate unique build ID for this module instance
resource "random_id" "build_id" {
  byte_length = 8
  keepers = {
    # Include module instance ID for uniqueness
    module_instance_id = local.module_instance_id
    # Trigger rebuild when content changes
    content_hash = md5("evaluation-functions")
  }
}

data "archive_file" "evaluation_code" {
  count = var.evaluation_config != null ? 1 : 0

  type        = "zip"
  source_dir  = "${path.module}/../../sources/src/lambda/evaluation_function"
  output_path = "${local.module_build_dir}/evaluation-function.zip_${random_id.build_id.hex}"

  # Exclude any potential dependencies that might be there
  excludes = [
    "*.so",
    "*.dist-info/**",
    "*.egg-info/**",
    "__pycache__/**",
    "*.pyc",
    "boto3/**",
    "botocore/**"
  ]

  depends_on = [null_resource.create_module_build_dir]
}

# Evaluation Lambda Function
resource "aws_lambda_function" "evaluation" {
  count = var.evaluation_config != null ? 1 : 0

  function_name = "idp-evaluation-${random_string.suffix.result}"

  filename         = data.archive_file.evaluation_code[0].output_path
  source_code_hash = data.archive_file.evaluation_code[0].output_base64sha256

  handler     = "index.handler"
  runtime     = "python3.12"
  timeout     = 30
  memory_size = 512
  role        = aws_iam_role.evaluation_role[0].arn
  description = "Lambda function that evaluates extraction results against baseline documents"

  # Use the idp_common layer for evaluation functionality
  layers = [var.idp_common_layer_arn]

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = {
      LOG_LEVEL                    = var.log_level
      METRIC_NAMESPACE             = var.metric_namespace
      TRACKING_TABLE               = local.tracking_table.table_name
      PROCESSING_OUTPUT_BUCKET     = local.output_bucket_name
      EVALUATION_OUTPUT_BUCKET     = local.output_bucket_name
      BASELINE_BUCKET              = local.baseline_bucket_name
      CONFIGURATION_TABLE_NAME     = local.configuration_table.table_name
      DOCUMENT_TRACKING_MODE       = var.api != null ? "appsync" : "dynamodb"
      APPSYNC_API_URL              = var.api != null ? var.api.graphql_url : ""
      REPORTING_BUCKET             = var.enable_reporting ? local.reporting_bucket_name : ""
      SAVE_REPORTING_FUNCTION_NAME = var.enable_reporting ? aws_lambda_function.save_reporting_data[0].function_name : ""
    }
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.evaluation_dlq[0].arn
  }

  dynamic "vpc_config" {
    for_each = length(var.subnet_ids) > 0 ? [1] : []
    content {
      subnet_ids         = var.subnet_ids
      security_group_ids = var.security_group_ids
    }
  }

  tracing_config {
    mode = var.lambda_tracing_mode
  }

  # Ensure all IAM policy attachments are complete before creating the Lambda function
  depends_on = [
    aws_iam_role_policy_attachment.evaluation_policy_attachment[0],
    aws_iam_role_policy_attachment.evaluation_kms_attachment,
    aws_iam_role_policy_attachment.evaluation_vpc_attachment
  ]

  tags = var.tags
}

# SQS Dead Letter Queue for Evaluation function
resource "aws_sqs_queue" "evaluation_dlq" {
  count = var.evaluation_config != null ? 1 : 0

  name                       = "idp-evaluation-dlq-${random_string.suffix.result}"
  message_retention_seconds  = 345600 # 4 days
  visibility_timeout_seconds = 30

  kms_master_key_id = local.key != null ? local.key.key_arn : null

  tags = var.tags
}

# IAM Role for Evaluation Lambda Function
resource "aws_iam_role" "evaluation_role" {
  count = var.evaluation_config != null ? 1 : 0

  name = "idp-evaluation-role-${random_string.suffix.result}"

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

  tags = var.tags
}

# IAM Policy for Evaluation Lambda Function
resource "aws_iam_policy" "evaluation_policy" {
  count = var.evaluation_config != null ? 1 : 0

  name        = "idp-evaluation-policy-${random_string.suffix.result}"
  description = "Policy for Evaluation Lambda Function"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:${data.aws_partition.current.partition}:logs:*:*:*"
      },
      {
        Action = [
          "sqs:SendMessage"
        ]
        Effect   = "Allow"
        Resource = aws_sqs_queue.evaluation_dlq[0].arn
      },
      {
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Effect = "Allow"
        Resource = [
          local.tracking_table.table_arn,
          "${local.tracking_table.table_arn}/index/*"
        ]
      },
      {
        Action = [
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Effect = "Allow"
        Resource = [
          local.configuration_table.table_arn,
          "${local.configuration_table.table_arn}/index/*"
        ]
      },
      {
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = [
          var.evaluation_config.baseline_bucket_arn,
          "${var.evaluation_config.baseline_bucket_arn}/*"
        ]
      },
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = [
          var.output_bucket_arn,
          "${var.output_bucket_arn}/*"
        ]
      },
      {
        Action = [
          "bedrock:InvokeModel"
        ]
        Effect   = "Allow"
        Resource = var.evaluation_config.evaluation_model_arn
      },
      {
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Effect   = "Allow"
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = var.metric_namespace
          }
        }
      },
      {
        Action = [
          "lambda:InvokeFunction"
        ]
        Effect   = "Allow"
        Resource = var.enable_reporting ? aws_lambda_function.save_reporting_data[0].arn : "*"
        Condition = var.enable_reporting ? {} : {
          "Bool" = {
            "aws:RequestedRegion" = "false" # This condition will never be true, effectively disabling this statement when enable_reporting is false
          }
        }
      }
    ]
  })
}

# Attach policy to Evaluation role
resource "aws_iam_role_policy_attachment" "evaluation_policy_attachment" {
  count = var.evaluation_config != null ? 1 : 0

  role       = aws_iam_role.evaluation_role[0].name
  policy_arn = aws_iam_policy.evaluation_policy[0].arn
}

# Add KMS permissions if key is provided
resource "aws_iam_policy" "evaluation_kms_policy" {
  for_each = var.evaluation_config != null ? toset(["enabled"]) : toset([])

  name        = "idp-evaluation-kms-policy-${random_string.suffix.result}"
  description = "KMS policy for Evaluation Lambda Function"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Effect   = "Allow"
        Resource = var.encryption_key_arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "evaluation_kms_attachment" {
  for_each = var.evaluation_config != null ? toset(["enabled"]) : toset([])

  role       = aws_iam_role.evaluation_role[0].name
  policy_arn = aws_iam_policy.evaluation_kms_policy["enabled"].arn
}

# Add VPC permissions if VPC config is provided
resource "aws_iam_role_policy_attachment" "evaluation_vpc_attachment" {
  count = var.evaluation_config != null && length(var.subnet_ids) > 0 ? 1 : 0

  role       = aws_iam_role.evaluation_role[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Add AppSync permissions if API is provided
resource "aws_iam_policy" "evaluation_appsync_policy" {
  count = var.evaluation_config != null && var.api != null ? 1 : 0

  name        = "idp-evaluation-appsync-policy-${random_string.suffix.result}"
  description = "AppSync policy for Evaluation Lambda Function"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "appsync:GraphQL"
        ]
        Effect   = "Allow"
        Resource = "${var.api.api_arn}/types/Mutation/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "evaluation_appsync_attachment" {
  count = var.evaluation_config != null && var.api != null ? 1 : 0

  role       = aws_iam_role.evaluation_role[0].name
  policy_arn = aws_iam_policy.evaluation_appsync_policy[0].arn
}

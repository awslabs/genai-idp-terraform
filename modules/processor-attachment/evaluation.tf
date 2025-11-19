# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Evaluation function resources (conditional)

# Registry-compatible build directory approach
locals {
  # Module-specific build directory that works both locally and in registry
  module_build_dir = "${path.module}/.terraform-build"
  # Unique identifier for this module instance
  module_instance_id = substr(md5("${path.module}-processor-attachment"), 0, 8)
}

# CloudWatch Log Group for Evaluation Function
resource "aws_cloudwatch_log_group" "evaluation_function" {
  count             = var.evaluation_options != null ? 1 : 0
  name              = "/aws/lambda/${var.name}-evaluation-function-${random_string.suffix.result}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.encryption_key_arn

  tags = var.tags
}

# Evaluation function code
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
    content_hash = md5("processor-attachment-evaluation")
  }
}

data "archive_file" "evaluation_function_code" {
  count       = var.evaluation_options != null ? 1 : 0
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

# IAM Role for Evaluation Lambda Function
resource "aws_iam_role" "evaluation_function_role" {
  count = var.evaluation_options != null ? 1 : 0
  name  = "${var.name}-evaluation-function-role-${random_string.suffix.result}"

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

# Basic execution policy attachment for Evaluation Lambda
resource "aws_iam_role_policy_attachment" "evaluation_function_basic_execution" {
  count      = var.evaluation_options != null ? 1 : 0
  role       = aws_iam_role.evaluation_function_role[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# VPC execution policy attachment for Evaluation Lambda (conditional)
resource "aws_iam_role_policy_attachment" "evaluation_function_vpc_execution" {
  count      = var.evaluation_options != null && length(var.vpc_subnet_ids) > 0 ? 1 : 0
  role       = aws_iam_role.evaluation_function_role[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Custom policy for Evaluation Lambda Function
resource "aws_iam_policy" "evaluation_function_policy" {
  count       = var.evaluation_options != null ? 1 : 0
  name        = "${var.name}-evaluation-function-policy-${random_string.suffix.result}"
  description = "Policy for Evaluation Lambda Function"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # S3 permissions for baseline bucket
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.evaluation_options.baseline_bucket_arn,
          "${var.evaluation_options.baseline_bucket_arn}/*"
        ]
      },
      # S3 permissions for output bucket
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.output_bucket_arn,
          "${var.output_bucket_arn}/*"
        ]
      },
      # S3 permissions for working bucket
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.working_bucket_arn,
          "${var.working_bucket_arn}/*"
        ]
      },
      # DynamoDB permissions for tracking table
      {
        Effect = "Allow"
        Action = [
          "dynamodb:UpdateItem",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:Query"
        ]
        Resource = var.tracking_table_arn
      },
      # DynamoDB permissions for configuration table
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = var.configuration_table_arn
      },
      # AppSync permissions for GraphQL API
      {
        Effect = "Allow"
        Action = [
          "appsync:GraphQL"
        ]
        Resource = "${var.api_arn}/*"
      },
      # Bedrock permissions for evaluation invokable
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel"
        ]
        Resource = local.evaluation_model_arn
      },
      # CloudWatch metrics permissions
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = var.metric_namespace
          }
        }
      },
      # KMS permissions (conditional)
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = var.encryption_key_arn != null ? var.encryption_key_arn : "*"
        Condition = var.encryption_key_arn != null ? {
          StringEquals = {
            "kms:ViaService" = [
              "s3.${data.aws_region.current.id}.amazonaws.com",
              "dynamodb.${data.aws_region.current.id}.amazonaws.com"
            ]
          }
        } : null
      }
    ]
  })

  tags = var.tags
}

# Attach custom policy to the evaluation role
resource "aws_iam_role_policy_attachment" "evaluation_function_custom_policy" {
  count      = var.evaluation_options != null ? 1 : 0
  role       = aws_iam_role.evaluation_function_role[0].name
  policy_arn = aws_iam_policy.evaluation_function_policy[0].arn
}

# Evaluation Lambda Function
resource "aws_lambda_function" "evaluation_function" {
  count            = var.evaluation_options != null ? 1 : 0
  function_name    = "${var.name}-evaluation-function-${random_string.suffix.result}"
  filename         = data.archive_file.evaluation_function_code[0].output_path
  source_code_hash = data.archive_file.evaluation_function_code[0].output_base64sha256
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 30
  memory_size      = 128
  role             = aws_iam_role.evaluation_function_role[0].arn
  description      = "Lambda function that evaluates document extraction results"

  layers = [var.idp_common_layer_arn]

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = {
      LOG_LEVEL                    = var.log_level
      METRIC_NAMESPACE             = var.metric_namespace
      EVALUATION_MODEL_ID          = var.evaluation_options.model_id
      BASELINE_BUCKET              = local.baseline_bucket_name
      OUTPUT_BUCKET                = local.output_bucket_name
      PROCESSING_OUTPUT_BUCKET     = local.output_bucket_name
      EVALUATION_OUTPUT_BUCKET     = local.output_bucket_name
      APPSYNC_API_URL              = var.api_graphql_url
      TRACKING_TABLE               = local.tracking_table_name
      CONFIGURATION_TABLE_NAME     = local.configuration_table_name
      DOCUMENT_TRACKING_MODE       = var.api_id != null ? "appsync" : "dynamodb"
      WORKING_BUCKET               = local.working_bucket_name
      REPORTING_BUCKET             = "" # Not supported in processor-attachment evaluation
      SAVE_REPORTING_FUNCTION_NAME = "" # Not supported in processor-attachment evaluation
    }
  }

  dynamic "vpc_config" {
    for_each = length(var.vpc_subnet_ids) > 0 ? [local.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  tracing_config {
    mode = var.lambda_tracing_mode
  }

  tags = var.tags

  depends_on = [
    aws_iam_role_policy_attachment.evaluation_function_basic_execution,
    aws_iam_role_policy_attachment.evaluation_function_vpc_execution,
    aws_cloudwatch_log_group.evaluation_function,
  ]
}

# EventBridge Rule for Evaluation Function (triggered on successful processing)
resource "aws_cloudwatch_event_rule" "evaluation_function_rule" {
  count       = var.evaluation_options != null ? 1 : 0
  name        = "${var.name}-evaluation-function-rule-${random_string.suffix.result}"
  description = "Rule for triggering evaluation function on successful document processing"

  event_pattern = jsonencode({
    source        = ["aws.states"]
    "detail-type" = ["Step Functions Execution Status Change"]
    detail = {
      stateMachineArn = [var.processor.state_machine_arn]
      status          = ["SUCCEEDED"]
    }
  })

  tags = var.tags
}

# EventBridge Target for Evaluation Function
resource "aws_cloudwatch_event_target" "evaluation_function_target" {
  count     = var.evaluation_options != null ? 1 : 0
  rule      = aws_cloudwatch_event_rule.evaluation_function_rule[0].name
  target_id = "SendToEvaluationFunction"
  arn       = aws_lambda_function.evaluation_function[0].arn

  retry_policy {
    maximum_event_age_in_seconds = 7200 # 2 hours
    maximum_retry_attempts       = 3
  }
}

# Lambda permission for EventBridge to invoke Evaluation Function
resource "aws_lambda_permission" "allow_eventbridge_to_invoke_evaluation" {
  count         = var.evaluation_options != null ? 1 : 0
  statement_id  = "AllowExecutionFromEventBridge-${random_string.suffix.result}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.evaluation_function[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.evaluation_function_rule[0].arn
}

# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

# CloudWatch Log Group for Save Reporting Data function
resource "aws_cloudwatch_log_group" "save_reporting_data_log_group" {
  count = var.enable_reporting ? 1 : 0

  name              = "/aws/lambda/${aws_lambda_function.save_reporting_data[0].function_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.encryption_key_arn

  tags = var.tags
}

# Source code archive for Save Reporting Data function


# Create module-specific build directory

# Generate unique build ID for this module instance

data "archive_file" "save_reporting_data_code" {
  count = var.enable_reporting ? 1 : 0

  type        = "zip"
  source_dir  = "${path.module}/../../sources/src/lambda/save_reporting_data"
  output_path = "${local.module_build_dir}/save-reporting-data.zip_${random_id.build_id.hex}"

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

# Save Reporting Data Lambda Function
resource "aws_lambda_function" "save_reporting_data" {
  count = var.enable_reporting ? 1 : 0

  function_name = "idp-save-reporting-data-${random_string.suffix.result}"

  filename         = data.archive_file.save_reporting_data_code[0].output_path
  source_code_hash = data.archive_file.save_reporting_data_code[0].output_base64sha256

  handler     = "index.handler"
  runtime     = "python3.12"
  timeout     = 300 # 5 minutes as per CDK
  memory_size = 1024
  role        = aws_iam_role.save_reporting_data_role[0].arn
  description = "Lambda function that saves reporting data to the reporting bucket"

  # Use the idp_common layer for reporting functionality
  layers = [var.idp_common_layer_arn]

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = {
      LOG_LEVEL                = "INFO"
      METRIC_NAMESPACE         = var.metric_namespace
      CONFIGURATION_TABLE_NAME = local.configuration_table.table_name
    }
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
    aws_iam_role_policy_attachment.save_reporting_data_policy_attachment[0],
    aws_iam_role_policy_attachment.save_reporting_data_kms_attachment,
    aws_iam_role_policy_attachment.save_reporting_data_vpc_attachment
  ]

  tags = var.tags
}

# IAM Role for Save Reporting Data Lambda Function
resource "aws_iam_role" "save_reporting_data_role" {
  count = var.enable_reporting ? 1 : 0

  name = "idp-save-reporting-data-role-${random_string.suffix.result}"

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

# IAM Policy for Save Reporting Data Lambda Function
resource "aws_iam_policy" "save_reporting_data_policy" {
  count = var.enable_reporting ? 1 : 0

  name        = "idp-save-reporting-data-policy-${random_string.suffix.result}"
  description = "Policy for Save Reporting Data Lambda Function"

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
          "s3:GetObject",
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
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Effect = "Allow"
        Resource = [
          var.reporting_bucket_arn,
          "${var.reporting_bucket_arn}/*"
        ]
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
      }
    ]
  })
}

# Attach policy to Save Reporting Data role
resource "aws_iam_role_policy_attachment" "save_reporting_data_policy_attachment" {
  count = var.enable_reporting ? 1 : 0

  role       = aws_iam_role.save_reporting_data_role[0].name
  policy_arn = aws_iam_policy.save_reporting_data_policy[0].arn
}

# Add KMS permissions if key is provided
resource "aws_iam_policy" "save_reporting_data_kms_policy" {
  for_each = var.enable_reporting ? toset(["enabled"]) : toset([])

  name        = "idp-save-reporting-data-kms-policy-${random_string.suffix.result}"
  description = "KMS policy for Save Reporting Data Lambda Function"

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

resource "aws_iam_role_policy_attachment" "save_reporting_data_kms_attachment" {
  for_each = var.enable_reporting ? toset(["enabled"]) : toset([])

  role       = aws_iam_role.save_reporting_data_role[0].name
  policy_arn = aws_iam_policy.save_reporting_data_kms_policy["enabled"].arn
}

# Add VPC permissions if VPC config is provided
resource "aws_iam_role_policy_attachment" "save_reporting_data_vpc_attachment" {
  count = var.enable_reporting && length(var.subnet_ids) > 0 ? 1 : 0

  role       = aws_iam_role.save_reporting_data_role[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

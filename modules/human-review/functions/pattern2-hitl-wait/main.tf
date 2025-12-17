# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

# Data sources for cross-partition compatibility
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

locals {
  module_build_dir   = "${path.module}/.terraform-build"
  module_instance_id = substr(md5("${path.module}-pattern2-hitl-wait"), 0, 8)
}

# Create module-specific build directory
resource "null_resource" "create_module_build_dir" {
  provisioner "local-exec" {
    command = "mkdir -p ${local.module_build_dir}"
  }
}

# Generate unique build ID
resource "random_id" "build_id" {
  byte_length = 8
  keepers = {
    module_instance_id = local.module_instance_id
    content_hash       = md5("pattern2-hitl-wait-function")
  }
}

# Random string for unique resource names
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Source code archive
data "archive_file" "pattern2_hitl_wait_code" {
  type        = "zip"
  source_dir  = "${path.module}/../../../../sources/patterns/pattern-2/src/hitl-wait-function"
  output_path = "${local.module_build_dir}/pattern2-hitl-wait.zip_${random_id.build_id.hex}"

  depends_on = [null_resource.create_module_build_dir]
}

# Lambda function
resource "aws_lambda_function" "pattern2_hitl_wait" {
  function_name = "${var.name_prefix}-function-${random_string.suffix.result}"

  filename         = data.archive_file.pattern2_hitl_wait_code.output_path
  source_code_hash = data.archive_file.pattern2_hitl_wait_code.output_base64sha256

  layers = [var.idp_common_layer_arn]

  handler     = "index.lambda_handler"
  runtime     = "python3.12"
  timeout     = 300
  memory_size = 256
  role        = aws_iam_role.pattern2_hitl_wait_role.arn
  description = "Lambda function that creates HITL task tokens for Pattern-2 sections needing human review"

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = {
      LOG_LEVEL                       = var.log_level
      TRACKING_TABLE                  = var.tracking_table_name
      WORKING_BUCKET                  = var.working_bucket_name
      SAGEMAKER_A2I_REVIEW_PORTAL_URL = var.sagemaker_a2i_review_portal_url
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
}


# IAM role
resource "aws_iam_role" "pattern2_hitl_wait_role" {
  name = "${var.name_prefix}-role-${random_string.suffix.result}"

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

# IAM policy
resource "aws_iam_policy" "pattern2_hitl_wait_policy" {
  name = "${var.name_prefix}-policy-${random_string.suffix.result}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:${data.aws_partition.current.partition}:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = var.tracking_table_arn
      },
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
      }
    ]
  })

  tags = var.tags
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "pattern2_hitl_wait_policy_attachment" {
  role       = aws_iam_role.pattern2_hitl_wait_role.name
  policy_arn = aws_iam_policy.pattern2_hitl_wait_policy.arn
}

# Add KMS permissions if encryption key is provided
resource "aws_iam_policy" "kms_policy" {
  count       = var.encryption_key_arn != null ? 1 : 0
  name        = "${var.name_prefix}-kms-policy-${random_string.suffix.result}"
  description = "KMS policy for Pattern-2 HITL wait function"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Effect   = "Allow"
        Resource = var.encryption_key_arn
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "pattern2_hitl_wait_kms_attachment" {
  count      = var.encryption_key_arn != null ? 1 : 0
  role       = aws_iam_role.pattern2_hitl_wait_role.name
  policy_arn = aws_iam_policy.kms_policy[0].arn
}

# VPC policy
resource "aws_iam_policy" "vpc_policy" {
  #checkov:skip=CKV_AWS_355:EC2 network interface operations require wildcard resource as ENIs are created dynamically by Lambda in VPC
  #checkov:skip=CKV_AWS_290:EC2 network interface operations require wildcard resource as ENIs are created dynamically by Lambda in VPC
  count       = length(var.vpc_subnet_ids) > 0 ? 1 : 0
  name        = "${var.name_prefix}-vpc-policy-${random_string.suffix.result}"
  description = "VPC policy for Pattern-2 HITL wait function"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "pattern2_hitl_wait_vpc_attachment" {
  count      = length(var.vpc_subnet_ids) > 0 ? 1 : 0
  role       = aws_iam_role.pattern2_hitl_wait_role.name
  policy_arn = aws_iam_policy.vpc_policy[0].arn
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "pattern2_hitl_wait_logs" {
  name              = "/aws/lambda/${aws_lambda_function.pattern2_hitl_wait.function_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.encryption_key_arn

  tags = var.tags
}

# VPC config local
locals {
  vpc_config = length(var.vpc_subnet_ids) > 0 ? {
    subnet_ids         = var.vpc_subnet_ids
    security_group_ids = var.vpc_security_group_ids
  } : null
}

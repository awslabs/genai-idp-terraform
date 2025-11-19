# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.1"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.1"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.0"
    }
  }
}

# Data sources for cross-partition compatibility
data "aws_partition" "current" {}

locals {
  module_build_dir   = "${path.module}/.terraform-build"
  module_instance_id = substr(md5("${path.module}-get-workforce-url"), 0, 8)
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
    content_hash       = md5("get-workforce-url-function")
  }
}

# Random string for unique resource names
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Source code archive
data "archive_file" "get_workforce_url_code" {
  type        = "zip"
  source_dir  = "${path.module}/../../../../sources/src/lambda/hitl/get_workforce_url_function"
  output_path = "${local.module_build_dir}/get-workforce-url.zip_${random_id.build_id.hex}"

  depends_on = [null_resource.create_module_build_dir]
}

# Lambda function
resource "aws_lambda_function" "get_workforce_url" {
  function_name = "${var.name_prefix}-function-${random_string.suffix.result}"

  filename         = data.archive_file.get_workforce_url_code.output_path
  source_code_hash = data.archive_file.get_workforce_url_code.output_base64sha256

  layers = [var.idp_common_layer_arn]

  handler     = "index.handler"
  runtime     = "python3.12"
  timeout     = 300
  memory_size = 256
  role        = aws_iam_role.get_workforce_url_role.arn
  description = "Lambda function that retrieves workforce portal URL for HITL"

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = {
      LOG_LEVEL                      = var.log_level
      WORKTEAM_NAME                  = var.workteam_name
      PRIVATE_WORKFORCE_ARN          = var.private_workforce_arn
      WORKFORCE_PORTAL_URL_PARAMETER = "/${var.name_prefix}/human-review/workforce-portal-url"
      LABELING_CONSOLE_URL_PARAMETER = "/${var.name_prefix}/human-review/labeling-console-url"
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
resource "aws_iam_role" "get_workforce_url_role" {
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
resource "aws_iam_policy" "get_workforce_url_policy" {
  #checkov:skip=CKV_AWS_355:SageMaker DescribeWorkteam/DescribeWorkforce require wildcard resource as workforce ARNs are external
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
          "sagemaker:DescribeWorkteam",
          "sagemaker:DescribeWorkforce"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:PutParameter",
          "ssm:GetParameter"
        ]
        Resource = [
          "arn:${data.aws_partition.current.partition}:ssm:*:*:parameter/${var.name_prefix}/human-review/workforce-portal-url",
          "arn:${data.aws_partition.current.partition}:ssm:*:*:parameter/${var.name_prefix}/human-review/labeling-console-url"
        ]
      }
    ]
  })

  tags = var.tags
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "get_workforce_url_policy_attachment" {
  role       = aws_iam_role.get_workforce_url_role.name
  policy_arn = aws_iam_policy.get_workforce_url_policy.arn
}

# Add KMS permissions if encryption key is provided
resource "aws_iam_policy" "kms_policy" {
  count       = var.encryption_key_arn != null ? 1 : 0
  name        = "${var.name_prefix}-kms-policy-${random_string.suffix.result}"
  description = "KMS policy for HITL functions"

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

resource "aws_iam_role_policy_attachment" "get_workforce_url_kms_attachment" {
  count      = var.encryption_key_arn != null ? 1 : 0
  role       = aws_iam_role.get_workforce_url_role.name
  policy_arn = aws_iam_policy.kms_policy[0].arn
}

# VPC policy
resource "aws_iam_policy" "vpc_policy" {
  #checkov:skip=CKV_AWS_355:EC2 network interface operations require wildcard resource as ENIs are created dynamically by Lambda in VPC
  #checkov:skip=CKV_AWS_290:EC2 network interface operations require wildcard resource as ENIs are created dynamically by Lambda in VPC
  count       = length(var.vpc_subnet_ids) > 0 ? 1 : 0
  name        = "${var.name_prefix}-vpc-policy-${random_string.suffix.result}"
  description = "VPC policy for HITL functions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # EC2 network interface operations for VPC Lambda - AWS service limitation requires wildcard resource
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

resource "aws_iam_role_policy_attachment" "get_workforce_url_vpc_attachment" {
  count      = length(var.vpc_subnet_ids) > 0 ? 1 : 0
  role       = aws_iam_role.get_workforce_url_role.name
  policy_arn = aws_iam_policy.vpc_policy[0].arn
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "get_workforce_url_logs" {
  name              = "/aws/lambda/${aws_lambda_function.get_workforce_url.function_name}"
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

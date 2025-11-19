# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

# Data sources for cross-partition compatibility
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

locals {
  module_build_dir   = "${path.module}/.terraform-build"
  module_instance_id = substr(md5("${path.module}-create-a2i-resources"), 0, 8)
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
    content_hash       = md5("create-a2i-resources-function")
  }
}

# Random string for unique resource names
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Source code archive
data "archive_file" "create_a2i_resources_code" {
  type        = "zip"
  source_dir  = "${path.module}/../../../../sources/src/lambda/hitl/create_a2i_resources_function"
  output_path = "${local.module_build_dir}/create-a2i-resources.zip_${random_id.build_id.hex}"

  depends_on = [null_resource.create_module_build_dir]
}

# Lambda function
resource "aws_lambda_function" "create_a2i_resources" {
  function_name = "${var.name_prefix}-function-${random_string.suffix.result}"

  filename         = data.archive_file.create_a2i_resources_code.output_path
  source_code_hash = data.archive_file.create_a2i_resources_code.output_base64sha256

  layers = [var.idp_common_layer_arn]

  handler     = "index.handler"
  runtime     = "python3.12"
  timeout     = 300
  memory_size = 256
  role        = aws_iam_role.create_a2i_resources_role.arn
  description = "Lambda function that creates A2I resources for HITL"

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = {
      LOG_LEVEL                = var.log_level
      WORKTEAM_ARN             = var.workteam_arn
      FLOW_DEFINITION_ROLE_ARN = var.flow_definition_role_arn
      OUTPUT_BUCKET            = var.output_bucket_name
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
resource "aws_iam_role" "create_a2i_resources_role" {
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
resource "aws_iam_policy" "create_a2i_resources_policy" {
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
          "sagemaker:CreateFlowDefinition",
          "sagemaker:DescribeFlowDefinition",
          "sagemaker:DeleteFlowDefinition",
          "sagemaker:CreateHumanTaskUi",
          "sagemaker:DescribeHumanTaskUi",
          "sagemaker:DeleteHumanTaskUi"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = var.flow_definition_role_arn
      },
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
      }
    ]
  })

  tags = var.tags
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "create_a2i_resources_policy_attachment" {
  role       = aws_iam_role.create_a2i_resources_role.name
  policy_arn = aws_iam_policy.create_a2i_resources_policy.arn
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

resource "aws_iam_role_policy_attachment" "create_a2i_resources_kms_attachment" {
  count      = var.encryption_key_arn != null ? 1 : 0
  role       = aws_iam_role.create_a2i_resources_role.name
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

resource "aws_iam_role_policy_attachment" "create_a2i_resources_vpc_attachment" {
  count      = length(var.vpc_subnet_ids) > 0 ? 1 : 0
  role       = aws_iam_role.create_a2i_resources_role.name
  policy_arn = aws_iam_policy.vpc_policy[0].arn
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "create_a2i_resources_logs" {
  name              = "/aws/lambda/${aws_lambda_function.create_a2i_resources.function_name}"
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

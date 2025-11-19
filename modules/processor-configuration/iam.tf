# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

# Lambda execution role
resource "aws_iam_role" "lambda_execution" {
  name = "${var.name_prefix}-processor-configuration-role"

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

# Basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# VPC execution policy (conditional)
resource "aws_iam_role_policy_attachment" "lambda_vpc_execution" {
  count      = var.vpc_config != null ? 1 : 0
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# DynamoDB permissions policy
resource "aws_iam_policy" "dynamodb_access" {
  name        = "${var.name_prefix}-processor-configuration-dynamodb"
  description = "DynamoDB access policy for processor configuration Lambda"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem"
        ]
        Resource = "arn:${data.aws_partition.current.partition}:dynamodb:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:table/${var.configuration_table_name}"
      }
    ]
  })
}

# Attach DynamoDB policy to Lambda execution role
resource "aws_iam_role_policy_attachment" "dynamodb_access" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = aws_iam_policy.dynamodb_access.arn
}

# KMS permissions policy (conditional content based on encryption key being provided)
resource "aws_iam_policy" "kms_access" {
  count       = 1
  name        = "${var.name_prefix}-processor-configuration-kms"
  description = "KMS access policy for processor configuration Lambda"

  policy = var.encryption_key_arn != null ? jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = var.encryption_key_arn
      }
    ]
    }) : jsonencode({
    Version   = "2012-10-17"
    Statement = []
  })
}

# Attach KMS policy to Lambda execution role (always attached)
resource "aws_iam_role_policy_attachment" "kms_access" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = aws_iam_policy.kms_access[0].arn
}

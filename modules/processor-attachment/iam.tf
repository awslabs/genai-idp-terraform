# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# IAM Role for Queue Processor Lambda Function
resource "aws_iam_role" "queue_processor_role" {
  name = "${var.name}-qp-role-${random_string.suffix.result}"

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

# Basic execution policy attachment for Lambda
resource "aws_iam_role_policy_attachment" "queue_processor_basic_execution" {
  role       = aws_iam_role.queue_processor_role.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# VPC execution policy attachment for Lambda (conditional)
resource "aws_iam_role_policy_attachment" "queue_processor_vpc_execution" {
  count      = length(var.vpc_subnet_ids) > 0 ? 1 : 0
  role       = aws_iam_role.queue_processor_role.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Custom policy for Queue Processor Lambda Function
resource "aws_iam_policy" "queue_processor_policy" {
  name        = "${var.name}-queue-processor-policy-${random_string.suffix.result}"
  description = "Policy for Queue Processor Lambda Function"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # SQS permissions for consuming messages from the document queue
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:ChangeMessageVisibility",
          "sqs:GetQueueUrl",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = var.document_queue_arn
      },
      # Step Functions permissions to start executions
      {
        Effect = "Allow"
        Action = [
          "states:StartExecution"
        ]
        Resource = var.processor.state_machine_arn
      },
      # DynamoDB permissions for concurrency table
      {
        Effect = "Allow"
        Action = [
          "dynamodb:UpdateItem",
          "dynamodb:GetItem",
          "dynamodb:PutItem"
        ]
        Resource = var.concurrency_table_arn
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
      # S3 permissions for working bucket (document compression)
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject"
        ]
        Resource = [
          var.working_bucket_arn,
          "${var.working_bucket_arn}/*"
        ]
      },
      # AppSync permissions for GraphQL API
      {
        Effect = "Allow"
        Action = [
          "appsync:GraphQL"
        ]
        Resource = var.api_arn != null ? [
          "${var.api_arn}/types/Query/*",
          "${var.api_arn}/types/Mutation/*",
          "${var.api_arn}/types/Subscription/*"
        ] : ["*"]
      }
    ]
  })

  tags = var.tags
}

# Attach custom policy to the role
resource "aws_iam_role_policy_attachment" "queue_processor_custom_policy" {
  role       = aws_iam_role.queue_processor_role.name
  policy_arn = aws_iam_policy.queue_processor_policy.arn
}

# KMS permissions (only if encryption key is provided)
resource "aws_iam_policy" "queue_processor_kms_policy" {
  count       = var.enable_encryption ? 1 : 0
  name        = "${var.name}-queue-processor-kms-policy-${random_string.suffix.result}"
  description = "KMS policy for Queue Processor Lambda Function"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*"
        ]
        Resource = var.encryption_key_arn
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = var.encryption_key_arn
        Condition = {
          StringEquals = {
            "kms:ViaService" = [
              "sqs.${data.aws_region.current.id}.amazonaws.com",
              "dynamodb.${data.aws_region.current.id}.amazonaws.com"
            ]
          }
        }
      }
    ]
  })

  tags = var.tags
}

# Attach KMS policy to the role
resource "aws_iam_role_policy_attachment" "queue_processor_kms_attachment" {
  count      = var.enable_encryption ? 1 : 0
  role       = aws_iam_role.queue_processor_role.name
  policy_arn = aws_iam_policy.queue_processor_kms_policy[0].arn
}

# Data source to get current AWS region, partition, and account
data "aws_region" "current" {}
data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}


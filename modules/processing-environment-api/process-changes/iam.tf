# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# IAM resources for Process Changes functionality

# =============================================================================
# Process Changes Resolver IAM Role
# =============================================================================

resource "aws_iam_role" "process_changes_resolver_role" {
  name = "${var.name_prefix}-process-changes-role-${random_string.suffix.result}"

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

# =============================================================================
# Process Changes Resolver IAM Policy
# =============================================================================

resource "aws_iam_role_policy" "process_changes_resolver_policy" {
  name = "${var.name_prefix}-process-changes-policy"
  role = aws_iam_role.process_changes_resolver_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      # CloudWatch Logs permissions
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.name_prefix}-process-changes-*",
          "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.name_prefix}-process-changes-*:*"
        ]
      },
      # DynamoDB permissions for tracking table
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          var.tracking_table_arn,
          "${var.tracking_table_arn}/*"
        ]
      },
      # SQS permissions for document queue
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = var.queue_arn
      },
      # S3 permissions for buckets
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.output_bucket_arn,
          "${var.output_bucket_arn}/*",
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
        Resource = [
          "arn:${data.aws_partition.current.partition}:appsync:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:apis/*/types/Mutation/*"
        ]
      },
      # KMS permissions for encryption
      {
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = var.encryption_key_arn
      }
      ],
      # VPC permissions (conditional - only if VPC is configured)
      length(var.vpc_subnet_ids) > 0 ? [
        {
          Effect = "Allow"
          Action = [
            "ec2:CreateNetworkInterface",
            "ec2:DescribeNetworkInterfaces",
            "ec2:DeleteNetworkInterface",
            "ec2:AttachNetworkInterface",
            "ec2:DetachNetworkInterface"
          ]
          Resource = "*"
        }
    ] : [])
  })
}
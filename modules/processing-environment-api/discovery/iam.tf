# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

# =============================================================================
# IAM Role for Discovery Upload Resolver Lambda
# =============================================================================

resource "aws_iam_role" "discovery_upload_resolver_role" {
  name = "${var.name_prefix}-discovery-upload-role-${local.suffix}"

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

resource "aws_iam_policy" "discovery_upload_resolver_policy" {
  name = "${var.name_prefix}-discovery-upload-policy-${local.suffix}"

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
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.discovery_bucket.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem"
        ]
        Resource = aws_dynamodb_table.discovery_tracking.arn
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage"
        ]
        Resource = aws_sqs_queue.discovery_queue.arn
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "discovery_upload_resolver_policy_attachment" {
  role       = aws_iam_role.discovery_upload_resolver_role.name
  policy_arn = aws_iam_policy.discovery_upload_resolver_policy.arn
}

# VPC policy for upload resolver
resource "aws_iam_policy" "discovery_upload_resolver_vpc_policy" {
  #checkov:skip=CKV_AWS_355:EC2 network interface operations require wildcard resource as ENIs are created dynamically by Lambda in VPC
  #checkov:skip=CKV_AWS_290:EC2 network interface operations require wildcard resource as ENIs are created dynamically by Lambda in VPC
  count = length(var.vpc_subnet_ids) > 0 ? 1 : 0
  name  = "${var.name_prefix}-discovery-upload-vpc-policy-${local.suffix}"

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

resource "aws_iam_role_policy_attachment" "discovery_upload_resolver_vpc_attachment" {
  count      = length(var.vpc_subnet_ids) > 0 ? 1 : 0
  role       = aws_iam_role.discovery_upload_resolver_role.name
  policy_arn = aws_iam_policy.discovery_upload_resolver_vpc_policy[0].arn
}

# KMS policy for upload resolver
resource "aws_iam_policy" "discovery_upload_resolver_kms_policy" {
  name = "${var.name_prefix}-discovery-upload-kms-policy-${local.suffix}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = var.encryption_key_arn != null ? [
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
    ] : []
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "discovery_upload_resolver_kms_attachment" {
  role       = aws_iam_role.discovery_upload_resolver_role.name
  policy_arn = aws_iam_policy.discovery_upload_resolver_kms_policy.arn
}

# =============================================================================
# IAM Role for Discovery Processor Lambda
# =============================================================================

resource "aws_iam_role" "discovery_processor_role" {
  name = "${var.name_prefix}-discovery-processor-role-${local.suffix}"

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

resource "aws_iam_policy" "discovery_processor_policy" {
  name = "${var.name_prefix}-discovery-processor-policy-${local.suffix}"

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
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.discovery_bucket.arn,
          "${aws_s3_bucket.discovery_bucket.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query"
        ]
        Resource = aws_dynamodb_table.discovery_tracking.arn
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
        Resource = var.configuration_table_arn
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.discovery_queue.arn
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = "arn:${data.aws_partition.current.partition}:bedrock:*::foundation-model/*"
      },
      {
        Effect = "Allow"
        Action = [
          "textract:AnalyzeDocument",
          "textract:DetectDocumentText"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "discovery_processor_policy_attachment" {
  role       = aws_iam_role.discovery_processor_role.name
  policy_arn = aws_iam_policy.discovery_processor_policy.arn
}

# AppSync policy for processor (to update job status)
resource "aws_iam_policy" "discovery_processor_appsync_policy" {
  name = "${var.name_prefix}-discovery-processor-appsync-policy-${local.suffix}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = var.appsync_api_url != null ? [
      {
        Effect = "Allow"
        Action = [
          "appsync:GraphQL"
        ]
        Resource = "arn:${data.aws_partition.current.partition}:appsync:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:apis/*"
      }
    ] : []
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "discovery_processor_appsync_attachment" {
  role       = aws_iam_role.discovery_processor_role.name
  policy_arn = aws_iam_policy.discovery_processor_appsync_policy.arn
}

# VPC policy for processor
resource "aws_iam_policy" "discovery_processor_vpc_policy" {
  #checkov:skip=CKV_AWS_355:EC2 network interface operations require wildcard resource as ENIs are created dynamically by Lambda in VPC
  #checkov:skip=CKV_AWS_290:EC2 network interface operations require wildcard resource as ENIs are created dynamically by Lambda in VPC
  count = length(var.vpc_subnet_ids) > 0 ? 1 : 0
  name  = "${var.name_prefix}-discovery-processor-vpc-policy-${local.suffix}"

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

resource "aws_iam_role_policy_attachment" "discovery_processor_vpc_attachment" {
  count      = length(var.vpc_subnet_ids) > 0 ? 1 : 0
  role       = aws_iam_role.discovery_processor_role.name
  policy_arn = aws_iam_policy.discovery_processor_vpc_policy[0].arn
}

# KMS policy for processor
resource "aws_iam_policy" "discovery_processor_kms_policy" {
  name = "${var.name_prefix}-discovery-processor-kms-policy-${local.suffix}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = var.encryption_key_arn != null ? [
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
    ] : []
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "discovery_processor_kms_attachment" {
  role       = aws_iam_role.discovery_processor_role.name
  policy_arn = aws_iam_policy.discovery_processor_kms_policy.arn
}
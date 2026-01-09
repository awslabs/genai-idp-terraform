# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

# =============================================================================
# IAM Role for Chat with Document Resolver Lambda
# =============================================================================

resource "aws_iam_role" "chat_with_document_resolver_role" {
  name = "${var.name_prefix}-chat-with-document-role-${local.suffix}"

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

resource "aws_iam_policy" "chat_with_document_resolver_policy" {
  name = "${var.name_prefix}-chat-with-document-policy-${local.suffix}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        # CloudWatch Logs permissions
        {
          Effect = "Allow"
          Action = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ]
          Resource = "arn:${data.aws_partition.current.partition}:logs:*:*:*"
        },
        # S3 permissions
        {
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:PutObject",
            "s3:ListBucket"
          ]
          Resource = [
            var.input_bucket_arn,
            "${var.input_bucket_arn}/*",
            var.output_bucket_arn,
            "${var.output_bucket_arn}/*",
            var.working_bucket_arn,
            "${var.working_bucket_arn}/*"
          ]
        },
        # DynamoDB permissions
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
            var.configuration_table_arn
          ]
        },
        # Bedrock foundation model permissions
        {
          Effect = "Allow"
          Action = [
            "bedrock:InvokeModel",
            "bedrock:InvokeModelWithResponseStream",
            "bedrock:GetFoundationModel"
          ]
          Resource = "arn:${data.aws_partition.current.partition}:bedrock:*::foundation-model/*"
        },
        # Bedrock inference profile permissions
        {
          Effect = "Allow"
          Action = [
            "bedrock:GetInferenceProfile",
            "bedrock:InvokeModel",
            "bedrock:InvokeModelWithResponseStream"
          ]
          Resource = "arn:${data.aws_partition.current.partition}:bedrock:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:inference-profile/*"
        },
        # CloudWatch metrics permissions (for BedrockClient metrics)
        {
          Effect = "Allow"
          Action = [
            "cloudwatch:PutMetricData"
          ]
          Resource = "*"
        }
      ],
      # Knowledge Base permissions (conditional - if knowledge_base_arn is provided)
      var.knowledge_base_arn != null ? [
        {
          Effect = "Allow"
          Action = [
            "bedrock:Retrieve",
            "bedrock:RetrieveAndGenerate"
          ]
          Resource = var.knowledge_base_arn
        }
      ] : [],
      # Guardrail permissions (conditional - if guardrail is configured)
      var.guardrail_id_and_version != null ? [
        {
          Effect = "Allow"
          Action = [
            "bedrock:ApplyGuardrail"
          ]
          Resource = "arn:${data.aws_partition.current.partition}:bedrock:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:guardrail/${split(":", var.guardrail_id_and_version)[0]}"
        }
      ] : []
    )
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "chat_with_document_resolver_policy_attachment" {
  role       = aws_iam_role.chat_with_document_resolver_role.name
  policy_arn = aws_iam_policy.chat_with_document_resolver_policy.arn
}

# VPC policy for chat resolver
resource "aws_iam_policy" "chat_with_document_resolver_vpc_policy" {
  #checkov:skip=CKV_AWS_355:EC2 network interface operations require wildcard resource as ENIs are created dynamically by Lambda in VPC
  #checkov:skip=CKV_AWS_290:EC2 network interface operations require wildcard resource as ENIs are created dynamically by Lambda in VPC
  count = length(var.vpc_subnet_ids) > 0 ? 1 : 0
  name  = "${var.name_prefix}-chat-with-document-vpc-policy-${local.suffix}"

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

resource "aws_iam_role_policy_attachment" "chat_with_document_resolver_vpc_attachment" {
  count      = length(var.vpc_subnet_ids) > 0 ? 1 : 0
  role       = aws_iam_role.chat_with_document_resolver_role.name
  policy_arn = aws_iam_policy.chat_with_document_resolver_vpc_policy[0].arn
}

# KMS policy for chat resolver
resource "aws_iam_policy" "chat_with_document_resolver_kms_policy" {
  name = "${var.name_prefix}-chat-with-document-kms-policy-${local.suffix}"

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

resource "aws_iam_role_policy_attachment" "chat_with_document_resolver_kms_attachment" {
  role       = aws_iam_role.chat_with_document_resolver_role.name
  policy_arn = aws_iam_policy.chat_with_document_resolver_kms_policy.arn
}
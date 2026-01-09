# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Note: EC2 network interface operations for VPC Lambda functions require wildcard resources (AWS service limitation)
#
# Data sources for constructing ARNs
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

# IAM Role for AppSync to access DynamoDB
resource "aws_iam_role" "appsync_dynamodb_role" {
  name = "AppSyncDynamoDBRole-${random_string.suffix.result}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "appsync.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# IAM Policy for AppSync to access DynamoDB
resource "aws_iam_policy" "appsync_dynamodb_policy" {
  name        = "AppSyncDynamoDBPolicy-${random_string.suffix.result}"
  description = "Policy for AppSync to access DynamoDB"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      # DynamoDB permissions - only if tracking table ARN is provided
      local.tracking_table_arn != null ? [
        {
          Action = [
            "dynamodb:GetItem",
            "dynamodb:PutItem",
            "dynamodb:UpdateItem",
            "dynamodb:DeleteItem",
            "dynamodb:Query",
            "dynamodb:Scan",
            "dynamodb:BatchGetItem",
            "dynamodb:BatchWriteItem",
            "dynamodb:TransactWriteItems"
          ]
          Effect = "Allow"
          Resource = compact([
            local.tracking_table_arn,
            local.tracking_table_arn != null ? "${local.tracking_table_arn}/index/*" : null
          ])
        }
      ] : [],
      # Agent Analytics DynamoDB permissions (conditional)
      var.agent_analytics.enabled ? [
        {
          Action = [
            "dynamodb:GetItem",
            "dynamodb:PutItem",
            "dynamodb:UpdateItem",
            "dynamodb:DeleteItem",
            "dynamodb:Query",
            "dynamodb:Scan"
          ]
          Effect = "Allow"
          Resource = [
            module.agent_analytics[0].agent_table_arn,
            "${module.agent_analytics[0].agent_table_arn}/index/*"
          ]
        }
      ] : [],
      # KMS permissions - always included
      [
        {
          Action = [
            "kms:Encrypt",
            "kms:Decrypt",
            "kms:ReEncrypt*",
            "kms:GenerateDataKey*"
          ]
          Effect   = "Allow"
          Resource = local.encryption_key_arn != null ? local.encryption_key_arn : "*"
        }
      ]
    )
  })
}

# Attach DynamoDB policy to role
resource "aws_iam_role_policy_attachment" "appsync_dynamodb_attachment" {
  role       = aws_iam_role.appsync_dynamodb_role.name
  policy_arn = aws_iam_policy.appsync_dynamodb_policy.arn
}

# IAM Role for AppSync to invoke Lambda functions
resource "aws_iam_role" "appsync_lambda_role" {
  name = "AppSyncLambdaRole-${random_string.suffix.result}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "appsync.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# IAM Policy for AppSync to invoke Lambda functions
resource "aws_iam_policy" "appsync_lambda_policy" {
  name        = "AppSyncLambdaPolicy-${random_string.suffix.result}"
  description = "Policy for AppSync to invoke Lambda functions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "lambda:InvokeFunction"
        Effect = "Allow"
        Resource = concat(
          [
            aws_lambda_function.upload_resolver.arn,
            aws_lambda_function.delete_document_resolver.arn,
            aws_lambda_function.reprocess_document_resolver.arn,
            aws_lambda_function.get_file_contents_resolver.arn,
            aws_lambda_function.configuration_resolver.arn,
            aws_lambda_function.get_stepfunction_execution_resolver.arn
          ],
          local.knowledge_base_id != null ? [aws_lambda_function.query_knowledge_base_resolver["enabled"].arn] : [],
          local.evaluation_baseline_bucket_arn != null ? [aws_lambda_function.copy_to_baseline_resolver["enabled"].arn] : [],
          var.agent_analytics.enabled ? [
            module.agent_analytics[0].agent_request_handler_function_arn,
            module.agent_analytics[0].list_available_agents_function_arn
          ] : [],
          var.chat_with_document.enabled ? [module.chat_with_document[0].chat_with_document_resolver_function_arn] : [],
          var.discovery.enabled ? [
            module.discovery[0].discovery_upload_resolver_function_arn,
            module.discovery[0].discovery_processor_function_arn
          ] : []
        )
      }
    ]
  })
}

# Attach Lambda policy to role
resource "aws_iam_role_policy_attachment" "appsync_lambda_attachment" {
  role       = aws_iam_role.appsync_lambda_role.name
  policy_arn = aws_iam_policy.appsync_lambda_policy.arn
}

# =============================================================================
# LAMBDA EXECUTION ROLES AND POLICIES
# =============================================================================

# IAM resources from lambda_configuration_resolver.tf
resource "aws_iam_role" "configuration_resolver_role" {
  name = "ConfigurationResolverRole-${random_string.suffix.result}"

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
resource "aws_iam_policy" "configuration_resolver_logs_policy" {
  name        = "ConfigurationResolverLogsPolicy-${random_string.suffix.result}"
  description = "Policy for Configuration Resolver Lambda to write logs to CloudWatch"

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
      }
    ]
  })
}
resource "aws_iam_policy" "configuration_resolver_dynamodb_policy" {
  name        = "ConfigurationResolverDynamoDBPolicy-${random_string.suffix.result}"
  description = "Policy for Configuration Resolver Lambda to access DynamoDB"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = var.configuration_table_arn != null ? [
      {
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Effect = "Allow"
        Resource = [
          var.configuration_table_arn,
          "${var.configuration_table_arn}/index/*"
        ]
      }
    ] : []
  })
}
resource "aws_iam_policy" "configuration_resolver_kms_policy" {
  name        = "ConfigurationResolverKMSPolicy-${random_string.suffix.result}"
  description = "Policy for Configuration Resolver Lambda to use KMS key"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Effect   = "Allow"
        Resource = var.encryption_key_arn
      }
    ]
  })
}
resource "aws_iam_policy" "configuration_resolver_vpc_policy" {
  #checkov:skip=CKV_AWS_355:EC2 network interface operations require wildcard resource as ENIs are created dynamically by Lambda in VPC
  #checkov:skip=CKV_AWS_290:EC2 network interface operations require wildcard resource as ENIs are created dynamically by Lambda in VPC
  count       = var.vpc_config != null ? 1 : 0
  name        = "ConfigurationResolverVPCPolicy-${random_string.suffix.result}"
  description = "Policy for Configuration Resolver Lambda to access VPC"

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
}
resource "aws_iam_policy" "appsync_invoke_configuration_resolver_policy" {
  name        = "AppSyncInvokeConfigurationResolverPolicy-${random_string.suffix.result}"
  description = "Policy for AppSync to invoke the Configuration Resolver Lambda"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "lambda:InvokeFunction"
        Effect   = "Allow"
        Resource = aws_lambda_function.configuration_resolver.arn
      }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "appsync_invoke_configuration_resolver_attachment" {
  role       = aws_iam_role.appsync_lambda_role.name
  policy_arn = aws_iam_policy.appsync_invoke_configuration_resolver_policy.arn
}
resource "aws_iam_role_policy_attachment" "configuration_resolver_logs_attachment" {
  role       = aws_iam_role.configuration_resolver_role.name
  policy_arn = aws_iam_policy.configuration_resolver_logs_policy.arn
}
resource "aws_iam_role_policy_attachment" "configuration_resolver_dynamodb_attachment" {
  role       = aws_iam_role.configuration_resolver_role.name
  policy_arn = aws_iam_policy.configuration_resolver_dynamodb_policy.arn
}
resource "aws_iam_role_policy_attachment" "configuration_resolver_kms_attachment" {
  role       = aws_iam_role.configuration_resolver_role.name
  policy_arn = aws_iam_policy.configuration_resolver_kms_policy.arn
}
resource "aws_iam_role_policy_attachment" "configuration_resolver_vpc_attachment" {
  count      = var.vpc_config != null ? 1 : 0
  role       = aws_iam_role.configuration_resolver_role.name
  policy_arn = aws_iam_policy.configuration_resolver_vpc_policy[0].arn
}

# IAM resources from lambda_copy_to_baseline_resolver.tf
resource "aws_iam_role" "copy_to_baseline_resolver_role" {
  for_each = var.evaluation_enabled ? { "enabled" = true } : {}
  name     = "CopyToBaselineResolverRole-${random_string.suffix.result}"

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
resource "aws_iam_policy" "copy_to_baseline_resolver_logs_policy" {
  for_each    = var.evaluation_enabled ? { "enabled" = true } : {}
  name        = "CopyToBaselineResolverLogsPolicy-${random_string.suffix.result}"
  description = "Policy for Copy To Baseline Resolver Lambda to write logs to CloudWatch"

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
      }
    ]
  })
}
resource "aws_iam_policy" "copy_to_baseline_resolver_s3_policy" {
  for_each    = var.evaluation_enabled ? { "enabled" = true } : {}
  name        = "CopyToBaselineResolverS3Policy-${random_string.suffix.result}"
  description = "Policy for Copy To Baseline Resolver Lambda to access S3 buckets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = concat(
          compact([
            local.output_bucket_arn,
            local.output_bucket_arn != null ? "${local.output_bucket_arn}/*" : null
          ]),
          local.evaluation_baseline_bucket_arn != null ? [
            local.evaluation_baseline_bucket_arn,
            local.evaluation_baseline_bucket_arn != null ? "${local.evaluation_baseline_bucket_arn}/*" : null
          ] : []
        )
      }
    ]
  })
}
resource "aws_iam_policy" "copy_to_baseline_resolver_self_invoke_policy" {
  for_each    = var.evaluation_enabled ? { "enabled" = true } : {}
  name        = "CopyToBaselineResolverSelfInvokePolicy-${random_string.suffix.result}"
  description = "Policy for Copy To Baseline Resolver Lambda to invoke itself asynchronously"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "lambda:InvokeFunction"
        Effect   = "Allow"
        Resource = "arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:function:CopyToBaselineResolver-${random_string.suffix.result}"
      }
    ]
  })
}
resource "aws_iam_policy" "copy_to_baseline_resolver_appsync_policy" {
  for_each    = var.evaluation_enabled ? { "enabled" = true } : {}
  name        = "CopyToBaselineResolverAppSyncPolicy-${random_string.suffix.result}"
  description = "Policy for Copy To Baseline Resolver Lambda to access AppSync GraphQL API"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "appsync:GraphQL"
        Effect   = "Allow"
        Resource = "arn:${data.aws_partition.current.partition}:appsync:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:apis/*/types/Mutation/*"
      }
    ]
  })
}
resource "aws_iam_policy" "copy_to_baseline_resolver_kms_policy" {
  for_each    = var.evaluation_enabled ? { "enabled" = true } : {}
  name        = "CopyToBaselineResolverKMSPolicy-${random_string.suffix.result}"
  description = "Policy for Copy To Baseline Resolver Lambda to use KMS key"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Effect   = "Allow"
        Resource = local.encryption_key_arn
      }
    ]
  })
}
resource "aws_iam_policy" "copy_to_baseline_resolver_vpc_policy" {
  #checkov:skip=CKV_AWS_355:EC2 network interface operations require wildcard resource as ENIs are created dynamically by Lambda in VPC
  #checkov:skip=CKV_AWS_290:EC2 network interface operations require wildcard resource as ENIs are created dynamically by Lambda in VPC
  count       = var.evaluation_enabled && var.vpc_config != null ? 1 : 0
  name        = "CopyToBaselineResolverVPCPolicy-${random_string.suffix.result}"
  description = "Policy for Copy To Baseline Resolver Lambda to access VPC"

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
}
resource "aws_iam_role_policy_attachment" "copy_to_baseline_resolver_logs_attachment" {
  count      = var.evaluation_enabled ? 1 : 0
  role       = aws_iam_role.copy_to_baseline_resolver_role["enabled"].name
  policy_arn = aws_iam_policy.copy_to_baseline_resolver_logs_policy["enabled"].arn
}
resource "aws_iam_role_policy_attachment" "copy_to_baseline_resolver_s3_attachment" {
  count      = var.evaluation_enabled ? 1 : 0
  role       = aws_iam_role.copy_to_baseline_resolver_role["enabled"].name
  policy_arn = aws_iam_policy.copy_to_baseline_resolver_s3_policy["enabled"].arn
}
resource "aws_iam_role_policy_attachment" "copy_to_baseline_resolver_self_invoke_attachment" {
  count      = var.evaluation_enabled ? 1 : 0
  role       = aws_iam_role.copy_to_baseline_resolver_role["enabled"].name
  policy_arn = aws_iam_policy.copy_to_baseline_resolver_self_invoke_policy["enabled"].arn
}
resource "aws_iam_role_policy_attachment" "copy_to_baseline_resolver_appsync_attachment" {
  count      = var.evaluation_enabled ? 1 : 0
  role       = aws_iam_role.copy_to_baseline_resolver_role["enabled"].name
  policy_arn = aws_iam_policy.copy_to_baseline_resolver_appsync_policy["enabled"].arn
}
resource "aws_iam_role_policy_attachment" "copy_to_baseline_resolver_kms_attachment" {
  count      = var.evaluation_enabled ? 1 : 0
  role       = aws_iam_role.copy_to_baseline_resolver_role["enabled"].name
  policy_arn = aws_iam_policy.copy_to_baseline_resolver_kms_policy["enabled"].arn
}
resource "aws_iam_role_policy_attachment" "copy_to_baseline_resolver_vpc_attachment" {
  count      = var.evaluation_enabled && var.vpc_config != null ? 1 : 0
  role       = aws_iam_role.copy_to_baseline_resolver_role["enabled"].name
  policy_arn = aws_iam_policy.copy_to_baseline_resolver_vpc_policy["enabled"].arn
}

# IAM resources from lambda_delete_document_resolver.tf
resource "aws_iam_role" "delete_document_resolver_role" {
  name = "DeleteDocumentResolverRole-${random_string.suffix.result}"

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
resource "aws_iam_policy" "delete_document_resolver_logs_policy" {
  name        = "DeleteDocumentResolverLogsPolicy-${random_string.suffix.result}"
  description = "Policy for Delete Document Resolver Lambda to write logs to CloudWatch"

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
      }
    ]
  })
}
resource "aws_iam_policy" "delete_document_resolver_s3_policy" {
  name        = "DeleteDocumentResolverS3Policy-${random_string.suffix.result}"
  description = "Policy for Delete Document Resolver Lambda to access S3 buckets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = compact([
          local.input_bucket_arn,
          local.input_bucket_arn != null ? "${local.input_bucket_arn}/*" : null,
          local.output_bucket_arn,
          local.output_bucket_arn != null ? "${local.output_bucket_arn}/*" : null
        ])
      }
    ]
  })
}
resource "aws_iam_policy" "delete_document_resolver_dynamodb_policy" {
  name        = "DeleteDocumentResolverDynamoDBPolicy-${random_string.suffix.result}"
  description = "Policy for Delete Document Resolver Lambda to access DynamoDB"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Effect = "Allow"
        Resource = compact([
          local.tracking_table_arn,
          local.tracking_table_arn != null ? "${local.tracking_table_arn}/index/*" : null
        ])
      }
    ]
  })
}
resource "aws_iam_policy" "delete_document_resolver_kms_policy" {
  for_each    = toset(["enabled"])
  name        = "DeleteDocumentResolverKMSPolicy-${random_string.suffix.result}"
  description = "Policy for Delete Document Resolver Lambda to use KMS key"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Effect   = "Allow"
        Resource = local.encryption_key_arn
      }
    ]
  })
}
resource "aws_iam_policy" "delete_document_resolver_vpc_policy" {
  #checkov:skip=CKV_AWS_355:EC2 network interface operations require wildcard resource as ENIs are created dynamically by Lambda in VPC
  #checkov:skip=CKV_AWS_290:EC2 network interface operations require wildcard resource as ENIs are created dynamically by Lambda in VPC
  count       = var.vpc_config != null ? 1 : 0
  name        = "DeleteDocumentResolverVPCPolicy-${random_string.suffix.result}"
  description = "Policy for Delete Document Resolver Lambda to access VPC"

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
}
resource "aws_iam_role_policy_attachment" "delete_document_resolver_logs_attachment" {
  role       = aws_iam_role.delete_document_resolver_role.name
  policy_arn = aws_iam_policy.delete_document_resolver_logs_policy.arn
}
resource "aws_iam_role_policy_attachment" "delete_document_resolver_s3_attachment" {
  role       = aws_iam_role.delete_document_resolver_role.name
  policy_arn = aws_iam_policy.delete_document_resolver_s3_policy.arn
}
resource "aws_iam_role_policy_attachment" "delete_document_resolver_dynamodb_attachment" {
  role       = aws_iam_role.delete_document_resolver_role.name
  policy_arn = aws_iam_policy.delete_document_resolver_dynamodb_policy.arn
}
resource "aws_iam_role_policy_attachment" "delete_document_resolver_kms_attachment" {
  for_each   = toset(["enabled"])
  role       = aws_iam_role.delete_document_resolver_role.name
  policy_arn = aws_iam_policy.delete_document_resolver_kms_policy["enabled"].arn
}
resource "aws_iam_role_policy_attachment" "delete_document_resolver_vpc_attachment" {
  count      = var.vpc_config != null ? 1 : 0
  role       = aws_iam_role.delete_document_resolver_role.name
  policy_arn = aws_iam_policy.delete_document_resolver_vpc_policy[0].arn
}

# IAM resources from lambda_get_file_contents_resolver.tf
resource "aws_iam_role" "get_file_contents_resolver_role" {
  name = "GetFileContentsResolverRole-${random_string.suffix.result}"

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
resource "aws_iam_policy" "get_file_contents_resolver_logs_policy" {
  name        = "GetFileContentsResolverLogsPolicy-${random_string.suffix.result}"
  description = "Policy for Get File Contents Resolver Lambda to write logs to CloudWatch"

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
      }
    ]
  })
}
resource "aws_iam_policy" "get_file_contents_resolver_s3_policy" {
  name        = "GetFileContentsResolverS3Policy-${random_string.suffix.result}"
  description = "Policy for Get File Contents Resolver Lambda to access S3 buckets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = compact([
          local.input_bucket_arn,
          local.input_bucket_arn != null ? "${local.input_bucket_arn}/*" : null,
          local.output_bucket_arn,
          local.output_bucket_arn != null ? "${local.output_bucket_arn}/*" : null
        ])
      }
    ]
  })
}
resource "aws_iam_policy" "get_file_contents_resolver_kms_policy" {
  for_each    = toset(["enabled"])
  name        = "GetFileContentsResolverKMSPolicy-${random_string.suffix.result}"
  description = "Policy for Get File Contents Resolver Lambda to use KMS key"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Effect   = "Allow"
        Resource = local.encryption_key_arn
      }
    ]
  })
}
resource "aws_iam_policy" "get_file_contents_resolver_vpc_policy" {
  #checkov:skip=CKV_AWS_355:EC2 network interface operations require wildcard resource as ENIs are created dynamically by Lambda in VPC
  #checkov:skip=CKV_AWS_290:EC2 network interface operations require wildcard resource as ENIs are created dynamically by Lambda in VPC
  count       = var.vpc_config != null ? 1 : 0
  name        = "GetFileContentsResolverVPCPolicy-${random_string.suffix.result}"
  description = "Policy for Get File Contents Resolver Lambda to access VPC"

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
}
resource "aws_iam_role_policy_attachment" "get_file_contents_resolver_logs_attachment" {
  role       = aws_iam_role.get_file_contents_resolver_role.name
  policy_arn = aws_iam_policy.get_file_contents_resolver_logs_policy.arn
}
resource "aws_iam_role_policy_attachment" "get_file_contents_resolver_s3_attachment" {
  role       = aws_iam_role.get_file_contents_resolver_role.name
  policy_arn = aws_iam_policy.get_file_contents_resolver_s3_policy.arn
}
resource "aws_iam_role_policy_attachment" "get_file_contents_resolver_kms_attachment" {
  for_each   = toset(["enabled"])
  role       = aws_iam_role.get_file_contents_resolver_role.name
  policy_arn = aws_iam_policy.get_file_contents_resolver_kms_policy["enabled"].arn
}
resource "aws_iam_role_policy_attachment" "get_file_contents_resolver_vpc_attachment" {
  count      = var.vpc_config != null ? 1 : 0
  role       = aws_iam_role.get_file_contents_resolver_role.name
  policy_arn = aws_iam_policy.get_file_contents_resolver_vpc_policy[0].arn
}

# IAM resources from lambda_get_stepfunction_execution_resolver.tf
resource "aws_iam_role" "get_stepfunction_execution_resolver_role" {
  name = "GetStepFunctionExecutionResolverRole-${random_string.suffix.result}"

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
resource "aws_iam_policy" "get_stepfunction_execution_resolver_logs_policy" {
  name        = "GetStepFunctionExecutionResolverLogsPolicy-${random_string.suffix.result}"
  description = "Policy for Get Step Function Execution Resolver Lambda to write logs to CloudWatch"

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
      }
    ]
  })
}
resource "aws_iam_policy" "get_stepfunction_execution_resolver_stepfunctions_policy" {
  #checkov:skip=CKV_AWS_355:Step Functions execution ARNs are dynamic and cannot be pre-scoped
  name        = "GetStepFunctionExecutionResolverStepFunctionsPolicy-${random_string.suffix.result}"
  description = "Policy for Get Step Function Execution Resolver Lambda to access Step Functions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "states:DescribeExecution",
          "states:GetExecutionHistory"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}
resource "aws_iam_policy" "get_stepfunction_execution_resolver_vpc_policy" {
  #checkov:skip=CKV_AWS_355:EC2 network interface operations require wildcard resource as ENIs are created dynamically by Lambda in VPC
  #checkov:skip=CKV_AWS_290:EC2 network interface operations require wildcard resource as ENIs are created dynamically by Lambda in VPC
  count       = var.vpc_config != null ? 1 : 0
  name        = "GetStepFunctionExecutionResolverVPCPolicy-${random_string.suffix.result}"
  description = "Policy for Get Step Function Execution Resolver Lambda to access VPC"

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
}
resource "aws_iam_policy" "appsync_invoke_get_stepfunction_execution_resolver_policy" {
  name        = "AppSyncInvokeGetStepFunctionExecutionResolverPolicy-${random_string.suffix.result}"
  description = "Policy for AppSync to invoke the Get Step Function Execution Resolver Lambda"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "lambda:InvokeFunction"
        Effect   = "Allow"
        Resource = aws_lambda_function.get_stepfunction_execution_resolver.arn
      }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "appsync_invoke_get_stepfunction_execution_resolver_attachment" {
  role       = aws_iam_role.appsync_lambda_role.name
  policy_arn = aws_iam_policy.appsync_invoke_get_stepfunction_execution_resolver_policy.arn
}
resource "aws_iam_role_policy_attachment" "get_stepfunction_execution_resolver_logs_attachment" {
  role       = aws_iam_role.get_stepfunction_execution_resolver_role.name
  policy_arn = aws_iam_policy.get_stepfunction_execution_resolver_logs_policy.arn
}
resource "aws_iam_role_policy_attachment" "get_stepfunction_execution_resolver_stepfunctions_attachment" {
  role       = aws_iam_role.get_stepfunction_execution_resolver_role.name
  policy_arn = aws_iam_policy.get_stepfunction_execution_resolver_stepfunctions_policy.arn
}
resource "aws_iam_role_policy_attachment" "get_stepfunction_execution_resolver_vpc_attachment" {
  count      = var.vpc_config != null ? 1 : 0
  role       = aws_iam_role.get_stepfunction_execution_resolver_role.name
  policy_arn = aws_iam_policy.get_stepfunction_execution_resolver_vpc_policy[0].arn
}

# IAM resources from lambda_query_knowledge_base_resolver.tf
resource "aws_iam_role" "query_knowledge_base_resolver_role" {
  for_each = var.knowledge_base.enabled ? toset(["enabled"]) : toset([])
  name     = "QueryKnowledgeBaseResolverRole-${random_string.suffix.result}"

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
resource "aws_iam_policy" "query_knowledge_base_resolver_logs_policy" {
  for_each    = var.knowledge_base.enabled ? toset(["enabled"]) : toset([])
  name        = "QueryKnowledgeBaseResolverLogsPolicy-${random_string.suffix.result}"
  description = "Policy for Query Knowledge Base Resolver Lambda to write logs to CloudWatch"

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
      }
    ]
  })
}
resource "aws_iam_policy" "query_knowledge_base_resolver_bedrock_policy" {
  for_each    = var.knowledge_base.enabled ? toset(["enabled"]) : toset([])
  name        = "QueryKnowledgeBaseResolverBedrockPolicy-${random_string.suffix.result}"
  description = "Policy for Query Knowledge Base Resolver Lambda to access Bedrock"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      # Foundation model permissions (always included if model_id is provided)
      local.knowledge_base_model_permissions != null ? [{
        Effect   = local.knowledge_base_model_permissions.foundation_statement.effect
        Action   = local.knowledge_base_model_permissions.foundation_statement.actions
        Resource = local.knowledge_base_model_permissions.foundation_statement.resources
      }] : [],
      # Inference profile permissions (conditional)
      local.knowledge_base_model_permissions != null && local.knowledge_base_model_permissions.inference_profile_statement != null ? [{
        Effect   = local.knowledge_base_model_permissions.inference_profile_statement.effect
        Action   = local.knowledge_base_model_permissions.inference_profile_statement.actions
        Resource = local.knowledge_base_model_permissions.inference_profile_statement.resources
      }] : [],
      # Knowledge base permissions (always included)
      [{
        Action = [
          "bedrock:Retrieve",
          "bedrock:RetrieveAndGenerate"
        ]
        Effect = "Allow"
        Resource = [
          var.knowledge_base.knowledge_base_arn != null ? var.knowledge_base.knowledge_base_arn : "*"
        ]
      }],
      # Fallback permissions if no model_id is provided
      local.knowledge_base_model_permissions == null && var.knowledge_base.model_id != null ? [{
        Action = [
          "bedrock:InvokeModel",
          "bedrock:GetFoundationModel"
        ]
        Effect = "Allow"
        Resource = [
          "arn:${data.aws_partition.current.partition}:bedrock:${data.aws_region.current.id}::foundation-model/${var.knowledge_base.model_id}"
        ]
      }] : []
    )
  })
}
resource "aws_iam_policy" "query_knowledge_base_resolver_kms_policy" {
  for_each    = var.knowledge_base.enabled ? toset(["enabled"]) : toset([])
  name        = "QueryKnowledgeBaseResolverKMSPolicy-${random_string.suffix.result}"
  description = "Policy for Query Knowledge Base Resolver Lambda to use KMS key"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Effect   = "Allow"
        Resource = local.encryption_key_arn
      }
    ]
  })
}
resource "aws_iam_policy" "query_knowledge_base_resolver_vpc_policy" {
  #checkov:skip=CKV_AWS_355:EC2 network interface operations require wildcard resource as ENIs are created dynamically by Lambda in VPC
  #checkov:skip=CKV_AWS_290:EC2 network interface operations require wildcard resource as ENIs are created dynamically by Lambda in VPC
  for_each    = var.knowledge_base.enabled && var.vpc_config != null ? toset(["enabled"]) : toset([])
  name        = "QueryKnowledgeBaseResolverVPCPolicy-${random_string.suffix.result}"
  description = "Policy for Query Knowledge Base Resolver Lambda to access VPC"

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
}
resource "aws_iam_role_policy_attachment" "query_knowledge_base_resolver_logs_attachment" {
  for_each   = var.knowledge_base.enabled ? toset(["enabled"]) : toset([])
  role       = aws_iam_role.query_knowledge_base_resolver_role["enabled"].name
  policy_arn = aws_iam_policy.query_knowledge_base_resolver_logs_policy["enabled"].arn
}
resource "aws_iam_role_policy_attachment" "query_knowledge_base_resolver_bedrock_attachment" {
  for_each   = var.knowledge_base.enabled ? toset(["enabled"]) : toset([])
  role       = aws_iam_role.query_knowledge_base_resolver_role["enabled"].name
  policy_arn = aws_iam_policy.query_knowledge_base_resolver_bedrock_policy["enabled"].arn
}
resource "aws_iam_role_policy_attachment" "query_knowledge_base_resolver_kms_attachment" {
  for_each   = var.knowledge_base.enabled ? toset(["enabled"]) : toset([])
  role       = aws_iam_role.query_knowledge_base_resolver_role["enabled"].name
  policy_arn = aws_iam_policy.query_knowledge_base_resolver_kms_policy["enabled"].arn
}
resource "aws_iam_role_policy_attachment" "query_knowledge_base_resolver_vpc_attachment" {
  for_each   = var.knowledge_base.enabled && var.vpc_config != null ? toset(["enabled"]) : toset([])
  role       = aws_iam_role.query_knowledge_base_resolver_role["enabled"].name
  policy_arn = aws_iam_policy.query_knowledge_base_resolver_vpc_policy["enabled"].arn
}

# IAM resources from lambda_reprocess_document_resolver.tf
resource "aws_iam_role" "reprocess_document_resolver_role" {
  name = "ReprocessDocumentResolverRole-${random_string.suffix.result}"

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
resource "aws_iam_policy" "reprocess_document_resolver_logs_policy" {
  name        = "ReprocessDocumentResolverLogsPolicy-${random_string.suffix.result}"
  description = "Policy for Reprocess Document Resolver Lambda to write logs to CloudWatch"

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
      }
    ]
  })
}
resource "aws_iam_policy" "reprocess_document_resolver_s3_policy" {
  name        = "ReprocessDocumentResolverS3Policy-${random_string.suffix.result}"
  description = "Policy for Reprocess Document Resolver Lambda to access S3 buckets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = compact([
          local.input_bucket_arn,
          local.input_bucket_arn != null ? "${local.input_bucket_arn}/*" : null
        ])
      }
    ]
  })
}
resource "aws_iam_policy" "reprocess_document_resolver_kms_policy" {
  for_each    = toset(["enabled"])
  name        = "ReprocessDocumentResolverKMSPolicy-${random_string.suffix.result}"
  description = "Policy for Reprocess Document Resolver Lambda to use KMS key"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Effect   = "Allow"
        Resource = local.encryption_key_arn
      }
    ]
  })
}
resource "aws_iam_policy" "reprocess_document_resolver_vpc_policy" {
  #checkov:skip=CKV_AWS_355:EC2 network interface operations require wildcard resource as ENIs are created dynamically by Lambda in VPC
  #checkov:skip=CKV_AWS_290:EC2 network interface operations require wildcard resource as ENIs are created dynamically by Lambda in VPC
  count       = var.vpc_config != null ? 1 : 0
  name        = "ReprocessDocumentResolverVPCPolicy-${random_string.suffix.result}"
  description = "Policy for Reprocess Document Resolver Lambda to access VPC"

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
}
resource "aws_iam_role_policy_attachment" "reprocess_document_resolver_logs_attachment" {
  role       = aws_iam_role.reprocess_document_resolver_role.name
  policy_arn = aws_iam_policy.reprocess_document_resolver_logs_policy.arn
}
resource "aws_iam_role_policy_attachment" "reprocess_document_resolver_s3_attachment" {
  role       = aws_iam_role.reprocess_document_resolver_role.name
  policy_arn = aws_iam_policy.reprocess_document_resolver_s3_policy.arn
}
resource "aws_iam_role_policy_attachment" "reprocess_document_resolver_kms_attachment" {
  for_each   = toset(["enabled"])
  role       = aws_iam_role.reprocess_document_resolver_role.name
  policy_arn = aws_iam_policy.reprocess_document_resolver_kms_policy["enabled"].arn
}
resource "aws_iam_role_policy_attachment" "reprocess_document_resolver_vpc_attachment" {
  count      = var.vpc_config != null ? 1 : 0
  role       = aws_iam_role.reprocess_document_resolver_role.name
  policy_arn = aws_iam_policy.reprocess_document_resolver_vpc_policy[0].arn
}

# IAM resources from lambda_upload_resolver.tf
resource "aws_iam_role" "upload_resolver_role" {
  name = "UploadResolverRole-${random_string.suffix.result}"

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
resource "aws_iam_policy" "upload_resolver_logs_policy" {
  name        = "UploadResolverLogsPolicy-${random_string.suffix.result}"
  description = "Policy for Upload Resolver Lambda to write logs to CloudWatch"

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
      }
    ]
  })
}
resource "aws_iam_policy" "upload_resolver_s3_policy" {
  name        = "UploadResolverS3Policy-${random_string.suffix.result}"
  description = "Policy for Upload Resolver Lambda to access S3 buckets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = concat(
          compact([
            local.input_bucket_arn,
            local.input_bucket_arn != null ? "${local.input_bucket_arn}/*" : null,
            local.output_bucket_arn,
            local.output_bucket_arn != null ? "${local.output_bucket_arn}/*" : null
          ]),
          local.evaluation_baseline_bucket_arn != null ? [
            local.evaluation_baseline_bucket_arn,
            local.evaluation_baseline_bucket_arn != null ? "${local.evaluation_baseline_bucket_arn}/*" : null
          ] : []
        )
      }
    ]
  })
}
resource "aws_iam_policy" "upload_resolver_kms_policy" {
  for_each    = toset(["enabled"])
  name        = "UploadResolverKMSPolicy-${random_string.suffix.result}"
  description = "Policy for Upload Resolver Lambda to use KMS key"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Effect   = "Allow"
        Resource = local.encryption_key_arn
      }
    ]
  })
}
resource "aws_iam_policy" "upload_resolver_vpc_policy" {
  #checkov:skip=CKV_AWS_355:EC2 network interface operations require wildcard resource as ENIs are created dynamically by Lambda in VPC
  #checkov:skip=CKV_AWS_290:EC2 network interface operations require wildcard resource as ENIs are created dynamically by Lambda in VPC
  count       = var.vpc_config != null ? 1 : 0
  name        = "UploadResolverVPCPolicy-${random_string.suffix.result}"
  description = "Policy for Upload Resolver Lambda to access VPC"

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
}
resource "aws_iam_role_policy_attachment" "upload_resolver_logs_attachment" {
  role       = aws_iam_role.upload_resolver_role.name
  policy_arn = aws_iam_policy.upload_resolver_logs_policy.arn
}
resource "aws_iam_role_policy_attachment" "upload_resolver_s3_attachment" {
  role       = aws_iam_role.upload_resolver_role.name
  policy_arn = aws_iam_policy.upload_resolver_s3_policy.arn
}
resource "aws_iam_role_policy_attachment" "upload_resolver_kms_attachment" {
  for_each   = toset(["enabled"])
  role       = aws_iam_role.upload_resolver_role.name
  policy_arn = aws_iam_policy.upload_resolver_kms_policy["enabled"].arn
}
resource "aws_iam_role_policy_attachment" "upload_resolver_vpc_attachment" {
  count      = var.vpc_config != null ? 1 : 0
  role       = aws_iam_role.upload_resolver_role.name
  policy_arn = aws_iam_policy.upload_resolver_vpc_policy[0].arn
}




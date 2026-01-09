# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

# =============================================================================
# IAM Role for Agent Request Handler Lambda
# =============================================================================

resource "aws_iam_role" "agent_request_handler_role" {
  name = "${var.name_prefix}-agent-request-role-${local.suffix}"

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

resource "aws_iam_policy" "agent_request_handler_policy" {
  name = "${var.name_prefix}-agent-request-policy-${local.suffix}"

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
          "dynamodb:UpdateItem"
        ]
        Resource = aws_dynamodb_table.agent_jobs.arn
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = aws_lambda_function.agent_processor.arn
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "agent_request_handler_policy_attachment" {
  role       = aws_iam_role.agent_request_handler_role.name
  policy_arn = aws_iam_policy.agent_request_handler_policy.arn
}

# VPC policy for request handler
resource "aws_iam_policy" "agent_request_handler_vpc_policy" {
  #checkov:skip=CKV_AWS_355:EC2 network interface operations require wildcard resource as ENIs are created dynamically by Lambda in VPC
  #checkov:skip=CKV_AWS_290:EC2 network interface operations require wildcard resource as ENIs are created dynamically by Lambda in VPC
  count = length(var.vpc_subnet_ids) > 0 ? 1 : 0
  name  = "${var.name_prefix}-agent-request-vpc-policy-${local.suffix}"

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

resource "aws_iam_role_policy_attachment" "agent_request_handler_vpc_attachment" {
  count      = length(var.vpc_subnet_ids) > 0 ? 1 : 0
  role       = aws_iam_role.agent_request_handler_role.name
  policy_arn = aws_iam_policy.agent_request_handler_vpc_policy[0].arn
}

# KMS policy for request handler
resource "aws_iam_policy" "agent_request_handler_kms_policy" {
  count = var.enable_encryption ? 1 : 0
  name  = "${var.name_prefix}-agent-request-kms-policy-${local.suffix}"

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

resource "aws_iam_role_policy_attachment" "agent_request_handler_kms_attachment" {
  count      = var.enable_encryption ? 1 : 0
  role       = aws_iam_role.agent_request_handler_role.name
  policy_arn = aws_iam_policy.agent_request_handler_kms_policy[0].arn
}


# =============================================================================
# IAM Role for Agent Processor Lambda
# =============================================================================

resource "aws_iam_role" "agent_processor_role" {
  name = "${var.name_prefix}-agent-processor-role-${local.suffix}"

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

resource "aws_iam_policy" "agent_processor_policy" {
  name = "${var.name_prefix}-agent-processor-policy-${local.suffix}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
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
          "dynamodb:Query"
        ]
        Resource = aws_dynamodb_table.agent_jobs.arn
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = "arn:${data.aws_partition.current.partition}:dynamodb:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:table/${var.configuration_table_name}"
      },
      # Foundation model permissions (always needed)
      {
        Effect   = local.bedrock_model_permissions.foundation_statement.effect
        Action   = local.bedrock_model_permissions.foundation_statement.actions
        Resource = local.bedrock_model_permissions.foundation_statement.resources
      }],
      # Inference profile permissions (only for cross-region inference profiles)
      local.bedrock_model_permissions.inference_profile_statement != null ? [{
        Effect   = local.bedrock_model_permissions.inference_profile_statement.effect
        Action   = local.bedrock_model_permissions.inference_profile_statement.actions
        Resource = local.bedrock_model_permissions.inference_profile_statement.resources
      }] : [],
      [
        {
          Effect = "Allow"
          Action = [
            "bedrock-agentcore:StartCodeInterpreterSession",
            "bedrock-agentcore:StopCodeInterpreterSession",
            "bedrock-agentcore:InvokeCodeInterpreter",
            "bedrock-agentcore:GetCodeInterpreterSession",
            "bedrock-agentcore:ListCodeInterpreterSessions"
          ]
          Resource = "arn:${data.aws_partition.current.partition}:bedrock-agentcore:*:aws:code-interpreter/*"
        },
        {
          Effect = "Allow"
          Action = [
            "athena:StartQueryExecution",
            "athena:GetQueryExecution",
            "athena:GetQueryResults",
            "athena:StopQueryExecution",
            "athena:GetWorkGroup",
            "athena:GetDataCatalog",
            "athena:GetDatabase",
            "athena:GetTableMetadata",
            "athena:ListDatabases",
            "athena:ListTableMetadata"
          ]
          Resource = [
            "arn:${data.aws_partition.current.partition}:athena:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:workgroup/primary",
            "arn:${data.aws_partition.current.partition}:athena:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:datacatalog/*"
          ]
        },
        {
          Effect = "Allow"
          Action = [
            "glue:GetDatabase",
            "glue:GetDatabases",
            "glue:GetTable",
            "glue:GetTables",
            "glue:GetPartitions"
          ]
          Resource = [
            "arn:${data.aws_partition.current.partition}:glue:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:catalog",
            "arn:${data.aws_partition.current.partition}:glue:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:database/${var.reporting_database_name}",
            "arn:${data.aws_partition.current.partition}:glue:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:table/${var.reporting_database_name}/*"
          ]
        },
        {
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:PutObject",
            "s3:ListBucket",
            "s3:GetBucketLocation"
          ]
          Resource = [
            var.athena_results_bucket_arn,
            "${var.athena_results_bucket_arn}/*"
          ]
        },
        {
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:PutObject",
            "s3:DeleteObject",
            "s3:ListBucket",
            "s3:GetBucketLocation"
          ]
          Resource = [
            var.reporting_bucket_arn,
            "${var.reporting_bucket_arn}/*"
          ]
        }
    ])
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "agent_processor_policy_attachment" {
  role       = aws_iam_role.agent_processor_role.name
  policy_arn = aws_iam_policy.agent_processor_policy.arn
}

# AppSync policy for processor (to update job status)
resource "aws_iam_policy" "agent_processor_appsync_policy" {
  name = "${var.name_prefix}-agent-processor-appsync-policy-${local.suffix}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "appsync:GraphQL"
        ]
        Resource = "arn:${data.aws_partition.current.partition}:appsync:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:apis/${var.appsync_api_id}/*"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "agent_processor_appsync_attachment" {
  role       = aws_iam_role.agent_processor_role.name
  policy_arn = aws_iam_policy.agent_processor_appsync_policy.arn
}

# VPC policy for processor
resource "aws_iam_policy" "agent_processor_vpc_policy" {
  #checkov:skip=CKV_AWS_355:EC2 network interface operations require wildcard resource as ENIs are created dynamically by Lambda in VPC
  #checkov:skip=CKV_AWS_290:EC2 network interface operations require wildcard resource as ENIs are created dynamically by Lambda in VPC
  count = length(var.vpc_subnet_ids) > 0 ? 1 : 0
  name  = "${var.name_prefix}-agent-processor-vpc-policy-${local.suffix}"

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

resource "aws_iam_role_policy_attachment" "agent_processor_vpc_attachment" {
  count      = length(var.vpc_subnet_ids) > 0 ? 1 : 0
  role       = aws_iam_role.agent_processor_role.name
  policy_arn = aws_iam_policy.agent_processor_vpc_policy[0].arn
}

# KMS policy for processor
resource "aws_iam_policy" "agent_processor_kms_policy" {
  count = var.enable_encryption ? 1 : 0
  name  = "${var.name_prefix}-agent-processor-kms-policy-${local.suffix}"

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

resource "aws_iam_role_policy_attachment" "agent_processor_kms_attachment" {
  count      = var.enable_encryption ? 1 : 0
  role       = aws_iam_role.agent_processor_role.name
  policy_arn = aws_iam_policy.agent_processor_kms_policy[0].arn
}

# =============================================================================
# IAM Role for List Available Agents Lambda
# =============================================================================

resource "aws_iam_role" "list_available_agents_role" {
  name = "${var.name_prefix}-list-agents-role-${local.suffix}"

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

resource "aws_iam_policy" "list_available_agents_policy" {
  name = "${var.name_prefix}-list-agents-policy-${local.suffix}"

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
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "list_available_agents_policy_attachment" {
  role       = aws_iam_role.list_available_agents_role.name
  policy_arn = aws_iam_policy.list_available_agents_policy.arn
}

# VPC policy for list agents
resource "aws_iam_policy" "list_available_agents_vpc_policy" {
  #checkov:skip=CKV_AWS_355:EC2 network interface operations require wildcard resource as ENIs are created dynamically by Lambda in VPC
  #checkov:skip=CKV_AWS_290:EC2 network interface operations require wildcard resource as ENIs are created dynamically by Lambda in VPC
  count = length(var.vpc_subnet_ids) > 0 ? 1 : 0
  name  = "${var.name_prefix}-list-agents-vpc-policy-${local.suffix}"

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

resource "aws_iam_role_policy_attachment" "list_available_agents_vpc_attachment" {
  count      = length(var.vpc_subnet_ids) > 0 ? 1 : 0
  role       = aws_iam_role.list_available_agents_role.name
  policy_arn = aws_iam_policy.list_available_agents_vpc_policy[0].arn
}

# KMS policy for list agents
resource "aws_iam_policy" "list_available_agents_kms_policy" {
  count = var.enable_encryption ? 1 : 0
  name  = "${var.name_prefix}-list-agents-kms-policy-${local.suffix}"

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

resource "aws_iam_role_policy_attachment" "list_available_agents_kms_attachment" {
  count      = var.enable_encryption ? 1 : 0
  role       = aws_iam_role.list_available_agents_role.name
  policy_arn = aws_iam_policy.list_available_agents_kms_policy[0].arn
}

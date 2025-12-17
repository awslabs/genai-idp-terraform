# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# IAM Role for QueueSender Lambda Function
resource "aws_iam_role" "queue_sender_role" {
  name = "idp-queue-sender-role-${random_string.suffix.result}"

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

# IAM Policy for QueueSender Lambda Function
resource "aws_iam_policy" "queue_sender_policy" {
  name        = "idp-queue-sender-policy-${random_string.suffix.result}"
  description = "Policy for QueueSender Lambda Function"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect = "Allow"
        Resource = [
          "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${local.queue_sender_function_name}",
          "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${local.queue_sender_function_name}:*"
        ]
      },
      {
        Action = [
          "sqs:SendMessage",
          "sqs:GetQueueAttributes"
        ]
        Effect   = "Allow"
        Resource = aws_sqs_queue.document_queue.arn
      },
      {
        Action = [
          "sqs:SendMessage"
        ]
        Effect   = "Allow"
        Resource = aws_sqs_queue.queue_sender_dlq.arn
      },
      {
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = [
          var.input_bucket_arn,
          "${var.input_bucket_arn}/*"
        ]
      },
      {
        Action = [
          "s3:PutObject"
        ]
        Effect = "Allow"
        Resource = [
          var.output_bucket_arn,
          "${var.output_bucket_arn}/*"
        ]
      },
      {
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Effect = "Allow"
        Resource = [
          local.tracking_table.table_arn,
          "${local.tracking_table.table_arn}/index/*"
        ]
      }
    ]
  })
}

# Attach policy to QueueSender role
resource "aws_iam_role_policy_attachment" "queue_sender_policy_attachment" {
  role       = aws_iam_role.queue_sender_role.name
  policy_arn = aws_iam_policy.queue_sender_policy.arn
}

# Add KMS permissions if key is provided
resource "aws_iam_policy" "queue_sender_kms_policy" {
  for_each    = var.enable_encryption ? toset(["enabled"]) : toset([])
  name        = "idp-queue-sender-kms-policy-${random_string.suffix.result}"
  description = "KMS policy for QueueSender Lambda Function"

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

resource "aws_iam_role_policy_attachment" "queue_sender_kms_attachment" {
  for_each   = var.enable_encryption ? toset(["enabled"]) : toset([])
  role       = aws_iam_role.queue_sender_role.name
  policy_arn = aws_iam_policy.queue_sender_kms_policy["enabled"].arn
}

# Add AppSync permissions if API is provided
resource "aws_iam_policy" "queue_sender_appsync_policy" {
  count       = var.api != null ? 1 : 0
  name        = "idp-queue-sender-appsync-policy-${random_string.suffix.result}"
  description = "AppSync policy for QueueSender Lambda Function"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "appsync:GraphQL"
        ]
        Effect   = "Allow"
        Resource = "${var.api.api_arn}/types/Mutation/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "queue_sender_appsync_attachment" {
  count      = var.api != null ? 1 : 0
  role       = aws_iam_role.queue_sender_role.name
  policy_arn = aws_iam_policy.queue_sender_appsync_policy[0].arn
}

# IAM Role for WorkflowTracker Lambda Function
resource "aws_iam_role" "workflow_tracker_role" {
  name = "idp-workflow-tracker-role-${random_string.suffix.result}"

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

# IAM Policy for WorkflowTracker Lambda Function
resource "aws_iam_policy" "workflow_tracker_policy" {
  name        = "idp-workflow-tracker-policy-${random_string.suffix.result}"
  description = "Policy for WorkflowTracker Lambda Function"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect = "Allow"
        Resource = [
          "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${local.workflow_tracker_function_name}",
          "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${local.workflow_tracker_function_name}:*"
        ]
      },
      {
        Action = [
          "sqs:SendMessage"
        ]
        Effect   = "Allow"
        Resource = aws_sqs_queue.workflow_tracker_dlq.arn
      },
      {
        Action = [
          "dynamodb:GetItem",
          "dynamodb:UpdateItem"
        ]
        Effect   = "Allow"
        Resource = local.concurrency_table.table_arn
      },
      {
        Action = [
          "s3:GetObject"
        ]
        Effect = "Allow"
        Resource = [
          var.output_bucket_arn,
          "${var.output_bucket_arn}/*",
          var.working_bucket_arn,
          "${var.working_bucket_arn}/*"
        ]
      },
      {
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Effect = "Allow"
        Resource = [
          local.tracking_table.table_arn,
          "${local.tracking_table.table_arn}/index/*"
        ]
      },
      {
        # CloudWatch PutMetricData requires wildcard resource but is constrained by namespace condition
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Effect   = "Allow"
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = var.metric_namespace
          }
        }
      }
      ], var.enable_reporting ? [
      {
        Action = [
          "lambda:InvokeFunction"
        ]
        Effect   = "Allow"
        Resource = aws_lambda_function.save_reporting_data[0].arn
      }
    ] : [])
  })
}

# Attach policy to WorkflowTracker role
resource "aws_iam_role_policy_attachment" "workflow_tracker_policy_attachment" {
  role       = aws_iam_role.workflow_tracker_role.name
  policy_arn = aws_iam_policy.workflow_tracker_policy.arn
}

# Add KMS permissions if key is provided
resource "aws_iam_policy" "workflow_tracker_kms_policy" {
  for_each    = var.enable_encryption ? toset(["enabled"]) : toset([])
  name        = "idp-workflow-tracker-kms-policy-${random_string.suffix.result}"
  description = "KMS policy for WorkflowTracker Lambda Function"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Effect   = "Allow"
        Resource = local.key.key_arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "workflow_tracker_kms_attachment" {
  for_each   = var.enable_encryption ? toset(["enabled"]) : toset([])
  role       = aws_iam_role.workflow_tracker_role.name
  policy_arn = aws_iam_policy.workflow_tracker_kms_policy["enabled"].arn
}

# Add AppSync permissions if API is provided
resource "aws_iam_policy" "workflow_tracker_appsync_policy" {
  count       = var.api != null ? 1 : 0
  name        = "idp-workflow-tracker-appsync-policy-${random_string.suffix.result}"
  description = "AppSync policy for WorkflowTracker Lambda Function"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "appsync:GraphQL"
        ]
        Effect   = "Allow"
        Resource = "${var.api.api_arn}/types/Mutation/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "workflow_tracker_appsync_attachment" {
  count      = var.api != null ? 1 : 0
  role       = aws_iam_role.workflow_tracker_role.name
  policy_arn = aws_iam_policy.workflow_tracker_appsync_policy[0].arn
}

# IAM Role for LookupFunction Lambda Function
resource "aws_iam_role" "lookup_function_role" {
  name = "idp-lookup-function-role-${random_string.suffix.result}"

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

# IAM Policy for LookupFunction Lambda Function
resource "aws_iam_policy" "lookup_function_policy" {
  name        = "idp-lookup-function-policy-${random_string.suffix.result}"
  description = "Policy for LookupFunction Lambda Function"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect = "Allow"
        Resource = [
          "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${local.lookup_function_name}",
          "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${local.lookup_function_name}:*"
        ]
      },
      {
        Action = [
          "dynamodb:GetItem",
          "dynamodb:Query"
        ]
        Effect   = "Allow"
        Resource = local.tracking_table.table_arn
      }
    ]
  })
}

# Attach policy to LookupFunction role
resource "aws_iam_role_policy_attachment" "lookup_function_policy_attachment" {
  role       = aws_iam_role.lookup_function_role.name
  policy_arn = aws_iam_policy.lookup_function_policy.arn
}

# Add KMS permissions if key is provided
resource "aws_iam_policy" "lookup_function_kms_policy" {
  for_each    = var.enable_encryption ? toset(["enabled"]) : toset([])
  name        = "idp-lookup-function-kms-policy-${random_string.suffix.result}"
  description = "KMS policy for LookupFunction Lambda Function"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Effect   = "Allow"
        Resource = local.key.key_arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lookup_function_kms_attachment" {
  for_each   = var.enable_encryption ? toset(["enabled"]) : toset([])
  role       = aws_iam_role.lookup_function_role.name
  policy_arn = aws_iam_policy.lookup_function_kms_policy["enabled"].arn
}

# IAM Role for UpdateConfiguration Lambda Function
resource "aws_iam_role" "update_configuration_role" {
  name = "idp-update-configuration-role-${random_string.suffix.result}"

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

# IAM Policy for UpdateConfiguration Lambda Function
resource "aws_iam_policy" "update_configuration_policy" {
  name        = "idp-update-configuration-policy-${random_string.suffix.result}"
  description = "Policy for UpdateConfiguration Lambda Function"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect = "Allow"
        Resource = [
          "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${local.update_configuration_function_name}",
          "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${local.update_configuration_function_name}:*"
        ]
      },
      {
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem"
        ]
        Effect   = "Allow"
        Resource = local.configuration_table.table_arn
      }
    ]
  })
}

# Attach policy to UpdateConfiguration role
resource "aws_iam_role_policy_attachment" "update_configuration_policy_attachment" {
  role       = aws_iam_role.update_configuration_role.name
  policy_arn = aws_iam_policy.update_configuration_policy.arn
}

# Add KMS permissions if key is provided
resource "aws_iam_policy" "update_configuration_kms_policy" {
  for_each    = var.enable_encryption ? toset(["enabled"]) : toset([])
  name        = "idp-update-configuration-kms-policy-${random_string.suffix.result}"
  description = "KMS policy for UpdateConfiguration Lambda Function"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Effect   = "Allow"
        Resource = local.key.key_arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "update_configuration_kms_attachment" {
  for_each   = var.enable_encryption ? toset(["enabled"]) : toset([])
  role       = aws_iam_role.update_configuration_role.name
  policy_arn = aws_iam_policy.update_configuration_kms_policy["enabled"].arn
}

# Add VPC permissions if VPC config is provided
resource "aws_iam_policy" "lambda_vpc_policy" {
  #checkov:skip=CKV_AWS_355:EC2 network interface operations require wildcard resource as ENIs are created dynamically by Lambda in VPC
  #checkov:skip=CKV_AWS_290:EC2 network interface operations require wildcard resource as ENIs are created dynamically by Lambda in VPC
  count       = length(var.subnet_ids) > 0 ? 1 : 0
  name        = "idp-lambda-vpc-policy-${random_string.suffix.result}"
  description = "VPC policy for Lambda Functions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # EC2 network interface operations for VPC Lambda - AWS service limitation requires wildcard resource
        # These permissions are required for Lambda functions to create/manage ENIs in VPC
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

resource "aws_iam_role_policy_attachment" "queue_sender_vpc_attachment" {
  count      = length(var.subnet_ids) > 0 ? 1 : 0
  role       = aws_iam_role.queue_sender_role.name
  policy_arn = aws_iam_policy.lambda_vpc_policy[0].arn
}

resource "aws_iam_role_policy_attachment" "workflow_tracker_vpc_attachment" {
  count      = length(var.subnet_ids) > 0 ? 1 : 0
  role       = aws_iam_role.workflow_tracker_role.name
  policy_arn = aws_iam_policy.lambda_vpc_policy[0].arn
}

resource "aws_iam_role_policy_attachment" "lookup_function_vpc_attachment" {
  count      = length(var.subnet_ids) > 0 ? 1 : 0
  role       = aws_iam_role.lookup_function_role.name
  policy_arn = aws_iam_policy.lambda_vpc_policy[0].arn
}

resource "aws_iam_role_policy_attachment" "update_configuration_vpc_attachment" {
  count      = length(var.subnet_ids) > 0 ? 1 : 0
  role       = aws_iam_role.update_configuration_role.name
  policy_arn = aws_iam_policy.lambda_vpc_policy[0].arn
}

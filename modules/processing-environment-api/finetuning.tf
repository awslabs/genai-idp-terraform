# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Fine-tuning / Custom Models subsystem
# Conditional on var.enable_finetuning (requires var.enable_test_studio)

locals {
  finetuning_enabled = var.enable_finetuning

  finetuning_data_bucket_name   = "${local.api_name}-finetuning-data"
  finetuning_state_machine_name = "${local.api_name}-finetuning"
  finetuning_state_machine_arn  = "arn:${data.aws_partition.current.partition}:states:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:stateMachine:${local.finetuning_state_machine_name}"

  finetuning_kms_arn = local.kms_policy_resource_arn

  finetuning_test_set_bucket_id  = var.enable_finetuning ? aws_s3_bucket.test_sets[0].id : ""
  finetuning_test_set_bucket_arn = var.enable_finetuning ? aws_s3_bucket.test_sets[0].arn : ""
}

check "finetuning_requires_test_studio" {
  assert {
    condition     = !var.enable_finetuning || var.enable_test_studio
    error_message = "enable_finetuning = true requires enable_test_studio = true (the fine-tuning workflow reads the Test Studio test-sets bucket)."
  }
}

# =============================================================================
# S3 Bucket: finetuning data
# =============================================================================

resource "aws_s3_bucket" "finetuning_data" {
  count  = local.finetuning_enabled ? 1 : 0
  bucket = local.finetuning_data_bucket_name
  tags   = var.tags
}

resource "aws_s3_bucket_versioning" "finetuning_data" {
  count  = local.finetuning_enabled ? 1 : 0
  bucket = aws_s3_bucket.finetuning_data[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "finetuning_data" {
  count  = local.finetuning_enabled ? 1 : 0
  bucket = aws_s3_bucket.finetuning_data[0].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = local.encryption_key_arn != null ? "aws:kms" : "AES256"
      kms_master_key_id = local.encryption_key_arn
    }
    bucket_key_enabled = local.encryption_key_arn != null
  }
}

resource "aws_s3_bucket_public_access_block" "finetuning_data" {
  count                   = local.finetuning_enabled ? 1 : 0
  bucket                  = aws_s3_bucket.finetuning_data[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "finetuning_data" {
  count  = local.finetuning_enabled ? 1 : 0
  bucket = aws_s3_bucket.finetuning_data[0].id
  rule {
    id     = "expire-finetuning-data"
    status = "Enabled"
    filter {}
    expiration {
      days = var.data_retention_in_days
    }
  }
}

resource "aws_s3_bucket_policy" "finetuning_data" {
  count  = local.finetuning_enabled ? 1 : 0
  bucket = aws_s3_bucket.finetuning_data[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnforceSSLOnly"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.finetuning_data[0].arn,
          "${aws_s3_bucket.finetuning_data[0].arn}/*"
        ]
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      },
      {
        Sid       = "AllowBedrockAccess"
        Effect    = "Allow"
        Principal = { Service = "bedrock.${data.aws_partition.current.dns_suffix}" }
        Action    = ["s3:GetObject", "s3:ListBucket"]
        Resource = [
          aws_s3_bucket.finetuning_data[0].arn,
          "${aws_s3_bucket.finetuning_data[0].arn}/*"
        ]
        Condition = {
          StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
        }
      }
    ]
  })
}

# =============================================================================
# IAM Role: Bedrock fine-tuning service role
# =============================================================================

resource "aws_iam_role" "bedrock_finetuning" {
  count = local.finetuning_enabled ? 1 : 0
  name  = "${local.api_name}-bedrock-finetuning"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "bedrock.${data.aws_partition.current.dns_suffix}" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "bedrock_finetuning" {
  count = local.finetuning_enabled ? 1 : 0
  name  = "bedrock-finetuning-policy"
  role  = aws_iam_role.bedrock_finetuning[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:ListBucket", "s3:PutObject"]
        Resource = [
          aws_s3_bucket.finetuning_data[0].arn,
          "${aws_s3_bucket.finetuning_data[0].arn}/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
        Resource = local.finetuning_kms_arn
      }
    ]
  })
}

# =============================================================================
# Lambda: finetuning_list_documents (plain zip)
# =============================================================================

resource "aws_iam_role" "finetuning_list_documents" {
  count = local.finetuning_enabled ? 1 : 0
  name  = "${local.api_name}-ft-list-documents"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "finetuning_list_documents" {
  count = local.finetuning_enabled ? 1 : 0
  name  = "ft-list-documents-policy"
  role  = aws_iam_role.finetuning_list_documents[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:${data.aws_partition.current.partition}:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem",
          "dynamodb:DeleteItem", "dynamodb:Query", "dynamodb:Scan"
        ]
        Resource = [
          local.tracking_table_arn,
          "${local.tracking_table_arn}/index/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:ListBucket"]
        Resource = [local.finetuning_test_set_bucket_arn, "${local.finetuning_test_set_bucket_arn}/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
        Resource = local.finetuning_kms_arn
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "finetuning_list_documents" {
  count             = local.finetuning_enabled ? 1 : 0
  name              = "/aws/lambda/${local.api_name}-ft-list-documents"
  retention_in_days = var.log_retention_days
  kms_key_id        = local.encryption_key_arn
  tags              = var.tags
}

data "archive_file" "finetuning_list_documents" {
  count       = local.finetuning_enabled ? 1 : 0
  type        = "zip"
  source_dir  = "${path.module}/../../sources/src/lambda/finetuning_list_documents"
  output_path = "${path.module}/../../.terraform/archives/finetuning_list_documents.zip"
}

resource "aws_lambda_function" "finetuning_list_documents" {
  architectures    = [var.lambda_architecture]
  count            = local.finetuning_enabled ? 1 : 0
  function_name    = "${local.api_name}-ft-list-documents"
  role             = aws_iam_role.finetuning_list_documents[0].arn
  filename         = data.archive_file.finetuning_list_documents[0].output_path
  source_code_hash = data.archive_file.finetuning_list_documents[0].output_base64sha256
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 300
  memory_size      = 512
  layers           = compact([var.base_layer_arn, var.idp_common_layer_arn])
  environment {
    variables = {
      LOG_LEVEL              = var.log_level
      TRACKING_TABLE         = local.tracking_table_name
      TEST_SET_BUCKET        = local.finetuning_test_set_bucket_id
      FINETUNING_DATA_BUCKET = aws_s3_bucket.finetuning_data[0].id
    }
  }
  tracing_config { mode = var.lambda_tracing_mode }
  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }
  depends_on = [aws_cloudwatch_log_group.finetuning_list_documents]
  tags       = var.tags
}

# =============================================================================
# Lambda: finetuning_merge_data (plain zip)
# =============================================================================

resource "aws_iam_role" "finetuning_merge_data" {
  count = local.finetuning_enabled ? 1 : 0
  name  = "${local.api_name}-ft-merge-data"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "finetuning_merge_data" {
  count = local.finetuning_enabled ? 1 : 0
  name  = "ft-merge-data-policy"
  role  = aws_iam_role.finetuning_merge_data[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:${data.aws_partition.current.partition}:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem",
          "dynamodb:DeleteItem", "dynamodb:Query", "dynamodb:Scan"
        ]
        Resource = [
          local.tracking_table_arn,
          "${local.tracking_table_arn}/index/*"
        ]
      },
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
        Resource = [
          aws_s3_bucket.finetuning_data[0].arn,
          "${aws_s3_bucket.finetuning_data[0].arn}/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
        Resource = local.finetuning_kms_arn
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "finetuning_merge_data" {
  count             = local.finetuning_enabled ? 1 : 0
  name              = "/aws/lambda/${local.api_name}-ft-merge-data"
  retention_in_days = var.log_retention_days
  kms_key_id        = local.encryption_key_arn
  tags              = var.tags
}

data "archive_file" "finetuning_merge_data" {
  count       = local.finetuning_enabled ? 1 : 0
  type        = "zip"
  source_dir  = "${path.module}/../../sources/src/lambda/finetuning_merge_data"
  output_path = "${path.module}/../../.terraform/archives/finetuning_merge_data.zip"
}

resource "aws_lambda_function" "finetuning_merge_data" {
  architectures    = [var.lambda_architecture]
  count            = local.finetuning_enabled ? 1 : 0
  function_name    = "${local.api_name}-ft-merge-data"
  role             = aws_iam_role.finetuning_merge_data[0].arn
  filename         = data.archive_file.finetuning_merge_data[0].output_path
  source_code_hash = data.archive_file.finetuning_merge_data[0].output_base64sha256
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 900
  memory_size      = 3072
  layers           = compact([var.base_layer_arn, var.idp_common_layer_arn])
  environment {
    variables = {
      LOG_LEVEL              = var.log_level
      TRACKING_TABLE         = local.tracking_table_name
      FINETUNING_DATA_BUCKET = aws_s3_bucket.finetuning_data[0].id
    }
  }
  tracing_config { mode = var.lambda_tracing_mode }
  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }
  depends_on = [aws_cloudwatch_log_group.finetuning_merge_data]
  tags       = var.tags
}

# =============================================================================
# Lambda: finetuning_job_creator (plain zip; pyyaml from base layer)
# =============================================================================

resource "aws_iam_role" "finetuning_job_creator" {
  count = local.finetuning_enabled ? 1 : 0
  name  = "${local.api_name}-ft-job-creator"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "finetuning_job_creator" {
  count = local.finetuning_enabled ? 1 : 0
  name  = "ft-job-creator-policy"
  role  = aws_iam_role.finetuning_job_creator[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:${data.aws_partition.current.partition}:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem",
          "dynamodb:DeleteItem", "dynamodb:Query", "dynamodb:Scan"
        ]
        Resource = [
          local.tracking_table_arn,
          "${local.tracking_table_arn}/index/*"
        ]
      },
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:ListBucket"]
        Resource = [
          aws_s3_bucket.finetuning_data[0].arn,
          "${aws_s3_bucket.finetuning_data[0].arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = ["bedrock:CreateModelCustomizationJob", "bedrock:TagResource"]
        Resource = [
          "arn:${data.aws_partition.current.partition}:bedrock:*::foundation-model/*",
          "arn:${data.aws_partition.current.partition}:bedrock:*:${data.aws_caller_identity.current.account_id}:model-customization-job/*",
          "arn:${data.aws_partition.current.partition}:bedrock:*:${data.aws_caller_identity.current.account_id}:custom-model/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = aws_iam_role.bedrock_finetuning[0].arn
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
        Resource = local.finetuning_kms_arn
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "finetuning_job_creator" {
  count             = local.finetuning_enabled ? 1 : 0
  name              = "/aws/lambda/${local.api_name}-ft-job-creator"
  retention_in_days = var.log_retention_days
  kms_key_id        = local.encryption_key_arn
  tags              = var.tags
}

data "archive_file" "finetuning_job_creator" {
  count       = local.finetuning_enabled ? 1 : 0
  type        = "zip"
  source_dir  = "${path.module}/../../sources/src/lambda/finetuning_job_creator"
  output_path = "${path.module}/../../.terraform/archives/finetuning_job_creator.zip"
}

resource "aws_lambda_function" "finetuning_job_creator" {
  architectures    = [var.lambda_architecture]
  count            = local.finetuning_enabled ? 1 : 0
  function_name    = "${local.api_name}-ft-job-creator"
  role             = aws_iam_role.finetuning_job_creator[0].arn
  filename         = data.archive_file.finetuning_job_creator[0].output_path
  source_code_hash = data.archive_file.finetuning_job_creator[0].output_base64sha256
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 60
  memory_size      = 256
  layers           = compact([var.base_layer_arn, var.idp_common_layer_arn])
  environment {
    variables = {
      LOG_LEVEL                   = var.log_level
      TRACKING_TABLE              = local.tracking_table_name
      FINETUNING_DATA_BUCKET      = aws_s3_bucket.finetuning_data[0].id
      BEDROCK_FINETUNING_ROLE_ARN = aws_iam_role.bedrock_finetuning[0].arn
    }
  }
  tracing_config { mode = var.lambda_tracing_mode }
  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }
  depends_on = [aws_cloudwatch_log_group.finetuning_job_creator]
  tags       = var.tags
}

# =============================================================================
# Lambda: finetuning_job_status_checker (plain zip)
# =============================================================================

resource "aws_iam_role" "finetuning_job_status_checker" {
  count = local.finetuning_enabled ? 1 : 0
  name  = "${local.api_name}-ft-status-checker"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "finetuning_job_status_checker" {
  count = local.finetuning_enabled ? 1 : 0
  name  = "ft-status-checker-policy"
  role  = aws_iam_role.finetuning_job_status_checker[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:${data.aws_partition.current.partition}:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem",
          "dynamodb:DeleteItem", "dynamodb:Query", "dynamodb:Scan"
        ]
        Resource = [
          local.tracking_table_arn,
          "${local.tracking_table_arn}/index/*"
        ]
      },
      {
        Effect = "Allow"
        Action = ["bedrock:GetModelCustomizationJob", "bedrock:GetCustomModel", "bedrock:GetCustomModelDeployment"]
        Resource = [
          "arn:${data.aws_partition.current.partition}:bedrock:*:${data.aws_caller_identity.current.account_id}:model-customization-job/*",
          "arn:${data.aws_partition.current.partition}:bedrock:*:${data.aws_caller_identity.current.account_id}:custom-model/*",
          "arn:${data.aws_partition.current.partition}:bedrock:*:${data.aws_caller_identity.current.account_id}:custom-model-deployment/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
        Resource = local.finetuning_kms_arn
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "finetuning_job_status_checker" {
  count             = local.finetuning_enabled ? 1 : 0
  name              = "/aws/lambda/${local.api_name}-ft-status-checker"
  retention_in_days = var.log_retention_days
  kms_key_id        = local.encryption_key_arn
  tags              = var.tags
}

data "archive_file" "finetuning_job_status_checker" {
  count       = local.finetuning_enabled ? 1 : 0
  type        = "zip"
  source_dir  = "${path.module}/../../sources/src/lambda/finetuning_job_status_checker"
  output_path = "${path.module}/../../.terraform/archives/finetuning_job_status_checker.zip"
}

resource "aws_lambda_function" "finetuning_job_status_checker" {
  architectures    = [var.lambda_architecture]
  count            = local.finetuning_enabled ? 1 : 0
  function_name    = "${local.api_name}-ft-status-checker"
  role             = aws_iam_role.finetuning_job_status_checker[0].arn
  filename         = data.archive_file.finetuning_job_status_checker[0].output_path
  source_code_hash = data.archive_file.finetuning_job_status_checker[0].output_base64sha256
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 60
  memory_size      = 256
  layers           = compact([var.base_layer_arn, var.idp_common_layer_arn])
  environment {
    variables = {
      LOG_LEVEL      = var.log_level
      TRACKING_TABLE = local.tracking_table_name
    }
  }
  tracing_config { mode = var.lambda_tracing_mode }
  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }
  depends_on = [aws_cloudwatch_log_group.finetuning_job_status_checker]
  tags       = var.tags
}

# =============================================================================
# Lambda: finetuning_deployment_handler (plain zip)
# =============================================================================

resource "aws_iam_role" "finetuning_deployment_handler" {
  count = local.finetuning_enabled ? 1 : 0
  name  = "${local.api_name}-ft-deployment-handler"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "finetuning_deployment_handler" {
  count = local.finetuning_enabled ? 1 : 0
  name  = "ft-deployment-handler-policy"
  role  = aws_iam_role.finetuning_deployment_handler[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:${data.aws_partition.current.partition}:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem",
          "dynamodb:DeleteItem", "dynamodb:Query", "dynamodb:Scan"
        ]
        Resource = compact([
          local.tracking_table_arn,
          "${local.tracking_table_arn}/index/*",
          local.configuration_table_arn,
          local.configuration_table_arn != null ? "${local.configuration_table_arn}/index/*" : null
        ])
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:CreateCustomModelDeployment", "bedrock:GetCustomModelDeployment",
          "bedrock:DeleteCustomModelDeployment", "bedrock:ListCustomModelDeployments",
          "bedrock:TagResource"
        ]
        Resource = [
          "arn:${data.aws_partition.current.partition}:bedrock:*:${data.aws_caller_identity.current.account_id}:custom-model/*",
          "arn:${data.aws_partition.current.partition}:bedrock:*:${data.aws_caller_identity.current.account_id}:custom-model-deployment/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
        Resource = local.finetuning_kms_arn
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "finetuning_deployment_handler" {
  count             = local.finetuning_enabled ? 1 : 0
  name              = "/aws/lambda/${local.api_name}-ft-deployment-handler"
  retention_in_days = var.log_retention_days
  kms_key_id        = local.encryption_key_arn
  tags              = var.tags
}

data "archive_file" "finetuning_deployment_handler" {
  count       = local.finetuning_enabled ? 1 : 0
  type        = "zip"
  source_dir  = "${path.module}/../../sources/src/lambda/finetuning_deployment_handler"
  output_path = "${path.module}/../../.terraform/archives/finetuning_deployment_handler.zip"
}

resource "aws_lambda_function" "finetuning_deployment_handler" {
  architectures    = [var.lambda_architecture]
  count            = local.finetuning_enabled ? 1 : 0
  function_name    = "${local.api_name}-ft-deployment-handler"
  role             = aws_iam_role.finetuning_deployment_handler[0].arn
  filename         = data.archive_file.finetuning_deployment_handler[0].output_path
  source_code_hash = data.archive_file.finetuning_deployment_handler[0].output_base64sha256
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 120
  memory_size      = 256
  layers           = compact([var.base_layer_arn, var.idp_common_layer_arn])
  environment {
    variables = {
      LOG_LEVEL                = var.log_level
      TRACKING_TABLE           = local.tracking_table_name
      CONFIGURATION_TABLE_NAME = local.configuration_table_name != null ? local.configuration_table_name : ""
    }
  }
  tracing_config { mode = var.lambda_tracing_mode }
  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }
  depends_on = [aws_cloudwatch_log_group.finetuning_deployment_handler]
  tags       = var.tags
}

# =============================================================================
# Lambda: finetuning_jobs_resolver (plain zip; dispatcher-invoked)
# =============================================================================

resource "aws_iam_role" "finetuning_jobs_resolver" {
  count = local.finetuning_enabled ? 1 : 0
  name  = "${local.api_name}-ft-jobs-resolver"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "finetuning_jobs_resolver" {
  count = local.finetuning_enabled ? 1 : 0
  name  = "ft-jobs-resolver-policy"
  role  = aws_iam_role.finetuning_jobs_resolver[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:${data.aws_partition.current.partition}:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem",
          "dynamodb:DeleteItem", "dynamodb:Query", "dynamodb:Scan"
        ]
        Resource = [
          local.tracking_table_arn,
          "${local.tracking_table_arn}/index/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["states:StartExecution"]
        Resource = local.finetuning_state_machine_arn
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:GetCustomModel", "bedrock:DeleteCustomModel",
          "bedrock:GetCustomModelDeployment", "bedrock:DeleteCustomModelDeployment"
        ]
        Resource = [
          "arn:${data.aws_partition.current.partition}:bedrock:*:${data.aws_caller_identity.current.account_id}:custom-model/*",
          "arn:${data.aws_partition.current.partition}:bedrock:*:${data.aws_caller_identity.current.account_id}:custom-model-deployment/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["bedrock:ListCustomModels", "bedrock:ListCustomModelDeployments"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
        Resource = local.finetuning_kms_arn
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "finetuning_jobs_resolver" {
  count             = local.finetuning_enabled ? 1 : 0
  name              = "/aws/lambda/${local.api_name}-ft-jobs-resolver"
  retention_in_days = var.log_retention_days
  kms_key_id        = local.encryption_key_arn
  tags              = var.tags
}

data "archive_file" "finetuning_jobs_resolver" {
  count       = local.finetuning_enabled ? 1 : 0
  type        = "zip"
  source_dir  = "${path.module}/../../sources/nested/api-resolvers/src/lambda/finetuning_jobs_resolver"
  output_path = "${path.module}/../../.terraform/archives/finetuning_jobs_resolver.zip"
}

resource "aws_lambda_function" "finetuning_jobs_resolver" {
  architectures    = [var.lambda_architecture]
  count            = local.finetuning_enabled ? 1 : 0
  function_name    = "${local.api_name}-ft-jobs-resolver"
  role             = aws_iam_role.finetuning_jobs_resolver[0].arn
  filename         = data.archive_file.finetuning_jobs_resolver[0].output_path
  source_code_hash = data.archive_file.finetuning_jobs_resolver[0].output_base64sha256
  handler          = "index.lambda_handler"
  runtime          = "python3.12"
  timeout          = 60
  memory_size      = 512
  layers           = compact([var.base_layer_arn, var.idp_common_layer_arn])
  environment {
    variables = {
      LOG_LEVEL                    = var.log_level
      TRACKING_TABLE               = local.tracking_table_name
      FINETUNING_STATE_MACHINE_ARN = local.finetuning_state_machine_arn
      FINETUNING_DATA_BUCKET       = aws_s3_bucket.finetuning_data[0].id
    }
  }
  tracing_config { mode = var.lambda_tracing_mode }
  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }
  depends_on = [aws_cloudwatch_log_group.finetuning_jobs_resolver]
  tags       = var.tags
}

# =============================================================================
# Lambda: finetuning_process_document (CodeBuild self-contained bundle)
#
# Needs idp_common.model_finetuning.training_data_utils + Pillow + pypdfium2
# (native manylinux wheels), so the deployment zip is built in CodeBuild with
# idp_common_pkg[image] bundled and no base layer attached (layers = []), matching
# the agent_chat_processor pattern.
# =============================================================================

locals {
  finetuning_pd_src        = "${path.module}/../../sources/src/lambda/finetuning_process_document"
  finetuning_pd_idp_common = "${path.module}/../../sources/lib/idp_common_pkg"

  use_codebuild_finetuning_pd = local.finetuning_enabled && !var.lambda_local

  finetuning_pd_bucket_name = var.lambda_layers_bucket_arn != null ? split(":::", var.lambda_layers_bucket_arn)[1] : ""

  finetuning_pd_src_files_hash = local.finetuning_enabled ? sha256(join("", [
    for f in fileset(local.finetuning_pd_src, "**") :
    filesha256("${local.finetuning_pd_src}/${f}")
  ])) : ""
  finetuning_pd_idp_common_hash = local.finetuning_enabled ? sha256(join("", [
    for f in fileset("${local.finetuning_pd_idp_common}/idp_common", "**/*.py") :
    filesha256("${local.finetuning_pd_idp_common}/idp_common/${f}")
  ])) : ""
  finetuning_pd_input_hash = local.finetuning_enabled ? sha256(join("-", [
    local.finetuning_pd_src_files_hash,
    local.finetuning_pd_idp_common_hash,
    filesha256("${local.finetuning_pd_idp_common}/pyproject.toml"),
  ])) : ""

  finetuning_pd_cb_src_key      = "source/finetuning-pd/lambda_src_${substr(local.finetuning_pd_input_hash, 0, 16)}.zip"
  finetuning_pd_cb_idp_key      = "source/finetuning-pd/idp_common_pkg_${substr(local.finetuning_pd_input_hash, 0, 16)}.zip"
  finetuning_pd_cb_artifact_key = "finetuning-pd/finetuning_process_document.zip"
}

data "archive_file" "finetuning_pd_cb_src" {
  count       = local.use_codebuild_finetuning_pd ? 1 : 0
  type        = "zip"
  source_dir  = local.finetuning_pd_src
  output_path = "${path.module}/../../.terraform/tmp/finetuning_pd_cb_lambda_src.zip"
}

data "archive_file" "finetuning_pd_cb_idp" {
  count       = local.use_codebuild_finetuning_pd ? 1 : 0
  type        = "zip"
  source_dir  = local.finetuning_pd_idp_common
  output_path = "${path.module}/../../.terraform/tmp/finetuning_pd_cb_idp_common_pkg.zip"
  excludes    = ["**/__pycache__/**", "**/*.pyc", "**/*.egg-info/**", "**/.pytest_cache/**", "tests/**"]
}

resource "aws_s3_object" "finetuning_pd_cb_src" {
  count       = local.use_codebuild_finetuning_pd ? 1 : 0
  bucket      = local.finetuning_pd_bucket_name
  key         = local.finetuning_pd_cb_src_key
  source      = data.archive_file.finetuning_pd_cb_src[0].output_path
  source_hash = data.archive_file.finetuning_pd_cb_src[0].output_md5
}

resource "aws_s3_object" "finetuning_pd_cb_idp" {
  count       = local.use_codebuild_finetuning_pd ? 1 : 0
  bucket      = local.finetuning_pd_bucket_name
  key         = local.finetuning_pd_cb_idp_key
  source      = data.archive_file.finetuning_pd_cb_idp[0].output_path
  source_hash = data.archive_file.finetuning_pd_cb_idp[0].output_md5
}

resource "aws_iam_role" "finetuning_pd_codebuild" {
  count = local.use_codebuild_finetuning_pd ? 1 : 0
  name  = "${local.api_name}-ft-pd-cb-${random_string.suffix.result}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "codebuild.amazonaws.com" }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "finetuning_pd_codebuild" {
  count = local.use_codebuild_finetuning_pd ? 1 : 0
  name  = "CodeBuildPolicy"
  role  = aws_iam_role.finetuning_pd_codebuild[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents",
          "logs:DescribeLogGroups", "logs:DescribeLogStreams"
        ]
        Resource = [
          "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/${local.api_name}-ft-pd-${random_string.suffix.result}",
          "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/${local.api_name}-ft-pd-${random_string.suffix.result}:*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:GetObjectVersion", "s3:ListBucket"]
        Resource = [var.lambda_layers_bucket_arn, "${var.lambda_layers_bucket_arn}/*"]
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "finetuning_pd_codebuild" {
  count             = local.use_codebuild_finetuning_pd ? 1 : 0
  name              = "/aws/codebuild/${local.api_name}-ft-pd-${random_string.suffix.result}"
  retention_in_days = 14
  tags              = merge(var.tags, { Name = "${local.api_name}-ft-pd-codebuild-logs" })
}

resource "time_sleep" "finetuning_pd_cb_iam_propagation" {
  count = local.use_codebuild_finetuning_pd ? 1 : 0

  depends_on = [
    aws_iam_role.finetuning_pd_codebuild,
    aws_iam_role_policy.finetuning_pd_codebuild,
    aws_cloudwatch_log_group.finetuning_pd_codebuild
  ]

  create_duration = "30s"
}

resource "time_sleep" "finetuning_pd_cb_trigger_iam_propagation" {
  count = local.use_codebuild_finetuning_pd ? 1 : 0

  depends_on = [
    aws_iam_role.finetuning_pd_cb_trigger_lambda,
    aws_iam_role_policy.finetuning_pd_cb_trigger_lambda
  ]

  create_duration = "30s"
}

resource "aws_codebuild_project" "finetuning_process_document" {
  count = local.use_codebuild_finetuning_pd ? 1 : 0

  name          = "${local.api_name}-ft-pd-${random_string.suffix.result}"
  description   = "Build the self-contained finetuning_process_document Lambda zip"
  build_timeout = 60
  service_role  = aws_iam_role.finetuning_pd_codebuild[0].arn

  depends_on = [
    aws_iam_role.finetuning_pd_codebuild,
    aws_iam_role_policy.finetuning_pd_codebuild,
    aws_cloudwatch_log_group.finetuning_pd_codebuild
  ]

  dynamic "vpc_config" {
    for_each = local.codebuild_has_network ? [1] : []
    content {
      vpc_id             = var.vpc_config.vpc_id
      subnets            = var.vpc_config.subnet_ids
      security_group_ids = var.vpc_config.security_group_ids
    }
  }

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    type         = var.lambda_architecture == "arm64" ? "ARM_CONTAINER" : "LINUX_CONTAINER"
    compute_type = "BUILD_GENERAL1_LARGE"
    image = var.lambda_architecture == "arm64" ? (
      "aws/codebuild/amazonlinux2-aarch64-standard:3.0"
      ) : (
      "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    )
    privileged_mode             = false
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "ASSETS_BUCKET"
      value = local.finetuning_pd_bucket_name
      type  = "PLAINTEXT"
    }
    environment_variable {
      name  = "ARTIFACT_KEY"
      value = local.finetuning_pd_cb_artifact_key
      type  = "PLAINTEXT"
    }
    environment_variable {
      name  = "IDP_COMMON_KEY"
      value = local.finetuning_pd_cb_idp_key
      type  = "PLAINTEXT"
    }
    environment_variable {
      name  = "IDP_COMMON_EXTRAS"
      value = "image"
      type  = "PLAINTEXT"
    }
  }

  logs_config {
    cloudwatch_logs {
      status     = "ENABLED"
      group_name = aws_cloudwatch_log_group.finetuning_pd_codebuild[0].name
    }
  }

  source {
    type      = "S3"
    location  = "${local.finetuning_pd_bucket_name}/${aws_s3_object.finetuning_pd_cb_src[0].key}"
    buildspec = <<EOF
version: 0.2
phases:
  install:
    runtime-versions:
      python: 3.12
  build:
    commands:
      - |
        set -e
        BUILD=/tmp/build
        rm -rf "$BUILD" /tmp/idp_common_pkg
        mkdir -p "$BUILD" /tmp/idp_common_pkg

        aws s3 cp "s3://$ASSETS_BUCKET/$IDP_COMMON_KEY" /tmp/idp_common_pkg.zip
        (cd /tmp/idp_common_pkg && unzip -q /tmp/idp_common_pkg.zip)

        cp -rL ./. "$BUILD/"

        sed 's|^\./lib.*||g' "$BUILD/requirements.txt" > /tmp/requirements_clean.txt
        pip install -r /tmp/requirements_clean.txt -t "$BUILD" --no-cache-dir || true

        pip install "/tmp/idp_common_pkg[$IDP_COMMON_EXTRAS]" -t "$BUILD" --no-cache-dir --upgrade

        mkdir -p "$BUILD/idp_common"
        cp -rL /tmp/idp_common_pkg/idp_common/. "$BUILD/idp_common/"

        find "$BUILD" -type d -name '*.egg-info'   -exec rm -rf {} + 2>/dev/null || true
        find "$BUILD" -type d -name '__pycache__'  -exec rm -rf {} + 2>/dev/null || true
        find "$BUILD" -type d -name 'tests'        -exec rm -rf {} + 2>/dev/null || true
        find "$BUILD" -type f -name '__editable__*' -delete 2>/dev/null || true
        find "$BUILD" -type f -name '*.pyc'        -delete 2>/dev/null || true

        cd "$BUILD" && zip -r -q /tmp/finetuning_process_document.zip . -x '*.pyc'

        aws s3 cp /tmp/finetuning_process_document.zip "s3://$ASSETS_BUCKET/$ARTIFACT_KEY"
        echo "Uploaded s3://$ASSETS_BUCKET/$ARTIFACT_KEY"
  post_build:
    commands:
      - echo finetuning_process_document build complete
EOF
  }

  tags = var.tags
}

data "archive_file" "finetuning_pd_cb_trigger_lambda" {
  count       = local.use_codebuild_finetuning_pd ? 1 : 0
  type        = "zip"
  source_dir  = "${path.module}/../../src/lambda/idp-layer-codebuild-trigger"
  output_path = "${path.module}/../../.terraform/tmp/finetuning_pd_cb_trigger_lambda_${random_string.suffix.result}.zip"
}

resource "aws_iam_role" "finetuning_pd_cb_trigger_lambda" {
  count = local.use_codebuild_finetuning_pd ? 1 : 0
  name  = "${local.api_name}-ft-pd-cbt-${random_string.suffix.result}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "finetuning_pd_cb_trigger_lambda" {
  count = local.use_codebuild_finetuning_pd ? 1 : 0
  name  = "CodeBuildTriggerLambdaPolicy"
  role  = aws_iam_role.finetuning_pd_cb_trigger_lambda[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents",
          "logs:DescribeLogGroups", "logs:DescribeLogStreams", "logs:GetLogEvents"
        ]
        Resource = [
          "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${local.api_name}-ft-pd-cbt-*",
          "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/${local.api_name}-ft-pd-${random_string.suffix.result}",
          "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/${local.api_name}-ft-pd-${random_string.suffix.result}:*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["codebuild:StartBuild", "codebuild:BatchGetBuilds"]
        Resource = [aws_codebuild_project.finetuning_process_document[0].arn]
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "finetuning_pd_cb_trigger_lambda" {
  count             = local.use_codebuild_finetuning_pd ? 1 : 0
  name              = "/aws/lambda/${local.api_name}-ft-pd-cbt-${random_string.suffix.result}"
  retention_in_days = 14
  tags              = merge(var.tags, { Name = "${local.api_name}-ft-pd-codebuild-trigger-lambda-logs" })
}

resource "aws_lambda_function" "finetuning_pd_cb_trigger" {
  count = local.use_codebuild_finetuning_pd ? 1 : 0

  architectures    = [var.lambda_architecture]
  filename         = data.archive_file.finetuning_pd_cb_trigger_lambda[0].output_path
  function_name    = "${local.api_name}-ft-pd-cbt-${random_string.suffix.result}"
  role             = aws_iam_role.finetuning_pd_cb_trigger_lambda[0].arn
  handler          = "index.lambda_handler"
  runtime          = "python3.12"
  timeout          = 900
  memory_size      = 256
  source_code_hash = data.archive_file.finetuning_pd_cb_trigger_lambda[0].output_base64sha256

  tracing_config {
    mode = var.lambda_tracing_mode
  }

  depends_on = [
    aws_cloudwatch_log_group.finetuning_pd_cb_trigger_lambda,
    aws_iam_role_policy.finetuning_pd_cb_trigger_lambda
  ]

  tags = var.tags
}

resource "aws_lambda_invocation" "finetuning_pd_trigger_codebuild" {
  count = local.use_codebuild_finetuning_pd ? 1 : 0

  function_name = aws_lambda_function.finetuning_pd_cb_trigger[0].function_name

  input = jsonencode({
    codebuild_project_name = aws_codebuild_project.finetuning_process_document[0].name
    requirements_hash      = local.finetuning_pd_input_hash
    idp_common_extras      = ["image"]
    force_rebuild          = false
    buildspec_hash         = md5(aws_codebuild_project.finetuning_process_document[0].source[0].buildspec)
  })

  triggers = {
    input_hash     = local.finetuning_pd_input_hash
    buildspec_hash = md5(aws_codebuild_project.finetuning_process_document[0].source[0].buildspec)
  }

  depends_on = [
    aws_codebuild_project.finetuning_process_document,
    aws_iam_role_policy.finetuning_pd_codebuild,
    aws_s3_object.finetuning_pd_cb_src,
    aws_s3_object.finetuning_pd_cb_idp,
    time_sleep.finetuning_pd_cb_iam_propagation,
    time_sleep.finetuning_pd_cb_trigger_iam_propagation
  ]
}

# IAM Role for the finetuning_process_document Lambda
resource "aws_iam_role" "finetuning_process_document" {
  count = local.finetuning_enabled ? 1 : 0
  name  = "${local.api_name}-ft-process-document"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "finetuning_process_document" {
  count = local.finetuning_enabled ? 1 : 0
  name  = "ft-process-document-policy"
  role  = aws_iam_role.finetuning_process_document[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:${data.aws_partition.current.partition}:logs:*:*:*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:ListBucket"]
        Resource = [local.finetuning_test_set_bucket_arn, "${local.finetuning_test_set_bucket_arn}/*"]
      },
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
        Resource = [
          aws_s3_bucket.finetuning_data[0].arn,
          "${aws_s3_bucket.finetuning_data[0].arn}/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
        Resource = local.finetuning_kms_arn
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "finetuning_process_document" {
  count             = local.finetuning_enabled ? 1 : 0
  name              = "/aws/lambda/${local.api_name}-ft-process-document"
  retention_in_days = var.log_retention_days
  kms_key_id        = local.encryption_key_arn
  tags              = var.tags
}

resource "aws_lambda_function" "finetuning_process_document" {
  architectures = [var.lambda_architecture]
  count         = local.finetuning_enabled ? 1 : 0

  function_name = "${local.api_name}-ft-process-document"
  role          = aws_iam_role.finetuning_process_document[0].arn

  s3_bucket        = local.finetuning_pd_bucket_name
  s3_key           = local.finetuning_pd_cb_artifact_key
  source_code_hash = local.finetuning_pd_input_hash

  handler     = "index.handler"
  runtime     = "python3.12"
  timeout     = 300
  memory_size = 2048

  layers = []

  environment {
    variables = {
      LOG_LEVEL              = var.log_level
      TEST_SET_BUCKET        = local.finetuning_test_set_bucket_id
      FINETUNING_DATA_BUCKET = aws_s3_bucket.finetuning_data[0].id
    }
  }

  tracing_config { mode = var.lambda_tracing_mode }

  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.finetuning_process_document,
    aws_lambda_invocation.finetuning_pd_trigger_codebuild,
  ]
  tags = var.tags
}

# =============================================================================
# State machine: fine-tuning workflow (STANDARD, Distributed Map)
# =============================================================================

resource "aws_cloudwatch_log_group" "finetuning_state_machine" {
  count             = local.finetuning_enabled ? 1 : 0
  name              = "/aws/vendedlogs/states/${local.finetuning_state_machine_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = local.encryption_key_arn
  tags              = var.tags
}

resource "aws_iam_role" "finetuning_state_machine" {
  count = local.finetuning_enabled ? 1 : 0
  name  = "${local.api_name}-finetuning-sfn"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "states.${data.aws_partition.current.dns_suffix}" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "finetuning_state_machine" {
  count = local.finetuning_enabled ? 1 : 0
  name  = "finetuning-sfn-policy"
  role  = aws_iam_role.finetuning_state_machine[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["lambda:InvokeFunction"]
        Resource = [
          aws_lambda_function.finetuning_list_documents[0].arn,
          aws_lambda_function.finetuning_process_document[0].arn,
          aws_lambda_function.finetuning_merge_data[0].arn,
          aws_lambda_function.finetuning_job_creator[0].arn,
          aws_lambda_function.finetuning_job_status_checker[0].arn,
          aws_lambda_function.finetuning_deployment_handler[0].arn
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:UpdateItem", "dynamodb:GetItem", "dynamodb:PutItem"]
        Resource = [local.tracking_table_arn]
      },
      {
        Effect = "Allow"
        Action = ["s3:PutObject", "s3:GetObject", "s3:ListBucket"]
        Resource = [
          aws_s3_bucket.finetuning_data[0].arn,
          "${aws_s3_bucket.finetuning_data[0].arn}/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["states:StartExecution"]
        Resource = local.finetuning_state_machine_arn
      },
      {
        Effect = "Allow"
        Action = ["states:DescribeExecution", "states:StopExecution", "states:RedriveExecution"]
        Resource = [
          "arn:${data.aws_partition.current.partition}:states:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:execution:${local.finetuning_state_machine_name}:*",
          "arn:${data.aws_partition.current.partition}:states:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:execution:${local.finetuning_state_machine_name}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogDelivery", "logs:GetLogDelivery", "logs:UpdateLogDelivery",
          "logs:DeleteLogDelivery", "logs:ListLogDeliveries", "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies", "logs:DescribeLogGroups"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
        Resource = local.finetuning_kms_arn
      }
    ]
  })
}

resource "aws_sfn_state_machine" "finetuning" {
  count    = local.finetuning_enabled ? 1 : 0
  name     = local.finetuning_state_machine_name
  type     = "STANDARD"
  role_arn = aws_iam_role.finetuning_state_machine[0].arn

  definition = templatefile("${path.module}/../../sources/src/lambda/finetuning_state_machine/definition.json", {
    FinetuningListDocumentsArn     = aws_lambda_function.finetuning_list_documents[0].arn
    FinetuningProcessDocumentArn   = aws_lambda_function.finetuning_process_document[0].arn
    FinetuningMergeDataArn         = aws_lambda_function.finetuning_merge_data[0].arn
    FinetuningJobCreatorArn        = aws_lambda_function.finetuning_job_creator[0].arn
    FinetuningJobStatusCheckerArn  = aws_lambda_function.finetuning_job_status_checker[0].arn
    FinetuningDeploymentHandlerArn = aws_lambda_function.finetuning_deployment_handler[0].arn
    TrackingTableName              = local.tracking_table_name
    FinetuningDataBucket           = aws_s3_bucket.finetuning_data[0].id
  })

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.finetuning_state_machine[0].arn}:*"
    include_execution_data = true
    level                  = "ALL"
  }

  tracing_configuration {
    enabled = true
  }

  depends_on = [aws_iam_role_policy.finetuning_state_machine]

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "finetuning_pd_codebuild_vpc_access" {
  count      = local.use_codebuild_finetuning_pd && local.codebuild_has_network ? 1 : 0
  role       = aws_iam_role.finetuning_pd_codebuild[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSCodeBuildVPCAccessExecutionRole"
}

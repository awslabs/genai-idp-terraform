# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Discovery Sub-module for Processing Environment API
# This module creates the Lambda functions, DynamoDB table, and GraphQL resolvers for document discovery functionality

# Data sources for cross-partition compatibility
data "aws_partition" "current" {}
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  # Generate unique suffix for resource names
  suffix = random_string.suffix.result

  # Extract bucket names from ARNs
  input_bucket_name = element(split(":", var.input_bucket_arn), 5)

  # Module build directory for Lambda archives
  module_build_dir = "${path.module}/.terraform-build"
}

# Create a random string for unique resource names
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Create module-specific build directory
resource "null_resource" "create_module_build_dir" {
  provisioner "local-exec" {
    command = "mkdir -p ${local.module_build_dir}"
  }
}

# =============================================================================
# Discovery S3 Bucket
# =============================================================================

resource "aws_s3_bucket" "discovery_bucket" {
  bucket = "${var.name_prefix}-discovery-${local.suffix}"

  tags = var.tags
}

# Bucket versioning
resource "aws_s3_bucket_versioning" "discovery_bucket_versioning" {
  bucket = aws_s3_bucket.discovery_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Bucket encryption (conditional)
resource "aws_s3_bucket_server_side_encryption_configuration" "discovery_bucket_encryption" {
  bucket = aws_s3_bucket.discovery_bucket.id

  dynamic "rule" {
    for_each = var.encryption_key_arn != null ? [1] : []
    content {
      apply_server_side_encryption_by_default {
        kms_master_key_id = var.encryption_key_arn
        sse_algorithm     = "aws:kms"
      }
      bucket_key_enabled = true
    }
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "discovery_bucket_pab" {
  bucket = aws_s3_bucket.discovery_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Bucket policy to enforce SSL
resource "aws_s3_bucket_policy" "discovery_bucket_policy" {
  bucket = aws_s3_bucket.discovery_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnforceSSLOnly"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.discovery_bucket.arn,
          "${aws_s3_bucket.discovery_bucket.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# CORS configuration for Web UI uploads
resource "aws_s3_bucket_cors_configuration" "discovery_bucket_cors" {
  bucket = aws_s3_bucket.discovery_bucket.id

  cors_rule {
    allowed_headers = [
      "Content-Type",
      "x-amz-content-sha256",
      "x-amz-date",
      "Authorization",
      "x-amz-security-token"
    ]
    allowed_methods = ["PUT", "POST"]
    allowed_origins = [
      "*" # Will be restricted by bucket policy and IAM
    ]
    expose_headers = [
      "ETag",
      "x-amz-server-side-encryption"
    ]
    max_age_seconds = 3000
  }
}

# Lifecycle configuration for data retention
resource "aws_s3_bucket_lifecycle_configuration" "discovery_bucket_lifecycle" {
  bucket = aws_s3_bucket.discovery_bucket.id

  rule {
    id     = "DeleteAfterNDays"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = var.data_retention_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

# EventBridge notification configuration
resource "aws_s3_bucket_notification" "discovery_bucket_notification" {
  bucket      = aws_s3_bucket.discovery_bucket.id
  eventbridge = true
}

# =============================================================================
# DynamoDB Table for Discovery Job Tracking
# =============================================================================

resource "aws_dynamodb_table" "discovery_tracking" {
  name         = "${var.name_prefix}-discovery-tracking-${local.suffix}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"
  range_key    = "SK"

  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  ttl {
    attribute_name = "ExpiresAfter"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = var.point_in_time_recovery_enabled
  }

  dynamic "server_side_encryption" {
    for_each = var.encryption_key_arn != null ? [1] : []
    content {
      enabled     = true
      kms_key_arn = var.encryption_key_arn
    }
  }

  tags = var.tags
}

# =============================================================================
# SQS Queue for Discovery Processing
# =============================================================================

# Dead Letter Queue for failed discovery jobs
resource "aws_sqs_queue" "discovery_dlq" {
  name = "${var.name_prefix}-discovery-dlq-${local.suffix}"

  kms_master_key_id = var.encryption_key_arn

  tags = var.tags
}

# Main discovery processing queue
resource "aws_sqs_queue" "discovery_queue" {
  name                       = "${var.name_prefix}-discovery-queue-${local.suffix}"
  visibility_timeout_seconds = 960     # 16 minutes (longer than Lambda timeout)
  message_retention_seconds  = 1209600 # 14 days

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.discovery_dlq.arn
    maxReceiveCount     = 3
  })

  kms_master_key_id = var.encryption_key_arn

  tags = var.tags
}

# =============================================================================
# Discovery Upload Resolver Lambda Function
# =============================================================================

# Generate unique build ID for upload resolver
resource "random_id" "upload_resolver_build_id" {
  byte_length = 8
  keepers = {
    content_hash = md5("discovery-upload-resolver")
  }
}

# Source code archive for upload resolver
data "archive_file" "discovery_upload_resolver_code" {
  type        = "zip"
  source_dir  = "${path.module}/../../../sources/nested/api-resolvers/src/lambda/discovery_upload_resolver"
  output_path = "${local.module_build_dir}/discovery-upload-resolver.zip_${random_id.upload_resolver_build_id.hex}"

  depends_on = [null_resource.create_module_build_dir]
}

# Discovery Upload Resolver Lambda function
resource "aws_lambda_function" "discovery_upload_resolver" {
  architectures = [var.lambda_architecture]
  function_name = "${var.name_prefix}-discovery-upload-${local.suffix}"

  filename         = data.archive_file.discovery_upload_resolver_code.output_path
  source_code_hash = data.archive_file.discovery_upload_resolver_code.output_base64sha256

  layers = [var.idp_common_layer_arn]

  handler     = "index.handler"
  runtime     = "python3.12"
  timeout     = 60
  memory_size = 512
  role        = aws_iam_role.discovery_upload_resolver_role.arn
  description = "Handles discovery document upload requests and creates presigned URLs"

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = merge({
      LOG_LEVEL                = var.log_level
      DISCOVERY_TRACKING_TABLE = aws_dynamodb_table.discovery_tracking.name
      DISCOVERY_QUEUE_URL      = aws_sqs_queue.discovery_queue.url
      DISCOVERY_BUCKET         = aws_s3_bucket.discovery_bucket.id
    }, var.s3_endpoint_url != null ? { S3_ENDPOINT_URL = var.s3_endpoint_url } : {})
  }

  dynamic "vpc_config" {
    for_each = length(var.vpc_subnet_ids) > 0 ? [1] : []
    content {
      subnet_ids         = var.vpc_subnet_ids
      security_group_ids = var.vpc_security_group_ids
    }
  }

  tracing_config {
    mode = var.lambda_tracing_mode
  }

  tags = var.tags
}

# CloudWatch Log Group for upload resolver
resource "aws_cloudwatch_log_group" "discovery_upload_resolver_logs" {
  name              = "/aws/lambda/${aws_lambda_function.discovery_upload_resolver.function_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.encryption_key_arn

  tags = var.tags
}

# =============================================================================
# Discovery Processor Lambda Function
# =============================================================================

# Generate unique build ID for processor
resource "random_id" "processor_build_id" {
  byte_length = 8
  keepers = {
    content_hash = md5("discovery-processor")
  }
}

# Source code archive for processor
data "archive_file" "discovery_processor_code" {
  type        = "zip"
  source_dir  = "${path.module}/../../../sources/src/lambda/discovery_processor"
  output_path = "${local.module_build_dir}/discovery-processor.zip_${random_id.processor_build_id.hex}"

  depends_on = [null_resource.create_module_build_dir]
}

# Discovery Processor Lambda function
resource "aws_lambda_function" "discovery_processor" {
  architectures = [var.lambda_architecture]
  function_name = "${var.name_prefix}-discovery-processor-${local.suffix}"

  filename         = data.archive_file.discovery_processor_code.output_path
  source_code_hash = data.archive_file.discovery_processor_code.output_base64sha256

  layers = [var.idp_common_layer_arn]

  handler     = "index.handler"
  runtime     = "python3.12"
  timeout     = 900 # 15 minutes for complex discovery processing
  memory_size = 1024
  role        = aws_iam_role.discovery_processor_role.arn
  description = "Processes discovery jobs using ClassesDiscovery from idp_common"

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = {
      LOG_LEVEL                = var.log_level
      BEDROCK_LOG_LEVEL        = var.log_level
      DISCOVERY_TRACKING_TABLE = aws_dynamodb_table.discovery_tracking.name
      # APPSYNC_API_URL intentionally empty post-v0.6.4: the processor writes
      # the DiscoveryTable directly; the UI polls it via the dispatcher's
      # ddb_direct instead of AppSync subscriptions.
      APPSYNC_API_URL = var.appsync_api_url != null ? var.appsync_api_url : ""
    }
  }

  dynamic "vpc_config" {
    for_each = length(var.vpc_subnet_ids) > 0 ? [1] : []
    content {
      subnet_ids         = var.vpc_subnet_ids
      security_group_ids = var.vpc_security_group_ids
    }
  }

  tracing_config {
    mode = var.lambda_tracing_mode
  }

  tags = var.tags
}

# CloudWatch Log Group for processor
resource "aws_cloudwatch_log_group" "discovery_processor_logs" {
  name              = "/aws/lambda/${aws_lambda_function.discovery_processor.function_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.encryption_key_arn

  tags = var.tags
}

# =============================================================================
# SQS Event Source Mapping for Discovery Processor
# =============================================================================

resource "aws_lambda_event_source_mapping" "discovery_processor_sqs" {
  event_source_arn = aws_sqs_queue.discovery_queue.arn
  function_name    = aws_lambda_function.discovery_processor.arn
  batch_size       = 1

  # Enable partial batch failure reporting
  function_response_types = ["ReportBatchItemFailures"]
}

# =============================================================================
# NOTE (v0.6.4 REST migration): The AppSync data sources (discovery_lambda,
# discovery_table) and VTL resolvers (listDiscoveryJobs, updateDiscoveryJobStatus)
# were removed. listDiscoveryJobs/updateDiscoveryJobStatus/deleteDiscoveryJob are
# now served in-process by the dispatcher's ddb_direct.py against this module's
# DiscoveryTable; autoDetectSections (and its upload aliases) route to
# discovery_upload_resolver via the parent's field-function map. The Lambda
# functions, table, queues, and IAM roles above are unchanged.
# =============================================================================
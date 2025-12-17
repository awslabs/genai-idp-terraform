# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
/**
 * # Discovery Module
 *
 * This module creates the infrastructure for the Discovery feature, which enables
 * automated configuration generation from document samples. The Discovery module
 * analyzes documents to identify structure, field types, and organizational patterns,
 * then generates configuration blueprints automatically.
 *
 * ## Features
 * - Document analysis for structure and field identification
 * - Automatic configuration blueprint generation
 * - Support for Pattern-1 (BDA), Pattern-2 (Bedrock LLM), and Pattern-3 (SageMaker UDOP)
 * - Zero-touch BDA blueprint generation for Pattern-1
 */

# Data sources for cross-partition compatibility
data "aws_partition" "current" {}
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  # Generate unique suffix for resource names
  suffix = random_string.suffix.result

  # Extract bucket names from ARNs
  discovery_bucket_name = element(split(":", var.discovery_bucket_arn), 5)
  working_bucket_name   = var.working_bucket_arn != null ? element(split(":", var.working_bucket_arn), 5) : null

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
# DynamoDB Table for Discovery Job Tracking
# =============================================================================

resource "aws_dynamodb_table" "discovery_tracking" {
  name         = "${var.name_prefix}-discovery-tracking-${local.suffix}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "jobId"

  attribute {
    name = "jobId"
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
# SQS Queue for Discovery Job Processing
# =============================================================================

resource "aws_sqs_queue" "discovery_queue" {
  name                       = "${var.name_prefix}-discovery-queue-${local.suffix}"
  visibility_timeout_seconds = 900   # 15 minutes to match Lambda timeout
  message_retention_seconds  = 86400 # 1 day
  receive_wait_time_seconds  = 20

  # Enable server-side encryption
  kms_master_key_id = var.encryption_key_arn

  tags = var.tags
}

# Dead letter queue for failed discovery jobs
resource "aws_sqs_queue" "discovery_dlq" {
  name                      = "${var.name_prefix}-discovery-dlq-${local.suffix}"
  message_retention_seconds = 1209600 # 14 days

  tags = var.tags
}

# Redrive policy for main queue
resource "aws_sqs_queue_redrive_policy" "discovery_queue_redrive" {
  queue_url = aws_sqs_queue.discovery_queue.id
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.discovery_dlq.arn
    maxReceiveCount     = 3
  })
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
  source_dir  = "${path.module}/../../sources/src/lambda/discovery_upload_resolver"
  output_path = "${local.module_build_dir}/discovery-upload-resolver.zip_${random_id.upload_resolver_build_id.hex}"

  depends_on = [null_resource.create_module_build_dir]
}

# Discovery Upload Resolver Lambda function
resource "aws_lambda_function" "discovery_upload_resolver" {
  function_name = "${var.name_prefix}-discovery-upload-${local.suffix}"

  filename         = data.archive_file.discovery_upload_resolver_code.output_path
  source_code_hash = data.archive_file.discovery_upload_resolver_code.output_base64sha256

  layers = [var.idp_common_layer_arn]

  handler     = "index.handler"
  runtime     = "python3.12"
  timeout     = 60
  memory_size = 256
  role        = aws_iam_role.discovery_upload_resolver_role.arn
  description = "Generates presigned URLs for discovery document uploads and creates discovery jobs"

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = {
      LOG_LEVEL                = var.log_level
      DISCOVERY_TRACKING_TABLE = aws_dynamodb_table.discovery_tracking.name
      DISCOVERY_QUEUE_URL      = aws_sqs_queue.discovery_queue.url
      DISCOVERY_BUCKET         = local.discovery_bucket_name
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
  source_dir  = "${path.module}/../../sources/src/lambda/discovery_processor"
  output_path = "${local.module_build_dir}/discovery-processor.zip_${random_id.processor_build_id.hex}"

  depends_on = [null_resource.create_module_build_dir]
}

# Discovery Processor Lambda function
resource "aws_lambda_function" "discovery_processor" {
  function_name = "${var.name_prefix}-discovery-processor-${local.suffix}"

  filename         = data.archive_file.discovery_processor_code.output_path
  source_code_hash = data.archive_file.discovery_processor_code.output_base64sha256

  layers = [var.idp_common_layer_arn]

  handler     = "index.handler"
  runtime     = "python3.12"
  timeout     = 900 # 15 minutes for document analysis
  memory_size = 1024
  role        = aws_iam_role.discovery_processor_role.arn
  description = "Processes discovery jobs to analyze documents and generate configuration blueprints"

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = {
      LOG_LEVEL                = var.log_level
      DISCOVERY_TRACKING_TABLE = aws_dynamodb_table.discovery_tracking.name
      CONFIGURATION_TABLE_NAME = var.configuration_table_name
      APPSYNC_API_URL          = var.appsync_api_url
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

# SQS Event Source Mapping for Discovery Processor
resource "aws_lambda_event_source_mapping" "discovery_processor_sqs" {
  event_source_arn                   = aws_sqs_queue.discovery_queue.arn
  function_name                      = aws_lambda_function.discovery_processor.arn
  batch_size                         = 1
  maximum_batching_window_in_seconds = 0
  enabled                            = true

  function_response_types = ["ReportBatchItemFailures"]
}


# =============================================================================
# Step Functions State Machine for Discovery Workflow
# =============================================================================

# IAM Role for Step Functions
resource "aws_iam_role" "discovery_state_machine_role" {
  name = "${var.name_prefix}-discovery-sfn-role-${local.suffix}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_policy" "discovery_state_machine_policy" {
  name = "${var.name_prefix}-discovery-sfn-policy-${local.suffix}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = [
          aws_lambda_function.discovery_upload_resolver.arn,
          aws_lambda_function.discovery_processor.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:UpdateItem"
        ]
        Resource = aws_dynamodb_table.discovery_tracking.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogDelivery",
          "logs:GetLogDelivery",
          "logs:UpdateLogDelivery",
          "logs:DeleteLogDelivery",
          "logs:ListLogDeliveries",
          "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies",
          "logs:DescribeLogGroups"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords",
          "xray:GetSamplingRules",
          "xray:GetSamplingTargets"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "discovery_state_machine_policy_attachment" {
  role       = aws_iam_role.discovery_state_machine_role.name
  policy_arn = aws_iam_policy.discovery_state_machine_policy.arn
}

# CloudWatch Log Group for Step Functions
resource "aws_cloudwatch_log_group" "discovery_state_machine_logs" {
  name              = "/aws/vendedlogs/states/${var.name_prefix}-discovery-workflow-${local.suffix}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.encryption_key_arn

  tags = var.tags
}

# Step Functions State Machine
resource "aws_sfn_state_machine" "discovery_workflow" {
  name     = "${var.name_prefix}-discovery-workflow-${local.suffix}"
  role_arn = aws_iam_role.discovery_state_machine_role.arn

  definition = jsonencode({
    Comment = "Discovery workflow for automated configuration generation from document samples"
    StartAt = "ValidateInput"
    States = {
      ValidateInput = {
        Type = "Choice"
        Choices = [
          {
            Variable  = "$.documentKey"
            IsPresent = true
            Next      = "ProcessDiscovery"
          }
        ]
        Default = "InvalidInput"
      }
      InvalidInput = {
        Type  = "Fail"
        Error = "InvalidInput"
        Cause = "documentKey is required in the input"
      }
      ProcessDiscovery = {
        Type     = "Task"
        Resource = "arn:${data.aws_partition.current.partition}:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.discovery_processor.arn
          Payload = {
            "jobId.$"          = "$.jobId"
            "documentKey.$"    = "$.documentKey"
            "groundTruthKey.$" = "$.groundTruthKey"
            "bucket.$"         = "$.bucket"
          }
        }
        ResultPath = "$.processingResult"
        Retry = [
          {
            ErrorEquals     = ["Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException"]
            IntervalSeconds = 2
            MaxAttempts     = 3
            BackoffRate     = 2
          }
        ]
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            ResultPath  = "$.error"
            Next        = "HandleError"
          }
        ]
        Next = "DiscoveryComplete"
      }
      HandleError = {
        Type     = "Task"
        Resource = "arn:${data.aws_partition.current.partition}:states:::dynamodb:updateItem"
        Parameters = {
          TableName = aws_dynamodb_table.discovery_tracking.name
          Key = {
            jobId = {
              "S.$" = "$.jobId"
            }
          }
          UpdateExpression = "SET #status = :status, errorMessage = :error, updatedAt = :updated"
          ExpressionAttributeNames = {
            "#status" = "status"
          }
          ExpressionAttributeValues = {
            ":status" = {
              S = "FAILED"
            }
            ":error" = {
              "S.$" = "$.error.Cause"
            }
            ":updated" = {
              "S.$" = "$$.State.EnteredTime"
            }
          }
        }
        Next = "DiscoveryFailed"
      }
      DiscoveryFailed = {
        Type  = "Fail"
        Error = "DiscoveryFailed"
        Cause = "Discovery processing failed"
      }
      DiscoveryComplete = {
        Type = "Succeed"
      }
    }
  })

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.discovery_state_machine_logs.arn}:*"
    include_execution_data = true
    level                  = "ALL"
  }

  tracing_configuration {
    enabled = var.lambda_tracing_mode == "Active"
  }

  tags = var.tags
}

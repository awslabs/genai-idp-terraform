# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# CloudWatch Log Group for Queue Processor
resource "aws_cloudwatch_log_group" "queue_processor" {
  name              = "/aws/lambda/${var.name}-queue-processor-${random_string.suffix.result}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.encryption_key_arn

  tags = var.tags
}

# Queue Processor function code


# Create module-specific build directory

# Generate unique build ID for this module instance

data "archive_file" "queue_processor_code" {
  type        = "zip"
  source_dir  = "${path.module}/../../sources/src/lambda/queue_processor"
  output_path = "${local.module_build_dir}/queue-processor.zip_${random_id.build_id.hex}"

  # Exclude any potential dependencies that might be there
  excludes = [
    "*.so",
    "*.dist-info/**",
    "*.egg-info/**",
    "__pycache__/**",
    "*.pyc",
    "boto3/**",
    "botocore/**"
  ]

  depends_on = [null_resource.create_module_build_dir]
}

# Queue Processor Lambda Function
resource "aws_lambda_function" "queue_processor" {
  function_name = "${var.name}-queue-processor-${random_string.suffix.result}"

  filename         = data.archive_file.queue_processor_code.output_path
  source_code_hash = data.archive_file.queue_processor_code.output_base64sha256

  handler     = "index.handler"
  runtime     = "python3.12"
  timeout     = 30
  memory_size = 512
  role        = aws_iam_role.queue_processor_role.arn
  description = "Lambda function that processes documents from the queue"

  layers = [var.idp_common_layer_arn]

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = {
      LOG_LEVEL              = var.log_level
      STATE_MACHINE_ARN      = var.processor.state_machine_arn
      TRACKING_TABLE         = local.tracking_table_name
      CONCURRENCY_TABLE      = local.concurrency_table_name
      MAX_CONCURRENT         = var.processor.max_processing_concurrency
      DOCUMENT_TRACKING_MODE = var.api_id != null ? "appsync" : "dynamodb"
      APPSYNC_API_URL        = var.api_id != null ? var.api_graphql_url : ""
      WORKING_BUCKET         = local.working_bucket_name
    }
  }

  dynamic "vpc_config" {
    for_each = length(var.vpc_subnet_ids) > 0 ? [local.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  tracing_config {
    mode = var.lambda_tracing_mode
  }

  # Ensure all IAM policy attachments are complete before creating the Lambda function
  depends_on = [
    aws_iam_role_policy_attachment.queue_processor_basic_execution,
    aws_iam_role_policy_attachment.queue_processor_vpc_execution,
    aws_iam_role_policy_attachment.queue_processor_custom_policy,
    aws_cloudwatch_log_group.queue_processor,
  ]

  tags = var.tags
}

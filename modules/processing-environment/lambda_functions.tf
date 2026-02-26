# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
module "lambda_layers" {
  source = "../lambda-layer-codebuild"

  name_prefix              = "processing-environment-${random_string.suffix.result}"
  lambda_layers_bucket_arn = var.lambda_layers_bucket_arn

  requirements_files = {
    update_configuration = fileexists("${path.module}/../../sources/src/lambda/update_configuration/requirements.txt") ? file("${path.module}/../../sources/src/lambda/update_configuration/requirements.txt") : ""
  }

  # Calculate hash of all requirements files to use as trigger
  requirements_hash = md5(join("", [
    fileexists("${path.module}/../../sources/src/lambda/update_configuration/requirements.txt") ? file("${path.module}/../../sources/src/lambda/update_configuration/requirements.txt") : ""
  ]))

  # Don't force rebuild unless requirements change
  force_rebuild = false

  # Lambda tracing configuration
  lambda_tracing_mode = var.lambda_tracing_mode
}

# CloudWatch Log Groups for Lambda functions
resource "aws_cloudwatch_log_group" "queue_sender_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.queue_sender.function_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.encryption_key_arn

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "workflow_tracker_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.workflow_tracker.function_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.encryption_key_arn

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "lookup_function_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.lookup_function.function_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.encryption_key_arn

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "update_configuration_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.update_configuration.function_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.encryption_key_arn

  tags = var.tags
}
# Source code archives (just the code, no dependencies)
# Queue Sender function


# Create module-specific build directory

# Generate unique build ID for this module instance

data "archive_file" "queue_sender_code" {
  type        = "zip"
  source_dir  = "${path.module}/../../sources/src/lambda/queue_sender"
  output_path = "${local.module_build_dir}/queue-sender.zip_${random_id.build_id.hex}"

  # Exclude any potential dependencies that might be there
  excludes = [
    "*.so",
    "*.dist-info/**",
    "*.egg-info/**",
    "__pycache__/**",
    "*.pyc",
    "boto3/**",
    "botocore/**",
    "requests/**",
    "urllib3/**",
    "idna/**",
    "chardet/**",
    "certifi/**"
  ]

  depends_on = [null_resource.create_module_build_dir]
}

# QueueSender Lambda Function
resource "aws_lambda_function" "queue_sender" {
  function_name = local.queue_sender_function_name

  filename         = data.archive_file.queue_sender_code.output_path
  source_code_hash = data.archive_file.queue_sender_code.output_base64sha256

  # Include both the function-specific layer and idp_common layer
  # queue_sender uses idp_common[appsync] based on requirements.txt
  layers = [var.idp_common_layer_arn]

  handler     = "index.handler"
  runtime     = "python3.12"
  timeout     = 30
  memory_size = 512
  role        = aws_iam_role.queue_sender_role.arn
  description = "Lambda function that sends documents to the processing queue"

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = {
      LOG_LEVEL              = var.log_level
      QUEUE_URL              = aws_sqs_queue.document_queue.url
      TRACKING_TABLE         = local.tracking_table.table_name
      DATA_RETENTION_IN_DAYS = var.data_tracking_retention_days
      OUTPUT_BUCKET          = local.output_bucket_name
      DOCUMENT_TRACKING_MODE = var.api != null ? "appsync" : "dynamodb"
      APPSYNC_API_URL        = var.api != null ? var.api.graphql_url : ""
    }
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.queue_sender_dlq.arn
  }

  dynamic "vpc_config" {
    for_each = length(var.subnet_ids) > 0 ? [1] : []
    content {
      subnet_ids         = var.subnet_ids
      security_group_ids = var.security_group_ids
    }
  }

  tracing_config {
    mode = var.lambda_tracing_mode
  }

  # Ensure all IAM policy attachments are complete before creating the Lambda function
  depends_on = [
    aws_iam_role_policy_attachment.queue_sender_policy_attachment,
    aws_iam_role_policy_attachment.queue_sender_kms_attachment,
    aws_iam_role_policy_attachment.queue_sender_vpc_attachment
  ]

  tags = var.tags
}

# Workflow Tracker function
data "archive_file" "workflow_tracker_code" {
  type        = "zip"
  source_dir  = "${path.module}/../../sources/src/lambda/workflow_tracker"
  output_path = "${local.module_build_dir}/workflow-tracker.zip_${random_id.build_id.hex}"

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

# WorkflowTracker Lambda Function
resource "aws_lambda_function" "workflow_tracker" {
  function_name = "idp-workflow-tracker-${random_string.suffix.result}"

  filename         = data.archive_file.workflow_tracker_code.output_path
  source_code_hash = data.archive_file.workflow_tracker_code.output_base64sha256

  handler     = "index.handler"
  runtime     = "python3.12"
  timeout     = 30
  memory_size = 512
  role        = aws_iam_role.workflow_tracker_role.arn
  description = "Lambda function that tracks workflow execution status"

  # Include both the function-specific layer and idp_common layer
  # workflow_tracker uses idp_common[appsync] based on requirements.txt
  layers = [var.idp_common_layer_arn]

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = {
      CONCURRENCY_TABLE            = local.concurrency_table.table_name
      METRIC_NAMESPACE             = var.metric_namespace
      TRACKING_TABLE               = local.tracking_table.table_name
      OUTPUT_BUCKET                = local.output_bucket_name
      WORKING_BUCKET               = local.working_bucket_name
      DOCUMENT_TRACKING_MODE       = var.api != null ? "appsync" : "dynamodb"
      APPSYNC_API_URL              = var.api != null ? var.api.graphql_url : ""
      LOG_LEVEL                    = var.log_level
      REPORTING_BUCKET             = var.enable_reporting ? local.reporting_bucket_name : ""
      SAVE_REPORTING_FUNCTION_NAME = var.enable_reporting ? aws_lambda_function.save_reporting_data[0].function_name : ""
    }
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.workflow_tracker_dlq.arn
  }

  dynamic "vpc_config" {
    for_each = length(var.subnet_ids) > 0 ? [1] : []
    content {
      subnet_ids         = var.subnet_ids
      security_group_ids = var.security_group_ids
    }
  }

  tracing_config {
    mode = var.lambda_tracing_mode
  }

  # Ensure all IAM policy attachments are complete before creating the Lambda function
  depends_on = [
    aws_iam_role_policy_attachment.workflow_tracker_policy_attachment,
    aws_iam_role_policy_attachment.workflow_tracker_kms_attachment,
    aws_iam_role_policy_attachment.workflow_tracker_vpc_attachment
  ]

  tags = var.tags
}

# Document Status Lookup function
data "archive_file" "lookup_function_code" {
  type        = "zip"
  source_dir  = "${path.module}/../../sources/src/lambda/lookup_function"
  output_path = "${local.module_build_dir}/lookup_function.zip_${random_id.build_id.hex}"

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

# LookupFunction Lambda Function
resource "aws_lambda_function" "lookup_function" {
  function_name = "idp-lookup-function-${random_string.suffix.result}"

  filename         = data.archive_file.lookup_function_code.output_path
  source_code_hash = data.archive_file.lookup_function_code.output_base64sha256

  handler     = "index.handler"
  runtime     = "python3.12"
  timeout     = 30
  memory_size = 512
  role        = aws_iam_role.lookup_function_role.arn
  description = "Lambda function that looks up document information from the tracking table"

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = {
      TRACKING_TABLE = local.tracking_table.table_name
      LOG_LEVEL      = var.log_level
    }
  }

  dynamic "vpc_config" {
    for_each = length(var.subnet_ids) > 0 ? [1] : []
    content {
      subnet_ids         = var.subnet_ids
      security_group_ids = var.security_group_ids
    }
  }

  tracing_config {
    mode = var.lambda_tracing_mode
  }

  # Ensure all IAM policy attachments are complete before creating the Lambda function
  depends_on = [
    aws_iam_role_policy_attachment.lookup_function_policy_attachment,
    aws_iam_role_policy_attachment.lookup_function_kms_attachment,
    aws_iam_role_policy_attachment.lookup_function_vpc_attachment
  ]

  tags = var.tags
}

# Document Status Lookup function
data "archive_file" "update_configuration_code" {
  type        = "zip"
  source_dir  = "${path.module}/../../sources/src/lambda/update_configuration"
  output_path = "${local.module_build_dir}/update_configuration.zip_${random_id.build_id.hex}"

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

# UpdateConfiguration Lambda Function
resource "aws_lambda_function" "update_configuration" {
  function_name = "idp-update-configuration-${random_string.suffix.result}"

  filename         = data.archive_file.update_configuration_code.output_path
  source_code_hash = data.archive_file.update_configuration_code.output_base64sha256

  handler     = "index.handler"
  runtime     = "python3.12"
  timeout     = 30
  memory_size = 512
  role        = aws_iam_role.update_configuration_role.arn
  description = "Lambda function that updates configuration settings"

  # Include only the function-specific layer
  # update_configuration does NOT use idp_common (uses PyYAML, cfnresponse)
  layers = [module.lambda_layers.layer_arns["update_configuration"]]

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = {
      CONFIGURATION_TABLE = local.configuration_table.table_name
      LOG_LEVEL           = var.log_level
    }
  }

  dynamic "vpc_config" {
    for_each = length(var.subnet_ids) > 0 ? [1] : []
    content {
      subnet_ids         = var.subnet_ids
      security_group_ids = var.security_group_ids
    }
  }

  tracing_config {
    mode = var.lambda_tracing_mode
  }

  # Ensure all IAM policy attachments are complete before creating the Lambda function
  depends_on = [
    aws_iam_role_policy_attachment.update_configuration_policy_attachment,
    aws_iam_role_policy_attachment.update_configuration_kms_attachment,
    aws_iam_role_policy_attachment.update_configuration_vpc_attachment
  ]

  tags = var.tags
}

# Post-Processing Decompressor Lambda
data "archive_file" "post_processing_decompressor_code" {
  type        = "zip"
  source_dir  = "${path.module}/../../sources/src/lambda/post_processing_decompressor"
  output_path = "${local.module_build_dir}/post_processing_decompressor.zip_${random_id.build_id.hex}"

  excludes = ["*.so", "*.dist-info/**", "*.egg-info/**", "__pycache__/**", "*.pyc", "boto3/**", "botocore/**"]

  depends_on = [null_resource.create_module_build_dir]
}

resource "aws_lambda_function" "post_processing_decompressor" {
  function_name = "idp-post-processing-decompressor-${random_string.suffix.result}"

  filename         = data.archive_file.post_processing_decompressor_code.output_path
  source_code_hash = data.archive_file.post_processing_decompressor_code.output_base64sha256

  layers = [var.idp_common_layer_arn]

  handler     = "index.handler"
  runtime     = "python3.12"
  timeout     = 300
  memory_size = 512
  role        = aws_iam_role.post_processing_decompressor_role.arn
  description = "Decompresses documents from Step Functions and invokes custom post-processor Lambda"

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = {
      LOG_LEVEL                 = var.log_level
      WORKING_BUCKET            = local.working_bucket_name
      CUSTOM_POST_PROCESSOR_ARN = var.custom_post_processor_arn != null ? var.custom_post_processor_arn : ""
    }
  }

  dynamic "vpc_config" {
    for_each = length(var.subnet_ids) > 0 ? [1] : []
    content {
      subnet_ids         = var.subnet_ids
      security_group_ids = var.security_group_ids
    }
  }

  tracing_config {
    mode = var.lambda_tracing_mode
  }

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "post_processing_decompressor_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.post_processing_decompressor.function_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.encryption_key_arn

  tags = var.tags
}

resource "aws_iam_role" "post_processing_decompressor_role" {
  name = "idp-post-proc-decomp-role-${random_string.suffix.result}"

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

resource "aws_iam_role_policy" "post_processing_decompressor_policy" {
  name = "idp-post-proc-decomp-policy-${random_string.suffix.result}"
  role = aws_iam_role.post_processing_decompressor_role.id

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
        Action   = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
        Resource = [var.working_bucket_arn, "${var.working_bucket_arn}/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["lambda:InvokeFunction"]
        Resource = var.custom_post_processor_arn != null ? var.custom_post_processor_arn : "arn:${data.aws_partition.current.partition}:lambda:*:*:function:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "post_processing_decompressor_vpc" {
  count = length(var.subnet_ids) > 0 ? 1 : 0

  role       = aws_iam_role.post_processing_decompressor_role.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

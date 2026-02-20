# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
/**
 * # Lambda Functions
 *
 * This file defines the Lambda functions used by the BDA processor.
 * Functions with external dependencies use lambda-layer-codebuild for dependency management.
 * All functions use the IDP common layer for shared utilities.
 */

# CloudWatch Log Groups for Lambda functions
resource "aws_cloudwatch_log_group" "invoke_bda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.invoke_bda.function_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.encryption_key_arn

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "process_results_logs" {
  name              = "/aws/lambda/${aws_lambda_function.process_results.function_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.encryption_key_arn

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "summarization_logs" {
  name              = "/aws/lambda/${aws_lambda_function.summarization.function_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.encryption_key_arn

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "bda_completion_logs" {
  name              = "/aws/lambda/${aws_lambda_function.bda_completion.function_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.encryption_key_arn

  tags = var.tags
}

# DISABLED: Using shared evaluation function from processor-attachment module
# resource "aws_cloudwatch_log_group" "evaluation_logs" {
#   count             = var.evaluation_baseline_bucket != null ? 1 : 0
#   name              = "/aws/lambda/${aws_lambda_function.evaluation[0].function_name}"
#   retention_in_days = var.log_retention_days
#   kms_key_id        = var.encryption_key_arn
# 
#   tags = var.tags
# }

# HITL Wait Function Log Group
resource "aws_cloudwatch_log_group" "hitl_wait_logs" {
  name              = "/aws/lambda/${aws_lambda_function.hitl_wait.function_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.encryption_key_arn

  tags = var.tags
}

# HITL Process Function Log Group
resource "aws_cloudwatch_log_group" "hitl_process_logs" {
  name              = "/aws/lambda/${aws_lambda_function.hitl_process.function_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.encryption_key_arn

  tags = var.tags
}

# HITL Status Update Function Log Group
resource "aws_cloudwatch_log_group" "hitl_status_update_logs" {
  name              = "/aws/lambda/${aws_lambda_function.hitl_status_update.function_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.encryption_key_arn

  tags = var.tags
}

# Source code archives (just the code, no dependencies)
# BDA Invoke function
# Generate unique build ID for this configuration

# Registry-compatible build directory approach
locals {
  # Module-specific build directory that works both locally and in registry
  module_build_dir = "${path.module}/.terraform-build"
  # Unique identifier for this module instance
  module_instance_id = substr(md5("${path.module}-bda-processor"), 0, 8)
}

# Create module-specific build directory
resource "null_resource" "create_module_build_dir" {
  provisioner "local-exec" {
    command = "mkdir -p ${local.module_build_dir}"
  }
}

# Generate unique build ID for this module instance
resource "random_id" "build_id" {
  byte_length = 8
  keepers = {
    # Include module instance ID for uniqueness
    module_instance_id = local.module_instance_id
    # Trigger rebuild when content changes
    content_hash = md5("bda-processor-lambda")
  }
}

data "archive_file" "invoke_bda_code" {
  type        = "zip"
  source_dir  = "${path.module}/../../../sources/patterns/pattern-1/src/bda_invoke_function"
  output_path = "${local.module_build_dir}/bda-invoke.zip_${random_id.build_id.hex}"

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

# BDA Invoke Lambda Function
resource "aws_lambda_function" "invoke_bda" {
  function_name = "${var.name}-invoke-bda-${random_string.suffix.result}"

  filename         = data.archive_file.invoke_bda_code.output_path
  source_code_hash = data.archive_file.invoke_bda_code.output_base64sha256

  # Only use idp_common layer since no additional requirements are needed
  layers = [
    var.idp_common_layer_arn
  ]

  handler     = "index.handler"
  runtime     = "python3.12"
  timeout     = 300
  memory_size = 512
  role        = aws_iam_role.invoke_bda_role.arn
  description = "Lambda function that invokes Bedrock Data Automation jobs"

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = {
      TRACKING_TABLE               = local.tracking_table_name
      METRIC_NAMESPACE             = var.metric_namespace
      LOG_LEVEL                    = var.log_level
      LAMBDA_COST_METERING_ENABLED = "true"
      PROCESSING_CONTEXT           = "bda_invoke"
    }
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.invoke_bda_dlq.arn
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
    aws_iam_role_policy_attachment.invoke_bda_policy_attachment,
    aws_iam_role_policy_attachment.invoke_bda_data_automation_attachment
  ]

  tags = var.tags
}

# BDA Completion function
data "archive_file" "bda_completion_code" {
  type        = "zip"
  source_dir  = "${path.module}/../../../sources/patterns/pattern-1/src/bda_completion_function"
  output_path = "${local.module_build_dir}/bda-completion.zip_${random_id.build_id.hex}"

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

# BDA Completion Lambda Function
resource "aws_lambda_function" "bda_completion" {
  function_name = "${var.name}-bda-completion-${random_string.suffix.result}"

  filename         = data.archive_file.bda_completion_code.output_path
  source_code_hash = data.archive_file.bda_completion_code.output_base64sha256

  # Include both the function-specific layer (for boto3) and idp_common layer
  layers = compact([
    contains(keys(module.lambda_layers.layer_arns), "bda_completion_function") ? lookup(module.lambda_layers.layer_arns, "bda_completion_function") : null,
    var.idp_common_layer_arn
  ])

  handler     = "index.handler"
  runtime     = "python3.12"
  timeout     = 60
  memory_size = 512
  role        = aws_iam_role.bda_completion_role.arn
  description = "Lambda function that handles BDA job completion events"

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = {
      TRACKING_TABLE               = local.tracking_table_name
      METRIC_NAMESPACE             = var.metric_namespace
      LOG_LEVEL                    = var.log_level
      LAMBDA_COST_METERING_ENABLED = "true"
      PROCESSING_CONTEXT           = "bda_completion"
    }
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.bda_completion_dlq.arn
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
    aws_iam_role_policy_attachment.bda_completion_policy_attachment
  ]

  tags = var.tags
}

# Process Results function
data "archive_file" "process_results_code" {
  type        = "zip"
  source_dir  = "${path.module}/../../../sources/patterns/pattern-1/src/processresults_function"
  output_path = "${local.module_build_dir}/process-results.zip_${random_id.build_id.hex}"

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

# Process Results Lambda Function
resource "aws_lambda_function" "process_results" {
  function_name = "${var.name}-process-results-${random_string.suffix.result}"

  filename         = data.archive_file.process_results_code.output_path
  source_code_hash = data.archive_file.process_results_code.output_base64sha256

  # Include both the function-specific layer (for PyMuPDF + boto3) and idp_common layer
  layers = compact([
    contains(keys(module.lambda_layers.layer_arns), "processresults_function") ? lookup(module.lambda_layers.layer_arns, "processresults_function") : null,
    var.idp_common_layer_arn
  ])

  handler     = "index.handler"
  runtime     = "python3.12"
  timeout     = 300
  memory_size = 1024
  role        = aws_iam_role.process_results_role.arn
  description = "Lambda function that processes BDA extraction results"

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = {
      APPSYNC_API_URL              = var.api_graphql_url
      METRIC_NAMESPACE             = var.metric_namespace
      LOG_LEVEL                    = var.log_level
      WORKING_BUCKET               = local.working_bucket_name
      TRACKING_TABLE               = local.tracking_table_name
      CONFIGURATION_TABLE_NAME     = local.configuration_table_name
      DOCUMENT_TRACKING_MODE       = var.api_id != null ? "appsync" : "dynamodb"
      BDA_PROJECT_ARN              = var.data_automation_project_arn
      LAMBDA_COST_METERING_ENABLED = "true"
      PROCESSING_CONTEXT           = "process_results"
    }
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.process_results_dlq.arn
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
    aws_iam_role_policy_attachment.process_results_policy_attachment
  ]

  tags = var.tags
}

# Summarization function
data "archive_file" "summarization_code" {
  type        = "zip"
  source_dir  = "${path.module}/../../../sources/patterns/pattern-1/src/summarization_function"
  output_path = "${local.module_build_dir}/summarization.zip_${random_id.build_id.hex}"

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

# Summarization Lambda Function
resource "aws_lambda_function" "summarization" {
  function_name = "${var.name}-summarization-${random_string.suffix.result}"

  filename         = data.archive_file.summarization_code.output_path
  source_code_hash = data.archive_file.summarization_code.output_base64sha256

  # Include only idp_common layer (no external dependencies)
  layers = [var.idp_common_layer_arn]

  handler     = "index.handler"
  runtime     = "python3.12"
  timeout     = 300
  memory_size = 512
  role        = aws_iam_role.summarization_role.arn
  description = "Lambda function that provides document summarization"

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = {
      METRIC_NAMESPACE             = var.metric_namespace
      CONFIGURATION_TABLE_NAME     = local.configuration_table_name
      GUARDRAIL_ID_AND_VERSION     = var.summarization_guardrail != null ? var.summarization_guardrail.guardrail_id : ""
      LOG_LEVEL                    = var.log_level
      APPSYNC_API_URL              = var.api_graphql_url
      WORKING_BUCKET               = local.working_bucket_name
      TRACKING_TABLE               = local.tracking_table_name
      DOCUMENT_TRACKING_MODE       = var.api_id != null ? "appsync" : "dynamodb"
      LAMBDA_COST_METERING_ENABLED = "true"
      PROCESSING_CONTEXT           = "summarization"
    }
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.summarization_dlq.arn
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
    aws_iam_role_policy_attachment.summarization_policy_attachment
  ]

  tags = var.tags
}

# Evaluation function (optional)
# DISABLED: Using shared evaluation function from processor-attachment module
# data "archive_file" "evaluation_code" {
#   count       = var.evaluation_baseline_bucket != null ? 1 : 0
#   type        = "zip"
#   source_dir  = "${path.module}/../../../sources/src/lambda/evaluation_function"
#   output_path = "${local.module_build_dir}/evaluation.zip_${random_id.build_id.hex}"
# 
#   # Exclude any potential dependencies that might be there
#   excludes = [
#     "*.so",
#     "*.dist-info/**",
#     "*.egg-info/**",
#     "__pycache__/**",
#     "*.pyc",
#     "boto3/**",
#     "botocore/**"
#   ]
# 
#   depends_on = [null_resource.create_module_build_dir]
# }

# Evaluation Lambda Function
# DISABLED: Using shared evaluation function from processor-attachment module
# resource "aws_lambda_function" "evaluation" {
#   count         = var.evaluation_baseline_bucket != null ? 1 : 0
#   function_name = "${var.name}-evaluation-${random_string.suffix.result}"
# 
#   filename         = data.archive_file.evaluation_code[0].output_path
#   source_code_hash = data.archive_file.evaluation_code[0].output_base64sha256
# 
#   # Include only idp_common layer (uses shared evaluation function)
#   layers = [var.idp_common_layer_arn]
# 
#   handler     = "index.handler"
#   runtime     = "python3.12"
#   timeout     = 300
#   memory_size = 512
#   role        = aws_iam_role.evaluation_role[0].arn
#   description = "Lambda function that evaluates document processing results"
# 
#   environment {
#     variables = {
#       LOG_LEVEL                    = var.log_level
#       METRIC_NAMESPACE             = var.metric_namespace
#       TRACKING_TABLE               = local.tracking_table_name
#       PROCESSING_OUTPUT_BUCKET     = local.output_bucket_name
#       EVALUATION_OUTPUT_BUCKET     = local.output_bucket_name
#       BASELINE_BUCKET              = var.evaluation_baseline_bucket.bucket_name
#       CONFIGURATION_TABLE_NAME     = local.configuration_table_name
#       DOCUMENT_TRACKING_MODE       = var.api_id != null ? "appsync" : "dynamodb"
#       APPSYNC_API_URL              = var.api_id != null ? var.api_graphql_url : ""
#       REPORTING_BUCKET             = "" # Reporting not supported in BDA processor evaluation
#       SAVE_REPORTING_FUNCTION_NAME = "" # Reporting not supported in BDA processor evaluation
#     }
#   }
# 
#   dead_letter_config {
#     target_arn = aws_sqs_queue.evaluation_dlq[0].arn
#   }
# 
#   dynamic "vpc_config" {
#     for_each = length(var.vpc_subnet_ids) > 0 ? [local.vpc_config] : []
#     content {
#       subnet_ids         = vpc_config.value.subnet_ids
#       security_group_ids = vpc_config.value.security_group_ids
#     }
#   }
# 
#   tags = var.tags
# }

# HITL Wait Function
resource "aws_lambda_function" "hitl_wait" {
  function_name = "${var.name}-hitl-wait-${random_string.suffix.result}"

  filename         = data.archive_file.hitl_wait_code.output_path
  source_code_hash = data.archive_file.hitl_wait_code.output_base64sha256

  layers = [var.idp_common_layer_arn]

  handler     = "index.handler"
  runtime     = "python3.12"
  timeout     = 300
  memory_size = 512
  role        = aws_iam_role.hitl_wait_role.arn
  description = "Lambda function that waits for HITL (Human-in-the-Loop) processing completion"

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = {
      LOG_LEVEL                       = var.log_level
      METRIC_NAMESPACE                = var.metric_namespace
      TRACKING_TABLE                  = local.tracking_table_name
      CONFIGURATION_TABLE_NAME        = local.configuration_table_name
      WORKING_BUCKET                  = local.working_bucket_name
      DOCUMENT_TRACKING_MODE          = var.api_id != null ? "appsync" : "dynamodb"
      APPSYNC_API_URL                 = var.api_id != null ? var.api_graphql_url : ""
      SAGEMAKER_A2I_REVIEW_PORTAL_URL = var.sagemaker_a2i_review_portal_url != null ? var.sagemaker_a2i_review_portal_url : ""
      HITL_WORKTEAM_ARN               = var.hitl_workteam_arn != null ? var.hitl_workteam_arn : ""
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

  tags = var.tags
}

# HITL Process Function
resource "aws_lambda_function" "hitl_process" {
  function_name = "${var.name}-hitl-process-${random_string.suffix.result}"

  filename         = data.archive_file.hitl_process_code.output_path
  source_code_hash = data.archive_file.hitl_process_code.output_base64sha256

  layers = [var.idp_common_layer_arn]

  handler     = "index.handler"
  runtime     = "python3.12"
  timeout     = 300
  memory_size = 512
  role        = aws_iam_role.hitl_process_role.arn
  description = "Lambda function that processes HITL (Human-in-the-Loop) results"

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = {
      LOG_LEVEL                = var.log_level
      METRIC_NAMESPACE         = var.metric_namespace
      TRACKING_TABLE           = local.tracking_table_name
      CONFIGURATION_TABLE_NAME = local.configuration_table_name
      WORKING_BUCKET           = local.working_bucket_name
      OUTPUT_BUCKET            = local.output_bucket_name
      DOCUMENT_TRACKING_MODE   = var.api_id != null ? "appsync" : "dynamodb"
      APPSYNC_API_URL          = var.api_id != null ? var.api_graphql_url : ""
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

  tags = var.tags
}

# HITL Status Update Function
resource "aws_lambda_function" "hitl_status_update" {
  function_name = "${var.name}-hitl-status-update-${random_string.suffix.result}"

  filename         = data.archive_file.hitl_status_update_code.output_path
  source_code_hash = data.archive_file.hitl_status_update_code.output_base64sha256

  layers = [var.idp_common_layer_arn]

  handler     = "index.handler"
  runtime     = "python3.12"
  timeout     = 300
  memory_size = 512
  role        = aws_iam_role.hitl_status_update_role.arn
  description = "Lambda function that updates HITL status in tracking table"

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = {
      LOG_LEVEL                = var.log_level
      METRIC_NAMESPACE         = var.metric_namespace
      TRACKING_TABLE           = local.tracking_table_name
      CONFIGURATION_TABLE_NAME = local.configuration_table_name
      DOCUMENT_TRACKING_MODE   = var.api_id != null ? "appsync" : "dynamodb"
      APPSYNC_API_URL          = var.api_id != null ? var.api_graphql_url : ""
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

  tags = var.tags
}
# HITL Wait Function Archive
data "archive_file" "hitl_wait_code" {
  type        = "zip"
  source_dir  = "${path.module}/../../../sources/patterns/pattern-1/src/hitl-wait-function"
  output_path = "${local.module_build_dir}/hitl_wait.zip_${random_id.build_id.hex}"

  depends_on = [null_resource.create_module_build_dir]
}

# HITL Process Function Archive
data "archive_file" "hitl_process_code" {
  type        = "zip"
  source_dir  = "${path.module}/../../../sources/patterns/pattern-1/src/hitl-process-function"
  output_path = "${local.module_build_dir}/hitl_process.zip_${random_id.build_id.hex}"

  depends_on = [null_resource.create_module_build_dir]
}

# HITL Status Update Function Archive
data "archive_file" "hitl_status_update_code" {
  type        = "zip"
  source_dir  = "${path.module}/../../../sources/patterns/pattern-1/src/hitl-status-update-function"
  output_path = "${local.module_build_dir}/hitl_status_update.zip_${random_id.build_id.hex}"

  depends_on = [null_resource.create_module_build_dir]
}

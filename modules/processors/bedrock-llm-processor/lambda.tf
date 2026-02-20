# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Lambda Functions for Bedrock LLM Processor

# OCR Function
resource "aws_lambda_function" "ocr" {
  function_name = "${local.name_prefix}-ocr"
  role          = aws_iam_role.ocr_lambda.arn
  handler       = "index.handler"
  runtime       = "python3.12"
  timeout       = 900
  memory_size   = 1024

  filename         = data.archive_file.ocr_lambda.output_path
  source_code_hash = data.archive_file.ocr_lambda.output_base64sha256

  layers = [var.idp_common_layer_arn]

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = {
      LOG_LEVEL                = local.log_level
      METRIC_NAMESPACE         = local.metric_namespace
      MAX_WORKERS              = var.ocr_max_workers
      CONFIGURATION_TABLE_NAME = local.configuration_table_name
      TRACKING_TABLE           = local.tracking_table_name
      WORKING_BUCKET           = local.working_bucket_name
      DOCUMENT_TRACKING_MODE   = local.api_id != null ? "appsync" : "dynamodb"
      APPSYNC_API_URL          = local.api_graphql_url != null ? local.api_graphql_url : ""
      LAMBDA_COST_METERING_ENABLED = "true"
      PROCESSING_CONTEXT       = "ocr"
    }
  }

  dynamic "vpc_config" {
    for_each = length(local.vpc_subnet_ids) > 0 ? [1] : []
    content {
      subnet_ids         = local.vpc_subnet_ids
      security_group_ids = local.vpc_security_group_ids
    }
  }

  tracing_config {
    mode = var.lambda_tracing_mode
  }

  tags = local.common_tags
}

# Classification Function
resource "aws_lambda_function" "classification" {
  function_name = "${local.name_prefix}-classification"
  role          = aws_iam_role.classification_lambda.arn
  handler       = "index.handler"
  runtime       = "python3.12"
  timeout       = 900
  memory_size   = 3008

  filename         = data.archive_file.classification_lambda.output_path
  source_code_hash = data.archive_file.classification_lambda.output_base64sha256

  layers = [var.idp_common_layer_arn]

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = {
      METRIC_NAMESPACE         = local.metric_namespace
      MAX_WORKERS              = var.classification_max_workers
      TRACKING_TABLE           = local.tracking_table_name
      CONFIGURATION_TABLE_NAME = local.configuration_table_name
      LOG_LEVEL                = local.log_level
      WORKING_BUCKET           = local.working_bucket_name
      GUARDRAIL_ID_AND_VERSION = var.classification_guardrail != null ? var.classification_guardrail.guardrail_id : ""
      DOCUMENT_TRACKING_MODE   = local.api_id != null ? "appsync" : "dynamodb"
      APPSYNC_API_URL          = local.api_graphql_url != null ? local.api_graphql_url : ""
      LAMBDA_COST_METERING_ENABLED = "true"
      PROCESSING_CONTEXT       = "classification"
      MAX_PAGES_FOR_CLASSIFICATION = var.max_pages_for_classification
    }
  }

  tracing_config {
    mode = var.lambda_tracing_mode
  }

  tags = local.common_tags
}

# Extraction Function
resource "aws_lambda_function" "extraction" {
  function_name = "${local.name_prefix}-extraction"
  role          = aws_iam_role.extraction_lambda.arn
  handler       = "index.handler"
  runtime       = "python3.12"
  timeout       = 900
  memory_size   = 1024

  filename         = data.archive_file.extraction_lambda.output_path
  source_code_hash = data.archive_file.extraction_lambda.output_base64sha256

  layers = [var.idp_common_layer_arn]

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = {
      METRIC_NAMESPACE         = local.metric_namespace
      CONFIGURATION_TABLE_NAME = local.configuration_table_name
      WORKING_BUCKET           = local.working_bucket_name
      GUARDRAIL_ID_AND_VERSION = var.extraction_guardrail != null ? var.extraction_guardrail.guardrail_id : ""
      LOG_LEVEL                = local.log_level
      TRACKING_TABLE           = local.tracking_table_name
      DOCUMENT_TRACKING_MODE   = local.api_id != null ? "appsync" : "dynamodb"
      APPSYNC_API_URL          = local.api_graphql_url != null ? local.api_graphql_url : ""
      LAMBDA_COST_METERING_ENABLED = "true"
      PROCESSING_CONTEXT       = "extraction"
    }
  }

  tracing_config {
    mode = var.lambda_tracing_mode
  }

  tags = local.common_tags
}

# Process Results Function
resource "aws_lambda_function" "process_results" {
  function_name = "${local.name_prefix}-process-results"
  role          = aws_iam_role.process_results_lambda.arn
  handler       = "index.handler"
  runtime       = "python3.12"
  timeout       = 900
  memory_size   = 1024

  filename         = data.archive_file.process_results_lambda.output_path
  source_code_hash = data.archive_file.process_results_lambda.output_base64sha256

  layers = [var.idp_common_layer_arn]

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = {
      METRIC_NAMESPACE       = local.metric_namespace
      LOG_LEVEL              = local.log_level
      TRACKING_TABLE         = local.tracking_table_name
      WORKING_BUCKET         = local.working_bucket_name
      DOCUMENT_TRACKING_MODE = local.api_id != null ? "appsync" : "dynamodb"
      APPSYNC_API_URL        = local.api_graphql_url != null ? local.api_graphql_url : ""
      LAMBDA_COST_METERING_ENABLED = "true"
      PROCESSING_CONTEXT     = "process_results"
    }
  }

  tracing_config {
    mode = var.lambda_tracing_mode
  }

  tags = local.common_tags
}

# Summarization Function (conditional)
resource "aws_lambda_function" "summarization" {
  count = var.is_summarization_enabled ? 1 : 0

  function_name = "${local.name_prefix}-summarization"
  role          = aws_iam_role.summarization_lambda[0].arn
  handler       = "index.handler"
  runtime       = "python3.12"
  timeout       = 900
  memory_size   = 1024

  filename         = data.archive_file.summarization_lambda.output_path
  source_code_hash = data.archive_file.summarization_lambda.output_base64sha256

  layers = [var.idp_common_layer_arn]

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = {
      METRIC_NAMESPACE         = local.metric_namespace
      CONFIGURATION_TABLE_NAME = local.configuration_table_name
      WORKING_BUCKET           = local.working_bucket_name
      LOG_LEVEL                = local.log_level
      GUARDRAIL_ID_AND_VERSION = var.summarization_guardrail != null ? var.summarization_guardrail.guardrail_id : ""
      TRACKING_TABLE           = local.tracking_table_name
      DOCUMENT_TRACKING_MODE   = local.api_id != null ? "appsync" : "dynamodb"
      APPSYNC_API_URL          = local.api_graphql_url != null ? local.api_graphql_url : ""
      LAMBDA_COST_METERING_ENABLED = "true"
      PROCESSING_CONTEXT       = "summarization"
    }
  }

  tracing_config {
    mode = var.lambda_tracing_mode
  }

  tags = local.common_tags
}

# CloudWatch Log Groups for Lambda Functions
resource "aws_cloudwatch_log_group" "ocr_lambda" {
  name              = "/aws/lambda/${aws_lambda_function.ocr.function_name}"
  retention_in_days = local.log_retention_days
  kms_key_id        = local.encryption_key_arn

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "classification_lambda" {
  name              = "/aws/lambda/${aws_lambda_function.classification.function_name}"
  retention_in_days = local.log_retention_days
  kms_key_id        = local.encryption_key_arn

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "extraction_lambda" {
  name              = "/aws/lambda/${aws_lambda_function.extraction.function_name}"
  retention_in_days = local.log_retention_days
  kms_key_id        = local.encryption_key_arn

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "process_results_lambda" {
  name              = "/aws/lambda/${aws_lambda_function.process_results.function_name}"
  retention_in_days = local.log_retention_days
  kms_key_id        = local.encryption_key_arn

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "summarization_lambda" {
  count = var.is_summarization_enabled ? 1 : 0

  name              = "/aws/lambda/${aws_lambda_function.summarization[0].function_name}"
  retention_in_days = local.log_retention_days
  kms_key_id        = local.encryption_key_arn

  tags = local.common_tags
}

# Assessment Function (always deployed, controlled by configuration)
resource "aws_lambda_function" "assessment" {
  function_name = "${local.name_prefix}-assessment"
  role          = aws_iam_role.assessment_lambda.arn
  handler       = "index.handler"
  runtime       = "python3.12"
  timeout       = 900
  memory_size   = 512

  filename         = data.archive_file.assessment_lambda.output_path
  source_code_hash = data.archive_file.assessment_lambda.output_base64sha256

  layers = [var.idp_common_layer_arn]

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = {
      METRIC_NAMESPACE         = local.metric_namespace
      CONFIGURATION_TABLE_NAME = local.configuration_table_name
      LOG_LEVEL                = local.log_level
      WORKING_BUCKET           = local.working_bucket_name
      TRACKING_TABLE           = local.tracking_table_name
      DOCUMENT_TRACKING_MODE   = local.api_id != null ? "appsync" : "dynamodb"
      APPSYNC_API_URL          = local.api_graphql_url != null ? local.api_graphql_url : ""
      LAMBDA_COST_METERING_ENABLED = "true"
      PROCESSING_CONTEXT       = "assessment"
    }
  }

  tracing_config {
    mode = var.lambda_tracing_mode
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "assessment_lambda" {
  name              = "/aws/lambda/${aws_lambda_function.assessment.function_name}"
  retention_in_days = local.log_retention_days
  kms_key_id        = local.encryption_key_arn

  tags = local.common_tags
}

# HITL Wait Function (conditional)
resource "aws_lambda_function" "hitl_wait" {
  count = var.enable_hitl ? 1 : 0

  function_name = "${local.name_prefix}-hitl-wait"
  role          = aws_iam_role.hitl_wait_lambda[0].arn
  handler       = "index.lambda_handler"
  runtime       = "python3.12"
  timeout       = 300
  memory_size   = 512

  filename         = data.archive_file.hitl_wait_lambda.output_path
  source_code_hash = data.archive_file.hitl_wait_lambda.output_base64sha256

  layers = [var.idp_common_layer_arn]

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = {
      LOG_LEVEL                       = local.log_level
      TRACKING_TABLE                  = local.tracking_table_name
      WORKING_BUCKET                  = local.working_bucket_name
      SAGEMAKER_A2I_REVIEW_PORTAL_URL = ""
    }
  }

  dynamic "vpc_config" {
    for_each = length(local.vpc_subnet_ids) > 0 ? [1] : []
    content {
      subnet_ids         = local.vpc_subnet_ids
      security_group_ids = local.vpc_security_group_ids
    }
  }

  tracing_config {
    mode = var.lambda_tracing_mode
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "hitl_wait_lambda" {
  count = var.enable_hitl ? 1 : 0

  name              = "/aws/lambda/${aws_lambda_function.hitl_wait[0].function_name}"
  retention_in_days = local.log_retention_days
  kms_key_id        = local.encryption_key_arn

  tags = local.common_tags
}

# HITL Status Update Function (conditional)
resource "aws_lambda_function" "hitl_status_update" {
  count = var.enable_hitl ? 1 : 0

  function_name = "${local.name_prefix}-hitl-status-update"
  role          = aws_iam_role.hitl_status_update_lambda[0].arn
  handler       = "index.handler"
  runtime       = "python3.12"
  timeout       = 60
  memory_size   = 256

  filename         = data.archive_file.hitl_status_update_lambda.output_path
  source_code_hash = data.archive_file.hitl_status_update_lambda.output_base64sha256

  kms_key_arn = var.encryption_key_arn

  dynamic "vpc_config" {
    for_each = length(local.vpc_subnet_ids) > 0 ? [1] : []
    content {
      subnet_ids         = local.vpc_subnet_ids
      security_group_ids = local.vpc_security_group_ids
    }
  }

  tracing_config {
    mode = var.lambda_tracing_mode
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "hitl_status_update_lambda" {
  count = var.enable_hitl ? 1 : 0

  name              = "/aws/lambda/${aws_lambda_function.hitl_status_update[0].function_name}"
  retention_in_days = local.log_retention_days
  kms_key_id        = local.encryption_key_arn

  tags = local.common_tags
}

# Lambda deployment packages
# Generate unique build ID for this configuration

# Create temporary directory for build artifacts

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
    content_hash = md5("bedrock-llm-processor-lambda")
  }
}

data "archive_file" "assessment_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/../../../sources/patterns/pattern-2/src/assessment_function"
  output_path = "${path.module}/assessment_function.zip"

  depends_on = [null_resource.create_module_build_dir]
}

data "archive_file" "ocr_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/../../../sources/patterns/pattern-2/src/ocr_function"
  output_path = "${path.module}/ocr_function.zip"

  depends_on = [null_resource.create_module_build_dir]
}

data "archive_file" "classification_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/../../../sources/patterns/pattern-2/src/classification_function"
  output_path = "${path.module}/classification_function.zip"

  depends_on = [null_resource.create_module_build_dir]
}

data "archive_file" "extraction_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/../../../sources/patterns/pattern-2/src/extraction_function"
  output_path = "${path.module}/extraction_function.zip"

  depends_on = [null_resource.create_module_build_dir]
}

data "archive_file" "process_results_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/../../../sources/patterns/pattern-2/src/processresults_function"
  output_path = "${path.module}/process_results_function.zip"

  depends_on = [null_resource.create_module_build_dir]
}

data "archive_file" "summarization_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/../../../sources/patterns/pattern-2/src/summarization_function"
  output_path = "${path.module}/summarization_function.zip"

  depends_on = [null_resource.create_module_build_dir]
}

data "archive_file" "hitl_wait_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/../../../sources/patterns/pattern-2/src/hitl-wait-function"
  output_path = "${path.module}/hitl_wait_function.zip"

  depends_on = [null_resource.create_module_build_dir]
}

data "archive_file" "hitl_status_update_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/../../../sources/patterns/pattern-2/src/hitl-status-update-function"
  output_path = "${path.module}/hitl_status_update_function.zip"

  depends_on = [null_resource.create_module_build_dir]
}

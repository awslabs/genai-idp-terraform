# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Lambda Functions for BDA Processor
# All functions use Docker images from ECR (arm64), matching the SAM/CloudFormation reference.

# =============================================================================
# CloudWatch Log Groups
# =============================================================================

resource "aws_cloudwatch_log_group" "invoke_bda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.invoke_bda.function_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.encryption_key_arn
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "bda_completion_logs" {
  name              = "/aws/lambda/${aws_lambda_function.bda_completion.function_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.encryption_key_arn
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "process_results_logs" {
  name              = "/aws/lambda/${aws_lambda_function.process_results.function_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.encryption_key_arn
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "summarization_logs" {
  name              = "/aws/lambda/${aws_lambda_function.summarization.function_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.encryption_key_arn
  tags              = var.tags
}


resource "aws_cloudwatch_log_group" "evaluation_function_logs" {
  name              = "/aws/lambda/${aws_lambda_function.evaluation_function.function_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.encryption_key_arn
  tags              = var.tags
}

# =============================================================================
# BDA Invoke Function
# =============================================================================

resource "aws_lambda_function" "invoke_bda" {
  function_name = "${var.name}-invoke-bda-${random_string.suffix.result}"
  role          = aws_iam_role.invoke_bda_role.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.bda_processor.repository_url}:bda-invoke-function"
  architectures = ["arm64"]
  timeout       = 900
  memory_size   = 3008

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = {
      TRACKING_TABLE   = local.tracking_table_name
      METRIC_NAMESPACE = var.metric_namespace
      LOG_LEVEL        = var.log_level
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

  depends_on = [
    null_resource.bda_images_ready,
    aws_iam_role_policy_attachment.invoke_bda_policy_attachment,
    aws_iam_role_policy_attachment.invoke_bda_data_automation_attachment
  ]

  tags = var.tags
}

# =============================================================================
# BDA Completion Function
# =============================================================================

resource "aws_lambda_function" "bda_completion" {
  function_name = "${var.name}-bda-completion-${random_string.suffix.result}"
  role          = aws_iam_role.bda_completion_role.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.bda_processor.repository_url}:bda-completion-function"
  architectures = ["arm64"]
  timeout       = 900
  # Upstream uses 4096 MB; capped at 3008 MB (default account quota).
  # Request a Lambda memory quota increase to 10240 MB via AWS Service Quotas to restore.
  memory_size = 3008

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = {
      TRACKING_TABLE   = local.tracking_table_name
      METRIC_NAMESPACE = var.metric_namespace
      LOG_LEVEL        = var.log_level
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

  depends_on = [
    null_resource.bda_images_ready,
    aws_iam_role_policy_attachment.bda_completion_policy_attachment
  ]

  tags = var.tags
}

# =============================================================================
# Process Results Function
# =============================================================================

resource "aws_lambda_function" "process_results" {
  function_name = "${var.name}-process-results-${random_string.suffix.result}"
  role          = aws_iam_role.process_results_role.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.bda_processor.repository_url}:processresults-function"
  architectures = ["arm64"]
  timeout       = 900
  # Upstream uses 4096 MB; capped at 3008 MB (default account quota).
  # Request a Lambda memory quota increase to 10240 MB via AWS Service Quotas to restore.
  memory_size = 3008

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = {
      APPSYNC_API_URL          = var.api_graphql_url
      METRIC_NAMESPACE         = var.metric_namespace
      LOG_LEVEL                = var.log_level
      WORKING_BUCKET           = local.working_bucket_name
      TRACKING_TABLE           = local.tracking_table_name
      CONFIGURATION_TABLE_NAME = local.configuration_table_name
      DOCUMENT_TRACKING_MODE   = var.api_id != null ? "appsync" : "dynamodb"
      BDA_PROJECT_ARN          = var.data_automation_project_arn
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

  depends_on = [
    null_resource.bda_images_ready,
    aws_iam_role_policy_attachment.process_results_policy_attachment
  ]

  tags = var.tags
}

# =============================================================================
# Summarization Function
# =============================================================================

resource "aws_lambda_function" "summarization" {
  function_name = "${var.name}-summarization-${random_string.suffix.result}"
  role          = aws_iam_role.summarization_role.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.bda_processor.repository_url}:summarization-function"
  architectures = ["arm64"]
  timeout       = 900
  # Upstream uses 4096 MB; capped at 3008 MB (default account quota).
  # Request a Lambda memory quota increase to 10240 MB via AWS Service Quotas to restore.
  memory_size = 3008

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = {
      METRIC_NAMESPACE         = var.metric_namespace
      CONFIGURATION_TABLE_NAME = local.configuration_table_name
      GUARDRAIL_ID_AND_VERSION = var.summarization_guardrail != null ? var.summarization_guardrail.guardrail_id : ""
      LOG_LEVEL                = var.log_level
      APPSYNC_API_URL          = var.api_graphql_url
      WORKING_BUCKET           = local.working_bucket_name
      TRACKING_TABLE           = local.tracking_table_name
      DOCUMENT_TRACKING_MODE   = var.api_id != null ? "appsync" : "dynamodb"
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

  depends_on = [
    null_resource.bda_images_ready,
    aws_iam_role_policy_attachment.summarization_policy_attachment
  ]

  tags = var.tags
}

# =============================================================================
# Evaluation Function (Docker image from ECR)
# Must be defined BEFORE the Step Functions state machine (the state machine
# definition template references evaluation_function.arn).
# =============================================================================

resource "aws_lambda_function" "evaluation_function" {
  function_name = "${var.name}-evaluation-function-${random_string.suffix.result}"
  role          = aws_iam_role.evaluation_function_role.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.bda_processor.repository_url}:evaluation-function"
  architectures = ["arm64"]
  timeout       = 900
  memory_size   = 1024

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = {
      LOG_LEVEL                    = var.log_level
      METRIC_NAMESPACE             = var.metric_namespace
      TRACKING_TABLE               = local.tracking_table_name
      CONFIGURATION_TABLE_NAME     = local.configuration_table_name
      WORKING_BUCKET               = local.working_bucket_name
      BASELINE_BUCKET              = var.evaluation_baseline_bucket_name
      REPORTING_BUCKET             = var.reporting_bucket_name
      SAVE_REPORTING_FUNCTION_NAME = var.save_reporting_function_name
      DOCUMENT_TRACKING_MODE       = var.api_id != null ? "appsync" : "dynamodb"
      APPSYNC_API_URL              = var.api_id != null ? coalesce(var.api_graphql_url, "") : ""
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

  depends_on = [
    null_resource.bda_images_ready,
    aws_iam_role_policy_attachment.evaluation_function_policy_attachment
  ]

  tags = var.tags
}

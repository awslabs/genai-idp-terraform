# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Lambda Functions for SageMaker UDOP Processor
# All functions use Docker images from ECR (arm64).

locals {
  idp_common_layer_arn = var.idp_common_layer_arn
  module_build_dir     = "${path.module}/.terraform-build"
  module_instance_id   = substr(md5("${path.module}-sagemaker-udop"), 0, 8)
}

resource "aws_cloudwatch_log_group" "ocr_function_logs" {
  name              = "/aws/lambda/${local.name_prefix}-sagemaker-udop-ocr"
  retention_in_days = local.log_retention_days
  kms_key_id        = local.encryption_key_arn
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "classification_function_logs" {
  name              = "/aws/lambda/${local.name_prefix}-sagemaker-udop-classification"
  retention_in_days = local.log_retention_days
  kms_key_id        = local.encryption_key_arn
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "extraction_function_logs" {
  name              = "/aws/lambda/${local.name_prefix}-sagemaker-udop-extraction"
  retention_in_days = local.log_retention_days
  kms_key_id        = local.encryption_key_arn
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "process_results_function_logs" {
  name              = "/aws/lambda/${local.name_prefix}-sagemaker-udop-process-results"
  retention_in_days = local.log_retention_days
  kms_key_id        = local.encryption_key_arn
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "summarization_function_logs" {
  name              = "/aws/lambda/${local.name_prefix}-sagemaker-udop-summarization"
  retention_in_days = local.log_retention_days
  kms_key_id        = local.encryption_key_arn
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "assessment_lambda" {
  name              = "/aws/lambda/${aws_lambda_function.assessment_function.function_name}"
  retention_in_days = local.log_retention_days
  kms_key_id        = local.encryption_key_arn
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "evaluation_function_logs" {
  name              = "/aws/lambda/${var.name}-evaluation-function"
  retention_in_days = local.log_retention_days
  kms_key_id        = local.encryption_key_arn
  tags              = local.common_tags
}

resource "aws_lambda_function" "ocr_function" {
  function_name = "${local.name_prefix}-sagemaker-udop-ocr"
  role          = aws_iam_role.ocr_function_role.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.udop_processor.repository_url}:ocr-function"
  architectures = ["arm64"]
  timeout       = 900
  memory_size   = 4096
  kms_key_arn   = var.encryption_key_arn

  environment {
    variables = {
      METRIC_NAMESPACE         = local.metric_namespace
      MAX_WORKERS              = var.ocr_max_workers
      CONFIGURATION_TABLE_NAME = local.configuration_table_name
      LOG_LEVEL                = local.log_level
      TRACKING_TABLE           = local.tracking_table_name
      WORKING_BUCKET           = local.working_bucket_name
      DOCUMENT_TRACKING_MODE   = local.api_id != null ? "appsync" : "dynamodb"
      APPSYNC_API_URL          = local.api_graphql_url != null ? local.api_graphql_url : ""
    }
  }

  dynamic "vpc_config" {
    for_each = length(local.vpc_subnet_ids) > 0 ? [1] : []
    content {
      subnet_ids         = local.vpc_subnet_ids
      security_group_ids = local.vpc_security_group_ids
    }
  }

  tracing_config { mode = var.lambda_tracing_mode }

  depends_on = [
    null_resource.trigger_udop_build,
    aws_iam_role_policy_attachment.ocr_function_basic_execution,
    aws_cloudwatch_log_group.ocr_function_logs,
  ]

  tags = local.common_tags
}

resource "aws_lambda_function" "classification_function" {
  function_name = "${local.name_prefix}-sagemaker-udop-classification"
  role          = aws_iam_role.classification_function_role.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.udop_processor.repository_url}:classification-function"
  architectures = ["arm64"]
  timeout       = 900
  memory_size   = 4096
  kms_key_arn   = var.encryption_key_arn

  environment {
    variables = {
      METRIC_NAMESPACE         = local.metric_namespace
      MAX_WORKERS              = var.classification_max_workers
      TRACKING_TABLE           = local.tracking_table_name
      SAGEMAKER_ENDPOINT_NAME  = local.sagemaker_endpoint_name
      CONFIGURATION_TABLE_NAME = local.configuration_table_name
      GUARDRAIL_ID_AND_VERSION = var.classification_guardrail != null ? "${var.classification_guardrail.guardrail_id}:${var.classification_guardrail.guardrail_version}" : ""
      LOG_LEVEL                = local.log_level
      WORKING_BUCKET           = local.working_bucket_name
      DOCUMENT_TRACKING_MODE   = local.api_id != null ? "appsync" : "dynamodb"
      APPSYNC_API_URL          = local.api_graphql_url != null ? local.api_graphql_url : ""
    }
  }

  dynamic "vpc_config" {
    for_each = length(local.vpc_subnet_ids) > 0 ? [1] : []
    content {
      subnet_ids         = local.vpc_subnet_ids
      security_group_ids = local.vpc_security_group_ids
    }
  }

  tracing_config { mode = var.lambda_tracing_mode }

  depends_on = [
    null_resource.trigger_udop_build,
    aws_iam_role_policy_attachment.classification_function_basic_execution,
    aws_cloudwatch_log_group.classification_function_logs,
  ]

  tags = local.common_tags
}

resource "aws_lambda_function" "extraction_function" {
  function_name = "${local.name_prefix}-sagemaker-udop-extraction"
  role          = aws_iam_role.extraction_function_role.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.udop_processor.repository_url}:extraction-function"
  architectures = ["arm64"]
  timeout       = 900
  memory_size   = 512
  kms_key_arn   = var.encryption_key_arn

  environment {
    variables = {
      EXTRACTION_MODEL_ID      = local.config_with_overrides.extraction.model
      CONFIGURATION_TABLE_NAME = local.configuration_table_name
      METRIC_NAMESPACE         = local.metric_namespace
      GUARDRAIL_ID_AND_VERSION = var.extraction_guardrail != null ? "${var.extraction_guardrail.guardrail_id}:${var.extraction_guardrail.guardrail_version}" : ""
      LOG_LEVEL                = local.log_level
      TRACKING_TABLE           = local.tracking_table_name
      WORKING_BUCKET           = local.working_bucket_name
      DOCUMENT_TRACKING_MODE   = local.api_id != null ? "appsync" : "dynamodb"
      APPSYNC_API_URL          = local.api_graphql_url != null ? local.api_graphql_url : ""
    }
  }

  dynamic "vpc_config" {
    for_each = length(local.vpc_subnet_ids) > 0 ? [1] : []
    content {
      subnet_ids         = local.vpc_subnet_ids
      security_group_ids = local.vpc_security_group_ids
    }
  }

  tracing_config { mode = var.lambda_tracing_mode }

  depends_on = [
    null_resource.trigger_udop_build,
    aws_iam_role_policy_attachment.extraction_function_basic_execution,
    aws_cloudwatch_log_group.extraction_function_logs,
  ]

  tags = local.common_tags
}

resource "aws_lambda_function" "process_results_function" {
  function_name = "${local.name_prefix}-sagemaker-udop-process-results"
  role          = aws_iam_role.process_results_function_role.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.udop_processor.repository_url}:processresults-function"
  architectures = ["arm64"]
  timeout       = 900
  memory_size   = 4096
  kms_key_arn   = var.encryption_key_arn

  environment {
    variables = {
      METRIC_NAMESPACE       = local.metric_namespace
      LOG_LEVEL              = local.log_level
      TRACKING_TABLE         = local.tracking_table_name
      WORKING_BUCKET         = local.working_bucket_name
      DOCUMENT_TRACKING_MODE = local.api_id != null ? "appsync" : "dynamodb"
      APPSYNC_API_URL        = local.api_graphql_url != null ? local.api_graphql_url : ""
    }
  }

  dynamic "vpc_config" {
    for_each = length(local.vpc_subnet_ids) > 0 ? [1] : []
    content {
      subnet_ids         = local.vpc_subnet_ids
      security_group_ids = local.vpc_security_group_ids
    }
  }

  tracing_config { mode = var.lambda_tracing_mode }

  depends_on = [
    null_resource.trigger_udop_build,
    aws_iam_role_policy_attachment.process_results_function_basic_execution,
    aws_cloudwatch_log_group.process_results_function_logs,
  ]

  tags = local.common_tags
}

resource "aws_lambda_function" "summarization_function" {
  function_name = "${local.name_prefix}-sagemaker-udop-summarization"
  role          = aws_iam_role.summarization_function_role.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.udop_processor.repository_url}:summarization-function"
  architectures = ["arm64"]
  timeout       = 900
  memory_size   = 4096
  kms_key_arn   = var.encryption_key_arn

  environment {
    variables = {
      METRIC_NAMESPACE         = local.metric_namespace
      CONFIGURATION_TABLE_NAME = local.configuration_table_name
      GUARDRAIL_ID_AND_VERSION = var.summarization_guardrail != null ? "${var.summarization_guardrail.guardrail_id}:${var.summarization_guardrail.guardrail_version}" : ""
      LOG_LEVEL                = local.log_level
      TRACKING_TABLE           = local.tracking_table_name
      WORKING_BUCKET           = local.working_bucket_name
      DOCUMENT_TRACKING_MODE   = local.api_id != null ? "appsync" : "dynamodb"
      APPSYNC_API_URL          = local.api_graphql_url != null ? local.api_graphql_url : ""
    }
  }

  dynamic "vpc_config" {
    for_each = length(local.vpc_subnet_ids) > 0 ? [1] : []
    content {
      subnet_ids         = local.vpc_subnet_ids
      security_group_ids = local.vpc_security_group_ids
    }
  }

  tracing_config { mode = var.lambda_tracing_mode }

  depends_on = [
    null_resource.trigger_udop_build,
    aws_iam_role_policy_attachment.summarization_function_basic_execution,
    aws_cloudwatch_log_group.summarization_function_logs,
  ]

  tags = local.common_tags
}

resource "aws_lambda_function" "assessment_function" {
  function_name = "${local.name_prefix}-assessment"
  role          = aws_iam_role.assessment_lambda.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.udop_processor.repository_url}:assessment-function"
  architectures = ["arm64"]
  timeout       = 900
  memory_size   = 512
  kms_key_arn   = var.encryption_key_arn

  environment {
    variables = {
      METRIC_NAMESPACE         = local.metric_namespace
      CONFIGURATION_TABLE_NAME = local.configuration_table_name
      LOG_LEVEL                = local.log_level
      WORKING_BUCKET           = local.working_bucket_name
      TRACKING_TABLE           = local.tracking_table_name
      DOCUMENT_TRACKING_MODE   = local.api_id != null ? "appsync" : "dynamodb"
      APPSYNC_API_URL          = local.api_graphql_url != null ? local.api_graphql_url : ""
    }
  }

  tracing_config { mode = var.lambda_tracing_mode }

  depends_on = [null_resource.trigger_udop_build]

  tags = local.common_tags
}

resource "aws_lambda_function" "evaluation_function" {
  function_name = "${var.name}-evaluation-function"
  role          = aws_iam_role.evaluation_function_role.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.udop_processor.repository_url}:evaluation-function"
  architectures = ["arm64"]
  timeout       = 900
  memory_size   = 1024
  kms_key_arn   = var.encryption_key_arn

  environment {
    variables = {
      LOG_LEVEL                    = local.log_level
      METRIC_NAMESPACE             = local.metric_namespace
      TRACKING_TABLE               = local.tracking_table_name
      CONFIGURATION_TABLE_NAME     = local.configuration_table_name
      WORKING_BUCKET               = local.working_bucket_name
      BASELINE_BUCKET              = var.evaluation_baseline_bucket_name
      REPORTING_BUCKET             = var.reporting_bucket_name
      SAVE_REPORTING_FUNCTION_NAME = var.save_reporting_function_name
      DOCUMENT_TRACKING_MODE       = local.api_id != null ? "appsync" : "dynamodb"
      APPSYNC_API_URL              = local.api_id != null ? coalesce(local.api_graphql_url, "") : ""
    }
  }

  dynamic "vpc_config" {
    for_each = length(local.vpc_subnet_ids) > 0 ? [1] : []
    content {
      subnet_ids         = local.vpc_subnet_ids
      security_group_ids = local.vpc_security_group_ids
    }
  }

  tracing_config { mode = var.lambda_tracing_mode }

  depends_on = [
    null_resource.trigger_udop_build,
    aws_iam_role_policy_attachment.evaluation_function_policy_attachment
  ]

  tags = local.common_tags
}

resource "null_resource" "create_module_build_dir" {
  provisioner "local-exec" {
    command = "mkdir -p ${local.module_build_dir}"
  }
}

resource "random_id" "build_id" {
  byte_length = 8
  keepers = {
    module_instance_id = local.module_instance_id
    content_hash       = md5("sagemaker-udop-processor-lambda")
  }
}

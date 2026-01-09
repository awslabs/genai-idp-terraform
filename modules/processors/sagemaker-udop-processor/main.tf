# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# SageMaker UDOP Processor
# This processor implements an intelligent document processing workflow that uses SageMaker 
# endpoints for document classification combined with Amazon Bedrock models for information extraction.

# Data sources
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

# Local values
locals {
  name_prefix = var.name

  input_bucket_arn        = var.input_bucket_arn != null ? var.input_bucket_arn : ""
  output_bucket_arn       = var.output_bucket_arn != null ? var.output_bucket_arn : ""
  working_bucket_arn      = var.working_bucket_arn != null ? var.working_bucket_arn : (var.output_bucket_arn != null ? var.output_bucket_arn : "")
  configuration_table_arn = var.configuration_table_arn != null ? var.configuration_table_arn : ""
  tracking_table_arn      = var.tracking_table_arn != null ? var.tracking_table_arn : ""
  api_graphql_url         = var.api_graphql_url
  api_id                  = var.api_id
  api_arn                 = var.api_arn
  encryption_key_arn      = var.encryption_key_arn
  metric_namespace        = var.metric_namespace
  log_level               = var.log_level
  log_retention_days      = var.log_retention_days
  vpc_subnet_ids          = var.vpc_subnet_ids
  vpc_security_group_ids  = var.vpc_security_group_ids

  # Extract resource names from ARNs
  # Format for S3 bucket ARN: arn:${data.aws_partition.current.partition}:s3:::bucket-name
  input_bucket_name   = element(split(":", local.input_bucket_arn), 5)
  output_bucket_name  = element(split(":", local.output_bucket_arn), 5)
  working_bucket_name = element(split(":", local.working_bucket_arn), 5)

  # Format for DynamoDB table ARN: arn:${data.aws_partition.current.partition}:dynamodb:region:account-id:table/table-name
  configuration_table_name = element(split("/", local.configuration_table_arn), 1)
  tracking_table_name      = element(split("/", local.tracking_table_arn), 1)

  # Extract KMS key ID from ARN if provided
  # Format for KMS key ARN: arn:${data.aws_partition.current.partition}:kms:region:account-id:key/key-id
  encryption_key_id = local.encryption_key_arn != null ? element(split("/", local.encryption_key_arn), 1) : null

  # Extract SageMaker endpoint name from ARN
  # Format for SageMaker endpoint ARN: arn:${data.aws_partition.current.partition}:sagemaker:region:account-id:endpoint/endpoint-name
  sagemaker_endpoint_name = element(split("/", var.classification_endpoint_arn), 1)

  # VPC configuration for Lambda functions
  vpc_config = length(var.vpc_subnet_ids) > 0 ? {
    subnet_ids         = var.vpc_subnet_ids
    security_group_ids = var.vpc_security_group_ids
  } : null

  # S3 bucket resources for IAM policies (handle null working bucket)
  s3_bucket_arns = concat(
    [local.input_bucket_arn, local.output_bucket_arn],
    local.working_bucket_arn != null ? [local.working_bucket_arn] : []
  )

  s3_bucket_object_arns = concat(
    ["${local.input_bucket_arn}/*", "${local.output_bucket_arn}/*"],
    local.working_bucket_arn != null ? ["${local.working_bucket_arn}/*"] : []
  )

  # Common tags
  common_tags = merge(var.tags, {
    Component = "SagemakerUdopProcessor"
  })
}

# Create the configuration components using the processor-configuration module
module "processor_configuration" {
  source = "../../processor-configuration"

  name_prefix              = var.name
  configuration_table_name = local.configuration_table_name
  encryption_key_arn       = var.encryption_key_arn

  # Use the config passed from parent module (from config_library YAML files)
  configuration = local.config_with_overrides
  schema        = jsondecode(file("${path.module}/schema.json"))

  vpc_config          = local.vpc_config
  lambda_tracing_mode = var.lambda_tracing_mode
  tags                = var.tags
}

# Configuration logic (moved from configuration/main.tf)
locals {
  # Use the config passed from parent module (from sources/config_library/)
  # If no config is provided, use defaults in the individual configurations below
  base_config = var.config

  # Apply model overrides if provided, similar to CDK transforms
  config_with_overrides = merge(
    local.base_config,
    # Only override extraction model if provided
    var.extraction_model_id != null ? {
      extraction = merge(
        try(local.base_config.extraction, {}),
        {
          model = var.extraction_model_id
        }
      )
    } : {},
    # Only override summarization model if provided
    var.summarization_model_id != null ? {
      summarization = merge(
        try(local.base_config.summarization, {}),
        {
          model = var.summarization_model_id
        }
      )
    } : {},
    # Only override evaluation model if provided
    var.evaluation_model_id != null ? {
      evaluation = merge(
        try(local.base_config.evaluation, {}),
        {
          model = var.evaluation_model_id
        }
      )
    } : {},
    # Only override assessment model if provided
    var.assessment_model_id != null ? {
      assessment = merge(
        try(local.base_config.assessment, {}),
        {
          model = var.assessment_model_id
        }
      )
    } : {},
    # Override classification settings
    {
      classification = merge(
        try(local.base_config.classification, {}),
        {
          model = merge(
            # Handle case where model might be a string in YAML - convert to object
            try(
              can(local.base_config.classification.model.endpoint_name) ? local.base_config.classification.model : { description = try(local.base_config.classification.model, "SageMaker UDOP endpoint") },
              { description = "SageMaker UDOP endpoint" }
            ),
            {
              endpoint_name = local.sagemaker_endpoint_name
            }
          )
        }
      )
    },
    # OCR settings - no overrides needed, use base config as-is
    # Note: ocr_max_workers is passed as environment variable to OCR Lambda function only
  )
}

# Create Step Functions state machine
resource "aws_sfn_state_machine" "document_processing" {
  name     = "${local.name_prefix}-sagemaker-udop-processor"
  role_arn = aws_iam_role.step_functions_role.arn

  definition = templatefile("${path.module}/../../../sources/patterns/pattern-3/statemachine/workflow.asl.json", {
    OCRFunctionArn            = aws_lambda_function.ocr_function.arn
    ClassificationFunctionArn = aws_lambda_function.classification_function.arn
    ExtractionFunctionArn     = aws_lambda_function.extraction_function.arn
    ProcessResultsLambdaArn   = aws_lambda_function.process_results_function.arn
    AssessmentFunctionArn     = aws_lambda_function.assessment_function.arn
    IsSummarizationEnabled    = var.summarization_model_id != null ? "true" : "false"
    SummarizationLambdaArn    = aws_lambda_function.summarization_function.arn
    OutputBucket              = local.output_bucket_name
  })

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.step_functions_logs.arn}:*"
    include_execution_data = true
    level                  = "ALL"
  }

  tracing_configuration {
    enabled = true
  }

  tags = local.common_tags
}

# CloudWatch Log Group for Step Functions
resource "aws_cloudwatch_log_group" "step_functions_logs" {
  name              = "/aws/vendedlogs/states/${local.name_prefix}-sagemaker-udop-processor"
  retention_in_days = local.log_retention_days
  kms_key_id        = local.encryption_key_arn

  tags = local.common_tags
}

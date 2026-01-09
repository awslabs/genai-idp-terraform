# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#

# Bedrock LLM Processor
# This processor implements an intelligent document processing workflow that uses Amazon Bedrock 
# with Nova or Claude models for both page classification/grouping and information extraction.
#
# Note: The deprecated nested 'processing_environment' variable has been removed.
# All resources now use flat variables directly, following Terraform best practices.

# Data sources
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

# Local values
locals {
  name_prefix = var.name

  # Use flat variables directly
  input_bucket_arn        = var.input_bucket_arn
  output_bucket_arn       = var.output_bucket_arn
  working_bucket_arn      = var.working_bucket_arn
  configuration_table_arn = var.configuration_table_arn
  tracking_table_arn      = var.tracking_table_arn
  concurrency_table_arn   = var.concurrency_table_arn
  metric_namespace        = var.metric_namespace
  log_level               = var.log_level
  log_retention_days      = var.log_retention_days
  encryption_key_arn      = var.encryption_key_arn
  vpc_subnet_ids          = var.vpc_subnet_ids
  vpc_security_group_ids  = var.vpc_security_group_ids
  api_id                  = var.api_id
  api_arn                 = var.api_arn
  api_graphql_url         = var.api_graphql_url

  # Extract resource names from ARNs
  # Format for S3 bucket ARN: arn:${data.aws_partition.current.partition}:s3:::bucket-name
  input_bucket_name   = element(split(":", local.input_bucket_arn), 5)
  output_bucket_name  = element(split(":", local.output_bucket_arn), 5)
  working_bucket_name = element(split(":", local.working_bucket_arn), 5)

  # DynamoDB table names (format: arn:${data.aws_partition.current.partition}:dynamodb:region:account:table/table-name)
  configuration_table_name = element(split("/", local.configuration_table_arn), 1)
  tracking_table_name      = element(split("/", local.tracking_table_arn), 1)
  concurrency_table_name   = element(split("/", local.concurrency_table_arn), 1)

  # S3 bucket resource lists for IAM policies
  s3_bucket_arns = [
    local.input_bucket_arn,
    local.output_bucket_arn,
    local.working_bucket_arn
  ]

  s3_object_arns = [
    "${local.input_bucket_arn}/*",
    "${local.output_bucket_arn}/*",
    "${local.working_bucket_arn}/*"
  ]

  # Extract KMS key ID from ARN if provided
  # Format for KMS key ARN: arn:${data.aws_partition.current.partition}:kms:region:account-id:key/key-id
  encryption_key_id = local.encryption_key_arn != null ? element(split("/", local.encryption_key_arn), 1) : null

  # Build directory and instance ID for Lambda functions
  module_build_dir   = "${path.module}/build"
  module_instance_id = "${var.name}-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.id}"

  # Common tags
  common_tags = merge(var.tags, {
    Component = "BedrockLlmProcessor"
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
  base_config = var.config

  # Apply model overrides if provided, similar to CDK transforms
  config_with_overrides = merge(
    local.base_config,
    # Only override classification model if provided
    var.classification_model_id != null ? {
      classification = merge(
        local.base_config.classification,
        {
          model = var.classification_model_id
        }
      )
    } : {},
    # Only override extraction model if provided
    var.extraction_model_id != null ? {
      extraction = merge(
        local.base_config.extraction,
        {
          model = var.extraction_model_id
        }
      )
    } : {},
    # Only override summarization model if provided
    var.summarization_model_id != null ? {
      summarization = merge(
        local.base_config.summarization,
        {
          model = var.summarization_model_id
        }
      )
    } : {},
    # Only override evaluation model if provided
    var.evaluation_model_id != null ? {
      evaluation = merge(
        local.base_config.evaluation,
        {
          llm_method = merge(
            local.base_config.evaluation.llm_method,
            {
              model = var.evaluation_model_id
            }
          )
        }
      )
    } : {},
    # Only override assessment model if provided
    var.assessment_model_id != null ? {
      assessment = merge(
        local.base_config.assessment,
        {
          model = var.assessment_model_id
        }
      )
    } : {}
  )

  # VPC config
  vpc_config = length(var.vpc_subnet_ids) > 0 ? {
    subnet_ids         = var.vpc_subnet_ids
    security_group_ids = var.vpc_security_group_ids
  } : null
}

# Step Functions State Machine
resource "aws_sfn_state_machine" "document_processing" {
  name     = "${local.name_prefix}-document-processing"
  role_arn = aws_iam_role.state_machine.arn

  definition = templatefile("${path.module}/../../../sources/patterns/pattern-2/statemachine/workflow.asl.json", {
    OCRFunctionArn              = aws_lambda_function.ocr.arn
    ClassificationFunctionArn   = aws_lambda_function.classification.arn
    ExtractionFunctionArn       = aws_lambda_function.extraction.arn
    ProcessResultsLambdaArn     = aws_lambda_function.process_results.arn
    AssessmentFunctionArn       = aws_lambda_function.assessment.arn
    SummarizationLambdaArn      = var.is_summarization_enabled ? aws_lambda_function.summarization[0].arn : "arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:function:nonexistent-function"
    IsSummarizationEnabled      = var.is_summarization_enabled ? "true" : "false"
    HITLWaitFunctionArn         = var.enable_hitl ? aws_lambda_function.hitl_wait[0].arn : "arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:function:nonexistent-hitl-wait-function"
    HITLStatusUpdateFunctionArn = var.enable_hitl ? aws_lambda_function.hitl_status_update[0].arn : "arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:function:nonexistent-hitl-status-function"
    EvaluationLambdaArn         = "arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:function:nonexistent-evaluation-function"
    OutputBucket                = local.output_bucket_name
  })

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.state_machine.arn}:*"
    include_execution_data = true
    level                  = "ALL"
  }

  tracing_configuration {
    enabled = true
  }

  tags = local.common_tags
}

# CloudWatch Log Group for State Machine
resource "aws_cloudwatch_log_group" "state_machine" {
  name              = "/aws/vendedlogs/states/${local.name_prefix}-document-processing"
  retention_in_days = local.log_retention_days
  kms_key_id        = local.encryption_key_arn

  tags = local.common_tags
}

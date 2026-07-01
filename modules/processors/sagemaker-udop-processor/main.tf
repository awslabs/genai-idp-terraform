# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#

# SageMaker-UDOP Processor (public façade) — Pattern 3 retained
#
# Mirrors the CDK accelerator's `SagemakerUdopProcessor` (verified against
# cdklabs/genai-idp@main): a thin public façade that creates NO SageMaker
# hosting/training resources of its own. The consumer supplies the SageMaker
# endpoint via `var.classification_endpoint_arn`.
#
# Classification runs through idp_common's native SageMaker backend
# (classify_page_sagemaker), which invokes the endpoint directly with the
# {input_image, input_textract} schema the UDOP model expects. The façade
# delegates all document processing to the shared internal engine
# (`modules/processors/unified-processor/`), routing down the non-BDA pipeline
# branch (`use_bda = false`) with classification_backend = "sagemaker".

data "aws_partition" "current" {}

locals {
  # Extract the working-bucket name from its ARN for S3 read scoping.
  working_bucket_arn  = var.working_bucket_arn != null ? var.working_bucket_arn : var.output_bucket_arn
  working_bucket_name = element(split(":", local.working_bucket_arn), 5)

  # Evaluation is enabled when a baseline bucket name is supplied.
  evaluation_enabled             = var.evaluation_baseline_bucket_name != ""
  evaluation_baseline_bucket_arn = local.evaluation_enabled ? "arn:${data.aws_partition.current.partition}:s3:::${var.evaluation_baseline_bucket_name}" : null

  common_tags = merge(var.tags, {
    Component = "SagemakerUdopProcessor"
  })
}

# =============================================================================
# Delegate document processing to the shared engine (non-BDA pipeline branch).
# =============================================================================

module "engine" {
  source = "../unified-processor"

  name = var.name

  # SageMaker-UDOP is the non-BDA pipeline branch with classification routed to
  # idp_common's native SageMaker backend.
  use_bda         = false
  bda_project_arn = null

  classification_backend                = "sagemaker"
  classification_sagemaker_endpoint_arn = var.classification_endpoint_arn

  # API wiring
  enable_api      = var.enable_api
  api_id          = var.api_id
  api_arn         = var.api_arn
  api_graphql_url = var.api_graphql_url

  # Shared environment ARNs
  input_bucket_arn        = var.input_bucket_arn
  output_bucket_arn       = var.output_bucket_arn
  working_bucket_arn      = local.working_bucket_arn
  configuration_table_arn = var.configuration_table_arn
  tracking_table_arn      = var.tracking_table_arn
  concurrency_table_arn   = var.concurrency_table_arn

  # Processing-environment configuration
  metric_namespace   = var.metric_namespace
  log_level          = var.log_level
  log_retention_days = var.log_retention_days

  # Encryption
  encryption_key_arn = var.encryption_key_arn

  # VPC configuration
  vpc_subnet_ids         = var.vpc_subnet_ids
  vpc_security_group_ids = var.vpc_security_group_ids

  # Lambda layers
  idp_common_layer_arn = var.idp_common_layer_arn
  base_layer_arn       = var.base_layer_arn
  evaluation_layer_arn = var.evaluation_layer_arn

  # Model configuration
  extraction_model_id        = var.extraction_model_id
  classification_max_workers = var.classification_max_workers
  ocr_max_workers            = var.ocr_max_workers

  # Evaluation (derived from the baseline bucket name supplied by the root)
  evaluation_enabled             = local.evaluation_enabled
  evaluation_baseline_bucket_arn = local.evaluation_baseline_bucket_arn
  evaluation_model_id            = var.evaluation_model_id

  # Summarization
  is_summarization_enabled = var.summarization_model_id != null
  summarization_model_id   = var.summarization_model_id

  # Concurrency
  max_processing_concurrency = var.max_processing_concurrency

  # Document processing configuration
  config = var.config

  # Extra non-active config versions seeded alongside the default
  additional_configurations = var.additional_configurations

  # Lambda tracing configuration
  lambda_tracing_mode = var.lambda_tracing_mode

  tags = var.tags
}

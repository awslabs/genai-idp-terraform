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
# (`modules/processors/unified-processor/`) with classification_backend =
# "sagemaker". The engine always deploys both the BDA branch and the pipeline
# branch and routes each document at runtime by its config version's `use_bda`
# flag; there is no deploy-time branch selector.

data "aws_partition" "current" {}

locals {
  # Extract the working-bucket name from its ARN for S3 read scoping.
  working_bucket_arn  = var.working_bucket_arn != null ? var.working_bucket_arn : var.output_bucket_arn
  working_bucket_name = element(split(":", local.working_bucket_arn), 5)

  # Evaluation is enabled when a baseline bucket name is supplied.
  evaluation_enabled             = var.evaluation_baseline_bucket_name != ""
  evaluation_baseline_bucket_arn = local.evaluation_enabled ? "arn:${data.aws_partition.current.partition}:s3:::${var.evaluation_baseline_bucket_name}" : null

  # Summarization enablement is config-authoritative: config value, falling back
  # to the upstream system default (base-summarization.yaml => true) the seeder
  # merges in when the config omits the section. A plain try(..., false) would
  # wrongly disable summarization for the sparse example configs.
  _default_summarization_enabled = try(yamldecode(file("${path.module}/../../../sources/lib/idp_common_pkg/idp_common/config/system_defaults/base-summarization.yaml")).summarization.enabled, false)
  is_summarization_enabled       = try(var.config.summarization.enabled, local._default_summarization_enabled)

  common_tags = merge(var.tags, {
    Component = "SagemakerUdopProcessor"
  })
}

# =============================================================================
# Delegate document processing to the shared engine. The engine always deploys
# both branches and routes per document at runtime; classification is routed to
# idp_common's native SageMaker backend.
# =============================================================================

module "engine" {
  source = "../unified-processor"

  allowed_bedrock_model_ids = var.allowed_bedrock_model_ids

  name = var.name

  # Lambda architecture (must match the idp_common layer build architecture).
  lambda_architecture = var.lambda_architecture

  # IDP v0.6 `ocr.backend: bda` support (deployment-scoped BDA OCR project).
  enable_bda_ocr_backend = var.enable_bda_ocr_backend

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

  # Model configuration (per-stage models come from the YAML config, not TF)
  classification_max_workers = var.classification_max_workers
  ocr_max_workers            = var.ocr_max_workers

  # Evaluation (derived from the baseline bucket name supplied by the root)
  evaluation_enabled             = local.evaluation_enabled
  evaluation_baseline_bucket_arn = local.evaluation_baseline_bucket_arn
  reporting_bucket_name          = var.reporting_bucket_name
  save_reporting_function_name   = var.save_reporting_function_name
  save_reporting_function_arn    = var.save_reporting_function_arn

  # Rule validation
  enable_rule_validation = var.enable_rule_validation

  # Summarization enablement is config-authoritative: config value, falling back
  # to the upstream system default (base-summarization.yaml => true) the seeder
  # merges in when the config omits the section (see local._default_summarization_enabled).
  is_summarization_enabled = local.is_summarization_enabled

  # Concurrency
  max_processing_concurrency = var.max_processing_concurrency

  # Document processing configuration
  config = var.config

  # Extra non-active config versions seeded alongside the default
  additional_configurations = var.additional_configurations
  seed_managed_configs      = var.seed_managed_configs

  # Optional fallback BDA project for use_bda:true additional versions; does not
  # relink the default (stays pipeline).
  bda_project_arn = var.bda_project_arn

  # Lambda tracing configuration
  lambda_tracing_mode = var.lambda_tracing_mode

  tags = var.tags
}

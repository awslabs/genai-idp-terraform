# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#

# Bedrock-LLM Processor (public façade)
#
# Mirrors the CDK accelerator's `BedrockLlmProcessor` (verified against
# cdklabs/genai-idp@main): a thin public façade that creates NO Bedrock Data
# Automation (BDA) resources and NO document-processing engine resources of its
# own. It delegates ALL document processing to the shared internal engine
# (`modules/processors/unified-processor/`) via a nested `module "engine"`. The
# engine always deploys both the BDA branch and the step-by-step pipeline
# branch; documents are routed at runtime by their config version's `use_bda`
# flag, so a Bedrock-LLM deployment processes `use_bda: false` versions through
# the pipeline branch by default while still being able to route BDA-linked
# versions to the BDA branch.
#
# The façade owns no document-processing resources of its own; that all lives in
# the shared engine (`module.engine.*`).

module "engine" {
  source = "../unified-processor"

  # The engine resources adopt the façade's name.
  name = var.name

  # Lambda architecture (must match the idp_common layer build architecture).
  lambda_architecture = var.lambda_architecture

  # API wiring
  enable_api      = var.enable_api
  api_id          = var.api_id
  api_arn         = var.api_arn
  api_graphql_url = var.api_graphql_url

  # Shared environment ARNs
  input_bucket_arn        = var.input_bucket_arn
  output_bucket_arn       = var.output_bucket_arn
  working_bucket_arn      = var.working_bucket_arn
  configuration_table_arn = var.configuration_table_arn
  tracking_table_arn      = var.tracking_table_arn
  concurrency_table_arn   = var.concurrency_table_arn

  # Processing-environment configuration
  metric_namespace   = var.metric_namespace
  log_level          = var.log_level
  log_retention_days = var.log_retention_days

  # Encryption
  encryption_key_arn = var.encryption_key_arn
  enable_encryption  = var.enable_encryption

  # VPC configuration
  vpc_subnet_ids         = var.vpc_subnet_ids
  vpc_security_group_ids = var.vpc_security_group_ids

  # Lambda layers
  idp_common_layer_arn = var.idp_common_layer_arn
  base_layer_arn       = var.base_layer_arn
  evaluation_layer_arn = var.evaluation_layer_arn

  # Rule validation
  enable_rule_validation = var.enable_rule_validation

  # Lambda hook inference (v0.4.15+)
  lambda_hook_ocr            = var.lambda_hook_ocr
  lambda_hook_classification = var.lambda_hook_classification
  lambda_hook_extraction     = var.lambda_hook_extraction
  lambda_hook_assessment     = var.lambda_hook_assessment
  lambda_hook_summarization  = var.lambda_hook_summarization
  enable_hook_inference = length(compact([
    var.lambda_hook_ocr,
    var.lambda_hook_classification,
    var.lambda_hook_extraction,
    var.lambda_hook_assessment,
    var.lambda_hook_summarization,
  ])) > 0

  # Model configuration
  model_id                     = var.model_id
  classification_model_id      = var.classification_model_id
  classification_max_workers   = var.classification_max_workers
  max_pages_for_classification = var.max_pages_for_classification
  classification_guardrail     = var.classification_guardrail
  extraction_model_id          = var.extraction_model_id
  extraction_guardrail         = var.extraction_guardrail
  ocr_max_workers              = var.ocr_max_workers
  assessment_model_id          = var.assessment_model_id
  assessment_guardrail         = var.assessment_guardrail

  # Section splitting / agentic extraction
  section_splitting_strategy = var.section_splitting_strategy
  enable_agentic_extraction  = var.enable_agentic_extraction
  review_agent_model         = var.review_agent_model

  # Evaluation
  evaluation_enabled             = var.evaluation_enabled
  evaluation_baseline_bucket_arn = var.evaluation_baseline_bucket_arn
  evaluation_model_id            = var.evaluation_model_id

  # Summarization
  is_summarization_enabled = var.is_summarization_enabled
  summarization_model_id   = var.summarization_model_id
  summarization_guardrail  = var.summarization_guardrail

  # Concurrency
  max_processing_concurrency = var.max_processing_concurrency

  # HITL
  enable_hitl = var.enable_hitl

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

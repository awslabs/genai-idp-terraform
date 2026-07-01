# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
/**
 * # BDA Processor (thin public façade)
 *
 * This module is the public BDA processor façade. It mirrors the CDK
 * accelerator's `BdaProcessor` package (verified against
 * `cdklabs/genai-idp@main`): a thin façade that performs only the
 * BDA-specific, pattern-specific setup and delegates ALL document processing to
 * the shared internal engine (`modules/processors/unified-processor/`) via a
 * nested `module "engine"` with `use_bda = true`.
 *
 * Pattern-specific (BDA-only) concern handled here:
 *   * The Bedrock Data Automation Project ARN that the BDA branch invokes. In
 *     this Terraform wrapper the project is **consumer-supplied** through the
 *     required `var.data_automation_project_arn` (root: `var.bda_processor.project_arn`)
 *     rather than synthesized from config classes. This is a deliberate
 *     divergence from the CDK `BdaProcessor`, which builds Blueprints + a
 *     `DataAutomationProject` at synth time (CDK uses a CFN custom resource that
 *     has no native Terraform-provider equivalent). The public input surface is
 *     preserved so the root `module.bda_processor` call still type-checks. The
 *     ARN is forwarded to the engine as `bda_project_arn`; the engine's
 *     `use_bda = true` branch grants `bedrock:InvokeDataAutomationAsync` and runs
 *     the BDA invoke / completion / process-results Lambdas + state machine.
 *
 * Everything else (Lambdas, Step Functions state machine, IAM, SQS DLQs,
 * CloudWatch log groups, config seeding) is owned by the shared engine. The
 * former monolithic implementation (its own ECR + CodeBuild image pipeline,
 * pattern-1 `archive_file`/`templatefile`/`file()` references, per-function IAM,
 * and state machine) has been removed.
 */

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

# Parse the consumer-supplied Data Automation Project ARN so the module can
# expose the project id as an output. `aws_arn` does not validate existence; it
# only decomposes the ARN string at plan time.
data "aws_arn" "data_automation_project" {
  arn = var.data_automation_project_arn
}

locals {
  # Bedrock Data Automation project id, parsed from
  # "data-automation-project/<id>".
  project_id = element(split("/", data.aws_arn.data_automation_project.resource), 1)

  # Summarization is enabled when the consumer overrides the model OR the
  # supplied document config carries a summarization section. Mirrors the
  # former monolith's behaviour without reading any deleted pattern-1 config.
  is_summarization_enabled = var.summarization_model_id != null || try(var.config.summarization.model, null) != null

  # Evaluation is enabled when a baseline bucket name is supplied by the root.
  evaluation_enabled = var.evaluation_baseline_bucket_name != ""

  # Reconstruct the baseline bucket ARN expected by the engine from the bucket
  # name the root passes (S3 ARNs are partition-scoped, account-agnostic).
  evaluation_baseline_bucket_arn = local.evaluation_enabled ? "arn:${data.aws_partition.current.partition}:s3:::${var.evaluation_baseline_bucket_name}" : null
}

# =============================================================================
# Shared internal engine (unified-processor)
# =============================================================================
# Delegates ALL document processing to the shared engine with use_bda = true.
module "engine" {
  source = "../unified-processor"

  name = var.name

  # Façade ↔ engine delegation: BDA branch.
  use_bda         = true
  bda_project_arn = var.data_automation_project_arn

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

  # Processing environment configuration
  metric_namespace   = var.metric_namespace
  log_level          = var.log_level
  log_retention_days = var.log_retention_days

  # Encryption
  encryption_key_arn = var.encryption_key_arn
  enable_encryption  = var.enable_encryption

  # Layers
  idp_common_layer_arn = var.idp_common_layer_arn
  base_layer_arn       = var.base_layer_arn
  evaluation_layer_arn = var.evaluation_layer_arn

  # VPC configuration
  vpc_subnet_ids         = var.vpc_subnet_ids
  vpc_security_group_ids = var.vpc_security_group_ids

  # Summarization
  is_summarization_enabled = local.is_summarization_enabled
  summarization_model_id   = var.summarization_model_id
  summarization_guardrail  = var.summarization_guardrail

  # Evaluation
  evaluation_enabled             = local.evaluation_enabled
  evaluation_model_id            = var.evaluation_model_id
  evaluation_baseline_bucket_arn = local.evaluation_baseline_bucket_arn

  # Document processing configuration
  config                     = var.config
  max_processing_concurrency = var.max_processing_concurrency

  # Extra non-active config versions seeded alongside the default
  additional_configurations = var.additional_configurations

  # Lambda tracing configuration
  lambda_tracing_mode = var.lambda_tracing_mode

  tags = var.tags
}

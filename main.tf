# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
/**
 * # GenAI IDP Accelerator - Complete Deployment Module
 *
 * This module provides a one-stop solution for deploying an end-to-end GenAI Intelligent Document Processing (IDP) 
 * pipeline. It connects to your existing AWS resources (S3 buckets, KMS keys) and creates the processing infrastructure
 * including user identity management, processing environment, API, web UI, and the selected document processor.
 *
 * ## Features
 * - **Bring Your Own Resources**: Connect to existing S3 buckets and KMS keys
 * - **Configurable Processor**: Choose from BDA, Bedrock LLM, or SageMaker UDOP processors
 * - **Optional API**: Enable GraphQL API for programmatic access and notifications
 * - **Optional Web UI**: Enable web-based user interface for document management
 * - **Comprehensive Security**: Uses your KMS keys, IAM roles, and Cognito authentication
 * - **Monitoring & Logging**: CloudWatch logs, metrics, and optional reporting
 * - **Evaluation Support**: Optional baseline comparison and model evaluation
 *
 * ## Architecture
 * The module creates a complete document processing pipeline that connects to:
 * - Your existing S3 buckets for input, output, working, and optional logging/evaluation/reporting
 * - Your existing KMS key for encryption
 * - Processing environment with Step Functions orchestration
 * - Configurable document processor (BDA/Bedrock LLM/SageMaker UDOP)
 * - Optional GraphQL API with Cognito authentication
 * - Optional React-based web UI with CloudFront distribution
 * - Comprehensive IAM permissions and security controls
 */

# Validation: Web UI requires user_identity to be provided
#tfsec:ignore:*
check "web_ui_requires_user_identity" {
  assert {
    condition     = !var.web_ui.enabled || var.user_identity != null
    error_message = "When web_ui.enabled is true, user_identity must be provided for authentication."
  }
}

# Validation: Web UI requires API to be enabled
#tfsec:ignore:*
check "web_ui_requires_api" {
  assert {
    condition     = !var.web_ui.enabled || local.api_enabled
    error_message = "When web_ui.enabled is true, api.enabled must also be true. The Web UI requires the GraphQL API to function properly."
  }
}

# Validation: Exactly one processor must be configured
#tfsec:ignore:*
check "single_processor_required" {
  assert {
    condition = length([
      for p in [var.bedrock_llm_processor, var.bda_processor, var.sagemaker_udop_processor] : p if p != null
    ]) == 1
    error_message = "Exactly one processor must be configured (bedrock_llm_processor, bda_processor, or sagemaker_udop_processor)."
  }
}

# Note: Validation checks for computed values (bucket ARNs, encryption key ARN, etc.) 
# have been removed to eliminate "known after apply" warnings. These validations
# are still enforced by Terraform's resource dependencies and will fail at apply
# time if the required resources don't exist.

# Validation: Web UI logging bucket requirement
#tfsec:ignore:*
check "web_ui_logging_bucket" {
  assert {
    condition     = !var.web_ui.logging_enabled || var.web_ui.logging_bucket_arn != null
    error_message = "web_ui.logging_bucket_arn is required when web_ui.logging_enabled is true."
  }
}

# Validation: BDA processor project ARN requirement (only for static values)
# Note: Removed check for computed project_arn to eliminate warnings

# Validation: SageMaker UDOP processor endpoint ARN requirement
#tfsec:ignore:*
check "sagemaker_processor_endpoint_arn" {
  assert {
    condition     = var.sagemaker_udop_processor != null ? var.sagemaker_udop_processor.classification_endpoint_arn != null : true
    error_message = "classification_endpoint_arn is required in sagemaker_udop_processor configuration."
  }
}

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = ">= 0.70.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.1"
    }
  }
}

# Get current AWS account ID and caller identity
data "aws_caller_identity" "current" {}

# Get current AWS partition for cross-partition compatibility
data "aws_partition" "current" {}

# Create a random string for unique resource names
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Validate processor type and required parameters
# See locals.tf for validation logic

#
# Shared Assets Bucket
# Create a single S3 bucket for all application asset storage to reduce resource count
# Supports Lambda layers, UI assets, and other deployment artifacts
#
module "assets_bucket" {
  source = "./modules/assets-bucket"

  bucket_prefix = local.name_prefix

  # Enable lifecycle management for cost optimization
  enable_lifecycle_management = true
  asset_retention_days        = 90 # Keep assets for 90 days
  old_version_retention_days  = 30 # Keep old versions for 30 days

  tags = var.tags
}

#
# IDP Common Layer
#
module "idp_common_layer" {
  source = "./modules/idp-common-layer"

  layer_prefix             = "${local.name_prefix}-idp-layer"
  lambda_layers_bucket_arn = module.assets_bucket.bucket_arn
  idp_common_extras        = local.idp_common_layer_extras
  force_rebuild            = var.force_rebuild_layers
  lambda_tracing_mode      = var.lambda_tracing_mode
}

#
# User Identity (Cognito) - Only create if needed and not provided externally
#
module "user_identity" {
  count  = (local.api_enabled || var.web_ui.enabled) && var.user_identity == null ? 1 : 0
  source = "./modules/user-identity"

  name_prefix                 = "${local.name_prefix}-user-identity"
  allowed_signup_email_domain = var.web_ui.enable_signup
  deletion_protection         = var.deletion_protection

  tags = var.tags
}

# Human Review Environment (Optional)
module "human_review" {
  count  = var.human_review.enabled ? 1 : 0
  source = "./modules/human-review"

  name_prefix       = "${local.name_prefix}-human-review"
  user_pool_id      = var.human_review.user_pool_id
  output_bucket_arn = var.output_bucket_arn

  # Use externally created workforce and workteam
  private_workforce_arn = var.human_review.private_workforce_arn
  workteam_name         = var.human_review.workteam_name

  # Configuration
  log_level          = var.log_level
  log_retention_days = var.log_retention_days
  encryption_key_arn = var.encryption_key_arn

  # VPC configuration
  vpc_subnet_ids         = var.vpc_subnet_ids
  vpc_security_group_ids = var.vpc_security_group_ids

  # Lambda layer
  idp_common_layer_arn = module.idp_common_layer.layer_arn

  # Lambda tracing configuration
  lambda_tracing_mode = var.lambda_tracing_mode

  # Stack name for A2I resources
  stack_name = local.name_prefix

  # Pattern-2 HITL configuration
  enable_pattern2_hitl      = var.human_review.enable_pattern2_hitl
  hitl_confidence_threshold = var.human_review.hitl_confidence_threshold

  # Pattern-2 HITL dependencies (only needed when Pattern-2 HITL is enabled)
  tracking_table_name = module.processing_environment.tracking_table_name
  tracking_table_arn  = module.processing_environment.tracking_table_arn
  working_bucket_name = local.working_bucket_name
  working_bucket_arn  = var.working_bucket_arn
  state_machine_arn   = var.bedrock_llm_processor != null ? try(module.bedrock_llm_processor[0].state_machine_arn, "") : ""

  tags = var.tags
}

#
# Processing Environment
#
module "processing_environment" {
  source = "./modules/processing-environment"

  # Shared assets bucket for Lambda layers
  lambda_layers_bucket_arn = module.assets_bucket.bucket_arn

  metric_namespace = "${local.name_prefix}-metrics"

  # S3 bucket ARNs
  input_bucket_arn   = var.input_bucket_arn
  output_bucket_arn  = var.output_bucket_arn
  working_bucket_arn = var.working_bucket_arn

  # Encryption key
  encryption_key_arn = var.encryption_key_arn
  enable_encryption  = var.enable_encryption

  # Lambda layer
  idp_common_layer_arn = module.idp_common_layer.layer_arn

  # Optional: Evaluation configuration
  evaluation_config = var.evaluation.enabled ? {
    baseline_bucket_arn  = var.evaluation.baseline_bucket_arn
    evaluation_model_arn = "arn:${data.aws_partition.current.partition}:bedrock:${var.region}::foundation-model/${var.evaluation.model_id}"
  } : null

  # Optional: API configuration for UI updates
  api = local.api_enabled ? {
    api_id           = module.processing_environment_api[0].api_id
    api_name         = module.processing_environment_api[0].api_name
    api_arn          = module.processing_environment_api[0].api_arn
    graphql_url      = module.processing_environment_api[0].graphql_url
    realtime_url     = module.processing_environment_api[0].realtime_url
    api_key          = module.processing_environment_api[0].api_key
    lambda_functions = module.processing_environment_api[0].lambda_functions
  } : null

  # Configuration
  log_level                    = var.log_level
  log_retention_days           = var.log_retention_days
  data_tracking_retention_days = var.data_tracking_retention_days

  # VPC configuration
  subnet_ids         = var.vpc_subnet_ids
  security_group_ids = var.vpc_security_group_ids

  # Lambda tracing configuration
  lambda_tracing_mode = var.lambda_tracing_mode

  tags = var.tags
}

#
# GraphQL API (Optional)
#
module "processing_environment_api" {
  count  = local.api_enabled ? 1 : 0
  source = "./modules/processing-environment-api"

  name = "${local.name_prefix}-api"

  # User identity - Dynamic authorization based on user_identity availability
  authorization_config = {
    default_authorization = {
      authorization_type = var.user_identity != null || length(module.user_identity) > 0 ? "AMAZON_COGNITO_USER_POOLS" : "AWS_IAM"
      user_pool_config = var.user_identity != null || length(module.user_identity) > 0 ? {
        user_pool_id = local.user_pool_id
      } : null
    }
    additional_authorization_modes = var.user_identity != null || length(module.user_identity) > 0 ? [
      {
        authorization_type = "AWS_IAM"
      }
    ] : []
  }

  # Processing environment
  environment_variables = {
    TRACKING_TABLE_NAME      = module.processing_environment.tracking_table_name
    CONFIGURATION_TABLE_NAME = module.processing_environment.configuration_table_name
    INPUT_BUCKET_NAME        = local.input_bucket_name
    OUTPUT_BUCKET_NAME       = local.output_bucket_name
    ENCRYPTION_KEY_ID        = element(split("/", var.encryption_key_arn), 1)
    IDP_COMMON_LAYER_ARN     = module.idp_common_layer.layer_arn
  }

  # DynamoDB tables
  tracking_table_arn      = module.processing_environment.tracking_table_arn
  configuration_table_arn = module.processing_environment.configuration_table_arn

  # S3 bucket ARNs
  input_bucket_arn   = var.input_bucket_arn
  output_bucket_arn  = var.output_bucket_arn
  working_bucket_arn = var.working_bucket_arn

  # Optional: Evaluation baseline bucket
  evaluation_enabled             = var.evaluation.enabled
  evaluation_baseline_bucket_arn = var.evaluation.enabled ? var.evaluation.baseline_bucket_arn : null

  # Knowledge Base configuration
  knowledge_base = local.knowledge_base_config

  # Encryption key
  encryption_key_arn = var.encryption_key_arn

  # VPC configuration
  vpc_config = length(var.vpc_subnet_ids) > 0 ? {
    subnet_ids         = var.vpc_subnet_ids
    security_group_ids = var.vpc_security_group_ids
  } : null

  # Lambda tracing configuration
  lambda_tracing_mode = var.lambda_tracing_mode

  # Agent Analytics configuration
  agent_analytics = local.agent_analytics_config.enabled && var.reporting.enabled ? {
    enabled                 = true
    model_id                = local.agent_analytics_config.model_id
    reporting_database_name = var.reporting.database_name
    reporting_bucket_arn    = var.reporting.bucket_arn
  } : { enabled = false }

  # Discovery configuration
  discovery = local.discovery_config.enabled ? {
    enabled = true
  } : { enabled = false }

  # Chat with Document configuration
  chat_with_document = local.chat_with_document_config.enabled ? {
    enabled                  = true
    guardrail_id_and_version = local.chat_with_document_config.guardrail_id_and_version
  } : { enabled = false }

  # Process Changes configuration (Edit Sections feature)
  enable_edit_sections = local.process_changes_config.enabled
  document_queue_url   = local.process_changes_config.enabled ? module.processing_environment.document_queue_url : null
  document_queue_arn   = local.process_changes_config.enabled ? module.processing_environment.document_queue_arn : null

  # IDP Common Layer ARN for sub-modules
  idp_common_layer_arn     = module.idp_common_layer.layer_arn
  lambda_layers_bucket_arn = module.assets_bucket.bucket_arn

  tags = var.tags
}

#
# Document Processor
#

# BDA Processor
module "bda_processor" {
  source = "./modules/processors/bda-processor"
  count  = var.bda_processor != null ? 1 : 0

  name = "${local.name_prefix}-processor"

  # Shared assets bucket for Lambda layers
  lambda_layers_bucket_arn = module.assets_bucket.bucket_arn

  # API configuration (if enabled)
  api_id          = local.api_enabled ? module.processing_environment_api[0].api_id : null
  api_arn         = local.api_enabled ? module.processing_environment_api[0].api_arn : null
  api_graphql_url = local.api_enabled ? module.processing_environment_api[0].graphql_url : null

  # S3 bucket ARNs
  input_bucket_arn        = var.input_bucket_arn
  output_bucket_arn       = var.output_bucket_arn
  working_bucket_arn      = var.working_bucket_arn
  tracking_table_arn      = module.processing_environment.tracking_table_arn
  configuration_table_arn = module.processing_environment.configuration_table_arn
  concurrency_table_arn   = module.processing_environment.concurrency_table_arn

  # Processing environment configuration
  metric_namespace   = module.processing_environment.metric_namespace
  log_level          = module.processing_environment.log_level
  log_retention_days = module.processing_environment.log_retention_days

  encryption_key_arn   = var.encryption_key_arn
  idp_common_layer_arn = module.idp_common_layer.layer_arn

  # VPC configuration
  vpc_subnet_ids         = var.vpc_subnet_ids
  vpc_security_group_ids = var.vpc_security_group_ids

  # BDA-specific configurations
  data_automation_project_arn = var.bda_processor.project_arn

  # Optional: Evaluation configuration
  evaluation_model_id = var.evaluation.enabled ? var.evaluation.model_id : null

  # Optional: Summarization configuration (BDA only)
  summarization_model_id = var.bda_processor.summarization.enabled ? var.bda_processor.summarization.model_id : null

  # Optional: Document processing configuration
  config = var.bda_processor.config

  # Human Review configuration
  sagemaker_a2i_review_portal_url = var.human_review.enabled ? module.human_review[0].workforce_portal_url_parameter : null
  hitl_workteam_arn               = var.human_review.enabled ? module.human_review[0].workteam_arn : null

  # Lambda tracing configuration
  lambda_tracing_mode = var.lambda_tracing_mode

  tags = var.tags
}

# Bedrock LLM Processor
module "bedrock_llm_processor" {
  source = "./modules/processors/bedrock-llm-processor"
  count  = var.bedrock_llm_processor != null ? 1 : 0

  name = "${local.name_prefix}-processor"

  # API configuration (if enabled)
  enable_api      = local.api_enabled
  api_id          = local.api_enabled ? module.processing_environment_api[0].api_id : null
  api_arn         = local.api_enabled ? module.processing_environment_api[0].api_arn : null
  api_graphql_url = local.api_enabled ? module.processing_environment_api[0].graphql_url : null

  # S3 bucket ARNs
  input_bucket_arn        = var.input_bucket_arn
  output_bucket_arn       = var.output_bucket_arn
  working_bucket_arn      = var.working_bucket_arn
  tracking_table_arn      = module.processing_environment.tracking_table_arn
  configuration_table_arn = module.processing_environment.configuration_table_arn
  concurrency_table_arn   = module.processing_environment.concurrency_table_arn

  # Processing environment configuration
  metric_namespace   = module.processing_environment.metric_namespace
  log_level          = module.processing_environment.log_level
  log_retention_days = module.processing_environment.log_retention_days

  encryption_key_arn   = var.encryption_key_arn
  idp_common_layer_arn = module.idp_common_layer.layer_arn

  # VPC configuration
  vpc_subnet_ids         = var.vpc_subnet_ids
  vpc_security_group_ids = var.vpc_security_group_ids

  # Model configurations - pass model IDs directly for optional override
  # The processor will use config.yaml by default and override with these if provided
  classification_model_id      = var.bedrock_llm_processor.classification_model_id
  extraction_model_id          = var.bedrock_llm_processor.extraction_model_id
  evaluation_model_id          = var.evaluation.enabled ? var.evaluation.model_id : null
  max_pages_for_classification = var.bedrock_llm_processor.max_pages_for_classification



  # Optional: Document processing configuration
  config = var.bedrock_llm_processor.config

  # Feature flags
  is_summarization_enabled = var.bedrock_llm_processor.summarization.enabled
  enable_hitl              = var.bedrock_llm_processor.enable_hitl

  # Optional: Summarization model configuration
  summarization_model_id = var.bedrock_llm_processor.summarization.enabled ? var.bedrock_llm_processor.summarization.model_id : null

  # Lambda tracing configuration
  lambda_tracing_mode = var.lambda_tracing_mode

  tags = var.tags
}

# SageMaker UDOP Processor
module "sagemaker_udop_processor" {
  source = "./modules/processors/sagemaker-udop-processor"
  count  = var.sagemaker_udop_processor != null ? 1 : 0

  name = "${local.name_prefix}-processor"

  # API configuration (if enabled)
  enable_api      = local.api_enabled
  api_id          = local.api_enabled ? module.processing_environment_api[0].api_id : null
  api_arn         = local.api_enabled ? module.processing_environment_api[0].api_arn : null
  api_graphql_url = local.api_enabled ? module.processing_environment_api[0].graphql_url : null

  # S3 bucket ARNs
  input_bucket_arn        = var.input_bucket_arn
  output_bucket_arn       = var.output_bucket_arn
  working_bucket_arn      = var.working_bucket_arn
  tracking_table_arn      = module.processing_environment.tracking_table_arn
  configuration_table_arn = module.processing_environment.configuration_table_arn

  # Processing environment configuration
  metric_namespace   = module.processing_environment.metric_namespace
  log_level          = module.processing_environment.log_level
  log_retention_days = module.processing_environment.log_retention_days

  encryption_key_arn   = var.encryption_key_arn
  idp_common_layer_arn = module.idp_common_layer.layer_arn

  # VPC configuration
  vpc_subnet_ids         = var.vpc_subnet_ids
  vpc_security_group_ids = var.vpc_security_group_ids

  # SageMaker UDOP processor configuration
  classification_endpoint_arn = var.sagemaker_udop_processor.classification_endpoint_arn

  # Optional: Performance configuration
  ocr_max_workers            = var.sagemaker_udop_processor.ocr_max_workers
  classification_max_workers = var.sagemaker_udop_processor.classification_max_workers

  # Optional: Model configurations
  extraction_model_id    = null # Will use default from module
  summarization_model_id = var.sagemaker_udop_processor.summarization.enabled ? var.sagemaker_udop_processor.summarization.model_id : null
  evaluation_model_id    = var.evaluation.enabled ? var.evaluation.model_id : null

  # Feature flags

  # Optional: Document processing configuration
  config = var.sagemaker_udop_processor.config

  # Lambda tracing configuration
  lambda_tracing_mode = var.lambda_tracing_mode

  tags = var.tags
}

#
# Web UI (Optional)
#
module "web_ui" {
  count  = var.web_ui.enabled ? 1 : 0
  source = "./modules/web-ui"

  name_prefix  = "${local.name_prefix}-web-ui"
  prefix       = var.prefix
  display_name = var.web_ui.display_name != null ? var.web_ui.display_name : local.name_prefix

  # User identity
  user_identity = {
    user_pool = {
      user_pool_id  = local.user_pool_id
      user_pool_arn = local.user_pool_arn
      endpoint      = "https://cognito-idp.${var.region}.amazonaws.com/${local.user_pool_id}"
    }
    user_pool_client = {
      user_pool_client_id = local.user_pool_client_id
    }
    identity_pool = {
      identity_pool_id       = local.identity_pool_id
      authenticated_role_arn = local.authenticated_role_arn
    }
  }

  # API configuration (if enabled)
  api_url = local.api_enabled ? module.processing_environment_api[0].graphql_url : null

  # S3 bucket ARNs
  input_bucket_arn  = var.input_bucket_arn
  output_bucket_arn = var.output_bucket_arn

  # Optional: Logging bucket for CloudFront and S3 access logs
  logging_bucket = var.web_ui.logging_enabled ? {
    bucket_name = local.logging_bucket_name
    bucket_arn  = var.web_ui.logging_bucket_arn
  } : null

  # Reporting bucket name (extracted from ARN)
  reporting_bucket_name = local.web_ui_reporting_bucket_name

  # Evaluation baseline bucket name (extracted from ARN)
  evaluation_baseline_bucket_name = local.web_ui_evaluation_bucket_name

  # Discovery bucket name (if discovery is enabled)
  discovery_bucket_name = local.discovery_config.enabled && local.api_enabled ? module.processing_environment_api[0].discovery_bucket_name : null

  # Knowledge Base enabled flag
  knowledge_base_enabled = local.knowledge_base_config.enabled

  # IDP Pattern mapping (processor type to CloudFormation pattern names)
  idp_pattern = local.idp_pattern_mapping[local.processor_type]

  # Web UI configuration
  create_infrastructure             = var.web_ui.create_infrastructure
  web_app_bucket_name               = var.web_ui.bucket_name
  cloudfront_distribution_id        = var.web_ui.cloudfront_distribution_id
  should_allow_sign_up_email_domain = var.web_ui.enable_signup != ""

  # Encryption key
  encryption_key_arn = var.encryption_key_arn

  # Lambda tracing configuration
  lambda_tracing_mode = var.lambda_tracing_mode

  tags = var.tags
}

#
# IAM Permissions for Authenticated Users (when API/UI enabled)
# See locals.tf for IAM statement definitions
#

resource "aws_iam_role_policy" "authenticated_user_permissions" {
  for_each = local.enable_authenticated_user_permissions ? toset(["enabled"]) : toset([])
  name     = "${local.name_prefix}-authenticated-user-permissions"
  role     = basename(local.authenticated_role_arn)

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      local.base_authenticated_statements,
      local.api_statements,
      local.web_ui_statements,
      local.evaluation_statements,
      local.human_review_sagemaker_statement,
      local.human_review_ssm_statement,
      local.human_review_a2i_statement,
      local.processing_environment_api_statements
    )
  })
}

#
# Reporting (Optional)
#
module "reporting" {
  count  = var.reporting.enabled ? 1 : 0
  source = "./modules/reporting"

  name_prefix             = "${local.name_prefix}-reporting"
  reporting_database_name = var.reporting.database_name
  reporting_bucket_arn    = var.reporting.bucket_arn
  output_bucket_arn       = var.output_bucket_arn
  output_bucket_name      = local.output_bucket_name

  # Configuration table
  configuration_table_arn  = module.processing_environment.configuration_table_arn
  configuration_table_name = module.processing_environment.configuration_table_name

  # Configuration
  metric_namespace   = module.processing_environment.metric_namespace
  log_level          = var.log_level
  log_retention_days = var.log_retention_days
  encryption_key_arn = var.encryption_key_arn
  enable_encryption  = var.enable_encryption

  # Glue crawler configuration
  crawler_schedule            = var.reporting.crawler_schedule
  enable_partition_projection = var.reporting.enable_partition_projection

  # VPC configuration
  vpc_subnet_ids         = var.vpc_subnet_ids
  vpc_security_group_ids = var.vpc_security_group_ids

  # Lambda layer
  idp_common_layer_arn = module.idp_common_layer.layer_arn

  # Lambda tracing configuration
  lambda_tracing_mode = var.lambda_tracing_mode

  tags = var.tags
}

#
# Processor Attachments
#

# Processor Attachment - Single module for whichever processor is active
module "processor_attachment" {
  source = "./modules/processor-attachment"
  count  = local.processor_type != null ? 1 : 0

  name = "${local.name_prefix}-processor"

  # Processor configuration - dynamically determined based on active processor
  processor = local.processor_config

  # Processing environment resources  
  document_queue_arn             = module.processing_environment.document_queue_arn
  queue_sender_function_arn      = module.processing_environment.queue_sender_function_arn
  queue_sender_function_name     = module.processing_environment.queue_sender_function_name
  workflow_tracker_function_arn  = module.processing_environment.workflow_tracker_function_arn
  workflow_tracker_function_name = module.processing_environment.workflow_tracker_function_name

  # S3 bucket configuration
  input_bucket_arn   = var.input_bucket_arn
  output_bucket_arn  = var.output_bucket_arn
  working_bucket_arn = var.working_bucket_arn
  s3_prefix          = null # No prefix filtering

  # Configuration  
  tracking_table_arn      = module.processing_environment.tracking_table_arn
  configuration_table_arn = module.processing_environment.configuration_table_arn
  concurrency_table_arn   = module.processing_environment.concurrency_table_arn

  # Encryption and layers
  encryption_key_arn   = var.encryption_key_arn
  enable_encryption    = var.enable_encryption
  idp_common_layer_arn = module.idp_common_layer.layer_arn

  # Logging configuration
  metric_namespace   = module.processing_environment.metric_namespace
  log_level          = module.processing_environment.log_level
  log_retention_days = module.processing_environment.log_retention_days

  # Optional: API configuration
  api_id          = local.api_enabled ? module.processing_environment_api[0].api_id : null
  api_arn         = local.api_enabled ? module.processing_environment_api[0].api_arn : null
  api_graphql_url = local.api_enabled ? module.processing_environment_api[0].graphql_url : null

  # Optional: Evaluation configuration
  evaluation_options = var.evaluation.enabled ? {
    baseline_bucket_arn = var.evaluation.baseline_bucket_arn
    model_id            = var.evaluation.model_id
  } : null

  # VPC configuration
  vpc_subnet_ids         = var.vpc_subnet_ids
  vpc_security_group_ids = var.vpc_security_group_ids

  # Lambda tracing configuration
  lambda_tracing_mode = var.lambda_tracing_mode

  tags = var.tags
}

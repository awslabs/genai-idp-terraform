# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
#
# GenAI IDP Accelerator - complete deployment module.
#
# One-stop deployment of an end-to-end IDP pipeline: connects to existing S3
# buckets and KMS keys and creates the processing environment, optional API and
# web UI, user identity, and the selected document processor (BDA / Bedrock LLM
# / SageMaker UDOP).

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

# Validation: APIGateway Web UI hosting requires the API. In this mode the SPA is
# served BY the REST API (S3-proxy GET routes on the same stage as /op), so
# without the API there is nothing to serve the bucket from.
#tfsec:ignore:*
check "web_ui_apigateway_hosting_requires_api" {
  assert {
    condition     = !(var.web_ui.enabled && var.web_ui.hosting == "APIGateway") || local.api_enabled
    error_message = "web_ui.hosting = \"APIGateway\" requires api.enabled = true: the SPA is served as an S3 proxy on the REST API stage, so the API must exist. Use \"CloudFront\" hosting or enable the API."
  }
}

# Validation: Agent Analytics requires Reporting (it needs reporting.bucket_arn
# and reporting.database_name; otherwise the API config is silently downgraded).
# See https://github.com/awslabs/genai-idp-terraform/issues/84
#tfsec:ignore:*
check "agent_analytics_requires_reporting" {
  assert {
    condition     = !local.agent_analytics_config.enabled || var.reporting.enabled
    error_message = "When Agent Analytics is enabled (api.agent_analytics.enabled or the deprecated agent_analytics.enabled), reporting.enabled must also be true. Agent Analytics requires reporting.bucket_arn and reporting.database_name."
  }
}

# Validation: Chat-with-Document is only reachable through the API. It
# contributes `sendChatDocumentMessage` to the dispatcher's field-function map,
# so with the API off its Lambdas and tables are built but nothing can route to
# them.
#tfsec:ignore:*
check "chat_with_document_requires_api" {
  assert {
    condition     = !local.feature_enable.chat_with_document || local.api_enabled
    error_message = "When Chat-with-Document is enabled (api.chat_with_document.enabled or the deprecated chat_with_document.enabled), the API must also be enabled (api.enabled / enable_api). Its sendChatDocumentMessage field is served by the API dispatcher, so with the API off the feature is unreachable."
  }
}

# Deprecation notice: `api.visibility` was renamed to
# `api.api_gateway_visibility` in v0.6.4, when upstream replaced AppSync with
# the API Gateway REST transport (AppSyncVisibility -> ApiGatewayVisibility).
# The old spelling still works and takes precedence, so this is a non-blocking
# check (it warns on plan/apply without failing).
#tfsec:ignore:*
check "api_visibility_deprecated" {
  assert {
    condition     = var.api.visibility == null
    error_message = "DEPRECATED: api.visibility is renamed to api.api_gateway_visibility (upstream v0.6.4 renamed AppSyncVisibility to ApiGatewayVisibility when AppSync was replaced by the API Gateway REST transport). Your value is still being honored. Migrate by moving it to api.api_gateway_visibility; see docs/migration-v0.5.16-to-v0.6.4.md."
  }
}

# Processor selection and per-type required fields are enforced by validation on
# var.processor.

# Validation: enable_encryption requires a KMS key (some module IAM policies
# otherwise fall back to a KMS wildcard), so fail fast when the key is null.
#tfsec:ignore:*
check "enable_encryption_requires_key" {
  assert {
    condition     = !var.enable_encryption || var.encryption_key_arn != null
    error_message = "When enable_encryption is true, encryption_key_arn must be set to a non-null KMS key ARN."
  }
}

# Advisory: the configuration enables evaluation but no baseline bucket ARN was
# supplied, so evaluation will NOT run (local.evaluation_enabled AND-gates on the
# bucket). This is a soft check (warning, not error) because "evaluation enabled
# in config, no baseline wired" is a valid state the runtime tolerates — it just
# means no scoring happens. Supply var.evaluation.baseline_bucket_arn to activate.
check "evaluation_enabled_without_baseline_bucket" {
  assert {
    condition     = !local._config_evaluation_enabled || var.evaluation.baseline_bucket_arn != null
    error_message = "The configuration enables evaluation (config.evaluation.enabled = true) but var.evaluation.baseline_bucket_arn is not set, so evaluation will not run. Supply the baseline S3 bucket ARN to activate evaluation, or disable it in the config."
  }
}

# Validation: Web UI logging bucket requirement
#tfsec:ignore:*
check "web_ui_logging_bucket" {
  assert {
    condition     = !var.web_ui.logging_enabled || var.web_ui.logging_bucket_arn != null
    error_message = "web_ui.logging_bucket_arn is required when web_ui.logging_enabled is true."
  }
}

# Validation: presigned-URL-via-VPCE requires a supplied endpoint DNS name.
# The S3 interface endpoint is owned outside this module (the deployment's own
# VPC wiring), so its DNS name must be supplied via
# web_ui.s3_vpc_endpoint_dns_name_override. Mirrors upstream override rule.
#tfsec:ignore:*
check "web_ui_presign_vpce_dns" {
  assert {
    condition     = !var.web_ui.s3_presigned_url_via_vpc_endpoint || var.web_ui.s3_vpc_endpoint_dns_name_override != null
    error_message = "web_ui.s3_vpc_endpoint_dns_name_override is required when web_ui.s3_presigned_url_via_vpc_endpoint is true (set it to the DNS name of the S3 interface VPC endpoint serving the deployment)."
  }
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

# Random suffix for unique resource names.
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Random suffix for the web-app bucket name in APIGateway hosting mode.
#
# Owned by the root (not the web-ui module) so the API module can be told the
# bucket name for its S3-proxy integration without depending on module.web_ui —
# see local.web_ui_apigw_bucket_name in locals.tf for the cycle rationale. This
# resource exists in every configuration but only feeds the bucket name when
# web_ui.hosting = "APIGateway"; CloudFront deployments keep the web-ui module's
# internal suffix and are unaffected.
resource "random_string" "web_ui_bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

#
# Build runtime check
#
# Probes the deploy host for a usable container runtime (Docker / Podman /
# Finch) when var.build.lambda_local = true. The check {} block inside
# this module fails plan with per-OS install instructions if no runtime is
# available. When lambda_local = false the probe runs but is non-fatal.
#
module "build_runtime_check" {
  count  = var.build.lambda_local ? 1 : 0
  source = "./modules/build-runtime-check"

  lambda_local      = var.build.lambda_local
  container_runtime = var.build.container_runtime
}

# Web UI build check
#
# Probes the deploy host for Node.js >= 18 when var.build.ui_local = true
# and the web UI is enabled. The check {} block inside this module fails
# plan with install instructions if Node.js is missing or too old.
#
module "web_ui_build_check" {
  count  = var.build.ui_local && var.web_ui.enabled ? 1 : 0
  source = "./modules/web-ui-build-check"

  ui_local = var.build.ui_local
}

#
# Shared assets bucket for Lambda layers, UI assets, and deployment artifacts.
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

  # Build strategy (see var.build in variables.tf)
  lambda_local        = var.build.lambda_local
  lambda_architecture = var.build.lambda_architecture
  container_runtime   = var.build.container_runtime

  vpc_id             = try(var.private_network.vpc_id, null)
  subnet_ids         = var.vpc_subnet_ids
  security_group_ids = var.vpc_security_group_ids
}

# Base layer: docs_service extras — used by queue_sender, workflow_tracker, lookup_function,
# post_processing_decompressor, and evaluation functions (v0.4.11+)
module "idp_base_layer" {
  source = "./modules/idp-common-layer"

  layer_prefix             = "${local.name_prefix}-base-layer"
  lambda_layers_bucket_arn = module.assets_bucket.bucket_arn
  idp_common_extras        = ["docs_service"]
  force_rebuild            = var.force_rebuild_layers
  lambda_tracing_mode      = var.lambda_tracing_mode

  # Build strategy (see var.build in variables.tf)
  lambda_local        = var.build.lambda_local
  lambda_architecture = var.build.lambda_architecture
  container_runtime   = var.build.container_runtime
}

# Reporting layer: reporting extras — used by save_reporting_data function (v0.4.11+)
module "idp_reporting_layer" {
  source = "./modules/idp-common-layer"

  layer_prefix             = "${local.name_prefix}-reporting-layer"
  lambda_layers_bucket_arn = module.assets_bucket.bucket_arn
  idp_common_extras        = ["reporting"]
  force_rebuild            = var.force_rebuild_layers
  lambda_tracing_mode      = var.lambda_tracing_mode

  # Build strategy (see var.build in variables.tf)
  lambda_local        = var.build.lambda_local
  lambda_architecture = var.build.lambda_architecture
  container_runtime   = var.build.container_runtime
}

# Agents layer: agents extras — used by agent companion chat and agent analytics functions (v0.4.11+)
module "idp_agents_layer" {
  source = "./modules/idp-common-layer"

  layer_prefix             = "${local.name_prefix}-agents-layer"
  lambda_layers_bucket_arn = module.assets_bucket.bucket_arn
  idp_common_extras        = ["agents"]
  force_rebuild            = var.force_rebuild_layers
  lambda_tracing_mode      = var.lambda_tracing_mode

  # Build strategy (see var.build in variables.tf)
  lambda_local        = var.build.lambda_local
  lambda_architecture = var.build.lambda_architecture
  container_runtime   = var.build.container_runtime
}

# Evaluation layer: evaluation + docs_service extras for the per-processor
# evaluation Lambda (munkres + numpy). Built only when evaluation is enabled.
module "idp_evaluation_layer" {
  count  = local.evaluation_enabled ? 1 : 0
  source = "./modules/idp-common-layer"

  layer_prefix             = "${local.name_prefix}-evaluation-layer"
  lambda_layers_bucket_arn = module.assets_bucket.bucket_arn
  idp_common_extras        = ["evaluation", "docs_service"]
  force_rebuild            = var.force_rebuild_layers
  lambda_tracing_mode      = var.lambda_tracing_mode

  # Build strategy (see var.build in variables.tf)
  lambda_local        = var.build.lambda_local
  lambda_architecture = var.build.lambda_architecture
  container_runtime   = var.build.container_runtime
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

  # Register the Web UI custom domain URL as an OAuth callback+logout URL
  # so hosted-UI redirects succeed. CloudFront domains are not known until the
  # distribution exists, so only the explicit custom_domain_url is wired here.
  additional_callback_urls = var.web_ui.custom_domain_url != null ? [var.web_ui.custom_domain_url] : []
  additional_logout_urls   = var.web_ui.custom_domain_url != null ? [var.web_ui.custom_domain_url] : []

  # All no-ops when federation is off.
  additional_identity_providers     = local.federation_supported_identity_providers
  enable_idp_groups_attribute       = local.feature_enable.federation
  pre_token_generation_function_arn = local.federation_group_mapping_function_arn
  create_hosted_ui_domain           = local.feature_enable.federation
  hosted_ui_domain_prefix           = try(var.idp_federation.hosted_ui_domain_prefix, null)

  tags = var.tags
}

# Human Review (REMOVED in v0.5.12-tf.0). HITL is now the built-in
# complete_section_review Lambda + AppSync resolvers in
# processing-environment-api (gated by var.enable_hitl). var.human_review is
# kept as a deprecation shim: its enabled field still gates the legacy A2I IAM
# statements in locals.tf so existing tfvars keep planning.

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

  # Reporting ingest: creates save_reporting_data and wires workflow_tracker
  enable_reporting     = var.reporting.enabled
  reporting_bucket_arn = var.reporting.bucket_arn

  # Encryption key
  encryption_key_arn = var.encryption_key_arn
  enable_encryption  = var.enable_encryption

  # Lambda layer
  idp_common_layer_arn = module.idp_common_layer.layer_arn

  # Shared layers (v0.4.11+)
  base_layer_arn      = module.idp_base_layer.layer_arn
  reporting_layer_arn = module.idp_reporting_layer.layer_arn
  agents_layer_arn    = module.idp_agents_layer.layer_arn

  # Optional: API configuration for UI updates
  api = local.api_enabled ? {
    api_id           = module.processing_environment_api[0].api_id
    api_name         = module.processing_environment_api[0].api_name
    api_arn          = module.processing_environment_api[0].api_arn
    graphql_url      = ""
    lambda_functions = module.processing_environment_api[0].lambda_functions
  } : null

  # Configuration
  log_level                    = var.log_level
  log_retention_days           = var.log_retention_days
  data_tracking_retention_days = var.data_tracking_retention_days

  # Core table capacity / billing (see variables.tf; defaults preserve on-demand)
  core_table_capacity = var.core_table_capacity

  # VPC configuration
  subnet_ids         = var.vpc_subnet_ids
  security_group_ids = var.vpc_security_group_ids
  vpc_id             = try(var.private_network.vpc_id, null)

  # Lambda tracing configuration
  lambda_tracing_mode = var.lambda_tracing_mode

  # Build strategy (see var.build in variables.tf)
  lambda_local        = var.build.lambda_local
  lambda_architecture = var.build.lambda_architecture
  container_runtime   = var.build.container_runtime

  tags = var.tags
}

#
# GraphQL API (Optional)
#
module "processing_environment_api" {
  count  = local.api_enabled ? 1 : 0
  source = "./modules/processing-environment-api"

  name = "${local.name_prefix}-api"

  # Presigned-URL-via-VPCE (v0.5.16). When enabled with a supplied endpoint DNS
  # name, presigner Lambdas target the S3 interface VPC endpoint. Supplied as a
  # user input rather than derived from an in-module endpoint, which keeps the
  # graph acyclic.
  s3_endpoint_url = local.web_ui_s3_endpoint_url

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

  # processing_environment is always instantiated, so the tracking table always
  # exists. Pass this plan-time-known flag so the api module's tracking-table
  # gates don't key their count off the COMPUTED tracking_table_arn (which is
  # unknown at plan time and breaks a cold `terraform plan`).
  tracking_table_available = true

  # S3 bucket ARNs
  input_bucket_arn   = var.input_bucket_arn
  output_bucket_arn  = var.output_bucket_arn
  working_bucket_arn = var.working_bucket_arn

  # Optional: Evaluation baseline bucket
  evaluation_enabled             = local.evaluation_enabled
  evaluation_baseline_bucket_arn = local.evaluation_enabled ? var.evaluation.baseline_bucket_arn : null
  evaluation_layer_arn           = local.evaluation_enabled ? module.idp_evaluation_layer[0].layer_arn : null

  # Knowledge Base configuration
  knowledge_base = local.knowledge_base_config

  # Encryption key
  encryption_key_arn = var.encryption_key_arn

  # VPC configuration
  vpc_config = length(var.vpc_subnet_ids) > 0 ? {
    subnet_ids         = var.vpc_subnet_ids
    security_group_ids = var.vpc_security_group_ids
    vpc_id             = try(var.private_network.vpc_id, null)
  } : null

  # Lambda tracing configuration
  lambda_tracing_mode = var.lambda_tracing_mode

  # Agent Analytics configuration
  # Both branches need the same attribute set, or Terraform cannot unify them.
  agent_analytics = local.agent_analytics_config.enabled && var.reporting.enabled ? {
    enabled                   = true
    model_id                  = local.agent_analytics_config.model_id
    reporting_database_name   = var.reporting.database_name
    reporting_bucket_arn      = var.reporting.bucket_arn
    allowed_bedrock_model_ids = local.agent_analytics_config.allowed_bedrock_model_ids
    } : {
    enabled                   = false
    model_id                  = local.agent_analytics_config.model_id
    reporting_database_name   = null
    reporting_bucket_arn      = null
    allowed_bedrock_model_ids = []
  }

  # Discovery configuration
  discovery = local.discovery_config.enabled ? {
    enabled = true
  } : { enabled = false }
  # Restrict discovery upload bucket CORS to the app origin(s) (Wiz S3-036).
  discovery_allowed_cors_origins = var.discovery_allowed_cors_origins

  # Chat with Document configuration
  chat_with_document = local.chat_with_document_config.enabled ? {
    enabled                  = true
    guardrail_id_and_version = local.chat_with_document_config.guardrail_id_and_version
  } : { enabled = false }

  # Process Changes configuration (Edit Sections feature)
  enable_edit_sections = local.process_changes_config.enabled
  # Unconditional: the reprocess resolver also re-queues through this queue.
  document_queue_url = module.processing_environment.document_queue_url
  document_queue_arn = module.processing_environment.document_queue_arn

  # v0.4.8 feature flags
  enable_agent_companion_chat = try(var.api.enable_agent_companion_chat, false)
  enable_test_studio          = try(var.api.enable_test_studio, false)
  enable_fcc_dataset          = try(var.api.enable_fcc_dataset, false)
  enable_w2_dataset           = try(var.api.enable_w2_dataset, false)
  enable_finetuning           = try(var.api.enable_finetuning, false)
  enable_error_analyzer       = try(var.api.enable_error_analyzer, false)

  # version-check resolver (v0.5.11). Default-off: empty public_artifacts_bucket
  # creates no version-check Lambda/data source/resolver.
  public_artifacts_bucket = try(var.api.public_artifacts_bucket, "")
  public_artifacts_prefix = try(var.api.public_artifacts_prefix, "artifacts/genai-idp")
  public_artifacts_region = try(var.api.public_artifacts_region, "")

  # MCP moved to the mcp_integration feature submodule (features.tf), composed
  # via enabled_feature_contracts; the API module no longer owns the MCP stack.

  # v0.4.16 feature flags
  enable_hitl                     = try(var.api.enable_hitl, true)
  enable_capacity_planning        = try(var.api.enable_capacity_planning, false)
  enable_omni_ai_dataset          = try(var.api.enable_omni_ai_dataset, false)
  enable_docplit_poly_seq_dataset = try(var.api.enable_docplit_poly_seq_dataset, false)
  bda_project_arn                 = length(module.bda_processor) > 0 ? module.bda_processor[0].data_automation_project_arn : ""

  # REST API visibility (v0.6.4). "PRIVATE" makes the API Gateway REST endpoint
  # reachable only through the execute-api interface VPC endpoint (fully
  # isolated VPC deployments); "GLOBAL" is a public REGIONAL endpoint still
  # gated by the Cognito authorizer. Resolved from
  # api.api_gateway_visibility (or the deprecated api.visibility) in locals.tf.
  visibility                  = local.api_gateway_visibility
  api_gateway_vpc_endpoint_id = try(var.api.api_gateway_vpc_endpoint_id, "")
  waf_allowed_ipv4_ranges     = try(var.api.waf_allowed_ipv4_ranges, ["0.0.0.0/0"])

  # Web UI hosting on the REST API (v0.6.4, web_ui.hosting = "APIGateway").
  # Adds GET / and GET /{proxy+} S3-proxy routes on the same stage as the /op
  # transport, so the SPA inherits the PRIVATE-endpoint + WAF posture above.
  # The bucket name comes from a ROOT-derived local, never from module.web_ui —
  # see local.web_ui_apigw_bucket_name for why.
  serve_web_ui       = var.web_ui.enabled && var.web_ui.hosting == "APIGateway"
  web_ui_bucket_name = var.web_ui.hosting == "APIGateway" ? local.web_ui_apigw_bucket_name : ""

  # Lookup function (used by Agent Chat Processor)
  lookup_function_name = module.processing_environment.lookup_function_name

  # Step Functions state machine ARN. Used to scope the getStepFunctionExecution
  # resolver's states:DescribeExecution / states:GetExecutionHistory grant to
  # this deployment's own executions (least privilege) instead of "*".
  state_machine_arn = try(local.processor_config.state_machine_arn, null)

  # Lambda layers
  base_layer_arn           = module.processing_environment.base_layer_arn
  idp_common_layer_arn     = module.idp_common_layer.layer_arn
  agents_layer_arn         = module.idp_agents_layer.layer_arn
  lambda_layers_bucket_arn = module.assets_bucket.bucket_arn

  # Chat token-streaming endpoint (v0.6.4): AWS Lambda Web Adapter layer for the
  # streaming Function URL. Empty => API module constructs the upstream default.
  lambda_web_adapter_layer_arn = var.lambda_web_adapter_layer_arn

  # RBAC Users table for the streaming processor's scope enforcement (empty when
  # RBAC is off).
  users_table_name = local.feature_enable.rbac ? module.rbac[0].users_table_name : ""

  # Deterministic web-ui settings SSM parameter name for the streaming
  # processor. Passed as a plain string (NOT module.web_ui) to avoid a
  # dependency cycle: the web-ui module names the parameter
  # "/${name_prefix}/web-ui-settings" where its name_prefix is
  # "${local.name_prefix}-web-ui". Empty when the web UI is disabled.
  settings_parameter_name = var.web_ui.enabled ? "/${local.name_prefix}-web-ui/web-ui-settings" : ""

  # Build strategy (see var.build in variables.tf)
  lambda_local        = var.build.lambda_local
  lambda_architecture = var.build.lambda_architecture
  container_runtime   = var.build.container_runtime

  # Feature-plugin contracts from features.tf. Resolves to {} when all features
  # are off (no-op, default-off preserved).
  enabled_feature_contracts = local.enabled_feature_contracts
  has_feature_iam           = local.feature_enable.rbac

  # Feature Platform API fields -> Lambda ARNs for the REST dispatcher. Passed
  # separately because the Feature Platform is wired outside the contract map.
  # Safe (no cycle): the module no longer takes any input from the API module.
  feature_platform_field_functions = length(module.feature_platform) > 0 ? module.feature_platform[0].field_functions : {}

  tags = var.tags
}

#
# Document Processor
#

# BDA Processor
module "bda_processor" {
  allowed_bedrock_model_ids = var.processor.allowed_bedrock_model_ids
  source                    = "./modules/processors/bda-processor"
  count                     = var.processor.type == "bda" ? 1 : 0

  lambda_architecture = var.build.lambda_architecture

  # IDP v0.6 `ocr.backend: bda` support (deployment-scoped BDA OCR project).
  enable_bda_ocr_backend = local.bda_ocr_backend_enabled

  name = "${local.name_prefix}-processor"

  # Shared assets bucket for Lambda layers
  lambda_layers_bucket_arn = module.assets_bucket.bucket_arn

  # API configuration (if enabled)
  enable_api      = local.api_enabled
  api_id          = local.api_enabled ? module.processing_environment_api[0].api_id : null
  api_arn         = local.api_enabled ? module.processing_environment_api[0].api_arn : null
  api_graphql_url = ""

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

  enable_encryption    = var.enable_encryption
  encryption_key_arn   = var.encryption_key_arn
  idp_common_layer_arn = module.idp_common_layer.layer_arn
  base_layer_arn       = module.processing_environment.base_layer_arn

  # VPC configuration
  vpc_subnet_ids         = var.vpc_subnet_ids
  vpc_security_group_ids = var.vpc_security_group_ids

  # BDA-specific configurations
  data_automation_project_arn = var.processor.project_arn

  # Optional: Evaluation configuration (model comes from the YAML config)
  evaluation_baseline_bucket_name = local.web_ui_evaluation_bucket_name
  reporting_bucket_name           = local.reporting_bucket_name
  save_reporting_function_name    = module.processing_environment.save_reporting_data_function_name
  save_reporting_function_arn     = module.processing_environment.save_reporting_data_function_arn

  # Rule validation
  enable_rule_validation = local.rule_validation_enabled

  # Optional: Document processing configuration
  config = var.processor.config

  # Optional: extra non-active config versions seeded alongside the default
  additional_configurations = var.processor.additional_configurations
  seed_managed_configs      = var.seed_managed_configs

  # Lambda tracing configuration
  lambda_tracing_mode = var.lambda_tracing_mode


  tags = var.tags
}

# Bedrock LLM Processor
module "bedrock_llm_processor" {
  allowed_bedrock_model_ids = var.processor.allowed_bedrock_model_ids
  source                    = "./modules/processors/bedrock-llm-processor"
  count                     = var.processor.type == "bedrock-llm" ? 1 : 0

  lambda_architecture = var.build.lambda_architecture

  # IDP v0.6 `ocr.backend: bda` support (deployment-scoped BDA OCR project).
  enable_bda_ocr_backend = local.bda_ocr_backend_enabled

  name = "${local.name_prefix}-processor"

  # API configuration (if enabled)
  enable_api      = local.api_enabled
  api_id          = local.api_enabled ? module.processing_environment_api[0].api_id : null
  api_arn         = local.api_enabled ? module.processing_environment_api[0].api_arn : null
  api_graphql_url = ""

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
  enable_encryption    = var.enable_encryption
  idp_common_layer_arn = module.idp_common_layer.layer_arn
  base_layer_arn       = module.processing_environment.base_layer_arn
  evaluation_layer_arn = local.evaluation_enabled ? module.idp_evaluation_layer[0].layer_arn : null

  # VPC configuration
  vpc_subnet_ids         = var.vpc_subnet_ids
  vpc_security_group_ids = var.vpc_security_group_ids

  # Per-stage models come from the YAML configuration, not Terraform.
  max_pages_for_classification = var.processor.max_pages_for_classification

  # Evaluation: per-pattern Lambda built from sources/patterns/pattern-2, the
  # only evaluation surface, matching upstream.
  evaluation_enabled             = local.evaluation_enabled
  evaluation_baseline_bucket_arn = local.evaluation_enabled ? var.evaluation.baseline_bucket_arn : null
  reporting_bucket_name          = local.reporting_bucket_name
  save_reporting_function_name   = module.processing_environment.save_reporting_data_function_name
  save_reporting_function_arn    = module.processing_environment.save_reporting_data_function_arn

  # Optional: Document processing configuration
  config = var.processor.config

  # Optional: extra non-active config versions seeded alongside the default
  additional_configurations = var.processor.additional_configurations
  seed_managed_configs      = var.seed_managed_configs

  # Optional fallback BDA project for use_bda:true additional versions (does not
  # relink the default)
  bda_project_arn = var.processor.bda_project_arn

  # Feature flags. Summarization enablement is config-authoritative (derived
  # from var.processor.config at plan time); see local.summarization_enabled.
  is_summarization_enabled = local.summarization_enabled
  enable_hitl              = local.hitl_enabled
  enable_rule_validation   = local.rule_validation_enabled

  # Lambda tracing configuration
  lambda_tracing_mode = var.lambda_tracing_mode

  tags = var.tags
}

# SageMaker UDOP Processor
module "sagemaker_udop_processor" {
  allowed_bedrock_model_ids = var.processor.allowed_bedrock_model_ids
  source                    = "./modules/processors/sagemaker-udop-processor"
  count                     = var.processor.type == "sagemaker-udop" ? 1 : 0

  lambda_architecture = var.build.lambda_architecture

  # IDP v0.6 `ocr.backend: bda` support (deployment-scoped BDA OCR project).
  enable_bda_ocr_backend = local.bda_ocr_backend_enabled

  name = "${local.name_prefix}-processor"

  # API configuration (if enabled)
  enable_api      = local.api_enabled
  api_id          = local.api_enabled ? module.processing_environment_api[0].api_id : null
  api_arn         = local.api_enabled ? module.processing_environment_api[0].api_arn : null
  api_graphql_url = ""

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
  base_layer_arn       = module.processing_environment.base_layer_arn
  evaluation_layer_arn = local.evaluation_enabled ? module.idp_evaluation_layer[0].layer_arn : null

  # VPC configuration
  vpc_subnet_ids         = var.vpc_subnet_ids
  vpc_security_group_ids = var.vpc_security_group_ids

  # SageMaker UDOP processor configuration
  classification_endpoint_arn = var.processor.classification_endpoint_arn

  # Optional: Performance configuration
  ocr_max_workers            = var.processor.ocr_max_workers
  classification_max_workers = var.processor.classification_max_workers

  # Per-stage models come from the YAML configuration, not Terraform.
  evaluation_baseline_bucket_name = local.web_ui_evaluation_bucket_name
  reporting_bucket_name           = local.reporting_bucket_name
  save_reporting_function_name    = module.processing_environment.save_reporting_data_function_name
  save_reporting_function_arn     = module.processing_environment.save_reporting_data_function_arn

  # Rule validation
  enable_rule_validation = local.rule_validation_enabled

  # Optional: Document processing configuration
  config = var.processor.config

  # Optional: extra non-active config versions seeded alongside the default
  additional_configurations = var.processor.additional_configurations
  seed_managed_configs      = var.seed_managed_configs

  # Optional fallback BDA project for use_bda:true additional versions (does not
  # relink the default)
  bda_project_arn = var.processor.bda_project_arn

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

  lambda_architecture = var.build.lambda_architecture

  providers = {
    aws.us-east-1 = aws.us-east-1
  }

  name_prefix   = "${local.name_prefix}-web-ui"
  prefix        = var.prefix
  display_name  = var.web_ui.display_name != null ? var.web_ui.display_name : local.name_prefix
  console_title = var.web_ui.console_title
  idp_version   = trimspace(file("${path.module}/IDP_VERSION"))

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

  # Federated sign-in entry point for the UI. Null when federation is off.
  external_idp = local.feature_enable.federation ? {
    provider_name  = try(var.idp_federation.provider_name, "ExternalIdP")
    cognito_domain = local.federation_hosted_ui_domain
    auto_login     = try(var.idp_federation.auto_login, false)
  } : null

  # API configuration (if enabled)
  api_url = local.api_enabled ? module.processing_environment_api[0].api_base_url : null

  # Chat token-streaming Function URL (VITE_STREAM_URL). Null when the API (or
  # chat streaming) is disabled.
  stream_url = local.api_enabled ? module.processing_environment_api[0].chat_stream_function_url : null

  # S3 bucket ARNs
  input_bucket_arn   = var.input_bucket_arn
  output_bucket_arn  = var.output_bucket_arn
  working_bucket_arn = var.working_bucket_arn

  # working_bucket_arn is a required root input, so the working bucket always
  # exists here. Pass this plan-time-known flag so the web-ui CORS resource
  # doesn't gate its count off the COMPUTED working_bucket_arn (unknown at plan
  # time, which breaks a cold `terraform plan`).
  working_bucket_cors_enabled = true

  # Optional: Logging bucket for CloudFront and S3 access logs
  logging_bucket = var.web_ui.logging_enabled ? {
    bucket_name = local.logging_bucket_name
    bucket_arn  = var.web_ui.logging_bucket_arn
  } : null

  # Test Studio bucket, for settings.TestSetBucket + its CORS. Separate flag as
  # with working_bucket_cors_enabled above: the name is computed.
  test_set_bucket_name    = local.api_enabled ? module.processing_environment_api[0].test_set_bucket_name : null
  test_set_bucket_enabled = local.api_enabled && try(var.api.enable_test_studio, false)

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
  cloudfront_allowed_geos           = var.web_ui.allowed_geos
  should_allow_sign_up_email_domain = var.web_ui.enable_signup != ""

  # Hosting mode + public URL for CORS / UI build env. "CloudFront" creates the
  # distribution; "APIGateway" serves the bucket through the REST API stage, so
  # the app URL is the REST base (".../api") rather than a custom domain.
  hosting = var.web_ui.hosting
  web_ui_url = (
    var.web_ui.hosting == "APIGateway"
    ? (local.api_enabled ? module.processing_environment_api[0].api_base_url : null)
    : var.web_ui.custom_domain_url
  )

  # APIGateway hosting: the bucket name must be known to the API module for its
  # S3-proxy integration, so it is derived at the root instead of from the
  # module's own random suffix. Null in CloudFront mode, which keeps the module's
  # historical naming (and therefore the existing bucket) untouched.
  bucket_name_override = var.web_ui.hosting == "APIGateway" ? local.web_ui_apigw_bucket_name : null

  # Bucket policy principal for the API Gateway S3 proxy. The web-ui module
  # already depends on the API module (api_url / stream_url), so this adds no new
  # module edge.
  apigw_proxy_role_arn = local.api_enabled ? module.processing_environment_api[0].web_ui_proxy_role_arn : null

  # Encryption key
  encryption_key_arn = var.encryption_key_arn

  # Build strategy
  ui_local = var.build.ui_local

  # Lambda tracing configuration
  lambda_tracing_mode = var.lambda_tracing_mode

  # Places the UI CodeBuild project in the VPC. The build runs npm install, so
  # the subnets need egress to the registry.
  vpc_id             = try(var.private_network.vpc_id, null)
  subnet_ids         = var.vpc_subnet_ids
  security_group_ids = var.vpc_security_group_ids

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
# Chat token-streaming Function URL invoke grant (v0.6.4)
# Mirrors upstream CognitoAuthorizedRole ChatStreamInvoke: grants the
# authenticated Cognito Identity Pool role lambda:InvokeFunction +
# lambda:InvokeFunctionUrl on the stream function ARN. Attached as a separate
# inline policy on the same authenticated role (kept out of the big concat above
# because the stream function ARN is only known when chat streaming is enabled).
#
resource "aws_iam_role_policy" "chat_stream_invoke" {
  for_each = local.enable_chat_stream_invoke_grant ? toset(["enabled"]) : toset([])
  name     = "${local.name_prefix}-chat-stream-invoke"
  role     = basename(local.authenticated_role_arn)

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction",
          "lambda:InvokeFunctionUrl"
        ]
        Resource = module.processing_environment_api[0].chat_stream_function_arn
      }
    ]
  })
}

#
# Reporting (Optional)
#
module "reporting" {
  count  = var.reporting.enabled ? 1 : 0
  source = "./modules/reporting"

  lambda_architecture = var.build.lambda_architecture

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

  lambda_architecture = var.build.lambda_architecture

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
  api_graphql_url = ""

  # VPC configuration
  vpc_subnet_ids         = var.vpc_subnet_ids
  vpc_security_group_ids = var.vpc_security_group_ids

  # Lambda tracing configuration
  lambda_tracing_mode = var.lambda_tracing_mode

  tags = var.tags
}

# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
variable "region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "genai-idp"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Processor type is now determined by which processor object is configured

variable "deletion_protection" {
  description = "Enable deletion protection for Cognito resources"
  type        = bool
  default     = true
}

variable "user_identity" {
  description = "Configuration for external Cognito User Identity resources. If provided, the module will use this instead of creating its own user identity resources."
  type = object({
    user_pool_arn          = string
    user_pool_client_id    = optional(string)
    identity_pool_id       = optional(string)
    authenticated_role_arn = optional(string)
  })
  default = null

  validation {
    condition = var.user_identity == null || (
      can(regex("^arn:(aws|aws-us-gov):cognito-idp:[^:]+:[^:]+:userpool/.+$", var.user_identity.user_pool_arn))
    )
    error_message = "When user_identity is provided, user_pool_arn must be a valid Cognito User Pool ARN in the format: arn:aws:cognito-idp:region:account-id:userpool/user_pool_id (or arn:aws-us-gov for GovCloud)"
  }

  validation {
    condition = var.user_identity == null || (
      (try(var.user_identity.user_pool_client_id, null) != null) == (try(var.user_identity.identity_pool_id, null) != null && try(var.user_identity.authenticated_role_arn, null) != null)
    )
    error_message = "When user_identity is provided, either provide user_pool_client_id alone, or provide all of identity_pool_id and authenticated_role_arn together."
  }
}

variable "force_rebuild_layers" {
  description = "Force rebuild of Lambda layers regardless of requirements changes"
  type        = bool
  default     = false
}

variable "lambda_web_adapter_layer_arn" {
  description = "ARN of the AWS Lambda Web Adapter (LWA) layer attached to the chat token-streaming processor Function URL. When empty (default), the API module constructs the upstream default (arn:<partition>:lambda:<region>:753240598075:layer:LambdaAdapterLayerX86:25). Override to pin a specific LWA layer version/region/architecture."
  type        = string
  default     = ""
}

#
# Required Resource ARNs
#
variable "input_bucket_arn" {
  description = "ARN of the S3 bucket where source documents to be processed are stored"
  type        = string

  validation {
    condition     = can(regex("^arn:(aws|aws-us-gov):s3:::[^/]+$", var.input_bucket_arn))
    error_message = "input_bucket_arn must be a valid S3 bucket ARN in the format: arn:aws:s3:::bucket-name (or arn:aws-us-gov for GovCloud)"
  }
}

variable "output_bucket_arn" {
  description = "ARN of the S3 bucket where processed documents and extraction results will be stored"
  type        = string

  validation {
    condition     = can(regex("^arn:(aws|aws-us-gov):s3:::[^/]+$", var.output_bucket_arn))
    error_message = "output_bucket_arn must be a valid S3 bucket ARN in the format: arn:aws:s3:::bucket-name (or arn:aws-us-gov for GovCloud)"
  }
}

variable "working_bucket_arn" {
  description = "ARN of the S3 bucket for temporary working files during document processing"
  type        = string

  validation {
    condition     = can(regex("^arn:(aws|aws-us-gov):s3:::[^/]+$", var.working_bucket_arn))
    error_message = "working_bucket_arn must be a valid S3 bucket ARN in the format: arn:aws:s3:::bucket-name (or arn:aws-us-gov for GovCloud)"
  }
}

variable "encryption_key_arn" {
  description = "ARN of the KMS key used for encrypting resources in the document processing workflow"
  type        = string

  validation {
    condition     = can(regex("^arn:(aws|aws-us-gov):kms:[^:]+:[^:]+:key/.+$", var.encryption_key_arn))
    error_message = "encryption_key_arn must be a valid KMS key ARN in the format: arn:aws:kms:region:account-id:key/key-id (or arn:aws-us-gov for GovCloud)"
  }
}

variable "enable_encryption" {
  description = "Whether encryption is enabled. Set to true when providing encryption_key_arn. This is needed to avoid Terraform plan-time unknown value issues."
  type        = bool
  default     = true
}

#
#
# DEPRECATED: Individual API feature variables (continued)
#
variable "enable_api" {
  description = "DEPRECATED: Use api.enabled instead. Enable GraphQL API for programmatic access and notifications"
  type        = bool
  default     = null
}

variable "knowledge_base" {
  description = "DEPRECATED: Use api.knowledge_base instead. Configuration for AWS Bedrock Knowledge Base functionality"
  type = object({
    enabled            = optional(bool, false)
    knowledge_base_arn = optional(string)
    model_id           = optional(string, "us.amazon.nova-pro-v1:0")
    embedding_model_id = optional(string, "amazon.titan-embed-text-v1")
  })
  default = null
}

# Summarization is now configured per-processor within each processor object

#
#
# VPC Configuration (Optional)
#
variable "vpc_subnet_ids" {
  description = "List of subnet IDs for Lambda functions to run in (optional)"
  type        = list(string)
  default     = []
}

variable "vpc_security_group_ids" {
  description = "List of security group IDs for Lambda functions (optional)"
  type        = list(string)
  default     = []
}

# Private Network Deployment
#
# When set, the root instantiates `module.vpc_endpoints` so the VPC-placed IDP
# Lambdas can reach the AWS services the enabled processors and features need
# over PrivateLink. The interface ENIs are placed in `vpc_subnet_ids` with
# `vpc_security_group_ids`; the S3/DynamoDB gateway endpoints attach to
# `route_table_ids`. Default-off: leave this null (and/or `vpc_subnet_ids`
# empty) and no endpoint resources are created, preserving the public-deployment
# behavior.
variable "private_network" {
  description = "Optional private-network deployment configuration. When set with a vpc_id and non-empty vpc_subnet_ids, the root provisions the VPC interface/gateway endpoints (module.vpc_endpoints) required by the enabled processors and features. Leave null for a public deployment (default)."
  type = object({
    vpc_id              = string
    route_table_ids     = optional(list(string), [])
    private_dns_enabled = optional(bool, true)
  })
  default = null
}

#
# General Configuration
#
variable "log_level" {
  description = "Log level for Lambda functions"
  type        = string
  default     = "INFO"
  validation {
    condition     = contains(["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"], var.log_level)
    error_message = "Log level must be one of: DEBUG, INFO, WARNING, ERROR, CRITICAL."
  }
}

variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 7
  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "Log retention days must be one of the allowed values."
  }
}

variable "data_tracking_retention_days" {
  description = "Document tracking data retention period in days"
  type        = number
  default     = 365
}

#
# Custom Configuration
#
#
# Processor-specific Configuration Objects
#

variable "bedrock_llm_processor" {
  description = "Configuration for Bedrock LLM processor"
  type = object({
    classification_model_id      = optional(string, null)
    extraction_model_id          = optional(string, null)
    max_pages_for_classification = optional(string, "ALL")
    summarization = optional(object({
      enabled  = optional(bool, true)
      model_id = optional(string, null)
    }), { enabled = true, model_id = null })
    enable_hitl = optional(bool, false)
    config      = any
    # Extra non-active, editable config versions seeded alongside the default
    # (version_name => config object). Shown in the UI version dropdown.
    additional_configurations = optional(any, {})
    # Optional fallback BDA project for use_bda:true additional versions;
    # does not relink the default configuration.
    bda_project_arn = optional(string, null)
    # Provision the deployment-scoped BDA OCR project needed by IDP v0.6's
    # `ocr.backend: bda` setting (BDA standard-output SYNC as a Textract
    # replacement). Off by default: BDA is not available in every region.
    enable_bda_ocr_backend = optional(bool, false)
  })
  default = null

  validation {
    condition = var.bedrock_llm_processor == null || (
      try(var.bedrock_llm_processor.max_pages_for_classification, "ALL") == "ALL" ||
      can(tonumber(try(var.bedrock_llm_processor.max_pages_for_classification, "ALL")))
    )
    error_message = "max_pages_for_classification must be 'ALL' or a numeric value."
  }
}

variable "bda_processor" {
  description = "Configuration for BDA processor"
  type = object({
    project_arn = string
    summarization = optional(object({
      enabled  = optional(bool, true)
      model_id = optional(string, null)
    }), { enabled = true, model_id = null })
    config = any
    # Extra non-active, editable config versions seeded alongside the default
    # (version_name => config object). Shown in the UI version dropdown.
    additional_configurations = optional(any, {})
    # See bedrock_llm_processor.enable_bda_ocr_backend. Relevant here only for
    # additional config versions that run the pipeline branch (use_bda: false).
    enable_bda_ocr_backend = optional(bool, false)
  })
  default = null
}

variable "sagemaker_udop_processor" {
  description = "Configuration for SageMaker UDOP processor"
  type = object({
    classification_endpoint_arn = string
    extraction_model_id         = optional(string, null)
    summarization = optional(object({
      enabled  = optional(bool, true)
      model_id = optional(string, null)
    }), { enabled = true, model_id = null })
    ocr_max_workers            = optional(number, 20)
    classification_max_workers = optional(number, 20)
    config                     = any
    # Extra non-active, editable config versions seeded alongside the default
    # (version_name => config object). Shown in the UI version dropdown.
    additional_configurations = optional(any, {})
    # Optional fallback BDA project for use_bda:true additional versions;
    # does not relink the default configuration.
    bda_project_arn = optional(string, null)
    # See bedrock_llm_processor.enable_bda_ocr_backend.
    enable_bda_ocr_backend = optional(bool, false)
  })
  default = null
}

#
# Evaluation Configuration
#
variable "evaluation" {
  description = "Configuration for document processing evaluation against baseline"
  type = object({
    enabled             = optional(bool, false)
    model_id            = optional(string, null)
    baseline_bucket_arn = optional(string)
  })
  default = {
    enabled = false
  }

  validation {
    condition     = var.evaluation.enabled == false || var.evaluation.baseline_bucket_arn != null
    error_message = "When evaluation.enabled is true, baseline_bucket_arn is required."
  }
}

#
# Reporting Configuration
#
variable "reporting" {
  description = "Configuration for reporting and analytics functionality"
  type = object({
    enabled                     = optional(bool, false)
    bucket_arn                  = optional(string)
    database_name               = optional(string)
    crawler_schedule            = optional(string, "daily")
    enable_partition_projection = optional(bool, true)
  })
  default = {
    enabled                     = false
    crawler_schedule            = "daily"
    enable_partition_projection = true
  }

  validation {
    condition = var.reporting.enabled == false || (
      var.reporting.bucket_arn != null &&
      var.reporting.database_name != null
    )
    error_message = "When reporting.enabled is true, bucket_arn and database_name are required."
  }

  validation {
    condition     = contains(["manual", "15min", "hourly", "daily"], var.reporting.crawler_schedule)
    error_message = "crawler_schedule must be one of: manual, 15min, hourly, daily."
  }
}

#
# Human Review Configuration
#
variable "human_review" {
  description = "Configuration for human review functionality in document processing. SageMaker A2I fields (user_pool_id, private_workforce_arn, workteam_name) removed in v0.4.9 — HITL is now built into processing-environment-api via complete_section_review (gated by the API enable_hitl flag). DEPRECATED in v0.5.12-tf.0: enable_pattern2_hitl and hitl_confidence_threshold are now accepted-but-ignored no-ops (the Pattern-2 Step Functions HITL trio was removed — it referenced upstream source paths that never existed). enabled still gates the legacy A2I IAM statements. These fields are retained as a deprecation shim so existing tfvars keep working."
  type = object({
    enabled                   = optional(bool, false)
    enable_pattern2_hitl      = optional(bool, false) # DEPRECATED v0.5.12-tf.0: no-op (Pattern-2 HITL trio removed)
    hitl_confidence_threshold = optional(number, 80)  # DEPRECATED v0.5.12-tf.0: no-op (Pattern-2 HITL trio removed)
  })
  default = {
    enabled                   = false
    enable_pattern2_hitl      = false
    hitl_confidence_threshold = 80
  }

  validation {
    condition     = var.human_review.hitl_confidence_threshold >= 0 && var.human_review.hitl_confidence_threshold <= 100
    error_message = "hitl_confidence_threshold must be between 0 and 100."
  }
}

#
# Web UI Configuration
#
variable "web_ui" {
  description = "Web UI configuration object"
  type = object({
    enabled                    = optional(bool, true)
    create_infrastructure      = optional(bool, true)
    bucket_name                = optional(string, null)
    cloudfront_distribution_id = optional(string, null)
    logging_enabled            = optional(bool, false)
    logging_bucket_arn         = optional(string, null)
    enable_signup              = optional(string, "")
    display_name               = optional(string, null)
    console_title              = optional(string, "IDP Accelerator Console")

    # Hosting mode, mirroring upstream WebUIHosting.
    #
    # "CloudFront" (default) fronts the web app bucket with a CloudFront
    # distribution.
    #
    # "APIGateway" skips CloudFront entirely and serves the SPA as an S3 proxy on
    # the SAME API Gateway REST API that carries the /op transport: GET / returns
    # index.html and GET /{proxy+} returns the hashed assets. Consequences:
    #   * The Web UI inherits the API's posture — api.api_gateway_visibility
    #     (PRIVATE => VPC-only via the execute-api interface endpoint) and
    #     api.waf_allowed_ipv4_ranges (WAFv2 on the stage) apply to the SPA too.
    #   * No CloudFront distribution and no ACM certificate are needed, so this
    #     is the mode for fully isolated VPC / GovCloud deployments.
    #   * The app is served under the stage prefix, i.e. at the API base URL
    #     (".../api"), and the UI is built with Vite base = "/api/" so asset URLs
    #     resolve through the {proxy+} route.
    #   * Requires api.enabled = true (the REST API is what serves the SPA); see
    #     check "web_ui_apigateway_hosting_requires_api".
    #   * Switching an existing CloudFront deployment to this mode REPLACES the
    #     web app bucket (its name becomes root-derived). Only built static
    #     assets live there and the next build repopulates them — see
    #     docs/migration-v0.5.16-to-v0.6.4.md.
    #
    # "ALB" was REMOVED in v0.6.4 (upstream deleted ALB hosting in v0.6.0).
    # See docs/migration-v0.5.16-to-v0.6.4.md.
    hosting = optional(string, "CloudFront")

    # Public URL fronting the Web UI (custom domain). Drives input/output bucket
    # CORS and Cognito callback/logout URLs. Mirrors upstream CustomDomainUrl.
    # Only used for non-CloudFront hosting; ignored in APIGateway mode, where the
    # app URL is the REST API base URL. When null, CORS falls back to "*".
    custom_domain_url = optional(string, null)

    # Presigned-URL-via-VPCE settings (mirrors upstream
    # S3PresignedUrlViaVpcEndpoint / S3VpcEndpointDnsNameOverride). When
    # enabled, presigner Lambdas generate S3 URLs targeting the VPC interface
    # endpoint. Non-breaking default: off (presigned URLs use global S3).
    # The S3 interface endpoint is owned by the caller's VPC wiring, so supply
    # its DNS name/id here (e.g. from the vpc-endpoints module outputs at the
    # example level) rather than having this module derive it.
    s3_presigned_url_via_vpc_endpoint = optional(bool, false)
    s3_vpc_endpoint_dns_name_override = optional(string, null)
    s3_vpc_endpoint_id_override       = optional(string, null)
  })
  default = {
    enabled                    = true
    create_infrastructure      = true
    bucket_name                = null
    cloudfront_distribution_id = null
    logging_enabled            = false
    logging_bucket_arn         = null
    enable_signup              = ""
    display_name               = null
  }

  # Reject the removed "ALB" hosting mode with an actionable message instead of
  # letting it silently fall through to a bucket with no fronting layer.
  validation {
    condition     = contains(["CloudFront", "APIGateway"], var.web_ui.hosting)
    error_message = "web_ui.hosting = \"ALB\" was removed in v0.6.4 (upstream deleted ALB hosting). Use \"APIGateway\" for a VPC-capable private posture, or \"CloudFront\". See docs/migration-v0.5.16-to-v0.6.4.md."
  }
}

#
# API Configuration (Consolidated)
#
variable "api" {
  description = "Configuration for GraphQL API and all API-related features"
  type = object({
    # Core API configuration
    enabled = optional(bool, true)

    # Agent Analytics (GraphQL resolvers for agent functionality)
    agent_analytics = optional(object({
      enabled  = optional(bool, false)
      model_id = optional(string, "us.anthropic.claude-sonnet-4-5-20250929-v1:0")
    }), { enabled = false })

    # Discovery (Document discovery and classification workflow)
    discovery = optional(object({
      enabled = optional(bool, false)
    }), { enabled = false })

    # Chat with Document (per-document Q&A via Bedrock; no Knowledge Base needed).
    # Default-ON: enabled on every processor/example unless explicitly disabled.
    chat_with_document = optional(object({
      enabled                  = optional(bool, true)
      guardrail_id_and_version = optional(string, null)
    }), { enabled = true })

    # Process Changes (Document editing and reprocessing)
    process_changes = optional(object({
      enabled = optional(bool, false)
    }), { enabled = false })

    # Knowledge Base (external dependency for chat feature)
    knowledge_base = optional(object({
      enabled            = optional(bool, false)
      knowledge_base_arn = optional(string)
      model_id           = optional(string, "us.amazon.nova-pro-v1:0")
      embedding_model_id = optional(string, "amazon.titan-embed-text-v1")
    }), { enabled = false })

    # v0.4.8 feature flags
    enable_agent_companion_chat = optional(bool, false)
    enable_test_studio          = optional(bool, false)
    enable_fcc_dataset          = optional(bool, false)
    enable_w2_dataset           = optional(bool, false)
    enable_error_analyzer       = optional(bool, false)
    enable_mcp                  = optional(bool, false)

    # v0.5.11 — version-check resolver. When public_artifacts_bucket is
    # empty (default), the getLatestPublishedVersion resolver Lambda is not
    # created (default-off). Optional prefix/region are threaded to the Lambda.
    public_artifacts_bucket = optional(string, "")
    public_artifacts_prefix = optional(string, "artifacts/genai-idp")
    public_artifacts_region = optional(string, "")

    # v0.4.16 feature flags
    enable_hitl                     = optional(bool, true)
    enable_capacity_planning        = optional(bool, false)
    enable_omni_ai_dataset          = optional(bool, false)
    enable_docplit_poly_seq_dataset = optional(bool, false)

    # ---------------------------------------------------------------------
    # REST API transport visibility (v0.6.4). Upstream replaced AppSync with
    # an API Gateway REST API and renamed AppSyncVisibility/UsePrivateAppSync
    # to ApiGatewayVisibility/UsePrivateApi.
    # ---------------------------------------------------------------------
    # "PRIVATE" makes the REST API a PRIVATE endpoint reachable only through
    # the `execute-api` interface VPC endpoint (supply
    # api_gateway_vpc_endpoint_id), with a resource policy restricting
    # aws:SourceVpce. The default "GLOBAL" exposes a REGIONAL endpoint on the
    # public internet (still gated by the Cognito authorizer).
    api_gateway_visibility = optional(string, "GLOBAL")

    # Derived from api_gateway_visibility when null (PRIVATE => true). Set
    # explicitly only to override. Mirrors upstream UsePrivateApi.
    use_private_api = optional(bool, null)

    # VPC interface endpoint id for execute-api. Required when
    # api_gateway_visibility = "PRIVATE".
    api_gateway_vpc_endpoint_id = optional(string, "")

    # IPv4 CIDRs allowed to call the REST API. The allow-all default disables
    # WAF; any other value attaches a REGIONAL WAFv2 WebACL to the API stage.
    # Mirrors upstream WAFAllowedIPv4Ranges.
    waf_allowed_ipv4_ranges = optional(list(string), ["0.0.0.0/0"])

    # DEPRECATED (v0.6.4): renamed to `api_gateway_visibility` when the
    # transport moved from AppSync to API Gateway. Still honored — when set it
    # takes precedence and a `check` block surfaces a deprecation notice. Will
    # be removed in a future release; see
    # docs/migration-v0.5.16-to-v0.6.4.md.
    visibility = optional(string, null)
  })

  default = {
    enabled            = true
    agent_analytics    = { enabled = false }
    discovery          = { enabled = false }
    chat_with_document = { enabled = true }
    process_changes    = { enabled = false }
    knowledge_base     = { enabled = false }
  }

  validation {
    condition     = !var.api.agent_analytics.enabled || var.api.agent_analytics.model_id != null
    error_message = "When api.agent_analytics.enabled is true, model_id must be provided."
  }

  validation {
    condition     = contains(["GLOBAL", "PRIVATE"], var.api.api_gateway_visibility)
    error_message = "api.api_gateway_visibility must be \"GLOBAL\" or \"PRIVATE\"."
  }

  validation {
    # Ternary, not `x == null || contains(...)`: Terraform does not short-circuit
    # `||` when the right operand errors, and contains() rejects a null value — so
    # the `||` form fails validation on the null default (the normal case now that
    # api_gateway_visibility is the supported input).
    condition     = var.api.visibility == null ? true : contains(["GLOBAL", "PRIVATE"], var.api.visibility)
    error_message = "api.visibility (deprecated — use api.api_gateway_visibility) must be \"GLOBAL\" or \"PRIVATE\" when set."
  }

  # A PRIVATE REST API is only reachable through an execute-api interface VPC
  # endpoint, and the endpoint id is required to build both the endpoint
  # configuration and the aws:SourceVpce resource policy. Fail fast at plan
  # time rather than producing an unreachable API.
  validation {
    condition = (
      coalesce(var.api.visibility, var.api.api_gateway_visibility) != "PRIVATE" ||
      trimspace(var.api.api_gateway_vpc_endpoint_id) != ""
    )
    error_message = "When the REST API is PRIVATE you must also set api.api_gateway_vpc_endpoint_id to the execute-api interface VPC endpoint id."
  }
}

#
# Tracking table configuration — TypeDateIndex GSI backfill
#
variable "tracking" {
  description = "Configuration for the tracking table and its TypeDateIndex GSI backfill. The GSI itself is always created (additive, in place); the backfill is an operator-triggered, default-off Step Functions run that populates GSI attributes on pre-existing items."
  type = object({
    # When true, provisions the GSI-backfill module (worker Lambda + Step
    # Functions state machine). Default false. Even when enabled, the backfill
    # never runs on `terraform apply` — the operator starts the execution
    # explicitly (see module.tracking_gsi_backfill.state_machine_arn).
    enable_gsi_backfill = optional(bool, false)
  })
  default = {}
}

#
# DEPRECATED: Individual API feature variables (use 'api' variable instead)
# These will be removed in a future major version
#
variable "agent_analytics" {
  description = "DEPRECATED: Use api.agent_analytics instead. Configuration for agent analytics functionality"
  type = object({
    enabled  = optional(bool, false)
    model_id = optional(string, "us.anthropic.claude-sonnet-4-5-20250929-v1:0")
  })
  default = null
}

variable "discovery" {
  description = "DEPRECATED: Use api.discovery instead. Configuration for document discovery functionality"
  type = object({
    enabled = optional(bool, false)
  })
  default = null
}

variable "chat_with_document" {
  description = "DEPRECATED: Use api.chat_with_document instead. Configuration for chat with document functionality"
  type = object({
    enabled                  = optional(bool, false)
    guardrail_id_and_version = optional(string, null)
  })
  default = null
}

variable "process_changes" {
  description = "DEPRECATED: Use api.process_changes instead. Configuration for document editing and reprocessing functionality"
  type = object({
    enabled = optional(bool, false)
  })
  default = null
}

#
# Lambda Configuration
#
variable "lambda_tracing_mode" {
  description = "X-Ray tracing mode for Lambda functions. Valid values: Active, PassThrough"
  type        = string
  default     = "Active"

  validation {
    condition     = contains(["Active", "PassThrough"], var.lambda_tracing_mode)
    error_message = "lambda_tracing_mode must be either 'Active' or 'PassThrough'."
  }
}

#
# Processor Configuration Validation
# See locals.tf for processor validation logic

#
# Build Configuration (Lambda artifact build strategy)
#
# Controls how Lambda layers and processor container images are built:
#   - lambda_local = false (default): AWS CodeBuild builds artifacts in-cloud
#     on every apply. Preserves existing behavior bit-for-bit.
#   - lambda_local = true: artifacts are built locally on the deploy host
#     using a container runtime (Docker / Podman / Finch). Eliminates
#     CodeBuild infrastructure (projects, trigger Lambdas, IAM roles,
#     log groups) entirely. Requires a container runtime on the host.
#
# See docs/content/deployment-guides/local-lambda-build.md for details.
#
variable "build" {
  description = "Build strategy for Lambda layers and processor container images. Controls whether artifacts are built via AWS CodeBuild (default) or locally on the deploy host using Docker/Podman/Finch."
  type = object({
    # When true, build Lambda artifacts locally instead of via AWS CodeBuild.
    # Non-breaking: defaults to false (CodeBuild path). When true a container
    # runtime is required on the host (var.build.container_runtime selects it).
    lambda_local = optional(bool, false)

    # Target Lambda architecture. Propagates to compatible_architectures on
    # every layer, architectures on every function this module owns, the
    # --platform linux/${arch} flag on local Docker builds, and the
    # CodeBuild image selection on the CodeBuild path. Honored by BOTH paths.
    lambda_architecture = optional(string, "arm64")

    # Container runtime selector when lambda_local = true. "auto" probes in
    # order: docker -> podman -> finch. Explicit values skip auto-detection.
    container_runtime = optional(string, "auto")

    # When true, build the web UI locally on the deploy host via npm
    # instead of using AWS CodeBuild. Requires Node.js >= 18.
    ui_local = optional(bool, false)
  })

  default = {
    lambda_local        = false
    lambda_architecture = "arm64"
    container_runtime   = "auto"
    ui_local            = false
  }

  validation {
    condition     = contains(["x86_64", "arm64"], var.build.lambda_architecture)
    error_message = "build.lambda_architecture must be one of: x86_64, arm64."
  }

  validation {
    condition     = contains(["auto", "docker", "podman", "finch"], var.build.container_runtime)
    error_message = "build.container_runtime must be one of: auto, docker, podman, finch."
  }
}

#
# RBAC feature plugin
#
# Role-based access control modeled as a feature-plugin submodule
# (`modules/features/rbac/`), NOT a boolean on the monolithic `var.api` object.
# When `enabled`, the root instantiates `module.rbac` (features.tf): the four
# Cognito groups, the `Users` table, the user-management Lambda, and the
# server-side authorization surface, emitting the feature-plugin contract the
# API module composes.
#
# Default-off: leave `enabled = false` (the default) and no RBAC resources are
# created — the single-tenant Cognito authorization behavior is preserved. RBAC
# requires a Cognito user pool; that constraint is enforced at plan time by a
# root `check {}`.
variable "rbac" {
  description = "Configuration for the RBAC feature plugin. Default-off. When enabled, provisions the four Cognito groups, the Users table, and the user-management Lambda via module.rbac. Requires a Cognito user pool (enforced at plan time)."
  type = object({
    enabled = optional(bool, false)
    # Optional overrides for the four RBAC Cognito group names. Each key
    # defaults to its canonical name so overriding one or more does not change
    # the default-on behavior of the four roles.
    group_names = optional(object({
      admin    = optional(string, "Admin")
      author   = optional(string, "Author")
      reviewer = optional(string, "Reviewer")
      viewer   = optional(string, "Viewer")
    }), {})
    # Comma-separated list of email domains the user-management Lambda permits
    # when creating users. Empty disables domain restriction (default).
    allowed_signup_email_domains = optional(string, "")
  })
  default = {
    enabled = false
  }
}

#
# External SAML/OIDC IdP federation feature plugin
#
# Federation modeled as a feature-plugin submodule
# (`modules/features/idp-federation/`). When `enabled`, the root instantiates
# `module.idp_federation` (features.tf): the Cognito SAML/OIDC identity
# provider, the OIDC client-secret resolver (no plaintext in state), and the
# group-mapping trigger Lambda that maps external groups to the four RBAC
# groups. The submodule always emits the feature-plugin contract.
#
# Default-off: leave `enabled = false` (the default) and the user pool stays
# configured for direct Cognito authentication. The ~12 provider fields mirror
# the upstream v0.5.6 `ExternalIdP*` surface. The OIDC client secret is supplied
# by REFERENCE (`oidc_client_secret_ref` — a Secrets Manager ARN / SSM parameter
# name), never as a raw value.
variable "idp_federation" {
  description = "Configuration for the external SAML/OIDC IdP federation feature plugin. Default-off. When enabled, provisions the Cognito identity provider and group-mapping trigger via module.idp_federation. The OIDC client secret is supplied by reference (oidc_client_secret_ref), never in plaintext."
  type = object({
    enabled                = optional(bool, false)
    provider_type          = optional(string, "SAML")
    provider_name          = optional(string, "ExternalIdP")
    saml_metadata_url      = optional(string, "")
    saml_metadata_file     = optional(string, "")
    oidc_issuer            = optional(string, "")
    oidc_client_id         = optional(string, "")
    oidc_client_secret_ref = optional(string, "")
    oidc_authorize_scopes  = optional(string, "openid email profile")
    attribute_mapping      = optional(map(string), {})
    group_attribute_name   = optional(string, "")
    group_mapping          = optional(map(string), {})
  })
  default = {
    enabled = false
  }
}

variable "seed_managed_configs" {
  description = "Seed the managed baseline configuration versions (sources/config_library/managed_config) as non-active, non-editable reference rows. Set false to skip them."
  type        = bool
  default     = true
}

# Feature Platform (installable features). Default-ON to match upstream IDP
# v0.5.16 (EnableFeaturePlatform defaults to 'true'). Requires the API
# (AppSync) to be enabled, which is the default (`api.enabled = true`). Set
# `enabled = false` to remove the platform entirely (no platform resources
# are created). Mirrors upstream EnableFeaturePlatform + related parameters.
variable "feature_platform" {
  description = "Configuration for the Feature Platform (installable features). Enabled by default to match upstream; requires the API enabled. Set enabled=false to remove the platform entirely."
  type = object({
    enabled                     = optional(bool, true)
    simulator_endpoint          = optional(string, "")
    subscription_mode           = optional(string, "auto-subscribe")
    default_customer_identifier = optional(string, "")
    default_buyer_account_id    = optional(string, "")
    feature_offer_id_map        = optional(string, "{}")
    admin_group_name            = optional(string, "Admin")
    configuration_bucket_name   = optional(string, "")
    catalog_key                 = optional(string, "feature-platform/catalog.json")
    artifact_region             = optional(string, "")
    seller_bucket_object_arns   = optional(list(string), [])
  })
  default = {}
}

# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
variable "name" {
  description = "The name of the GraphQL API"
  type        = string
  default     = null
}

variable "xray_enabled" {
  description = "A flag indicating whether or not X-Ray tracing is enabled for the GraphQL API"
  type        = bool
  default     = false
}

variable "visibility" {
  description = "A value indicating whether the API is accessible from anywhere (GLOBAL) or can only be access from a VPC (PRIVATE)"
  type        = string
  default     = "GLOBAL"
  validation {
    condition     = contains(["GLOBAL", "PRIVATE"], var.visibility)
    error_message = "Allowed values for visibility are \"GLOBAL\" or \"PRIVATE\"."
  }
}

variable "resolver_count_limit" {
  description = "A number indicating the maximum number of resolvers that should be accepted when handling queries"
  type        = number
  default     = 0
}

variable "query_depth_limit" {
  description = "A number indicating the maximum depth resolvers should be accepted when handling queries"
  type        = number
  default     = 0
}

variable "owner_contact" {
  description = "The owner contact information for an API resource"
  type        = string
  default     = null
}

variable "log_config" {
  description = "Logging configuration for this API"
  type = object({
    cloudwatch_logs_role_arn = optional(string)
    exclude_verbose_content  = optional(bool, false)
    field_log_level          = string
  })
  default = null
}

variable "introspection_config" {
  description = "A value indicating whether the API to enable (ENABLED) or disable (DISABLED) introspection"
  type        = string
  default     = "ENABLED"
  validation {
    condition     = contains(["ENABLED", "DISABLED"], var.introspection_config)
    error_message = "Allowed values for introspection_config are \"ENABLED\" or \"DISABLED\"."
  }
}

variable "environment_variables" {
  description = "A map containing the list of resources with their properties and environment variables"
  type        = map(string)
  default     = {}
}

variable "domain_name" {
  description = "The domain name configuration for the GraphQL API"
  type = object({
    certificate_arn = string
    domain_name     = string
  })
  default = null
}

variable "authorization_config" {
  description = "Authorization configuration for the GraphQL API. Must be set explicitly; the module no longer defaults to API_KEY because that exposes every mutation to anyone with the key."
  type = object({
    default_authorization = object({
      authorization_type = string
      user_pool_config = optional(object({
        user_pool_id        = string
        app_id_client_regex = optional(string)
        aws_region          = optional(string)
        default_action      = optional(string, "ALLOW")
      }))
      openid_connect_config = optional(object({
        auth_ttl  = optional(number)
        client_id = optional(string)
        iat_ttl   = optional(number)
        issuer    = string
      }))
      lambda_authorizer_config = optional(object({
        authorizer_result_ttl_seconds  = optional(number)
        authorizer_uri                 = string
        identity_validation_expression = optional(string)
      }))
    })
    additional_authorization_modes = optional(list(object({
      authorization_type = string
      user_pool_config = optional(object({
        user_pool_id        = string
        app_id_client_regex = optional(string)
        aws_region          = optional(string)
        default_action      = optional(string, "ALLOW")
      }))
      openid_connect_config = optional(object({
        auth_ttl  = optional(number)
        client_id = optional(string)
        iat_ttl   = optional(number)
        issuer    = string
      }))
      lambda_authorizer_config = optional(object({
        authorizer_result_ttl_seconds  = optional(number)
        authorizer_uri                 = string
        identity_validation_expression = optional(string)
      }))
    })))
  })
  default = null

  validation {
    condition     = var.authorization_config == null || try(var.authorization_config.default_authorization.authorization_type, null) != "API_KEY"
    error_message = "authorization_config.default_authorization.authorization_type must not be API_KEY. API_KEY exposes every AppSync mutation to anyone with the key. Use AMAZON_COGNITO_USER_POOLS, AWS_IAM, OPENID_CONNECT, or AWS_LAMBDA."
  }
}

# S3 Bucket Variables - New ARN-based approach
variable "input_bucket_arn" {
  description = "ARN of the S3 bucket where source documents are stored"
  type        = string
  default     = null
}

variable "output_bucket_arn" {
  description = "ARN of the S3 bucket where processed document outputs are stored"
  type        = string
  default     = null
}

variable "evaluation_enabled" {
  description = "Whether evaluation functionality is enabled"
  type        = bool
  default     = false
}

variable "evaluation_baseline_bucket_arn" {
  description = "ARN of the S3 bucket for storing evaluation baseline documents"
  type        = string
  default     = null
}

# DynamoDB Table Variables - New ARN-based approach
variable "tracking_table_arn" {
  description = "ARN of the DynamoDB table for tracking document processing status"
  type        = string
  default     = null
}

variable "configuration_table_arn" {
  description = "ARN of the DynamoDB table for storing configuration settings"
  type        = string
  default     = null
}

# KMS Key Variable - New ARN-based approach
variable "encryption_key_arn" {
  description = "ARN of the KMS key for encryption"
  type        = string
  default     = null
}

# Legacy object-based variables for backward compatibility
variable "evaluation_baseline_bucket" {
  description = "Optional S3 bucket name for storing evaluation baseline documents (Legacy format - use evaluation_baseline_bucket_arn instead)"
  type = object({
    bucket_name = string
    bucket_arn  = string
  })
  default = null
}

variable "knowledge_base" {
  description = "Knowledge base configuration object"
  type = object({
    enabled                  = bool
    knowledge_base_arn       = optional(string)
    model_id                 = optional(string)
    guardrail_id_and_version = optional(string)
  })
  default = {
    enabled                  = false
    knowledge_base_arn       = null
    model_id                 = null
    guardrail_id_and_version = null
  }
}

variable "guardrail" {
  description = "Optional Bedrock guardrail to apply to model interactions"
  type = object({
    guardrail_id  = string
    guardrail_arn = string
  })
  default = null
}

variable "tracking_table" {
  description = "The DynamoDB table for tracking document processing status (Legacy format - use tracking_table_arn instead)"
  type = object({
    table_name = string
    table_arn  = string
  })
  default = null
}

variable "configuration_table" {
  description = "The DynamoDB table for storing configuration settings (Legacy format - use configuration_table_arn instead)"
  type = object({
    table_name = string
    table_arn  = string
  })
  default = null
}

variable "log_level" {
  description = "Log level for Lambda functions"
  type        = string
  default     = "INFO"
  validation {
    condition     = contains(["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"], var.log_level)
    error_message = "Allowed values for log_level are \"DEBUG\", \"INFO\", \"WARNING\", \"ERROR\", or \"CRITICAL\"."
  }
}

variable "log_retention_days" {
  description = "Log retention period in days"
  type        = number
  default     = 7
  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "Log retention days must be one of the allowed values."
  }
}

variable "vpc_config" {
  description = "VPC configuration for Lambda functions"
  type = object({
    subnet_ids         = list(string)
    security_group_ids = list(string)
  })
  default = null
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "lambda_tracing_mode" {
  description = "X-Ray tracing mode for Lambda functions. Valid values: Active, PassThrough"
  type        = string
  default     = "Active"

  validation {
    condition     = contains(["Active", "PassThrough"], var.lambda_tracing_mode)
    error_message = "lambda_tracing_mode must be either 'Active' or 'PassThrough'."
  }
}

variable "agent_analytics" {
  description = "Agent analytics configuration"
  type = object({
    enabled                 = bool
    model_id                = optional(string, "us.anthropic.claude-sonnet-4-5-20250929-v1:0")
    reporting_database_name = optional(string)
    reporting_bucket_arn    = optional(string)
  })
  default = { enabled = false }
}

variable "discovery" {
  description = "Discovery workflow configuration"
  type = object({
    enabled = bool
  })
  default = { enabled = false }
}

variable "chat_with_document" {
  description = "Chat with Document functionality configuration"
  type = object({
    enabled                  = bool
    guardrail_id_and_version = optional(string, null)
  })
  default = { enabled = false }
}

# =============================================================================
# EDIT SECTIONS FEATURE VARIABLES
# =============================================================================

variable "enable_edit_sections" {
  description = "Whether to enable the Edit Sections feature for selective reprocessing"
  type        = bool
  default     = false
}

variable "working_bucket_arn" {
  description = "ARN of the S3 bucket for working files (required for Edit Sections feature)"
  type        = string
  default     = null
}

variable "document_queue_url" {
  description = "URL of the SQS queue for document processing (required for Edit Sections feature)"
  type        = string
  default     = null
}

variable "document_queue_arn" {
  description = "ARN of the SQS queue for document processing (required for Edit Sections feature)"
  type        = string
  default     = null
}

variable "data_retention_in_days" {
  description = "Data retention period in days for processed documents"
  type        = number
  default     = 7
}

variable "idp_common_layer_arn" {
  description = "ARN of the IDP Common Lambda layer (required for Edit Sections feature)"
  type        = string
  default     = null
}

variable "base_layer_arn" {
  description = "ARN of the base Lambda layer containing shared Python dependencies (from processing-environment module)"
  type        = string
  default     = null
}

variable "enable_encryption" {
  description = "Enable encryption for resources"
  type        = bool
  default     = true
}

variable "lambda_layers_bucket_arn" {
  description = "ARN of the S3 bucket for Lambda layers"
  type        = string
  default     = null
}

# =============================================================================
# FEATURE FLAG VARIABLES (v0.4.8)
# =============================================================================

variable "enable_agent_companion_chat" {
  description = "Enable Agent Companion Chat feature (multi-agent AI chat sessions)"
  type        = bool
  default     = true
}

variable "enable_hitl" {
  description = "Enable built-in HITL review via complete_section_review Lambda (v0.4.9+). Replaces SageMaker A2I."
  type        = bool
  default     = true
}

variable "enable_test_studio" {
  description = "Enable Test Studio feature (automated dataset testing)"
  type        = bool
  default     = true
}

variable "enable_fcc_dataset" {
  description = "Enable FCC dataset deployer (deploys sample FCC dataset for Test Studio)"
  type        = bool
  default     = false
}

variable "enable_w2_dataset" {
  description = "Enable W2 dataset deployer (deploys the Fake W-2 Tax Form sample dataset for Test Studio). Requires enable_test_studio = true."
  type        = bool
  default     = false
}

# =============================================================================
# VERSION-CHECK FEATURE VARIABLES (v0.5.11)
# =============================================================================

variable "public_artifacts_bucket" {
  description = "Name of the (optionally public / cross-account) S3 bucket the version_check_resolver Lambda lists for `<prefix>/idp-main_<version>.yaml` templates. When empty (default), the version-check Lambda, AppSync data source, and resolver are not created (default-off)."
  type        = string
  default     = ""
}

variable "public_artifacts_prefix" {
  description = "S3 key prefix under public_artifacts_bucket where versioned IDP templates live. Threaded into the resolver's PUBLIC_ARTIFACTS_PREFIX env var. Only used when public_artifacts_bucket is set."
  type        = string
  default     = "artifacts/genai-idp"
}

variable "public_artifacts_region" {
  description = "Region of public_artifacts_bucket, threaded into the resolver's PUBLIC_ARTIFACTS_REGION env var. When empty, the shipped resolver defaults to AWS_REGION. Only used when public_artifacts_bucket is set."
  type        = string
  default     = ""
}

variable "enable_error_analyzer" {
  description = "DEPRECATED (no-op as of v0.5.12). The standalone Error Analyzer Lambdas were removed upstream; error analysis is now provided by the unified agents framework (Error-Analyzer-Agent via the agent resolvers). Retained for backward compatibility; setting it has no effect."
  type        = bool
  default     = false
}

variable "bda_project_arn" {
  description = "ARN of the BDA Data Automation Project (used by sync_bda_idp resolver). Leave empty if not using BDA processor."
  type        = string
  default     = ""
}

variable "enable_capacity_planning" {
  description = "Enable Capacity Planning feature (v0.4.13+). Deploys calculate_capacity and calculate_capacity_resolver Lambdas."
  type        = bool
  default     = false
}

variable "enable_omni_ai_dataset" {
  description = "Enable OmniAI OCR Benchmark dataset deployer (v0.4.15+). Requires enable_test_studio = true."
  type        = bool
  default     = false
}

variable "enable_docplit_poly_seq_dataset" {
  description = "Enable DocSplit RVL-CDIP-NMP Packet dataset deployer (v0.4.15+). Requires enable_test_studio = true."
  type        = bool
  default     = false
}

variable "post_processing_decompressor_arn" {
  description = "ARN of the post_processing_decompressor Lambda function (from processing-environment module)"
  type        = string
  default     = null
}

variable "state_machine_arn" {
  description = "ARN of the Step Functions state machine (used by Error Analyzer)"
  type        = string
  default     = null
}

variable "lookup_function_name" {
  description = "Name of the LookupFunction Lambda (used by Agent Chat Processor to look up document info)"
  type        = string
  default     = null
}

# =============================================================================
# Feature-plugin composition (.enable()-style wiring)
# =============================================================================
#
# NOTE: MCP integration moved to the `mcp-integration` feature submodule in
# v0.5.12-tf.0. Its former inputs (`user_pool_id`, `mcp_callback_urls`) now live
# on `modules/features/mcp-integration` and are wired at the root (features.tf).

variable "enabled_feature_contracts" {
  description = <<-EOT
    Map of enabled feature-plugin contracts to compose into the API, mirroring
    the CDK accelerator's `api.enable(feature)` mechanism. Each value is a
    feature submodule's outputs contract with the shape:

      {
        enabled          = bool
        resolvers        = { <field> = { data_source, request_template, response_template } }
        iam_statements   = [ <policy statement objects> ]
        environment      = { <env-var name> = <value> }
        schema_additions = optional(string)  # GraphQL SDL fragment
      }

    Default `{}` is a no-op: no feature resolvers, IAM statements, or env vars
    are composed (default-off preserved).
  EOT
  type        = any
  default     = {}
}

variable "has_feature_iam" {
  description = "Whether an enabled feature contributes IAM statements to compose."
  type        = bool
  default     = false
}

#
# Build strategy pass-through (see root var.build in variables.tf)
#
variable "lambda_local" {
  description = "When true, build Lambda layers locally using a container runtime instead of via AWS CodeBuild."
  type        = bool
  default     = false
}

variable "lambda_architecture" {
  description = "Target Lambda architecture (x86_64 | arm64)."
  type        = string
  default     = "arm64"

  validation {
    condition     = contains(["x86_64", "arm64"], var.lambda_architecture)
    error_message = "lambda_architecture must be one of: x86_64, arm64."
  }
}

variable "container_runtime" {
  description = "Container runtime for local builds (auto|docker|podman|finch)."
  type        = string
  default     = "auto"

  validation {
    condition     = contains(["auto", "docker", "podman", "finch"], var.container_runtime)
    error_message = "container_runtime must be one of: auto, docker, podman, finch."
  }
}

# =============================================================================
# PRESIGNED-URL-VIA-VPCE (v0.5.16)
# =============================================================================

variable "s3_endpoint_url" {
  description = <<-EOT
    Optional S3 endpoint URL for presigner/dataset Lambdas. When set (e.g.
    "https://bucket.vpce-abc123.s3.us-east-1.vpce.amazonaws.com"), those
    Lambdas generate presigned URLs and issue S3 calls against the S3 interface
    VPC endpoint using virtual-host addressing (private-network path). When
    null (default), presigned URLs use the global regional S3 endpoint.
    Mirrors upstream S3PresignedUrlViaVpcEndpoint / S3VpcEndpointDnsNameOverride.
  EOT
  type        = string
  default     = null
}

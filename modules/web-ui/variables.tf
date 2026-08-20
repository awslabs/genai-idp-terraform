# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Core module inputs
variable "name_prefix" {
  description = "Prefix for resource naming"
  type        = string
}

variable "prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "display_name" {
  description = "Display name for the stack (passed from top-level web_ui.display_name configuration)"
  type        = string
  default     = null
}

variable "reporting_bucket_name" {
  description = "Name of the reporting S3 bucket (extracted from reporting bucket ARN)"
  type        = string
  default     = ""
}

variable "evaluation_baseline_bucket_name" {
  description = "Name of the evaluation baseline S3 bucket (extracted from evaluation baseline bucket ARN)"
  type        = string
  default     = ""
}

variable "discovery_bucket_name" {
  description = "Name of the discovery S3 bucket (if discovery is enabled)"
  type        = string
  default     = null
}

variable "knowledge_base_enabled" {
  description = "Whether Knowledge Base functionality is enabled"
  type        = bool
  default     = false
}

variable "idp_pattern" {
  description = "IDP processing pattern name (mapped from processor type)"
  type        = string
  default     = ""
}

variable "console_title" {
  description = "Title shown in the Web UI top-navigation banner. Mirrors upstream ConsoleTitle."
  type        = string
  default     = "IDP Accelerator Console"
}

variable "idp_version" {
  description = "Upstream IDP version string surfaced in the Web UI Deployment Info panel. Should track the IDP_VERSION file at the repo root."
  type        = string
}

#
# Infrastructure Configuration
#
variable "create_infrastructure" {
  description = "Whether to create CloudFront distribution and web app bucket with default settings"
  type        = bool
  default     = true
}

variable "web_app_bucket_name" {
  description = "Name of S3 bucket for hosting the web application (required when create_infrastructure is false)"
  type        = string
  default     = null
}

variable "hosting" {
  description = <<-EOT
    Web UI hosting mode. "CloudFront" (default) creates a CloudFront
    distribution in front of the web app bucket. "ALB" skips CloudFront and
    expects an Application Load Balancer (see modules/web-ui-alb) to serve the
    bucket via an S3 interface VPC endpoint. Mirrors upstream WebUIHosting.
  EOT
  type        = string
  default     = "CloudFront"
  validation {
    condition     = contains(["CloudFront", "ALB"], var.hosting)
    error_message = "hosting must be CloudFront or ALB."
  }
}

variable "web_ui_url" {
  description = <<-EOT
    Public URL the browser uses to reach the Web UI. Used for input/output
    bucket CORS allowed-origins and the UI build environment. In CloudFront
    mode this is derived from the distribution; in ALB mode supply the custom
    domain URL fronting the ALB (mirrors upstream CustomDomainUrl). When null
    in ALB mode, CORS falls back to "*".
  EOT
  type        = string
  default     = null
}

variable "cloudfront_distribution_id" {
  description = "CloudFront distribution ID for cache invalidation (optional - skip invalidation if not provided)"
  type        = string
  default     = null
}

#
# Processing Environment Integration
#
variable "input_bucket_arn" {
  description = "ARN of the S3 bucket for input files"
  type        = string
}

variable "output_bucket_arn" {
  description = "ARN of the S3 bucket for output files"
  type        = string
}


variable "encryption_key_arn" {
  description = "ARN of the KMS key for encryption"
  type        = string
}

#
# API Integration
#
variable "api_url" {
  description = "Base URL of the REST API transport for the processing environment (VITE_API_BASE_URL). The SPA POSTs to <api_url>/op/<field>. Formerly the AppSync GraphQL endpoint (VITE_APPSYNC_GRAPHQL_URL) before the v0.6.4 REST migration; the input name is retained."
  type        = string
}

variable "stream_url" {
  description = "Function URL of the chat token-streaming endpoint (VITE_STREAM_URL). Null (default) when chat streaming is disabled; rendered as an empty string in the UI config."
  type        = string
  default     = null
}

#
# User Identity Integration
#
variable "user_identity" {
  description = "The user identity management system that handles authentication and authorization"
  type = object({
    user_pool = object({
      user_pool_id  = string
      user_pool_arn = string
      endpoint      = string
    })
    user_pool_client = object({
      user_pool_client_id = string
    })
    identity_pool = object({
      identity_pool_id       = string
      authenticated_role_arn = string
    })
  })
}

#
# Optional Infrastructure (when create_infrastructure = true)
#
variable "logging_bucket" {
  description = "Optional S3 bucket for storing CloudFront and S3 access logs (only used when create_infrastructure is true)"
  type = object({
    bucket_name = string
    bucket_arn  = string
  })
  default = null
}

#
# Web UI Configuration
#
variable "should_allow_sign_up_email_domain" {
  description = "Controls whether the UI allows users to sign up with any email domain"
  type        = bool
  default     = false
}

#
# CloudFront Configuration (when create_infrastructure = true)
#
variable "enable_waf" {
  description = "Enable WAF protection for CloudFront distribution (only used when create_infrastructure is true)"
  type        = bool
  default     = true
}

variable "waf_rate_limit" {
  description = "Rate limit for WAF (requests per 5-minute period, only used when create_infrastructure is true)"
  type        = number
  default     = 2000
}

variable "custom_domain_name" {
  description = "Custom domain name for CloudFront distribution (only used when create_infrastructure is true)"
  type        = string
  default     = null
}

variable "acm_certificate_arn" {
  description = "ARN of ACM certificate for custom domain (must be in us-east-1, only used when create_infrastructure is true)"
  type        = string
  default     = null
}

#
# Network Configuration (Optional)
#
variable "vpc_id" {
  description = "ID of the VPC for network integration"
  type        = string
  default     = null
}

variable "subnet_ids" {
  description = "List of subnet IDs for network integration"
  type        = list(string)
  default     = []
}

variable "security_group_ids" {
  description = "List of security group IDs for network integration"
  type        = list(string)
  default     = []
}

#
# Common Configuration
#
variable "lambda_tracing_mode" {
  description = "X-Ray tracing mode for Lambda functions. Valid values: Active, PassThrough"
  type        = string
  default     = "Active"
}

variable "ui_local" {
  description = "When true, build the web UI locally via npm instead of using AWS CodeBuild. Requires Node.js >= 18 on the deploy host."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "lambda_architecture" {
  description = "Target Lambda architecture (x86_64 | arm64). Must match the architecture the idp_common layers were built for; mismatches break native deps (e.g. pydantic_core)."
  type        = string
  default     = "arm64"
  validation {
    condition     = contains(["x86_64", "arm64"], var.lambda_architecture)
    error_message = "lambda_architecture must be one of: x86_64, arm64."
  }
}

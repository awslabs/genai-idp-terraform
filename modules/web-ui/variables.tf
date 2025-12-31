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
  description = "The GraphQL API URL for the processing environment"
  type        = string
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

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

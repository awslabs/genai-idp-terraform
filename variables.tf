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
# Feature Flags
#
variable "enable_api" {
  description = "Enable GraphQL API for programmatic access and notifications"
  type        = bool
  default     = true
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
    enable_assessment = optional(bool, false)
    enable_hitl       = optional(bool, false)
    config            = any
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
  })
  default = null
}

variable "sagemaker_udop_processor" {
  description = "Configuration for SageMaker UDOP processor"
  type = object({
    classification_endpoint_arn = string
    summarization = optional(object({
      enabled  = optional(bool, true)
      model_id = optional(string, null)
    }), { enabled = true, model_id = null })
    enable_assessment          = optional(bool, false)
    ocr_max_workers            = optional(number, 20)
    classification_max_workers = optional(number, 20)
    config                     = any
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
  description = "Configuration for human review functionality in document processing"
  type = object({
    enabled                   = optional(bool, false)
    user_group_name           = optional(string)
    user_pool_id              = optional(string)
    private_workforce_arn     = optional(string)
    workteam_name             = optional(string)
    enable_pattern2_hitl      = optional(bool, false)
    hitl_confidence_threshold = optional(number, 80)
  })
  default = {
    enabled                   = false
    enable_pattern2_hitl      = false
    hitl_confidence_threshold = 80
  }

  validation {
    condition = var.human_review.enabled == false || (
      var.human_review.user_group_name != null &&
      var.human_review.user_pool_id != null &&
      var.human_review.private_workforce_arn != null &&
      var.human_review.workteam_name != null
    )
    error_message = "When human_review.enabled is true, user_group_name, user_pool_id, private_workforce_arn, and workteam_name are required."
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
}

#
# Knowledge Base Configuration
#
variable "knowledge_base" {
  description = "Configuration for AWS Bedrock Knowledge Base functionality"
  type = object({
    enabled            = optional(bool, false)
    knowledge_base_arn = optional(string)
    model_id           = optional(string, "us.amazon.nova-pro-v1:0")
    embedding_model_id = optional(string, "amazon.titan-embed-text-v1")
  })
  default = {
    enabled = false
  }

  validation {
    condition     = var.knowledge_base.enabled == false || var.knowledge_base.knowledge_base_arn != null
    error_message = "When knowledge_base.enabled is true, knowledge_base_arn is required."
  }
}

#
# Agent Analytics Configuration
#
variable "agent_analytics" {
  description = "Configuration for agent analytics functionality"
  type = object({
    enabled  = optional(bool, false)
    model_id = optional(string, "us.anthropic.claude-3-5-sonnet-20241022-v2:0")
  })
  default = { enabled = false }

  validation {
    condition     = !var.agent_analytics.enabled || var.agent_analytics.model_id != null
    error_message = "When agent_analytics.enabled is true, model_id must be provided."
  }
}

#
# Discovery Configuration
#
variable "discovery" {
  description = "Configuration for document discovery functionality"
  type = object({
    enabled = optional(bool, false)
  })
  default = { enabled = false }
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

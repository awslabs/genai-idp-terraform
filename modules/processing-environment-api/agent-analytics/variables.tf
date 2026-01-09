# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "reporting_database_name" {
  description = "Name of the Glue database for reporting"
  type        = string
}



variable "athena_results_bucket_arn" {
  description = "ARN of the S3 bucket for Athena query results"
  type        = string
}

variable "reporting_bucket_arn" {
  description = "ARN of the S3 bucket containing reporting data"
  type        = string
}

variable "appsync_api_url" {
  description = "URL of the AppSync GraphQL API for status updates"
  type        = string
}

variable "appsync_api_id" {
  description = "ID of the AppSync GraphQL API"
  type        = string
}

variable "idp_common_layer_arn" {
  description = "ARN of the IDP common Lambda layer"
  type        = string
}

variable "lambda_layers_bucket_arn" {
  description = "ARN of the S3 bucket for storing Lambda layers. If not provided, a new bucket will be created."
  type        = string
  default     = null
}

variable "bedrock_model_id" {
  description = "Bedrock model ID for the analytics agent"
  type        = string
  default     = "us.anthropic.claude-3-5-sonnet-20241022-v2:0"
}

variable "log_level" {
  description = "Log level for Lambda functions"
  type        = string
  default     = "INFO"

  validation {
    condition     = contains(["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"], var.log_level)
    error_message = "log_level must be one of: DEBUG, INFO, WARNING, ERROR, CRITICAL."
  }
}

variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 7

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "log_retention_days must be a valid CloudWatch Logs retention period."
  }
}

variable "data_retention_days" {
  description = "Number of days to retain agent job data in DynamoDB"
  type        = number
  default     = 30
}

variable "encryption_key_arn" {
  description = "ARN of the KMS key for encryption"
  type        = string
  default     = null
}

variable "enable_encryption" {
  description = "Whether encryption is enabled. Use this instead of checking encryption_key_arn != null to avoid unknown value issues in for_each/count."
  type        = bool
  default     = false
}

variable "vpc_subnet_ids" {
  description = "List of subnet IDs for Lambda functions"
  type        = list(string)
  default     = []
}

variable "vpc_security_group_ids" {
  description = "List of security group IDs for Lambda functions"
  type        = list(string)
  default     = []
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

variable "point_in_time_recovery_enabled" {
  description = "Enable point-in-time recovery for DynamoDB tables"
  type        = bool
  default     = true
}

variable "configuration_table_name" {
  description = "Name of the DynamoDB configuration table"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

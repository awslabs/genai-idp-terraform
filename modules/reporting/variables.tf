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

variable "reporting_bucket_arn" {
  description = "ARN of the S3 bucket for reporting data"
  type        = string
}

variable "output_bucket_arn" {
  description = "ARN of the S3 bucket for processed documents"
  type        = string
}

variable "output_bucket_name" {
  description = "Name of the S3 bucket for processed documents"
  type        = string
}

variable "metric_namespace" {
  description = "Namespace for CloudWatch metrics"
  type        = string
}

variable "log_level" {
  description = "Log level for Lambda functions"
  type        = string
  default     = "INFO"
}

variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 7
}

variable "crawler_table_level" {
  description = "Table level configuration for the Glue crawler (1-3). Higher levels allow more granular partitioning but may cause warnings if data doesn't support the level."
  type        = number
  default     = 2
  validation {
    condition     = var.crawler_table_level >= 1 && var.crawler_table_level <= 3
    error_message = "Crawler table level must be between 1 and 3."
  }
}

variable "encryption_key_arn" {
  description = "ARN of the KMS key for encryption"
  type        = string
  default     = null
}

variable "configuration_table_arn" {
  description = "ARN of the DynamoDB table for configuration settings"
  type        = string
}

variable "configuration_table_name" {
  description = "Name of the DynamoDB table for configuration settings"
  type        = string
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

variable "idp_common_layer_arn" {
  description = "ARN of the IDP common Lambda layer"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
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

variable "crawler_schedule" {
  description = "Schedule for the Glue crawler. Valid values: manual, 15min, hourly, daily"
  type        = string
  default     = "daily"

  validation {
    condition     = contains(["manual", "15min", "hourly", "daily"], var.crawler_schedule)
    error_message = "crawler_schedule must be one of: manual, 15min, hourly, daily."
  }
}

variable "enable_partition_projection" {
  description = "Enable partition projection for Glue tables"
  type        = bool
  default     = true
}

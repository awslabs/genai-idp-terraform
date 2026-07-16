# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
variable "name_prefix" {
  description = "Prefix applied to the names of resources created by this module"
  type        = string
}

variable "tracking_table_name" {
  description = "Name of the tracking DynamoDB table whose GSI attributes are backfilled"
  type        = string
}

variable "tracking_table_arn" {
  description = "ARN of the tracking DynamoDB table. The worker is granted access to exactly this table and its indexes (<arn>/index/*)"
  type        = string
}

variable "encryption_key_arn" {
  description = "ARN of the customer-managed KMS key used to encrypt the tracking table and the worker's log group"
  type        = string
}

variable "base_layer_arn" {
  description = "ARN of the base Lambda layer attached to the backfill worker"
  type        = string
  default     = null
}

variable "idp_common_layer_arn" {
  description = "ARN of the idp_common Lambda layer attached to the backfill worker"
  type        = string
  default     = null
}

variable "log_level" {
  description = "Log level for the backfill worker Lambda"
  type        = string
  default     = "INFO"
  validation {
    condition     = contains(["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"], var.log_level)
    error_message = "Allowed values for log_level are \"DEBUG\", \"INFO\", \"WARNING\", \"ERROR\", or \"CRITICAL\"."
  }
}

variable "log_retention_days" {
  description = "CloudWatch log retention period in days for the backfill worker"
  type        = number
  default     = 7
  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "Log retention days must be one of the allowed values."
  }
}

variable "tags" {
  description = "A map of tags to add to all resources created by this module"
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

# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

variable "name_prefix" {
  description = "Prefix for all resource names created by this module"
  type        = string
}

variable "idp_input_bucket_arn" {
  description = "ARN of the IDP input bucket where merged bundles are written"
  type        = string
}

variable "idp_input_bucket_name" {
  description = "Name of the IDP input bucket where merged bundles are written"
  type        = string
}

variable "default_config_version" {
  description = "Config version stamped on merged bundles when a manifest omits config_version"
  type        = string
  default     = "default"
}

variable "encryption_key_arn" {
  description = "ARN of the KMS key for encryption (staging bucket, Lambda env, logs). Null = AWS-managed."
  type        = string
  default     = null
}

variable "staging_retention_days" {
  description = "Days after which staged bundle parts are expired from the staging bucket"
  type        = number
  default     = 7
}

variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 30
}

variable "lambda_tracing_mode" {
  description = "X-Ray tracing mode for the assembler Lambda (Active or PassThrough)"
  type        = string
  default     = "Active"

  validation {
    condition     = contains(["Active", "PassThrough"], var.lambda_tracing_mode)
    error_message = "lambda_tracing_mode must be either 'Active' or 'PassThrough'."
  }
}

variable "vpc_subnet_ids" {
  description = "Subnet IDs for the assembler Lambda (empty = no VPC)"
  type        = list(string)
  default     = []
}

variable "vpc_security_group_ids" {
  description = "Security group IDs for the assembler Lambda (empty = no VPC)"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

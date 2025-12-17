# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "tracking_table_name" {
  description = "Name of the DynamoDB tracking table"
  type        = string
}

variable "tracking_table_arn" {
  description = "ARN of the DynamoDB tracking table"
  type        = string
}

variable "working_bucket_name" {
  description = "Name of the S3 working bucket"
  type        = string
}

variable "working_bucket_arn" {
  description = "ARN of the S3 working bucket"
  type        = string
}

variable "sagemaker_a2i_review_portal_url" {
  description = "URL of the SageMaker A2I review portal"
  type        = string
  default     = ""
}

variable "log_level" {
  description = "Log level for Lambda function"
  type        = string
  default     = "INFO"
}

variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 7
}

variable "encryption_key_arn" {
  description = "ARN of the KMS key for encryption"
  type        = string
  default     = null
}

variable "vpc_subnet_ids" {
  description = "List of subnet IDs for Lambda function"
  type        = list(string)
  default     = []
}

variable "vpc_security_group_ids" {
  description = "List of security group IDs for Lambda function"
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

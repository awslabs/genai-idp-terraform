# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
variable "name_prefix" {
  description = "Prefix for resource naming and lambda layers"
  type        = string
}

variable "requirements_files" {
  description = "Map of function names to requirements file contents"
  type        = map(string)
}

variable "requirements_hash" {
  description = "Hash of the requirements files to trigger rebuilds only when they change"
  type        = string
  default     = "" # Default to empty string if not provided
}

variable "force_rebuild" {
  description = "Force rebuild of lambda layers regardless of requirements changes"
  type        = bool
  default     = false
}

variable "lambda_layers_bucket_arn" {
  description = "ARN of the S3 bucket for storing Lambda layers. This is required and should be provided by the assets-bucket module."
  type        = string

  validation {
    condition     = var.lambda_layers_bucket_arn != ""
    error_message = "lambda_layers_bucket_arn is required and cannot be empty."
  }
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

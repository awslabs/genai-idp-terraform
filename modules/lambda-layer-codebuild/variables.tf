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

#
# Build strategy (controls dispatcher in main.tf)
#
# When lambda_local = false (default), this module behaves bit-for-bit as before:
# it provisions an aws_codebuild_project, an IAM role/policy, a trigger Lambda,
# CloudWatch log group, time_sleep IAM-propagation guard, and uploads requirements
# to S3. When lambda_local = true, all those CodeBuild resources collapse to
# count = 0 and a sub-module modules/lambda-layer-local-build is instantiated
# instead, producing equivalent layer artifacts via Docker on the deploy host.
#
variable "lambda_local" {
  description = "When true, build the Lambda layer locally on the deploy host instead of via AWS CodeBuild. See modules/lambda-layer-local-build."
  type        = bool
  default     = false
}

variable "lambda_architecture" {
  description = "Target Lambda architecture (x86_64 | arm64). Sets compatible_architectures on the produced aws_lambda_layer_version regardless of build path."
  type        = string
  default     = "x86_64"

  validation {
    condition     = contains(["x86_64", "arm64"], var.lambda_architecture)
    error_message = "lambda_architecture must be one of: x86_64, arm64."
  }
}

variable "container_runtime" {
  description = "Container runtime for local builds (auto|docker|podman|finch). Ignored when lambda_local = false."
  type        = string
  default     = "auto"

  validation {
    condition     = contains(["auto", "docker", "podman", "finch"], var.container_runtime)
    error_message = "container_runtime must be one of: auto, docker, podman, finch."
  }
}

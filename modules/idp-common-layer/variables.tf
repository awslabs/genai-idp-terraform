# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
variable "lambda_layers_bucket_arn" {
  description = "ARN of the S3 bucket for storing Lambda layers. If not provided, a new bucket will be created."
  type        = string
  default     = ""
}

variable "layer_prefix" {
  description = "Prefix for the lambda layers (should be unique per deployment)"
  type        = string
  default     = "idp-common"
}

variable "idp_common_extras" {
  description = "List of extra dependencies to include (e.g., ['ocr', 'classification', 'extraction'])"
  type        = list(string)
  default     = ["all"]
}

variable "force_rebuild" {
  description = "Force rebuild of lambda layers regardless of requirements changes"
  type        = bool
  default     = false
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
# Build strategy pass-through (see root var.build in variables.tf)
#
variable "lambda_local" {
  description = "When true, build Lambda layers locally using a container runtime instead of via AWS CodeBuild. See root var.build.lambda_local."
  type        = bool
  default     = false
}

variable "lambda_architecture" {
  description = "Target Lambda architecture. Propagates to compatible_architectures on the layer and to the local/CodeBuild build-host platform."
  type        = string
  default     = "arm64"

  validation {
    condition     = contains(["x86_64", "arm64"], var.lambda_architecture)
    error_message = "lambda_architecture must be one of: x86_64, arm64."
  }
}

variable "container_runtime" {
  description = "Container runtime to use when lambda_local = true. \"auto\" probes docker -> podman -> finch."
  type        = string
  default     = "auto"

  validation {
    condition     = contains(["auto", "docker", "podman", "finch"], var.container_runtime)
    error_message = "container_runtime must be one of: auto, docker, podman, finch."
  }
}

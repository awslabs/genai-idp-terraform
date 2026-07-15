# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Local equivalent of modules/lambda-layer-codebuild. Public variable
# surface mirrors that module so the dispatcher (lambda-layer-codebuild
# main.tf) can pass everything through unchanged.

variable "name_prefix" {
  description = "Prefix for resource naming and lambda layers (mirrors lambda-layer-codebuild)."
  type        = string
}

variable "requirements_files" {
  description = "Map of logical layer name to requirements.txt contents. Empty values are skipped."
  type        = map(string)
}

variable "requirements_hash" {
  description = "Optional pre-computed hash for change detection. Empty string lets the module hash the inputs itself."
  type        = string
  default     = ""
}

variable "force_rebuild" {
  description = "Force rebuild of layers regardless of input changes."
  type        = bool
  default     = false
}

variable "lambda_layers_bucket_arn" {
  description = "ARN of the S3 bucket the produced layer zips are uploaded to. Same bucket the CodeBuild path uses, so consumers see no S3-bucket difference between modes."
  type        = string

  validation {
    condition     = var.lambda_layers_bucket_arn != ""
    error_message = "lambda_layers_bucket_arn is required and cannot be empty."
  }
}

variable "lambda_tracing_mode" {
  description = "Kept for signature parity with lambda-layer-codebuild. Not used here (no Lambda functions are created)."
  type        = string
  default     = "Active"

  validation {
    condition     = contains(["Active", "PassThrough"], var.lambda_tracing_mode)
    error_message = "lambda_tracing_mode must be either Active or PassThrough."
  }
}

variable "lambda_architecture" {
  description = "Target Lambda architecture. Drives both the SAM build image tag (latest-x86_64 vs latest-arm64) and compatible_architectures on the produced aws_lambda_layer_version."
  type        = string
  default     = "x86_64"

  validation {
    condition     = contains(["x86_64", "arm64"], var.lambda_architecture)
    error_message = "lambda_architecture must be one of: x86_64, arm64."
  }
}

variable "container_runtime" {
  description = "Container runtime selector. Informational here; the docker daemon is invoked by terraform-aws-modules/lambda via local-exec respecting the host's docker CLI / DOCKER_HOST. Kept on the signature for future use."
  type        = string
  default     = "auto"
}

variable "docker_host" {
  description = "DOCKER_HOST value to export when invoking terraform-aws-modules/lambda's build script. Empty string keeps the platform default (the docker CLI's own default socket). Non-empty values are passed through verbatim (e.g. unix:///path/to/podman.sock)."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags applied to the layer-version resources."
  type        = map(string)
  default     = {}
}

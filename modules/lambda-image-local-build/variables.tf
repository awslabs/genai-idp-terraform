# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#

variable "name" {
  description = "Human-readable identifier for the image (used in tags and resource names). Typically the processor name."
  type        = string
}

variable "source_path" {
  description = "Absolute path to the directory containing the Dockerfile and build context. Hashes of all files under this path drive image rebuild detection."
  type        = string
}

variable "dockerfile_path" {
  description = "Path to the Dockerfile relative to source_path. Defaults to \"Dockerfile\"."
  type        = string
  default     = "Dockerfile"
}

variable "ecr_repository_url" {
  description = "ECR repository URL (without tag) that the built image will be pushed to."
  type        = string
}

variable "image_tag" {
  description = "Tag to push under. Default \"latest\" matches the CodeBuild path; consumers reference the image by sha256 digest regardless of tag so :latest is safe."
  type        = string
  default     = "latest"
}

variable "lambda_architecture" {
  description = "Target Lambda architecture; drives the docker --platform value."
  type        = string
  default     = "x86_64"

  validation {
    condition     = contains(["x86_64", "arm64"], var.lambda_architecture)
    error_message = "lambda_architecture must be one of: x86_64, arm64."
  }
}

variable "build_args" {
  description = "Additional --build-arg key=value pairs to pass to docker build."
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags applied (where applicable -- docker provider resources don't accept tags)."
  type        = map(string)
  default     = {}
}

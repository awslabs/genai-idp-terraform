# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#

variable "lambda_local" {
  description = "When true (root build.lambda_local), this module gates plan/apply on a usable container runtime. When false, the probe still runs but the check {} block does not fail plan."
  type        = bool
  default     = false
}

variable "container_runtime" {
  description = "Runtime selector mirroring root var.build.container_runtime. \"auto\" probes docker -> podman -> finch in order. Explicit values probe only that runtime."
  type        = string
  default     = "auto"

  validation {
    condition     = contains(["auto", "docker", "podman", "finch"], var.container_runtime)
    error_message = "container_runtime must be one of: auto, docker, podman, finch."
  }
}

variable "script_path" {
  description = "Absolute path to scripts/detect-container-runtime.sh. Defaults to the path relative to this module."
  type        = string
  default     = ""
}

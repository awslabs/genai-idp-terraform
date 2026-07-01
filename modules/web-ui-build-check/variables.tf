# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#

variable "ui_local" {
  description = "When true (root build.ui_local), this module gates plan/apply on Node.js >= 18 being available. When false, the probe still runs but the check {} block does not fail plan."
  type        = bool
  default     = false
}

variable "script_path" {
  description = "Absolute path to scripts/detect-node-runtime.sh. Defaults to the path relative to this module."
  type        = string
  default     = ""
}

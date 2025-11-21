# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "kms_key_id" {
  description = "KMS key ID for encryption"
  type        = string
}

variable "max_epochs" {
  description = "Maximum number of epochs for training"
  type        = number
  default     = 3
}

variable "base_model" {
  description = "Base model to use for training"
  type        = string
  default     = "microsoft/udop-large"
}

variable "retrain_model" {
  description = "Whether to retrain the model on each apply"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

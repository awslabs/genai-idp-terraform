# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

variable "bucket_prefix" {
  description = "Prefix for the S3 bucket name"
  type        = string
  validation {
    condition     = length(var.bucket_prefix) > 0 && length(var.bucket_prefix) <= 50
    error_message = "Bucket prefix must be between 1 and 50 characters."
  }
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "enable_lifecycle_management" {
  description = "Enable S3 lifecycle management to automatically clean up old artifacts"
  type        = bool
  default     = true
}

variable "asset_retention_days" {
  description = "Number of days to retain assets before deletion"
  type        = number
  default     = 90
  validation {
    condition     = var.asset_retention_days > 0 && var.asset_retention_days <= 365
    error_message = "Asset retention days must be between 1 and 365."
  }
}

variable "old_version_retention_days" {
  description = "Number of days to retain old versions of assets"
  type        = number
  default     = 30
  validation {
    condition     = var.old_version_retention_days > 0 && var.old_version_retention_days <= 365
    error_message = "Old version retention days must be between 1 and 365."
  }
}

# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
variable "table_name" {
  description = "Name of the DynamoDB table"
  type        = string
  default     = null
}

variable "billing_mode" {
  description = "Controls how you are charged for read and write throughput and how you manage capacity"
  type        = string
  default     = "PROVISIONED"
  validation {
    condition     = contains(["PROVISIONED", "PAY_PER_REQUEST"], var.billing_mode)
    error_message = "Allowed values for billing_mode are \"PROVISIONED\" or \"PAY_PER_REQUEST\"."
  }
}

variable "read_capacity" {
  description = "The read capacity for the table"
  type        = number
  default     = 5
}

variable "write_capacity" {
  description = "The write capacity for the table"
  type        = number
  default     = 5
}

variable "point_in_time_recovery_enabled" {
  description = "Whether point-in-time recovery is enabled"
  type        = bool
  default     = true
}

variable "deletion_protection_enabled" {
  description = "Enables deletion protection for the table"
  type        = bool
  default     = false
}

variable "table_class" {
  description = "The table class to use"
  type        = string
  default     = "STANDARD"
  validation {
    condition     = contains(["STANDARD", "STANDARD_INFREQUENT_ACCESS"], var.table_class)
    error_message = "Allowed values for table_class are \"STANDARD\" or \"STANDARD_INFREQUENT_ACCESS\"."
  }
}

variable "kms_key_arn" {
  description = "The ARN of the KMS key to use for encryption"
  type        = string
  default     = null
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

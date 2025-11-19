# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
variable "region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "prefix" {
  description = "Prefix to add to resource names"
  type        = string
  default     = "idp"
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
  description = "The read capacity for the tables"
  type        = number
  default     = 5
}

variable "write_capacity" {
  description = "The write capacity for the tables"
  type        = number
  default     = 5
}

variable "point_in_time_recovery_enabled" {
  description = "Whether point-in-time recovery is enabled"
  type        = bool
  default     = false
}

variable "deletion_protection_enabled" {
  description = "Enables deletion protection for the tables"
  type        = bool
  default     = false
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default = {
    Environment = "development"
    Project     = "GenAI-IDP"
  }
}

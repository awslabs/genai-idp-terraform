# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

variable "bucket_name" {
  description = "Name of the access-log destination bucket."
  type        = string
}

variable "force_destroy" {
  description = "Delete the bucket and its logs on destroy. Default false, so a destroy fails while logs remain; set true for throwaway stacks."
  type        = bool
  default     = false
  nullable    = false
}

variable "expiration_days" {
  description = "Days before log objects and noncurrent versions expire."
  type        = number
  default     = 180
  nullable    = false
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

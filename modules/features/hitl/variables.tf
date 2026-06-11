# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Inputs for the HITL feature-plugin submodule. The submodule is a thin,
# self-contained contract emitter: it accepts the wiring it needs (the HITL
# Lambda data source + ARN, table/bucket/queue identifiers) and produces the
# feature-plugin `contract` that `processing-environment-api` composes.
#
# v0.5.12 handles HITL *inline* in the unified state machine
# (CheckHITLRequired -> MarkHITLPending). The only interactive piece is the
# `complete_section_review` Lambda (claim / release / skip / complete review),
# which physically lives in `processing-environment-api`. This submodule mirrors
# that operation's resolver definitions, IAM, and environment wiring as a
# contract — it does not itself create the Lambda or data source.

variable "data_source_name" {
  description = <<-EOT
    Name of the AppSync data source that fronts the `complete_section_review`
    Lambda. The API module creates this data source (it owns the inline HITL
    Lambda); the contract references it by name so the composed resolvers attach
    to it. Defaults to the name used by `processing-environment-api`.
  EOT
  type        = string
  default     = "CompleteSectionReviewDS"
}

variable "lambda_function_arn" {
  description = <<-EOT
    ARN of the `complete_section_review` Lambda. Used to scope the
    `lambda:InvokeFunction` statement the AppSync/API role needs to invoke the
    HITL resolvers. When null, the invoke statement is omitted from the
    contract (caller wires the permission directly).
  EOT
  type        = string
  default     = null
}

variable "partition" {
  description = "AWS partition (e.g. aws, aws-us-gov). Used to render IAM resource ARNs."
  type        = string
  default     = "aws"
}

variable "tracking_table_arn" {
  description = "ARN of the document tracking DynamoDB table the HITL review Lambda reads/writes."
  type        = string
  default     = null
}

variable "tracking_table_name" {
  description = "Name of the document tracking DynamoDB table (env wiring for the HITL review Lambda)."
  type        = string
  default     = null
}

variable "input_bucket_arn" {
  description = "ARN of the input S3 bucket the HITL review Lambda reads."
  type        = string
  default     = null
}

variable "input_bucket_name" {
  description = "Name of the input S3 bucket (env wiring)."
  type        = string
  default     = null
}

variable "output_bucket_arn" {
  description = "ARN of the output S3 bucket the HITL review Lambda reads/writes."
  type        = string
  default     = null
}

variable "output_bucket_name" {
  description = "Name of the output S3 bucket (env wiring)."
  type        = string
  default     = null
}

variable "working_bucket_arn" {
  description = "ARN of the working S3 bucket the HITL review Lambda reads/writes. Optional."
  type        = string
  default     = null
}

variable "working_bucket_name" {
  description = "Name of the working S3 bucket (env wiring). Optional."
  type        = string
  default     = null
}

variable "document_queue_arn" {
  description = "ARN of the document SQS queue used to trigger reprocessing after review. Optional."
  type        = string
  default     = null
}

variable "document_queue_url" {
  description = "URL of the document SQS queue (env wiring). Optional."
  type        = string
  default     = null
}

variable "encryption_key_arn" {
  description = "ARN of the KMS key used to encrypt HITL resources. Optional."
  type        = string
  default     = null
}

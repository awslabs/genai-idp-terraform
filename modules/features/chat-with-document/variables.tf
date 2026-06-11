# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Inputs for the Chat-with-Document feature-plugin submodule (C13).
#
# The submodule is self-contained: it provisions the v0.5.11+ async streaming
# Chat-with-Document Lambdas (a lightweight `sendChatDocumentMessage` resolver
# and the long-running `chat_with_document_processor` that streams tokens back
# via AppSync) and emits a feature-plugin `contract` that
# `modules/processing-environment-api` composes (resolvers + IAM + env). The
# legacy synchronous `chatWithDocument` Query was removed upstream at v0.5.12;
# this submodule mirrors the replacement async model.

# ---------------------------------------------------------------------------
# Naming / wiring
# ---------------------------------------------------------------------------

variable "name_prefix" {
  description = "Prefix for resource names created by this submodule."
  type        = string
}

variable "appsync_api_id" {
  description = "ID of the AppSync GraphQL API the chat resolvers attach to."
  type        = string
}

variable "appsync_graphql_api_arn" {
  description = <<-EOT
    ARN of the AppSync GraphQL API. Used to scope the `appsync:GraphQL` mutation
    permission the long-running processor Lambda needs to publish streaming
    status/delta/final messages back to subscribers.
  EOT
  type        = string
}

variable "appsync_graphql_url" {
  description = "GraphQL endpoint URL of the AppSync API; the processor publishes streaming updates to it."
  type        = string
}

variable "data_source_name" {
  description = <<-EOT
    Name of the AppSync Lambda data source that fronts the
    `sendChatDocumentMessage` resolver. The contract references it by name so
    the composed mutation resolver attaches to it.
  EOT
  type        = string
  default     = "SendChatDocumentMessageDataSource"
}

variable "none_data_source_name" {
  description = <<-EOT
    Name of the AppSync NONE (local) data source used by the
    `onChatDocumentMessageUpdate` subscription fan-out resolver. The API module
    owns the NONE data source; the contract references it by name.
  EOT
  type        = string
  default     = "ChatDocumentNoneDataSource"
}

# ---------------------------------------------------------------------------
# Shared environment ARNs / names
# ---------------------------------------------------------------------------

variable "output_bucket_arn" {
  description = "ARN of the output S3 bucket the chat processor reads document artifacts from."
  type        = string
}

variable "configuration_table_arn" {
  description = "ARN of the DynamoDB configuration table the chat processor reads chat/summarization config from."
  type        = string
}

variable "configuration_table_name" {
  description = "Name of the DynamoDB configuration table (env wiring for the chat processor)."
  type        = string
}

variable "tracking_table_arn" {
  description = "ARN of the DynamoDB tracking table the chat processor reads document metadata from."
  type        = string
}

variable "tracking_table_name" {
  description = "Name of the DynamoDB tracking table (env wiring for the chat processor)."
  type        = string
}

# ---------------------------------------------------------------------------
# Layers / runtime
# ---------------------------------------------------------------------------

variable "base_layer_arn" {
  description = "ARN of the base Lambda layer (idp_common). Attached to the chat processor per conventions."
  type        = string
  default     = null
}

variable "idp_common_layer_arn" {
  description = "ARN of the idp_common Lambda layer, when supplied separately from the base layer."
  type        = string
  default     = null
}

# ---------------------------------------------------------------------------
# Optional config
# ---------------------------------------------------------------------------

variable "config" {
  description = <<-EOT
    Document configuration object. Task 11.2 / Property 6: the effective chat
    configuration resolves to the top-level `chat:` block when present, else
    falls back to `summarization.*`; when no chat model is specified the default
    is `us.anthropic.claude-opus-4-7:1m` (v0.5.12 default). Only the chat-relevant
    keys are read here; the full config is otherwise opaque to this submodule.
  EOT
  type        = any
  default     = {}
}

variable "guardrail_id_and_version" {
  description = "Bedrock Guardrail ID and version in `id:version` form. Optional."
  type        = string
  default     = null
}

variable "encryption_key_arn" {
  description = "ARN of the KMS key used to encrypt chat resources/logs. Optional."
  type        = string
  default     = null
}

variable "data_retention_days" {
  description = "Retention (days) for ephemeral chat-session ownership records and logs."
  type        = number
  default     = 1
}

variable "log_level" {
  description = "Log level for the chat Lambdas."
  type        = string
  default     = "INFO"

  validation {
    condition     = contains(["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"], var.log_level)
    error_message = "log_level must be one of: DEBUG, INFO, WARNING, ERROR, CRITICAL."
  }
}

variable "log_retention_days" {
  description = "CloudWatch log retention period in days for the chat Lambdas."
  type        = number
  default     = 7

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "log_retention_days must be a valid CloudWatch Logs retention period."
  }
}

variable "lambda_tracing_mode" {
  description = "X-Ray tracing mode for the chat Lambdas. Valid values: Active, PassThrough."
  type        = string
  default     = "Active"

  validation {
    condition     = contains(["Active", "PassThrough"], var.lambda_tracing_mode)
    error_message = "lambda_tracing_mode must be either 'Active' or 'PassThrough'."
  }
}

variable "vpc_subnet_ids" {
  description = "Subnet IDs for the chat Lambdas (VPC mode). Empty disables VPC config."
  type        = list(string)
  default     = []
}

variable "vpc_security_group_ids" {
  description = "Security group IDs for the chat Lambdas (VPC mode)."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to resources."
  type        = map(string)
  default     = {}
}

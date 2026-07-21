# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Feature Platform — installable-feature registry + AppSync operations.
# Mirrors upstream IDP v0.5.16 feature-platform/main-stack-extensions.
# Instantiated by the root only when var.feature_platform.enabled = true
# (root gates via `count`), so resources here are unconditional.

variable "name_prefix" {
  description = "Prefix for resource names."
  type        = string
}

variable "main_stack_name" {
  description = "Logical stack/deployment name; used to scope feature stack ARNs (<name>-feature-*)."
  type        = string
}

variable "graphql_api_id" {
  description = "AppSync GraphQL API ID to attach feature-platform data sources and resolvers to."
  type        = string
}

variable "configuration_table_name" {
  description = "ConfigurationTable name (for hook registration and config presets)."
  type        = string
}

variable "configuration_table_arn" {
  description = "ConfigurationTable ARN."
  type        = string
}

variable "configuration_bucket_name" {
  description = "Configuration bucket holding the feature catalog (catalog.json)."
  type        = string
  default     = ""
}

variable "catalog_key" {
  description = "S3 key of the feature catalog manifest."
  type        = string
  default     = "feature-platform/catalog.json"
}

variable "encryption_key_arn" {
  description = "Customer-managed KMS key ARN (optional)."
  type        = string
  default     = null
}

variable "artifact_region" {
  description = "Region for the OSS feature template artifacts bucket."
  type        = string
  default     = ""
}

variable "simulator_entitlement_endpoint" {
  description = "Marketplace simulator entitlement endpoint (empty for real Marketplace / auto-subscribe)."
  type        = string
  default     = ""
}

variable "subscription_mode" {
  description = "Subscription mode / simulator source tag (e.g. auto-subscribe)."
  type        = string
  default     = "auto-subscribe"
}

variable "default_customer_identifier" {
  description = "Default Marketplace customer identifier."
  type        = string
  default     = ""
}

variable "default_buyer_account_id" {
  description = "Default buyer AWS account id for deterministic GetEntitlements filtering."
  type        = string
  default     = ""
}

variable "feature_offer_id_map" {
  description = "JSON map of feature id -> Marketplace offer id."
  type        = string
  default     = "{}"
}

variable "admin_group_name" {
  description = "Cognito admin group permitted to call privileged feature mutations."
  type        = string
  default     = "Admin"
}

variable "seller_bucket_object_arns" {
  description = "Seller bucket object ARNs the platform may GetObject (marketplace features)."
  type        = list(string)
  default     = []
}

variable "log_level" {
  description = "Lambda log level."
  type        = string
  default     = "INFO"
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days."
  type        = number
  default     = 30
}

variable "lambda_tracing_mode" {
  description = "Lambda X-Ray tracing mode."
  type        = string
  default     = "Active"
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}

variable "lambda_architecture" {
  description = "Target Lambda architecture (x86_64 | arm64). Must match the architecture the idp_common layers were built for; mismatches break native deps (e.g. pydantic_core)."
  type        = string
  default     = "arm64"
  validation {
    condition     = contains(["x86_64", "arm64"], var.lambda_architecture)
    error_message = "lambda_architecture must be one of: x86_64, arm64."
  }
}

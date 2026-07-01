# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "configuration_table_name" {
  description = "Name of the DynamoDB table to store configuration"
  type        = string
}

variable "schema" {
  description = "JSON schema object to store under 'Schema' key"
  type        = any
}

variable "configuration" {
  description = "JSON configuration object to store under 'Default' key"
  type        = any
}

variable "additional_configurations" {
  description = "Extra non-active, editable configuration versions seeded as Config#<name> rows (version_name => config object), Managed=false so they stay editable in the UI. A top-level `bda_project_arn` key on an entry is lifted out of the config body to link that version to a BDA project (never seeded as config data)."
  type        = any
  default     = {}
}

variable "default_bda_project_arn" {
  description = <<-EOT
    Optional BDA project ARN that links the `default` config version to a BDA
    project at seed time (set by the bda-processor façade). Also the last-resort
    fallback for use_bda:true additional versions. Null (default) links no default
    project, so pipeline façades keep their default pipeline.
  EOT
  type        = string
  default     = null
}

variable "fallback_bda_project_arn" {
  description = <<-EOT
    Optional BDA project ARN used only as the fallback for use_bda:true additional
    versions that omit their own `bda_project_arn`. Does not link the `default`
    version, so pipeline façades can link extra BDA versions while keeping their
    default pipeline. Precedence per version: per-version bda_project_arn >
    this fallback > default_bda_project_arn > none.
  EOT
  type        = string
  default     = null
}

variable "vpc_config" {
  description = "VPC configuration for Lambda function"
  type = object({
    subnet_ids         = list(string)
    security_group_ids = list(string)
  })
  default = null
}

variable "encryption_key_arn" {
  description = "ARN of the KMS key used for encrypting DynamoDB table"
  type        = string
  default     = null
}

variable "base_layer_arn" {
  description = <<-EOT
    ARN of the IDPCommonBaseLayer Lambda layer. The seeder Lambda needs
    `idp_common` available so it can call `merge_config_with_defaults`
    when storing a `Default` configuration. Without this layer attached
    the seeder still functions, but it skips the merge step and the
    runtime classification/extraction Lambdas will fail with
    `No system_prompt found in classification configuration`.
  EOT
  type        = string
  default     = null
}

variable "idp_common_layer_arn" {
  description = "ARN of the IDP common Lambda layer (full processor-extras flavor). Optional — `base_layer_arn` alone is enough for the seeder."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "lambda_tracing_mode" {
  description = "X-Ray tracing mode for Lambda functions. Valid values: Active, PassThrough"
  type        = string
  default     = "Active"

  validation {
    condition     = contains(["Active", "PassThrough"], var.lambda_tracing_mode)
    error_message = "lambda_tracing_mode must be either 'Active' or 'PassThrough'."
  }
}

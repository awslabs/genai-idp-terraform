# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Inputs for the RBAC feature-plugin submodule (CDK `UserManagement` analog).
#
# The submodule is self-contained: it ensures the four Cognito user-pool groups
# (Admin/Author/Reviewer/Viewer) exist, provisions the `Users` DynamoDB table
# and the user-management Lambda, wires server-side Reviewer document filtering +
# `allowedConfigVersions` scoping, and emits the feature-plugin `contract` that
# `modules/processing-environment-api` composes. Mirrors the CDK
# `UserManagement` / `UsersTable` / `UserManagementFunction` constructs (verified
# against `cdklabs/genai-idp@main`, `processing-environment-api/user-management/`).

# ---------------------------------------------------------------------------
# Enablement / naming
# ---------------------------------------------------------------------------

variable "enabled" {
  description = <<-EOT
    Whether the RBAC feature is enabled. The root forwards `var.rbac.enabled`
    here. The root instantiates this submodule with `count`, so when RBAC is
    disabled the submodule is not instantiated at all (default-off); this flag
    is also surfaced on the emitted contract's `enabled` field.
  EOT
  type        = bool
  default     = true
}

variable "name_prefix" {
  description = "Prefix for resource names created by this submodule (Users table, user-management Lambda, roles)."
  type        = string
}

# ---------------------------------------------------------------------------
# Cognito user pool (required — RBAC only makes sense with Cognito)
# ---------------------------------------------------------------------------

variable "user_pool_id" {
  description = <<-EOT
    ID of the Cognito user pool the four RBAC groups are created on and the
    user-management Lambda administers. RBAC requires Cognito; the root enforces
    this with a plan-time `check {}` mirroring the CDK `UserManagement`
    constructor guard.
  EOT
  type        = string
}

variable "user_pool_arn" {
  description = <<-EOT
    ARN of the Cognito user pool. Used to scope the user-management Lambda's
    Cognito admin permissions (group membership management) to exactly this pool
    and no broader.
  EOT
  type        = string
  default     = null
}

# ---------------------------------------------------------------------------
# Group-name overrides
# ---------------------------------------------------------------------------

variable "group_names" {
  description = <<-EOT
    Optional overrides for the four RBAC Cognito group names. Each key defaults
    to its canonical name (`Admin`/`Author`/`Reviewer`/`Viewer`) so overriding
    one or more does not change the default-on behavior of the four roles.
    Exactly four groups are always created.
  EOT
  type = object({
    admin    = optional(string, "Admin")
    author   = optional(string, "Author")
    reviewer = optional(string, "Reviewer")
    viewer   = optional(string, "Viewer")
  })
  default = {}
}

# ---------------------------------------------------------------------------
# Layers / runtime (used by the user-management Lambda)
# ---------------------------------------------------------------------------

variable "base_layer_arn" {
  description = "ARN of the base Lambda layer (idp_common shared deps). Attached to the user-management Lambda via compact([...])."
  type        = string
  default     = null
}

variable "idp_common_layer_arn" {
  description = "ARN of the idp_common Lambda layer, when supplied separately from the base layer."
  type        = string
  default     = null
}

variable "allowed_signup_email_domains" {
  description = <<-EOT
    Comma-separated list of email domains the user-management Lambda permits when
    creating users (e.g. `example.com,corp.example.com`). Empty (the default)
    disables domain restriction — any valid email is accepted. Wired into the
    Lambda as `ALLOWED_SIGNUP_EMAIL_DOMAINS` (the exact env key read by
    `sources/src/lambda/user_management/index.py`).
  EOT
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# Encryption / data stores (used by the Users table + resolvers)
# ---------------------------------------------------------------------------

variable "encryption_key_arn" {
  description = "ARN of the project KMS key used for server-side encryption of the Users table and the user-management Lambda log group."
  type        = string
  default     = null
}

variable "tracking_table_arn" {
  description = "ARN of the DynamoDB tracking table the document-list filtering path reads for Reviewer document filtering."
  type        = string
  default     = null
}

variable "tracking_table_name" {
  description = "Name of the DynamoDB tracking table (env wiring for the document-list filtering path)."
  type        = string
  default     = null
}

variable "configuration_table_arn" {
  description = "ARN of the DynamoDB configuration table the config-access resolvers read for `allowedConfigVersions` scoping."
  type        = string
  default     = null
}

variable "configuration_table_name" {
  description = "Name of the DynamoDB configuration table (env wiring for the config-access scoping path)."
  type        = string
  default     = null
}

# ---------------------------------------------------------------------------
# Networking (optional VPC placement for the user-management Lambda)
# ---------------------------------------------------------------------------

variable "vpc_config" {
  description = "Optional VPC configuration for the user-management Lambda. When null, the Lambda is not placed in a VPC."
  type = object({
    subnet_ids         = list(string)
    security_group_ids = list(string)
  })
  default = null
}

# ---------------------------------------------------------------------------
# Logging (used by the user-management Lambda)
# ---------------------------------------------------------------------------

variable "log_level" {
  description = "Log level for the RBAC Lambdas."
  type        = string
  default     = "INFO"

  validation {
    condition     = contains(["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"], var.log_level)
    error_message = "log_level must be one of: DEBUG, INFO, WARNING, ERROR, CRITICAL."
  }
}

variable "log_retention_days" {
  description = "CloudWatch log retention period in days for the RBAC Lambdas."
  type        = number
  default     = 7

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "log_retention_days must be a valid CloudWatch Logs retention period."
  }
}

variable "tags" {
  description = "A map of tags to apply to all RBAC resources."
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

# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# UserIdentityProps - Structural properties from CDK implementation
variable "user_pool" {
  description = "Optional pre-existing Cognito User Pool to use for authentication. When not provided, a new User Pool will be created with standard settings."
  type = object({
    user_pool_id  = string
    user_pool_arn = string
  })
  default = null
}

variable "identity_pool_options" {
  description = "Configuration for the Identity Pool"
  type = object({
    identity_pool_name               = optional(string)
    allow_unauthenticated_identities = optional(bool, false)
    allow_classic_flow               = optional(bool, false)
  })
  default = {}

  validation {
    condition     = !try(var.identity_pool_options.allow_unauthenticated_identities, false)
    error_message = "Unauthenticated access to Cognito Identity Pool is not allowed for security reasons. allow_unauthenticated_identities must be false."
  }
}

# Admin user configuration is now handled externally

variable "allowed_signup_email_domain" {
  description = "Optional comma-separated list of allowed email domains for self-service signup"
  type        = string
  default     = ""
}

# Legacy variables for backward compatibility
variable "name_prefix" {
  description = "Prefix for resource naming"
  type        = string
}

variable "deletion_protection" {
  description = "Enable deletion protection for the User Pool"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

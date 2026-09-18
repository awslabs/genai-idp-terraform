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

variable "additional_callback_urls" {
  description = "Extra OAuth callback URLs to allow on the user pool client (in addition to the localhost dev URL). Used to register the Web UI custom domain URL. Mirrors upstream CustomDomainUrl callback wiring."
  type        = list(string)
  default     = []
}

variable "additional_logout_urls" {
  description = "Extra OAuth logout URLs to allow on the user pool client (in addition to the localhost dev URL). Used to register the Web UI custom domain URL."
  type        = list(string)
  default     = []
}

variable "additional_identity_providers" {
  description = "External identity provider names to append to the user pool client's supported_identity_providers. COGNITO is always retained. Wired from the idp-federation feature's supported_identity_providers_contribution output."
  type        = list(string)
  default     = []
}

variable "enable_idp_groups_attribute" {
  description = "Add the custom `idp_groups` attribute to the user pool schema, required for external IdP group mapping. One-way: Cognito can add a schema attribute in place but can never remove one, so confirm your plan shows no pool replacement before enabling."
  type        = bool
  default     = false
}

variable "pre_token_generation_function_arn" {
  description = "ARN of a Lambda to attach as the user pool's PreTokenGeneration (V2_0) trigger. Used to map external IdP groups onto Cognito groups. When null, no trigger is attached."
  type        = string
  default     = null
}

variable "create_hosted_ui_domain" {
  description = "Create a Cognito hosted UI domain for the user pool. Required for external-IdP (SAML/OIDC) sign-in, which redirects through the hosted UI."
  type        = bool
  default     = false
}

variable "hosted_ui_domain_prefix" {
  description = "Domain prefix for the Cognito hosted UI. Must be globally unique across all AWS accounts. Defaults to a sanitized name_prefix."
  type        = string
  default     = null

  validation {
    condition     = var.hosted_ui_domain_prefix == null || can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", var.hosted_ui_domain_prefix))
    error_message = "hosted_ui_domain_prefix must be 1-63 lowercase alphanumeric or hyphen characters and may not start or end with a hyphen."
  }

  validation {
    condition     = var.hosted_ui_domain_prefix == null || !can(regex("aws|amazon|cognito", var.hosted_ui_domain_prefix))
    error_message = "hosted_ui_domain_prefix may not contain the Cognito-reserved words aws, amazon or cognito."
  }
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

variable "enable_cognito_waf" {
  description = "Attach a REGIONAL WAFv2 Web ACL (AWS managed common rule set) to the Cognito user pool (Wiz IDP-007)."
  type        = bool
  default     = true
}

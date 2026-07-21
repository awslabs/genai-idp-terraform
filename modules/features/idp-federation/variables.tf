# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Inputs for the External SAML/OIDC IdP federation feature-plugin submodule.
#
# Mirrors the upstream v0.5.6 federation surface (the `ExternalIdP*` CFN
# parameters in `sources/template.yaml`) and the CDK federation construct.

# ---------------------------------------------------------------------------
# Enable / provider selection
# ---------------------------------------------------------------------------

variable "enabled" {
  description = <<-EOT
    Whether external IdP federation is requested. When false the submodule
    provisions no Cognito identity provider and leaves the user pool configured
    for direct Cognito authentication (default-off).
  EOT
  type        = bool
  default     = false
}

variable "provider_type" {
  description = <<-EOT
    Type of external identity provider to federate with the Cognito user pool.
    `SAML` for providers like PingOne, Okta SAML, or ADFS; `OIDC` for providers
    like Okta OIDC, Auth0, or Azure AD. Mirrors the upstream `ExternalIdPType`.
  EOT
  type        = string
  default     = "SAML"

  validation {
    condition     = contains(["SAML", "OIDC"], var.provider_type)
    error_message = "provider_type must be either 'SAML' or 'OIDC'."
  }
}

variable "provider_name" {
  description = <<-EOT
    Display name for the external identity provider (e.g. PingOne, Okta,
    AzureAD), surfaced on the Cognito hosted-UI sign-in button. Must start with
    a letter and contain only alphanumeric characters and hyphens (max 32).
    Mirrors the upstream `ExternalIdPName`.
  EOT
  type        = string
  default     = "ExternalIdP"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]{0,31}$", var.provider_name))
    error_message = "provider_name must start with a letter and contain only alphanumeric characters and hyphens (max 32 characters)."
  }
}

# ---------------------------------------------------------------------------
# SAML provider details
# ---------------------------------------------------------------------------

variable "saml_metadata_url" {
  description = <<-EOT
    (SAML) The SAML metadata document URL from the identity provider, e.g.
    `https://idp.example.com/saml/metadata`. Mutually exclusive with
    `saml_metadata_file`. Mirrors the upstream `ExternalIdPMetadataURL`.
  EOT
  type        = string
  default     = ""

  validation {
    condition     = var.saml_metadata_url == "" || can(regex("^https://", var.saml_metadata_url))
    error_message = "saml_metadata_url must be empty or a valid HTTPS URL."
  }
}

variable "saml_metadata_file" {
  description = <<-EOT
    (SAML) The SAML metadata document contents, supplied inline as an
    alternative to `saml_metadata_url` (Cognito `MetadataFile`). Empty when a
    metadata URL is used instead.
  EOT
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# OIDC provider details
# ---------------------------------------------------------------------------

variable "oidc_issuer" {
  description = <<-EOT
    (OIDC) The issuer URL from the OIDC identity provider, e.g.
    `https://login.example.com` or `https://example.okta.com/oauth2/default`.
    Mirrors the upstream `ExternalIdPOIDCIssuer`.
  EOT
  type        = string
  default     = ""

  validation {
    condition     = var.oidc_issuer == "" || can(regex("^https://", var.oidc_issuer))
    error_message = "oidc_issuer must be empty or a valid HTTPS URL."
  }
}

variable "oidc_client_id" {
  description = "(OIDC) The client ID registered with the OIDC identity provider. Mirrors the upstream `ExternalIdPOIDCClientId`."
  type        = string
  default     = ""
}

variable "oidc_client_secret_ref" {
  description = <<-EOT
    (OIDC) Reference to the OIDC client secret — an AWS Secrets Manager secret
    ARN (or SSM parameter name) — NOT the raw secret value. The secret is
    resolved at apply time and passed only to the Cognito provider details; the
    plaintext is never stored as a module input value or output. Mirrors the
    upstream `ExternalIdPOIDCClientSecretArn`.
  EOT
  type        = string
  default     = ""
}

variable "oidc_authorize_scopes" {
  description = "(OIDC) Space-delimited OAuth scopes requested from the OIDC provider. Mirrors the upstream default of `openid email profile`."
  type        = string
  default     = "openid email profile"
}

# ---------------------------------------------------------------------------
# Attribute / group mapping
# ---------------------------------------------------------------------------

variable "attribute_mapping" {
  description = <<-EOT
    Map of Cognito user-pool attribute name -> external IdP attribute/claim
    name (the Cognito `AttributeMapping`). When empty, the module applies the
    upstream defaults appropriate to the selected `provider_type` (SAML claim
    URIs vs OIDC claim names) for `email`, `given_name`, and `family_name`.
  EOT
  type        = map(string)
  default     = {}
}

variable "group_attribute_name" {
  description = <<-EOT
    The SAML attribute or OIDC claim name that carries group membership from the
    external IdP (mapped into the Cognito `custom:idp_groups` attribute). For
    SAML this is typically `http://schemas.xmlsoap.org/claims/Group` or
    `memberOf`; for OIDC typically `groups`. Empty skips automatic group
    mapping. Mirrors the upstream `ExternalIdPGroupAttributeName`.
  EOT
  type        = string
  default     = ""
}

variable "group_mapping" {
  description = <<-EOT
    Map of external IdP group name -> IDP RBAC role (`Admin`/`Author`/
    `Reviewer`/`Viewer`). Consumed by the group-mapping Lambda to place
    federated users into the four RBAC groups at sign-in. Mirrors the upstream
    `ExternalIdP{Admin,Author,Reviewer,Viewer}GroupName` parameters.
  EOT
  type        = map(string)
  default     = {}
}

# ---------------------------------------------------------------------------
# Wiring inputs
# ---------------------------------------------------------------------------

variable "user_pool_id" {
  description = "ID of the Cognito user pool the external identity provider is attached to."
  type        = string
}

variable "user_pool_client_id" {
  description = <<-EOT
    ID of the Cognito user-pool client whose `supported_identity_providers` is
    additively updated to include the external provider, keeping the `COGNITO`
    provider so direct sign-in continues to work.
  EOT
  type        = string
  default     = null
}

variable "rbac_group_names" {
  description = <<-EOT
    Map of the four IDP RBAC role names (`Admin`/`Author`/`Reviewer`/`Viewer`)
    to the concrete Cognito group names provisioned by the RBAC submodule. The
    group-mapping Lambda targets these so federated users land in the same
    groups RBAC creates.
  EOT
  type        = map(string)
  default = {
    Admin    = "Admin"
    Author   = "Author"
    Reviewer = "Reviewer"
    Viewer   = "Viewer"
  }
}

variable "base_layer_arn" {
  description = "ARN of the base Lambda layer (idp_common). Attached to the group-mapping Lambda via compact([...])."
  type        = string
  default     = null
}

variable "idp_common_layer_arn" {
  description = "ARN of the idp_common Lambda layer, when supplied separately from the base layer."
  type        = string
  default     = null
}

variable "log_level" {
  description = "Log level for the group-mapping Lambda."
  type        = string
  default     = "INFO"

  validation {
    condition     = contains(["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"], var.log_level)
    error_message = "log_level must be one of: DEBUG, INFO, WARNING, ERROR, CRITICAL."
  }
}

variable "log_retention_days" {
  description = "CloudWatch log retention period in days for the group-mapping Lambda."
  type        = number
  default     = 7

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "log_retention_days must be a valid CloudWatch Logs retention period."
  }
}

variable "encryption_key_arn" {
  description = "ARN of the KMS key used to encrypt the group-mapping Lambda log group. Optional."
  type        = string
  default     = null
}

variable "tags" {
  description = "A map of tags to add to all federation resources."
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

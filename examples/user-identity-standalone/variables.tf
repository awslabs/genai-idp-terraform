# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Basic Configuration
variable "region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "idp-user-identity"
}

# User Identity Configuration
variable "admin_email" {
  description = "Email address for the admin user"
  type        = string
}

variable "allowed_signup_email_domain" {
  description = "Optional comma-separated list of allowed email domains for self-service signup"
  type        = string
  default     = ""
}

variable "allow_unauthenticated_identities" {
  description = "Allow unauthenticated identities in the Identity Pool"
  type        = bool
  default     = false
}

variable "deletion_protection" {
  description = "Enable deletion protection for the User Pool"
  type        = bool
  default     = true
}

# Tags
variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "GenAI-IDP-Accelerator"
    Environment = "Development"
    ManagedBy   = "Terraform"
  }
}

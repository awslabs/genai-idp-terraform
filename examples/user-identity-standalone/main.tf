# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
/**
 * # User Identity Standalone Example
 *
 * This example demonstrates how to use the User Identity module independently.
 * It creates Cognito resources for user authentication and authorization.
 */

provider "aws" {
  region = var.region
}

# Create a random string for unique resource names
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Create User Identity Management
module "user_identity" {
  source = "../../modules/user-identity"

  name_prefix = "${var.prefix}-user-identity-${random_string.suffix.result}"

  # Identity Pool configuration
  identity_pool_options = {
    identity_pool_name               = "${var.prefix}-user-identity-${random_string.suffix.result}IdentityPool"
    allow_unauthenticated_identities = var.allow_unauthenticated_identities
    allow_classic_flow               = false
  }

  # Optional: Allow self-service signup
  allowed_signup_email_domain = var.allowed_signup_email_domain

  # Security configuration
  deletion_protection = var.deletion_protection

  tags = var.tags
}

# Admin user creation (optional, externalized from the module)
resource "aws_cognito_user" "admin_user" {
  count        = var.admin_email != null && var.admin_email != "" ? 1 : 0
  user_pool_id = module.user_identity.user_pool.user_pool_id
  username     = var.admin_email

  desired_delivery_mediums = ["EMAIL"]

  attributes = {
    email          = var.admin_email
    email_verified = "true"
    given_name     = "Admin"
    family_name    = "User"
  }

  # Send invitation email with temporary password
  # message_action = "SUPPRESS" # Removed to allow invitation email

  lifecycle {
    ignore_changes = [
      password,
      temporary_password
    ]
  }
}

# Admin group creation (optional)
resource "aws_cognito_user_group" "admin_group" {
  count        = var.admin_email != null && var.admin_email != "" ? 1 : 0
  name         = "Admin"
  user_pool_id = module.user_identity.user_pool.user_pool_id
  description  = "Administrators"
  precedence   = 0
}

# Add admin user to admin group
resource "aws_cognito_user_in_group" "admin_user_in_group" {
  count        = var.admin_email != null && var.admin_email != "" ? 1 : 0
  user_pool_id = module.user_identity.user_pool.user_pool_id
  group_name   = aws_cognito_user_group.admin_group[0].name
  username     = aws_cognito_user.admin_user[0].username
}

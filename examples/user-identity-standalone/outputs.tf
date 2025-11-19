# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# IUserIdentity Interface Outputs
output "user_identity" {
  description = "Complete user identity details following IUserIdentity interface"
  value = {
    user_pool        = module.user_identity.user_pool
    user_pool_client = module.user_identity.user_pool_client
    identity_pool    = module.user_identity.identity_pool
  }
}

# Individual Component Outputs
output "user_pool" {
  description = "Cognito User Pool details"
  value       = module.user_identity.user_pool
}

output "user_pool_client" {
  description = "Cognito User Pool Client details"
  value       = module.user_identity.user_pool_client
}

output "identity_pool" {
  description = "Cognito Identity Pool details"
  value       = module.user_identity.identity_pool
}

# Legacy Outputs for Backward Compatibility
output "user_pool_id" {
  description = "ID of the Cognito User Pool"
  value       = module.user_identity.user_pool_id
}

output "user_pool_client_id" {
  description = "ID of the Cognito User Pool Client"
  value       = module.user_identity.user_pool_client_id
}

output "identity_pool_id" {
  description = "ID of the Cognito Identity Pool"
  value       = module.user_identity.identity_pool_id
}

output "authenticated_role_arn" {
  description = "ARN of the authenticated IAM role"
  value       = module.user_identity.authenticated_role_arn
}

# Admin User Output
output "admin_user" {
  description = "Admin user details (if created)"
  value = var.admin_email != null && var.admin_email != "" ? {
    username = aws_cognito_user.admin_user[0].username
    email    = var.admin_email
    group    = aws_cognito_user_group.admin_group[0].name
  } : null
}

# Usage Instructions
output "usage_instructions" {
  description = "Instructions for using the User Identity resources"
  value = {
    user_pool_id        = module.user_identity.user_pool_id
    user_pool_client_id = module.user_identity.user_pool_client_id
    identity_pool_id    = module.user_identity.identity_pool_id
    admin_email         = var.admin_email != null && var.admin_email != "" ? var.admin_email : "No admin user created"
    cognito_console_url = "https://console.aws.amazon.com/cognito/users/?region=${var.region}#/pool/${module.user_identity.user_pool_id}/users"
  }
}

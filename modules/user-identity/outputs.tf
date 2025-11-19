# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# IUserIdentity - Behavioral interface outputs from CDK implementation
output "user_pool" {
  description = "The Cognito UserPool that stores user identities and credentials"
  value = {
    user_pool_id  = local.user_pool.user_pool_id
    user_pool_arn = local.user_pool.user_pool_arn
    endpoint      = local.user_pool.endpoint
  }
}

output "user_pool_client" {
  description = "The Cognito UserPool Client used by the web application for OAuth flows"
  value = {
    user_pool_client_id = aws_cognito_user_pool_client.user_pool_client.id
    client_secret       = aws_cognito_user_pool_client.user_pool_client.client_secret
  }
}

output "identity_pool" {
  description = "The Cognito Identity Pool that provides temporary AWS credentials"
  value = {
    identity_pool_id         = aws_cognito_identity_pool.identity_pool.id
    identity_pool_arn        = aws_cognito_identity_pool.identity_pool.arn
    authenticated_role_arn   = aws_iam_role.authenticated.arn
    unauthenticated_role_arn = var.identity_pool_options.allow_unauthenticated_identities ? aws_iam_role.unauthenticated[0].arn : null
  }
}

# Legacy outputs for backward compatibility
output "user_pool_id" {
  description = "ID of the Cognito User Pool"
  value       = local.user_pool.user_pool_id
}

output "user_pool_arn" {
  description = "ARN of the Cognito User Pool"
  value       = local.user_pool.user_pool_arn
}

output "user_pool_endpoint" {
  description = "Endpoint of the Cognito User Pool"
  value       = local.user_pool.endpoint
}

output "user_pool_client_id" {
  description = "ID of the Cognito User Pool Client"
  value       = aws_cognito_user_pool_client.user_pool_client.id
}

output "identity_pool_id" {
  description = "ID of the Cognito Identity Pool"
  value       = aws_cognito_identity_pool.identity_pool.id
}

output "authenticated_role_arn" {
  description = "ARN of the authenticated IAM role"
  value       = aws_iam_role.authenticated.arn
}

output "unauthenticated_role_arn" {
  description = "ARN of the unauthenticated IAM role (if enabled)"
  value       = var.identity_pool_options.allow_unauthenticated_identities ? aws_iam_role.unauthenticated[0].arn : null
}

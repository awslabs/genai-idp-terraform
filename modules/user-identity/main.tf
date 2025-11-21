# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
/**
 * # User Identity Module
 *
 * A module that manages user authentication and authorization following the CDK UserIdentity construct pattern.
 * Provides Cognito resources for user management and secure access to AWS resources.
 *
 * This module creates and configures:
 * - A Cognito User Pool for user registration and authentication
 * - A User Pool Client for the web application to interact with Cognito
 * - An Identity Pool that provides temporary AWS credentials to authenticated users
 * - Optional admin user and group creation
 *
 * The UserIdentity module enables secure access to the document processing solution,
 * ensuring that only authorized users can upload documents, view results, and
 * perform administrative actions.
 */

# Local values for resource configuration
locals {
  # Determine user pool - use provided or create new
  user_pool = var.user_pool != null ? var.user_pool : {
    user_pool_id  = aws_cognito_user_pool.user_pool[0].id
    user_pool_arn = aws_cognito_user_pool.user_pool[0].arn
    endpoint      = aws_cognito_user_pool.user_pool[0].endpoint
  }

  # Common tags
  common_tags = merge(var.tags, {
    Name        = "${var.name_prefix}-user-identity"
    Environment = var.name_prefix
  })

  # Identity pool configuration
  identity_pool_name = var.identity_pool_options.identity_pool_name != null ? var.identity_pool_options.identity_pool_name : "${var.name_prefix}IdentityPool"
}

# Cognito User Pool (created only if not provided)
resource "aws_cognito_user_pool" "user_pool" {
  count = var.user_pool == null ? 1 : 0
  name  = "${var.name_prefix}-user-pool"

  # Deletion protection
  deletion_protection = var.deletion_protection ? "ACTIVE" : "INACTIVE"

  # Username configuration
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]
  username_configuration {
    case_sensitive = true
  }

  # Password policy following CDK defaults
  password_policy {
    minimum_length                   = 8
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = true
    require_uppercase                = true
    temporary_password_validity_days = 3
  }

  # Standard attributes following CDK configuration
  schema {
    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = true
    name                     = "email"
    required                 = true

    string_attribute_constraints {
      min_length = 0
      max_length = 2048
    }
  }

  schema {
    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = true
    name                     = "given_name"
    required                 = true

    string_attribute_constraints {
      min_length = 0
      max_length = 2048
    }
  }

  schema {
    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = true
    name                     = "family_name"
    required                 = true

    string_attribute_constraints {
      min_length = 0
      max_length = 2048
    }
  }

  schema {
    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = true
    name                     = "phone_number"
    required                 = false

    string_attribute_constraints {
      min_length = 0
      max_length = 2048
    }
  }

  # Email verification
  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"
    email_subject        = "Your verification code"
    email_message        = "Your verification code is {####}"
  }

  # Admin create user configuration
  admin_create_user_config {
    allow_admin_create_user_only = var.allowed_signup_email_domain == "" ? true : false

    invite_message_template {
      email_subject = "Your temporary password"
      email_message = "Your username is {username} and temporary password is {####}"
      sms_message   = "Your username is {username} and temporary password is {####}"
    }
  }

  # Account recovery
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  tags = local.common_tags
}

# Cognito User Pool Client following CDK configuration
resource "aws_cognito_user_pool_client" "user_pool_client" {
  name         = "${var.name_prefix}-user-pool-client"
  user_pool_id = local.user_pool.user_pool_id

  # OAuth configuration following CDK defaults
  generate_secret = false

  # Token validity following CDK configuration
  access_token_validity  = 60 # 1 hour
  id_token_validity      = 60 # 1 hour  
  refresh_token_validity = 30 # 30 days

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }

  # Token revocation
  enable_token_revocation = true

  # Auth flows following CDK configuration
  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]

  # Prevent user existence errors
  prevent_user_existence_errors = "ENABLED"

  # Read attributes following CDK configuration
  read_attributes = [
    "email",
    "email_verified",
    "preferred_username"
  ]

  # Supported identity providers
  supported_identity_providers = ["COGNITO"]

  # OAuth scopes and flows
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes = [
    "openid",
    "email",
    "phone",
    "profile"
  ]

  # Callback URLs will be set by the web application module
  callback_urls = ["https://localhost:3000"]
  logout_urls   = ["https://localhost:3000"]
}
# Cognito Identity Pool following CDK configuration
resource "aws_cognito_identity_pool" "identity_pool" {
  #checkov:skip=CKV_AWS_366:Unauthenticated access is controlled by variable validation that enforces allow_unauthenticated_identities=false
  identity_pool_name               = local.identity_pool_name
  allow_unauthenticated_identities = var.identity_pool_options.allow_unauthenticated_identities
  allow_classic_flow               = var.identity_pool_options.allow_classic_flow

  cognito_identity_providers {
    client_id               = aws_cognito_user_pool_client.user_pool_client.id
    provider_name           = local.user_pool.endpoint
    server_side_token_check = false
  }

  tags = local.common_tags
}

# IAM Role for authenticated users
resource "aws_iam_role" "authenticated" {
  name = "${substr(var.name_prefix, 0, 40)}-auth-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "cognito-identity.amazonaws.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "cognito-identity.amazonaws.com:aud" = aws_cognito_identity_pool.identity_pool.id
          }
          "ForAnyValue:StringLike" = {
            "cognito-identity.amazonaws.com:amr" = "authenticated"
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

# IAM Role for unauthenticated users (optional)
resource "aws_iam_role" "unauthenticated" {
  count = var.identity_pool_options.allow_unauthenticated_identities ? 1 : 0
  name  = "${substr(var.name_prefix, 0, 40)}-unauth-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "cognito-identity.amazonaws.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "cognito-identity.amazonaws.com:aud" = aws_cognito_identity_pool.identity_pool.id
          }
          "ForAnyValue:StringLike" = {
            "cognito-identity.amazonaws.com:amr" = "unauthenticated"
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

# Basic policy for authenticated users
resource "aws_iam_policy" "authenticated_policy" {
  #checkov:skip=CKV_AWS_355:Cognito Sync and Mobile Analytics services do not support resource-level permissions
  #checkov:skip=CKV_AWS_290:Cognito Sync and Mobile Analytics services do not support resource-level permissions
  name        = "${var.name_prefix}-authenticated-policy"
  description = "Basic policy for authenticated users"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "mobileanalytics:PutEvents"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "cognito-sync:*"
        ]
        Resource = "*"
      },
      # Cognito Identity permissions scoped to specific identity pool
      # Excludes credential exposure actions like GetCredentialsForIdentity
      {
        Effect = "Allow"
        Action = [
          "cognito-identity:GetId",
          "cognito-identity:GetIdentityPoolRoles",
          "cognito-identity:ListIdentities"
        ]
        Resource = aws_cognito_identity_pool.identity_pool.arn
        Condition = {
          StringEquals = {
            "cognito-identity.amazonaws.com:aud" = aws_cognito_identity_pool.identity_pool.id
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "authenticated_policy_attachment" {
  role       = aws_iam_role.authenticated.name
  policy_arn = aws_iam_policy.authenticated_policy.arn
}

# Basic policy for unauthenticated users (if enabled)
resource "aws_iam_policy" "unauthenticated_policy" {
  #checkov:skip=CKV_AWS_355:Cognito Sync and Mobile Analytics services do not support resource-level permissions
  #checkov:skip=CKV_AWS_290:Cognito Sync and Mobile Analytics services do not support resource-level permissions
  count       = var.identity_pool_options.allow_unauthenticated_identities ? 1 : 0
  name        = "${var.name_prefix}-unauthenticated-policy"
  description = "Basic policy for unauthenticated users"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "mobileanalytics:PutEvents",
          "cognito-sync:*"
        ]
        Resource = "*"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "unauthenticated_policy_attachment" {
  count      = var.identity_pool_options.allow_unauthenticated_identities ? 1 : 0
  role       = aws_iam_role.unauthenticated[0].name
  policy_arn = aws_iam_policy.unauthenticated_policy[0].arn
}

# Attach roles to identity pool
resource "aws_cognito_identity_pool_roles_attachment" "identity_pool_roles" {
  identity_pool_id = aws_cognito_identity_pool.identity_pool.id

  roles = merge(
    {
      authenticated = aws_iam_role.authenticated.arn
    },
    var.identity_pool_options.allow_unauthenticated_identities ? {
      unauthenticated = aws_iam_role.unauthenticated[0].arn
    } : {}
  )
}

# Admin user and group creation is now handled externally

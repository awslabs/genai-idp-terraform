# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
/**
 * # SageMaker UDOP Processor Example with Web UI
 *
 * This example demonstrates how to use the SageMaker UDOP processor from the GenAI IDP Accelerator
 * with the integrated Web UI. It creates all the necessary resources including S3 buckets, KMS key, 
 * and uses the top-level module to deploy the complete solution with the SageMaker UDOP processor.
 */

provider "aws" {
  region = var.region
}

provider "awscc" {
  region = var.region
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

# Create a random string for unique resource names
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Local values
locals {
  name_prefix = "${var.prefix}-${random_string.suffix.result}"
}

# Create KMS key for encryption
resource "aws_kms_key" "encryption_key" {
  description             = "KMS key for IDP Processing Environment"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch Logs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${data.aws_region.current.id}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          ArnEquals = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:*"
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_kms_alias" "encryption_key" {
  name          = "alias/idp-sagemaker-udop-${random_string.suffix.result}"
  target_key_id = aws_kms_key.encryption_key.key_id
}

# Create S3 buckets for document processing
resource "aws_s3_bucket" "input_bucket" {
  bucket        = "${var.prefix}-input-${random_string.suffix.result}"
  force_destroy = true
  tags          = var.tags
}

resource "aws_s3_bucket" "output_bucket" {
  bucket        = "${var.prefix}-output-${random_string.suffix.result}"
  force_destroy = true
  tags          = var.tags
}

resource "aws_s3_bucket" "working_bucket" {
  bucket        = "${var.prefix}-working-${random_string.suffix.result}"
  force_destroy = true
  tags          = var.tags
}

# Optional buckets (created conditionally)
resource "aws_s3_bucket" "logging_bucket" {
  count         = var.web_ui.logging_enabled ? 1 : 0
  bucket        = "${var.prefix}-logging-${random_string.suffix.result}"
  force_destroy = true
  tags          = var.tags
}

resource "aws_s3_bucket" "evaluation_baseline_bucket" {
  count         = var.enable_evaluation ? 1 : 0
  bucket        = "${var.prefix}-evaluation-baseline-${random_string.suffix.result}"
  force_destroy = true
  tags          = var.tags
}

resource "aws_s3_bucket" "reporting_bucket" {
  count         = var.enable_reporting ? 1 : 0
  bucket        = "${var.prefix}-reporting-${random_string.suffix.result}"
  force_destroy = true
  tags          = var.tags
}

# Optional: Create Glue database for reporting if reporting is enabled
resource "aws_glue_catalog_database" "reporting_database" {
  count       = var.enable_reporting ? 1 : 0
  name        = "${var.prefix}-reporting-database-${random_string.suffix.result}"
  description = "Database containing tables for evaluation metrics and document processing analytics"
  tags        = var.tags
}

# Enable EventBridge notifications on input bucket (required for processor to work)
resource "aws_s3_bucket_notification" "input_bucket_notification" {
  bucket      = aws_s3_bucket.input_bucket.id
  eventbridge = true
}

#
# Cognito User Identity Resources
#

# Cognito User Pool
resource "aws_cognito_user_pool" "user_pool" {
  name                     = "${local.name_prefix}-user-pool"
  auto_verified_attributes = ["email"]
  deletion_protection      = "INACTIVE" # Disabled for examples

  password_policy {
    minimum_length                   = 8
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = true
    require_uppercase                = true
    temporary_password_validity_days = 7
  }

  user_pool_add_ons {
    advanced_security_mode = "ENFORCED"
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  schema {
    attribute_data_type = "String"
    name                = "email"
    required            = true
    mutable             = true
  }

  admin_create_user_config {
    allow_admin_create_user_only = true
    invite_message_template {
      email_message = "Your username is {username} and temporary password is {####}. Please sign in and change your password."
      email_subject = "Your temporary password for GenAI IDP Accelerator"
      sms_message   = "Your username is {username} and temporary password is {####}"
    }
  }

  tags = {
    Name = "${local.name_prefix}-user-pool"
  }
}

# Cognito User Pool Client
resource "aws_cognito_user_pool_client" "user_pool_client" {
  name         = "${local.name_prefix}-user-pool-client"
  user_pool_id = aws_cognito_user_pool.user_pool.id

  allowed_oauth_flows                  = ["code"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = ["email", "openid", "profile"]
  callback_urls                        = ["http://localhost:3000"]
  logout_urls                          = ["http://localhost:3000"]
  supported_identity_providers         = ["COGNITO"]

  access_token_validity  = 60
  id_token_validity      = 60
  refresh_token_validity = 30

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }

  generate_secret = false

  explicit_auth_flows = [
    "ALLOW_ADMIN_USER_PASSWORD_AUTH",
    "ALLOW_CUSTOM_AUTH",
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]
}

# Cognito Identity Pool
resource "aws_cognito_identity_pool" "identity_pool" {
  identity_pool_name               = "${local.name_prefix}-identity-pool"
  allow_unauthenticated_identities = false

  cognito_identity_providers {
    client_id               = aws_cognito_user_pool_client.user_pool_client.id
    provider_name           = aws_cognito_user_pool.user_pool.endpoint
    server_side_token_check = false
  }

  tags = {
    Name = "${local.name_prefix}-identity-pool"
  }
}

# IAM role for authenticated users
resource "aws_iam_role" "authenticated_role" {
  name = "${local.name_prefix}-authenticated-role"

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

  tags = {
    Name = "${local.name_prefix}-authenticated-role"
  }
}

# IAM role for unauthenticated users
resource "aws_iam_role" "unauthenticated_role" {
  name = "${local.name_prefix}-unauthenticated-role"

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

  tags = {
    Name = "${local.name_prefix}-unauthenticated-role"
  }
}

# Attach roles to identity pool
resource "aws_cognito_identity_pool_roles_attachment" "identity_pool_roles" {
  identity_pool_id = aws_cognito_identity_pool.identity_pool.id

  roles = {
    "authenticated"   = aws_iam_role.authenticated_role.arn
    "unauthenticated" = aws_iam_role.unauthenticated_role.arn
  }
}

# Admin user creation (optional, externalized from the module)
resource "aws_cognito_user" "admin_user" {
  count        = var.admin_email != null && var.admin_email != "" ? 1 : 0
  user_pool_id = aws_cognito_user_pool.user_pool.id
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
  user_pool_id = aws_cognito_user_pool.user_pool.id
  description  = "Administrators"
  precedence   = 0
}

# Add admin user to admin group
resource "aws_cognito_user_in_group" "admin_user_in_group" {
  count        = var.admin_email != null && var.admin_email != "" ? 1 : 0
  user_pool_id = aws_cognito_user_pool.user_pool.id
  group_name   = aws_cognito_user_group.admin_group[0].name
  username     = aws_cognito_user.admin_user[0].username
}

# Create and train the SageMaker UDOP model
module "sagemaker_model" {
  source = "./sagemaker-model"

  name_prefix   = local.name_prefix
  kms_key_id    = aws_kms_key.encryption_key.key_id
  max_epochs    = var.training_config.max_epochs
  base_model    = var.training_config.base_model
  retrain_model = var.training_config.retrain_model

  tags = var.tags
}

# Read configuration from config library (pattern-3 for SageMaker UDOP processor)
locals {
  config_file_path = var.config_file_path
  config_yaml      = file(local.config_file_path)
  config           = yamldecode(local.config_yaml)
}

# Deploy the GenAI IDP Accelerator with SageMaker UDOP processor
module "genai_idp_accelerator" {
  source = "../.."

  # Processor configuration
  sagemaker_udop_processor = {
    classification_endpoint_arn = aws_sagemaker_endpoint.udop_endpoint.arn
    summarization = {
      enabled  = var.summarization_enabled
      model_id = var.summarization_model_id
    }
    config            = local.config
  }

  # Use external user identity instead of creating new one
  user_identity = {
    user_pool_arn          = aws_cognito_user_pool.user_pool.arn
    user_pool_client_id    = aws_cognito_user_pool_client.user_pool_client.id
    identity_pool_id       = aws_cognito_identity_pool.identity_pool.id
    authenticated_role_arn = aws_iam_role.authenticated_role.arn
  }

  # Resource ARNs
  input_bucket_arn   = aws_s3_bucket.input_bucket.arn
  output_bucket_arn  = aws_s3_bucket.output_bucket.arn
  working_bucket_arn = aws_s3_bucket.working_bucket.arn
  encryption_key_arn = aws_kms_key.encryption_key.arn

  # Evaluation configuration
  evaluation = var.enable_evaluation ? {
    enabled             = true
    model_id            = var.evaluation_model_id
    baseline_bucket_arn = aws_s3_bucket.evaluation_baseline_bucket[0].arn
  } : { enabled = false }

  # Reporting configuration
  reporting = var.enable_reporting ? {
    enabled       = true
    bucket_arn    = aws_s3_bucket.reporting_bucket[0].arn
    database_name = aws_glue_catalog_database.reporting_database[0].name
  } : { enabled = false }

  # API configuration (consolidated)
  api = var.api

  # Feature flags (DEPRECATED - use api variable instead)
  # These are kept for backward compatibility during migration
  enable_api         = var.enable_api
  agent_analytics    = var.agent_analytics
  chat_with_document = var.chat_with_document
  process_changes    = var.process_changes
  discovery          = var.discovery

  # Layer configuration
  force_rebuild_layers = var.force_rebuild_layers

  # Web UI configuration
  web_ui = {
    enabled                    = var.web_ui.enabled
    create_infrastructure      = var.web_ui.create_infrastructure
    bucket_name                = var.web_ui.bucket_name
    cloudfront_distribution_id = var.web_ui.cloudfront_distribution_id
    logging_enabled            = var.web_ui.logging_enabled
    logging_bucket_arn         = var.web_ui.logging_enabled ? aws_s3_bucket.logging_bucket[0].arn : null
    enable_signup              = var.web_ui.enable_signup
    display_name               = "SageMaker UDOP Processor (${element(split("/", var.config_file_path), length(split("/", var.config_file_path)) - 2)})"
  }

  # General configuration
  prefix                       = var.prefix
  log_level                    = var.log_level
  log_retention_days           = var.log_retention_days
  data_tracking_retention_days = var.data_tracking_retention_days

  tags = var.tags
}

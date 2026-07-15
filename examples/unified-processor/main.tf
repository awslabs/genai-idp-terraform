# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
/**
 * # Unified Processor Example — dual-mode routing (BDA + Bedrock-LLM in one deployment)
 *
 * ONE processor, ONE Step Functions state machine, with both the Bedrock-LLM
 * branch and the Bedrock Data Automation (BDA) branch always deployed.
 * Each document routes at runtime by its configuration version's `use_bda` flag,
 * selected per upload via the `config-version` S3 object metadata.
 *
 * Two configuration versions are seeded:
 *   - `default` — Bedrock-LLM (`use_bda` absent). Documents tagged
 *     `config-version=default` route RouteByProcessingMode -> OCRStep.
 *   - `<bda_version_name>` (default `bda`) — `use_bda: true` plus a top-level
 *     `bda_project_arn` linking it to a BDA project. Documents tagged with this
 *     version route RouteByProcessingMode -> BDA_InvokeDataAutomation.
 *
 * The per-version `bda_project_arn` is lifted out of the config body by the
 * `processor-configuration` module and seeded onto the version's DynamoDB row as
 * `BdaProjectArn` (declarative replacement for a manual `update-item`). The
 * default is never relinked.
 *
 * The BDA project: set `create_bda_project = true` to have this example create one
 * (self-contained on a clean account), or pass an existing `bda_project_arn`.
 */

provider "aws" {
  region = var.region
}

provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

provider "awscc" {
  region = var.region
}

# OpenSearch provider for the optional Knowledge Base vector index. When the KB
# is disabled (default), the collection isn't created, so point at a harmless
# placeholder URL and skip the healthcheck (mirrors examples/bda-processor).
provider "opensearch" {
  url         = local.knowledge_base_enabled ? aws_opensearchserverless_collection.knowledge_base_collection[0].collection_endpoint : "https://placeholder.us-east-1.es.amazonaws.com"
  aws_region  = var.region
  healthcheck = false
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

# Create a random string for unique resource names
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

locals {
  name_prefix = "${var.prefix}-${random_string.suffix.result}"

  rbac_enabled     = try(var.rbac.enabled, false)
  admin_group_name = local.rbac_enabled ? try(module.genai_idp_accelerator.rbac_group_names["Admin"], "Admin") : one(aws_cognito_user_group.admin_group[*].name)

  # --------------------------------------------------------------------------
  # Knowledge Base backend (default on; see knowledge-base.tf)
  # --------------------------------------------------------------------------
  # Gates the whole OpenSearch Serverless + Bedrock Knowledge Base stack.
  knowledge_base_enabled = var.create_knowledge_base

  # Embedding model id used by knowledge-base.tf for the KB IAM policy and the
  # collection's embedding_model_arn. The query/generation model_id is passed to
  # the root api.knowledge_base wiring straight from var.knowledge_base_model_id
  # and MUST be a cross-region inference-profile id (us./eu./apac. prefix): the
  # KB query resolver builds an inference-profile ARN from it.
  knowledge_base_embedding_model_id = var.knowledge_base_embedding_model_id

  # DEFAULT (Bedrock-LLM) configuration version. The lending-package sample does
  # NOT set `use_bda`, so `config-version=default` routes through the Bedrock-LLM
  # branch (RouteByProcessingMode -> OCRStep).
  config = yamldecode(file(var.config_file_path))

  # Effective BDA project ARN: the one this example creates (create_bda_project)
  # or an existing ARN passed via var.bda_project_arn.
  effective_bda_project_arn = var.create_bda_project ? awscc_bedrock_data_automation_project.bda_project[0].project_arn : var.bda_project_arn

  # BDA-linked additional version. `use_bda: true` routes
  # `config-version=<bda_version_name>` through the BDA branch. The top-level
  # `bda_project_arn` is lifted out by processor-configuration and seeded as
  # `BdaProjectArn`. When no ARN is available the key is omitted and the version
  # degrades to the Bedrock-LLM branch at runtime.
  bda_mode_config = merge(
    {
      use_bda = true
      notes   = "Dual-mode demo: routes documents to the BDA branch."
    },
    local.effective_bda_project_arn != "" ? { bda_project_arn = local.effective_bda_project_arn } : {}
  )

  # Extra config versions from files (optional), plus the BDA-linked version.
  # Paths are relative to this example dir (or absolute). tfvars cannot call
  # yamldecode/file, so the decode happens here.
  additional_configurations = merge(
    {
      for name, p in var.additional_config_files :
      name => yamldecode(file(startswith(p, "/") ? p : "${path.module}/${p}"))
    },
    {
      (var.bda_version_name) = local.bda_mode_config
    }
  )
}

# Create KMS key for encryption
resource "aws_kms_key" "encryption_key" {
  description             = "KMS key for IDP Unified Processor example"
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
            "kms:EncryptionContext:aws:logs:arn" = "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:*"
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_kms_alias" "encryption_key" {
  name          = "alias/idp-unified-${random_string.suffix.result}"
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

# Optional logging bucket (created conditionally)
resource "aws_s3_bucket" "logging_bucket" {
  count         = var.web_ui.logging_enabled ? 1 : 0
  bucket        = "${var.prefix}-logging-${random_string.suffix.result}"
  force_destroy = true
  tags          = var.tags
}

# CloudFront standard logging requires legacy ACLs on the destination bucket.
resource "aws_s3_bucket_ownership_controls" "logging_bucket" {
  count  = var.web_ui.logging_enabled ? 1 : 0
  bucket = aws_s3_bucket.logging_bucket[0].id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "logging_bucket" {
  count      = var.web_ui.logging_enabled ? 1 : 0
  bucket     = aws_s3_bucket.logging_bucket[0].id
  acl        = "log-delivery-write"
  depends_on = [aws_s3_bucket_ownership_controls.logging_bucket]
}

# Enable EventBridge notifications on input bucket (required for processor to work).
#
# Terraform allows only ONE aws_s3_bucket_notification per bucket, so the optional
# Knowledge Base ingestion Lambda trigger is folded in here via a dynamic block
# (rather than a second notification resource). When create_knowledge_base is
# false the dynamic block emits nothing and this is just the EventBridge hook.
resource "aws_s3_bucket_notification" "input_bucket_notification" {
  bucket      = aws_s3_bucket.input_bucket.id
  eventbridge = true

  dynamic "lambda_function" {
    for_each = local.knowledge_base_enabled ? [1] : []
    content {
      lambda_function_arn = aws_lambda_function.knowledge_base_ingestion[0].arn
      events              = ["s3:ObjectCreated:Put"]
    }
  }

  depends_on = [aws_lambda_permission.allow_s3_invoke]
}

#
# Cognito User Identity Resources
#

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

resource "aws_cognito_identity_pool_roles_attachment" "identity_pool_roles" {
  identity_pool_id = aws_cognito_identity_pool.identity_pool.id

  roles = {
    "authenticated"   = aws_iam_role.authenticated_role.arn
    "unauthenticated" = aws_iam_role.unauthenticated_role.arn
  }
}

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

  lifecycle {
    ignore_changes = [
      password,
      temporary_password
    ]
  }
}

resource "aws_cognito_user_group" "admin_group" {
  count        = var.admin_email != null && var.admin_email != "" && !local.rbac_enabled ? 1 : 0
  name         = "Admin"
  user_pool_id = aws_cognito_user_pool.user_pool.id
  description  = "Administrators"
  precedence   = 0
}

resource "aws_cognito_user_in_group" "admin_user_in_group" {
  count        = var.admin_email != null && var.admin_email != "" ? 1 : 0
  user_pool_id = aws_cognito_user_pool.user_pool.id
  group_name   = local.admin_group_name
  username     = aws_cognito_user.admin_user[0].username
}

# Deploy the GenAI IDP Accelerator with the Bedrock-LLM processor façade.
#
# Both the Bedrock-LLM and BDA branches are always deployed by the shared engine.
# The `default` config stays Bedrock-LLM; the BDA-linked version (carried in
# `additional_configurations` with its own `bda_project_arn`) routes to BDA.
module "genai_idp_accelerator" {
  source = "../.."

  providers = {
    aws.us-east-1 = aws.us-east-1
  }

  # Build strategy (CodeBuild by default; local Docker/npm when build.lambda_local /
  # build.ui_local are true). Threaded through to the layer, env, api, and web-ui
  # build paths at the root.
  build = var.build

  # Processor configuration (Bedrock-LLM default + BDA-linked additional version)
  bedrock_llm_processor = {
    classification_model_id = var.classification_model_id
    extraction_model_id     = var.extraction_model_id
    summarization = {
      enabled  = var.summarization_enabled
      model_id = var.summarization_model_id
    }
    config = local.config
    # The BDA version carries its own per-version `bda_project_arn`, so no
    # top-level fallback is needed here. The default is never relinked.
    additional_configurations = local.additional_configurations
  }

  # Use external user identity created above
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

  # API configuration.
  #
  # chat_with_document + knowledge_base drive the Web UI's "Agent Companion Chat"
  # / "Document KB" tools. chat_with_document is per-document Q&A. The
  # knowledge_base backend (var.create_knowledge_base, default on) stands up an
  # OpenSearch Serverless + Bedrock Knowledge Base that ingests uploaded docs from
  # the input bucket; its ARN is wired in below. When create_knowledge_base is
  # false the KB is not created and knowledge_base_arn is null, leaving
  # chat-with-document to operate without a KB.
  api = {
    enabled            = true
    chat_with_document = { enabled = var.chat_with_document_enabled }
    knowledge_base = {
      enabled            = var.create_knowledge_base
      knowledge_base_arn = try(aws_bedrockagent_knowledge_base.knowledge_base[0].arn, null)
      model_id           = var.knowledge_base_model_id
      embedding_model_id = var.knowledge_base_embedding_model_id
    }
    # Discovery feature (Web UI "Discovery" tab); provisions the discovery pipeline.
    discovery = { enabled = var.create_discovery }
  }

  rbac = var.rbac

  # Web UI configuration
  web_ui = {
    enabled                    = var.web_ui.enabled
    create_infrastructure      = var.web_ui.create_infrastructure
    bucket_name                = var.web_ui.bucket_name
    cloudfront_distribution_id = var.web_ui.cloudfront_distribution_id
    logging_enabled            = var.web_ui.logging_enabled
    logging_bucket_arn         = var.web_ui.logging_enabled ? aws_s3_bucket.logging_bucket[0].arn : null
    enable_signup              = var.web_ui.enable_signup
    display_name               = "Unified Processor (dual-mode)"
  }

  # General configuration
  prefix                       = var.prefix
  seed_managed_configs         = var.seed_managed_configs
  log_level                    = var.log_level
  log_retention_days           = var.log_retention_days
  data_tracking_retention_days = var.data_tracking_retention_days

  tags = var.tags
}

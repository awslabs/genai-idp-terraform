# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
/**
 * # Unified Processor — HEADLESS dual-mode demo
 *
 *   - api = { enabled = false }, no AppSync API; processors run DynamoDB-only
 *   - no user-identity (Cognito), no web-ui
 *   - no vpc-endpoints, no hitl, no rbac, no gsi-backfill
 *   - ONE processor / ONE state machine, dual-mode: the `default` config
 *     version routes to the Bedrock-LLM branch, the `bda` version (use_bda=true
 *     + bda_project_arn) routes to the BDA branch. Per-document routing via the
 *     `config-version` S3 object metadata.
 *
 * Tracking/state is written to the DynamoDB tracking table only (no GraphQL).
 */

provider "aws" {
  region = var.region
}

# Root module requires an us-east-1 aliased provider (WAF/CloudFront). Unused
# here because web-ui is disabled, but the alias must still be passed.
provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

provider "awscc" {
  region = var.region
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

locals {
  name_prefix = "${var.prefix}-${random_string.suffix.result}"

  # DEFAULT (Bedrock-LLM) config version. The lending sample omits use_bda, so
  # config-version=default routes RouteByProcessingMode -> OCRStep.
  config = yamldecode(file(var.config_file_path))

  effective_bda_project_arn = var.create_bda_project ? awscc_bedrock_data_automation_project.bda_project[0].project_arn : var.bda_project_arn

  # BDA-linked version: use_bda=true + top-level bda_project_arn (lifted onto the
  # DynamoDB row as BdaProjectArn). config-version=bda routes to the BDA branch.
  bda_mode_config = merge(
    {
      use_bda = true
      notes   = "Headless dual-mode demo: routes documents to the BDA branch."
    },
    local.effective_bda_project_arn != "" ? { bda_project_arn = local.effective_bda_project_arn } : {}
  )

  additional_configurations = {
    (var.bda_version_name) = local.bda_mode_config
  }
}

resource "aws_kms_key" "encryption_key" {
  description             = "KMS key for IDP headless dual-mode demo"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "Enable IAM User Permissions"
        Effect    = "Allow"
        Principal = { AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "Allow CloudWatch Logs"
        Effect    = "Allow"
        Principal = { Service = "logs.${data.aws_region.current.id}.amazonaws.com" }
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
  name          = "alias/idp-headless-${random_string.suffix.result}"
  target_key_id = aws_kms_key.encryption_key.key_id
}

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

# EventBridge notifications on the input bucket trigger the processing pipeline.
resource "aws_s3_bucket_notification" "input_bucket_notification" {
  bucket      = aws_s3_bucket.input_bucket.id
  eventbridge = true
}

# Self-contained BDA project for the BDA branch (clean-account path).
resource "awscc_bedrock_data_automation_project" "bda_project" {
  count = var.create_bda_project ? 1 : 0

  project_name        = "${local.name_prefix}-bda-project"
  project_description = "Headless dual-mode demo: BDA project linked to the bda config version"

  standard_output_configuration = {
    document = {
      extraction = {
        granularity  = { types = ["PAGE", "ELEMENT"] }
        bounding_box = { state = "DISABLED" }
      }
      generative_field = { state = "DISABLED" }
      output_format = {
        text_format            = { types = ["MARKDOWN"] }
        additional_file_format = { state = "DISABLED" }
      }
    }
  }
}

# GenAI IDP Accelerator — HEADLESS: api disabled, no user-identity, no web-ui.
module "genai_idp_accelerator" {
  source = "../.."

  providers = {
    aws.us-east-1 = aws.us-east-1
  }

  bedrock_llm_processor = {
    classification_model_id   = var.classification_model_id
    extraction_model_id       = var.extraction_model_id
    summarization             = { enabled = false }
    config                    = local.config
    additional_configurations = local.additional_configurations
  }

  # Headless when enable_api = false: no GraphQL API, DynamoDB-only tracking.
  # chat_with_document defaults ON and is enabled purely off its own flag (not
  # AND-gated on api.enabled), so it is pinned to var.enable_chat_with_document
  # to avoid referencing the absent API module when the API is off.
  api = {
    enabled            = var.enable_api
    chat_with_document = { enabled = var.enable_chat_with_document }
  }

  # web-ui requires the API; no external user-identity (no Cognito) when headless.
  web_ui = { enabled = var.enable_web_ui }

  input_bucket_arn   = aws_s3_bucket.input_bucket.arn
  output_bucket_arn  = aws_s3_bucket.output_bucket.arn
  working_bucket_arn = aws_s3_bucket.working_bucket.arn
  encryption_key_arn = aws_kms_key.encryption_key.arn

  prefix               = var.prefix
  seed_managed_configs = false
  log_level            = var.log_level
  log_retention_days   = var.log_retention_days

  tags = var.tags
}

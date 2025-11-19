# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
/**
 * # Processing Environment Example
 *
 * This example demonstrates how to use the Processing Environment module from the GenAI IDP Accelerator.
 * It creates all the necessary resources including S3 buckets, KMS key, IDP common layer, and the processing environment.
 */

provider "aws" {
  region = var.region
}

# Create KMS key for encryption
resource "aws_kms_key" "encryption_key" {
  description             = "KMS key for IDP Processing Environment"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.kms_key_policy.json

  tags = var.tags
}

# KMS key policy to allow CloudWatch Logs service to use the key
data "aws_iam_policy_document" "kms_key_policy" {
  statement {
    sid    = "Enable IAM User Permissions"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "Allow CloudWatch Logs"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["logs.${var.region}.amazonaws.com"]
    }
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = ["*"]
    condition {
      test     = "ArnEquals"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:${data.aws_partition.current.partition}:logs:${var.region}:${data.aws_caller_identity.current.account_id}:*"]
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
resource "aws_kms_alias" "encryption_key_alias" {
  name          = "alias/idp-processing-environment-${random_string.suffix.result}"
  target_key_id = aws_kms_key.encryption_key.key_id
}

# Create S3 buckets for document processing
resource "aws_s3_bucket" "input_bucket" {
  bucket = "${var.prefix}-input-bucket-${random_string.suffix.result}"
  tags   = var.tags
}

resource "aws_s3_bucket_server_side_encryption_configuration" "input_bucket" {
  bucket = aws_s3_bucket.input_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.encryption_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket" "output_bucket" {
  bucket = "${var.prefix}-output-bucket-${random_string.suffix.result}"
  tags   = var.tags
}

resource "aws_s3_bucket_server_side_encryption_configuration" "output_bucket" {
  bucket = aws_s3_bucket.output_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.encryption_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

# Create evaluation baseline bucket (conditional)
resource "aws_s3_bucket" "evaluation_baseline_bucket" {
  count         = var.enable_evaluation ? 1 : 0
  bucket        = "${var.prefix}-evaluation-baseline-${random_string.suffix.result}"
  force_destroy = true

  tags = var.tags
}

resource "aws_s3_bucket_server_side_encryption_configuration" "evaluation_baseline_bucket" {
  count  = var.enable_evaluation ? 1 : 0
  bucket = aws_s3_bucket.evaluation_baseline_bucket[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.encryption_key.arn
    }
    bucket_key_enabled = true
  }
}

# Create reporting S3 bucket (conditional)
resource "aws_s3_bucket" "reporting_bucket" {
  count         = var.enable_reporting ? 1 : 0
  bucket        = "${var.prefix}-reporting-bucket-${random_string.suffix.result}"
  force_destroy = true
  tags          = var.tags
}

resource "aws_s3_bucket_versioning" "reporting_bucket_versioning" {
  count  = var.enable_reporting ? 1 : 0
  bucket = aws_s3_bucket.reporting_bucket[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "reporting_bucket_encryption" {
  count  = var.enable_reporting ? 1 : 0
  bucket = aws_s3_bucket.reporting_bucket[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.encryption_key.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "reporting_bucket_pab" {
  count  = var.enable_reporting ? 1 : 0
  bucket = aws_s3_bucket.reporting_bucket[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Create reporting database (conditional)
resource "aws_glue_catalog_database" "reporting_database" {
  count       = var.enable_reporting ? 1 : 0
  name        = "${var.prefix}_reporting_database_${random_string.suffix.result}"
  description = "Database containing tables for evaluation metrics and document processing analytics"
  tags        = var.tags
}

# Create reporting environment (conditional)
module "reporting_environment" {
  count  = var.enable_reporting ? 1 : 0
  source = "../../modules/reporting"

  # Pass the reporting bucket ARN
  reporting_bucket_arn = aws_s3_bucket.reporting_bucket[0].arn

  # Pass the reporting database name
  reporting_database_name = aws_glue_catalog_database.reporting_database[0].name
}

# Create the IDP Common Layer
module "idp_common_layer" {
  source = "../../modules/idp-common-layer"

  # Use a unique layer prefix per stack to avoid conflicts with parallel deployments
  name_prefix = "${var.prefix}-processing-env-${random_string.suffix.result}"

  # Configure the layer with the extras needed by processing environment functions
  # Based on requirements.txt analysis: queue_sender and workflow_tracker use appsync
  idp_common_extras = var.idp_common_layer_extras

  # Optional: Force rebuild if needed
  force_rebuild = var.force_layer_rebuild
}

# Create the Processing Environment
module "processing_environment" {
  source = "../../modules/processing-environment"

  # Required: External IDP common layer ARN
  idp_common_layer_arn = module.idp_common_layer.layer_arn

  # Required parameters
  input_bucket_arn  = aws_s3_bucket.input_bucket.arn
  output_bucket_arn = aws_s3_bucket.output_bucket.arn

  metric_namespace = "${var.prefix}-metrics"

  # Optional: Reporting environment
  enable_reporting     = var.enable_reporting
  reporting_bucket_arn = var.enable_reporting ? aws_s3_bucket.reporting_bucket[0].arn : null

  # Optional: Evaluation configuration
  evaluation_config = var.enable_evaluation ? {
    baseline_bucket_arn  = aws_s3_bucket.evaluation_baseline_bucket[0].arn
    evaluation_model_arn = "arn:${data.aws_partition.current.partition}:bedrock:${var.region}::foundation-model/${var.evaluation_model_id}"
  } : null

  # Optional parameters
  encryption_key_arn = aws_kms_key.encryption_key.arn

  log_level                    = var.log_level
  log_retention_days           = var.log_retention_days
  data_tracking_retention_days = var.data_tracking_retention_days

  tags = var.tags
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

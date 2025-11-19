# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

# Generate a random string for the S3 bucket name
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# S3 bucket for storing application assets (shared across multiple modules)
#checkov:skip=CKV_AWS_145:S3 bucket encryption is configured via separate aws_s3_bucket_server_side_encryption_configuration resource
resource "aws_s3_bucket" "assets_bucket" {
  bucket        = "${var.bucket_prefix}-assets-${random_string.bucket_suffix.result}"
  force_destroy = true

  tags = merge(var.tags, {
    Name        = "${var.bucket_prefix}-assets"
    Purpose     = "Application asset storage"
    SharedUsage = "true"
  })
}

resource "aws_s3_bucket_server_side_encryption_configuration" "assets_bucket" {
  bucket = aws_s3_bucket.assets_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = "alias/aws/s3"
    }
  }
}

resource "aws_s3_bucket_versioning" "assets_bucket" {
  bucket = aws_s3_bucket.assets_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "assets_bucket" {
  bucket = aws_s3_bucket.assets_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Optional lifecycle configuration to manage old artifacts
resource "aws_s3_bucket_lifecycle_configuration" "assets_bucket" {
  count = var.enable_lifecycle_management ? 1 : 0

  bucket = aws_s3_bucket.assets_bucket.id

  rule {
    id     = "cleanup_old_assets"
    status = "Enabled"

    # Apply to all objects in the bucket
    filter {}

    # Clean up old artifacts after specified days
    expiration {
      days = var.asset_retention_days
    }

    # Clean up incomplete multipart uploads
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    # Clean up old versions if versioning is enabled
    noncurrent_version_expiration {
      noncurrent_days = var.old_version_retention_days
    }
  }
}

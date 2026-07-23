# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Bundle assembler: merges prefix-grouped loose files staged in this module's
# staging bucket into one multi-page PDF, written to the IDP input bucket so the
# accelerator processes them as a single bundle. See
# docs/plans/2026-07-21-bundle-assembler-design.md.

data "aws_partition" "current" {}
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

locals {
  build_dir = "${path.root}/.terraform/tmp/bundle-assembler"
  src_dir   = "${path.module}/../../src/lambda/bundle-assembler"
}

# =============================================================================
# Staging bucket (loose bundle parts land here; NOT wired to IDP ingestion)
# =============================================================================
resource "aws_s3_bucket" "staging" {
  bucket        = "${var.name_prefix}-staging-${random_string.suffix.result}"
  force_destroy = true
  tags          = var.tags
}

resource "aws_s3_bucket_versioning" "staging" {
  bucket = aws_s3_bucket.staging.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "staging" {
  bucket = aws_s3_bucket.staging.id

  dynamic "rule" {
    for_each = var.encryption_key_arn != null ? [1] : []
    content {
      apply_server_side_encryption_by_default {
        kms_master_key_id = var.encryption_key_arn
        sse_algorithm     = "aws:kms"
      }
      bucket_key_enabled = true
    }
  }
}

resource "aws_s3_bucket_public_access_block" "staging" {
  bucket                  = aws_s3_bucket.staging.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "staging_ssl_only" {
  bucket = aws_s3_bucket.staging.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnforceSSLOnly"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.staging.arn,
          "${aws_s3_bucket.staging.arn}/*"
        ]
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      }
    ]
  })
}

# EventBridge must be enabled on the bucket for the manifest rule to fire.
resource "aws_s3_bucket_notification" "staging" {
  bucket      = aws_s3_bucket.staging.id
  eventbridge = true
}

# Transient parts must not accumulate.
resource "aws_s3_bucket_lifecycle_configuration" "staging" {
  bucket = aws_s3_bucket.staging.id

  rule {
    id     = "DeleteAfterNDays"
    status = "Enabled"
    filter {
      prefix = ""
    }
    expiration {
      days = var.staging_retention_days
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

# =============================================================================
# Assembler Lambda build (bundle source + pypdf/Pillow for x86_64 Lambda)
# =============================================================================
resource "null_resource" "build" {
  triggers = {
    source_hash = sha1(join(",", [
      for f in fileset(local.src_dir, "**/*") : filesha256("${local.src_dir}/${f}")
    ]))
    # Bump when the build pipeline (pip flags) changes.
    build_pipeline_version = "manylinux2014_x86_64-v1"
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      BUILD_DIR="${local.build_dir}"
      SRC_DIR="${local.src_dir}"

      rm -rf "$BUILD_DIR"
      mkdir -p "$BUILD_DIR"
      cp -r "$SRC_DIR"/. "$BUILD_DIR/"

      # Install deps for the Lambda runtime (Linux x86_64), not the build host.
      # Pillow ships native wheels; the platform/python-version/implementation
      # flags force the manylinux cp312 wheel Lambda can import. pypdf is pure
      # python and unaffected.
      python3 -m pip install \
        --target "$BUILD_DIR" \
        --upgrade \
        --no-cache-dir \
        --quiet \
        --platform manylinux2014_x86_64 \
        --python-version 3.12 \
        --implementation cp \
        --only-binary=:all: \
        -r "$BUILD_DIR/requirements.txt"

      find "$BUILD_DIR" -type d -name '__pycache__' -exec rm -rf {} + 2>/dev/null || true
      find "$BUILD_DIR" -type d -name '*.dist-info' -prune -o -type d -name 'tests' -exec rm -rf {} + 2>/dev/null || true
    EOT
  }
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = local.build_dir
  output_path = "${local.build_dir}.zip"
  depends_on  = [null_resource.build]
}

resource "aws_cloudwatch_log_group" "assembler" {
  name              = "/aws/lambda/${var.name_prefix}-assembler-${random_string.suffix.result}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.encryption_key_arn
  tags              = var.tags
}

resource "aws_lambda_function" "assembler" {
  function_name = "${var.name_prefix}-assembler-${random_string.suffix.result}"

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  handler       = "index.handler"
  runtime       = "python3.12"
  architectures = ["x86_64"]
  timeout       = 300
  memory_size   = 1024
  role          = aws_iam_role.assembler.arn
  kms_key_arn   = var.encryption_key_arn
  description   = "Merges prefix-grouped staged files into one multi-page PDF for IDP ingestion"

  environment {
    variables = {
      LOG_LEVEL              = "INFO"
      IDP_INPUT_BUCKET       = var.idp_input_bucket_name
      DEFAULT_CONFIG_VERSION = var.default_config_version
    }
  }

  dynamic "vpc_config" {
    for_each = length(var.vpc_subnet_ids) > 0 ? [1] : []
    content {
      subnet_ids         = var.vpc_subnet_ids
      security_group_ids = var.vpc_security_group_ids
    }
  }

  tracing_config {
    mode = var.lambda_tracing_mode
  }

  depends_on = [aws_cloudwatch_log_group.assembler]
  tags       = var.tags
}

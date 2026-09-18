# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Version-check sub-feature (upstream v0.5.11)
#
# Provisions the shipped `version_check_resolver` Lambda backing the
# `getLatestPublishedVersion` field. It lists a public artifacts S3 bucket for
# `<prefix>/idp-main_<version>.yaml` objects and returns the newest published IDP
# version so the web UI can surface an "update available" banner.
#
# Created UNCONDITIONALLY, matching upstream, which gives its
# VersionCheckResolverFunction no Condition and routes the field in the
# unconditional part of its field map. Only the S3 read grant is conditional.
#
# Gating the Lambda itself instead (what this module used to do) left the field
# unmapped, so the dispatcher answered 404 on every page load — the UI calls it
# from the layout on every mount. The resolver already handles the disabled case
# itself, returning 200 `{"checkEnabled": false}` when PUBLIC_ARTIFACTS_BUCKET is
# unset, which is the response the UI expects.

locals {
  # Whether the S3-backed check is actually configured. The Lambda exists either
  # way; this only decides its env and its S3 grant.
  version_check_enabled = var.public_artifacts_bucket != ""

  version_check_env = merge(
    { LOG_LEVEL = var.log_level },
    local.version_check_enabled ? { PUBLIC_ARTIFACTS_BUCKET = var.public_artifacts_bucket } : {},
    var.public_artifacts_prefix != "" ? { PUBLIC_ARTIFACTS_PREFIX = var.public_artifacts_prefix } : {},
    var.public_artifacts_region != "" ? { PUBLIC_ARTIFACTS_REGION = var.public_artifacts_region } : {},
  )
}

# =============================================================================
# CloudWatch log group
# =============================================================================

resource "aws_cloudwatch_log_group" "version_check_resolver" {
  name              = "/aws/lambda/${local.api_name}-version-check-resolver"
  retention_in_days = var.log_retention_days
  kms_key_id        = local.encryption_key_arn
  tags              = var.tags
}

# =============================================================================
# Lambda: version_check_resolver
# =============================================================================

data "archive_file" "version_check_resolver" {
  type        = "zip"
  source_dir  = "${path.module}/../../sources/src/lambda/version_check_resolver"
  output_path = "${path.module}/../../.terraform/archives/version_check_resolver.zip"
}

# =============================================================================
# IAM role: least-privilege read on exactly the public artifacts bucket
# =============================================================================

resource "aws_iam_role" "version_check_resolver" {
  name = "${local.api_name}-version-check-resolver"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "version_check_resolver" {
  name = "version-check-resolver-policy"
  role = aws_iam_role.version_check_resolver.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          # Scoped to exactly this Lambda's own log group (and its streams).
          Effect = "Allow"
          Action = ["logs:CreateLogStream", "logs:PutLogEvents"]
          Resource = [
            aws_cloudwatch_log_group.version_check_resolver.arn,
            "${aws_cloudwatch_log_group.version_check_resolver.arn}:*",
          ]
        },
      ],
      # Omitted when no bucket is configured: interpolating an empty name yields
      # the invalid ARN `arn:aws:s3:::`, and the resolver needs no S3 access to
      # report checkEnabled=false.
      local.version_check_enabled ? [
        {
          # The resolver first attempts unsigned (anonymous) reads, then falls
          # back to these signed credentials if the bucket is not anonymously
          # listable.
          Effect = "Allow"
          Action = ["s3:GetObject", "s3:ListBucket"]
          Resource = [
            "arn:${data.aws_partition.current.partition}:s3:::${var.public_artifacts_bucket}",
            "arn:${data.aws_partition.current.partition}:s3:::${var.public_artifacts_bucket}/*",
          ]
        },
      ] : [],
    )
  })
}

resource "aws_lambda_function" "version_check_resolver" {
  architectures    = [var.lambda_architecture]
  function_name    = "${local.api_name}-version-check-resolver"
  role             = aws_iam_role.version_check_resolver.arn
  filename         = data.archive_file.version_check_resolver.output_path
  source_code_hash = data.archive_file.version_check_resolver.output_base64sha256
  handler          = "index.lambda_handler"
  runtime          = "python3.12"
  timeout          = 30
  memory_size      = 256
  layers           = compact([var.base_layer_arn, var.idp_common_layer_arn])

  environment { variables = local.version_check_env }

  tracing_config { mode = var.lambda_tracing_mode }

  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  depends_on = [aws_cloudwatch_log_group.version_check_resolver]
  tags       = var.tags
}

# These resources were `count`-gated on public_artifacts_bucket, so on a
# deployment that HAD set it they exist at index [0]. Without these blocks that
# address change is a destroy-and-recreate, which for the IAM role means a
# same-name create racing its own delete.
moved {
  from = aws_cloudwatch_log_group.version_check_resolver[0]
  to   = aws_cloudwatch_log_group.version_check_resolver
}

moved {
  from = aws_iam_role.version_check_resolver[0]
  to   = aws_iam_role.version_check_resolver
}

moved {
  from = aws_iam_role_policy.version_check_resolver[0]
  to   = aws_iam_role_policy.version_check_resolver
}

moved {
  from = aws_lambda_function.version_check_resolver[0]
  to   = aws_lambda_function.version_check_resolver
}

# AppSync data source/resolver (Query.getLatestPublishedVersion) + invoke policy
# removed in the v0.6.4 REST migration. getLatestPublishedVersion is now routed
# to version_check_resolver by the dispatcher (see dispatcher.tf); the
# dispatcher role grants the invoke.

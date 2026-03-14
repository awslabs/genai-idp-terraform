# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Dataset Deployer sub-features (v0.4.15+)
# Two independent deployers, each conditional on its own flag:
#   - ocr_benchmark_deployer  (enable_omni_ai_dataset)
#   - docsplit_testset_deployer (enable_docplit_poly_seq_dataset)
# Both require enable_test_studio (they write to the test_sets bucket).

locals {
  # Deployers only make sense when Test Studio is also enabled
  enable_ocr_benchmark_deployer    = var.enable_omni_ai_dataset && var.enable_test_studio
  enable_docsplit_testset_deployer = var.enable_docplit_poly_seq_dataset && var.enable_test_studio
}

# =============================================================================
# Shared IAM role for dataset deployers
# =============================================================================

resource "aws_iam_role" "dataset_deployers" {
  count = (local.enable_ocr_benchmark_deployer || local.enable_docsplit_testset_deployer) ? 1 : 0
  name  = "${local.api_name}-dataset-deployers"

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

resource "aws_iam_role_policy" "dataset_deployers" {
  count = (local.enable_ocr_benchmark_deployer || local.enable_docsplit_testset_deployer) ? 1 : 0
  name  = "dataset-deployers-policy"
  role  = aws_iam_role.dataset_deployers[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:${data.aws_partition.current.partition}:logs:*:*:*"
      },
      {
        # Public HuggingFace dataset read (anonymous S3 access)
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:ListBucket"]
        Resource = "*"
      },
      {
        # Write to test_sets bucket
        Effect = "Allow"
        Action = ["s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
        Resource = var.enable_test_studio ? [
          aws_s3_bucket.test_sets[0].arn,
          "${aws_s3_bucket.test_sets[0].arn}/*",
        ] : []
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
        Resource = local.encryption_key_arn != null ? local.encryption_key_arn : "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "dataset_deployers_xray" {
  count      = (local.enable_ocr_benchmark_deployer || local.enable_docsplit_testset_deployer) ? 1 : 0
  role       = aws_iam_role.dataset_deployers[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# =============================================================================
# Lambda: ocr_benchmark_deployer (OmniAI OCR Benchmark dataset)
# =============================================================================

resource "aws_cloudwatch_log_group" "ocr_benchmark_deployer" {
  count             = local.enable_ocr_benchmark_deployer ? 1 : 0
  name              = "/aws/lambda/${local.api_name}-ocr-benchmark-deployer"
  retention_in_days = var.log_retention_days
  kms_key_id        = local.encryption_key_arn
  tags              = var.tags
}

data "archive_file" "ocr_benchmark_deployer" {
  count       = local.enable_ocr_benchmark_deployer ? 1 : 0
  type        = "zip"
  source_dir  = "${path.module}/../../sources/src/lambda/ocr_benchmark_deployer"
  output_path = "${path.module}/../../.terraform/archives/ocr_benchmark_deployer.zip"
}

resource "aws_lambda_function" "ocr_benchmark_deployer" {
  count            = local.enable_ocr_benchmark_deployer ? 1 : 0
  function_name    = "${local.api_name}-ocr-benchmark-deployer"
  role             = aws_iam_role.dataset_deployers[0].arn
  filename         = data.archive_file.ocr_benchmark_deployer[0].output_path
  source_code_hash = data.archive_file.ocr_benchmark_deployer[0].output_base64sha256
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 900
  memory_size      = 1024
  layers           = compact([var.base_layer_arn, var.idp_common_layer_arn])

  environment {
    variables = {
      LOG_LEVEL       = var.log_level
      TEST_SET_BUCKET = aws_s3_bucket.test_sets[0].id
    }
  }

  tracing_config { mode = var.lambda_tracing_mode }

  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  depends_on = [aws_cloudwatch_log_group.ocr_benchmark_deployer]
  tags       = var.tags
}

# =============================================================================
# Lambda: docsplit_testset_deployer (RVL-CDIP-NMP Packet dataset)
# =============================================================================

resource "aws_cloudwatch_log_group" "docsplit_testset_deployer" {
  count             = local.enable_docsplit_testset_deployer ? 1 : 0
  name              = "/aws/lambda/${local.api_name}-docsplit-testset-deployer"
  retention_in_days = var.log_retention_days
  kms_key_id        = local.encryption_key_arn
  tags              = var.tags
}

data "archive_file" "docsplit_testset_deployer" {
  count       = local.enable_docsplit_testset_deployer ? 1 : 0
  type        = "zip"
  source_dir  = "${path.module}/../../sources/src/lambda/docsplit_testset_deployer"
  output_path = "${path.module}/../../.terraform/archives/docsplit_testset_deployer.zip"
}

resource "aws_lambda_function" "docsplit_testset_deployer" {
  count            = local.enable_docsplit_testset_deployer ? 1 : 0
  function_name    = "${local.api_name}-docsplit-testset-deployer"
  role             = aws_iam_role.dataset_deployers[0].arn
  filename         = data.archive_file.docsplit_testset_deployer[0].output_path
  source_code_hash = data.archive_file.docsplit_testset_deployer[0].output_base64sha256
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 900
  memory_size      = 1024
  layers           = compact([var.base_layer_arn, var.idp_common_layer_arn])

  environment {
    variables = {
      LOG_LEVEL       = var.log_level
      TEST_SET_BUCKET = aws_s3_bucket.test_sets[0].id
    }
  }

  tracing_config { mode = var.lambda_tracing_mode }

  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  depends_on = [aws_cloudwatch_log_group.docsplit_testset_deployer]
  tags       = var.tags
}

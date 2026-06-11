# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#

# SageMaker-UDOP Processor (public façade) — Pattern 3 retained
#
# Mirrors the CDK accelerator's `SagemakerUdopProcessor` (verified against
# cdklabs/genai-idp@main): a thin public façade that creates NO SageMaker
# hosting/training resources and NO document-processing engine resources of its
# own. The consumer supplies the SageMaker endpoint via
# `var.classification_endpoint_arn`.
#
# Pattern-specific setup: the façade provisions a SageMaker classification-hook
# BRIDGE Lambda whose source is zipped (`data "archive_file"`) from the shipped
# sample `sources/samples/lambda-hook-inference/GENAIIDP-sagemaker-hook/` (no
# `sources/` edits). The bridge invokes the consumer-supplied SageMaker endpoint
# (reads `SAGEMAKER_ENDPOINT_NAME`) and returns a Converse-API-compatible
# response. The façade then overrides classification to the upstream `LambdaHook`
# seam (`classification.model = "LambdaHook"` + `model_lambda_hook_arn`) and
# delegates ALL document processing to the shared internal engine
# (`modules/processors/unified-processor/`) via a nested `module "engine"`,
# routing down the non-BDA pipeline branch (`use_bda = false`).
#
# The legacy monolith resources (its own image-based OCR/classification/
# extraction/assessment/process-results/summarization/evaluation Lambdas, the
# Step Functions state machine, the per-function IAM roles/policies, the
# CloudWatch log groups, the ECR repository + CodeBuild image pipeline, and all
# `sources/patterns/pattern-3/...` references) have been removed. Those
# responsibilities now live in the shared engine. The engine resources live at
# `module.engine.*`; the root `moved {}` blocks remap the preservable former
# per-façade addresses to `module.sagemaker_udop_processor[0].module.engine.*`.

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

locals {
  name_prefix = var.name

  # Extract the working-bucket name from its ARN for S3 read scoping.
  # Format for S3 bucket ARN: arn:<partition>:s3:::bucket-name
  working_bucket_arn  = var.working_bucket_arn != null ? var.working_bucket_arn : var.output_bucket_arn
  working_bucket_name = element(split(":", local.working_bucket_arn), 5)

  # SageMaker classification-hook bridge Lambda function name. MUST start with
  # "GENAIIDP-" so it satisfies the engine's `lambda_hook_classification`
  # validation (which pre-grants Step Functions InvokeFunction permission).
  bridge_function_name = "GENAIIDP-${var.name}-sagemaker-hook"
  bridge_function_arn  = "arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:function:${local.bridge_function_name}"

  # Evaluation is enabled when a baseline bucket name is supplied; derive the
  # engine's evaluation inputs (bucket ARN + flag) from it.
  evaluation_enabled             = var.evaluation_baseline_bucket_name != ""
  evaluation_baseline_bucket_arn = local.evaluation_enabled ? "arn:${data.aws_partition.current.partition}:s3:::${var.evaluation_baseline_bucket_name}" : null

  # VPC configuration for the bridge Lambda
  vpc_config = length(var.vpc_subnet_ids) > 0 ? {
    subnet_ids         = var.vpc_subnet_ids
    security_group_ids = var.vpc_security_group_ids
  } : null

  # Inject the LambdaHook bridge ARN into the document config's classification
  # block. The engine overrides `classification.model` to "LambdaHook" (via
  # classification_model_id below); `model_lambda_hook_arn` survives the engine's
  # merge because the engine only overwrites the `model` key.
  config_with_hook = merge(
    var.config,
    {
      classification = merge(
        try(var.config.classification, {}),
        {
          model_lambda_hook_arn = local.bridge_function_arn
        }
      )
    }
  )

  common_tags = merge(var.tags, {
    Component = "SagemakerUdopProcessor"
  })
}

# =============================================================================
# SageMaker classification-hook BRIDGE Lambda
# =============================================================================
# Source zipped from the shipped sample (read-only `sources/`); reads
# SAGEMAKER_ENDPOINT_NAME and proxies LambdaHook payloads to the
# consumer-supplied SageMaker endpoint.

data "archive_file" "sagemaker_hook" {
  type        = "zip"
  source_dir  = "${path.module}/../../../sources/samples/lambda-hook-inference/GENAIIDP-sagemaker-hook"
  output_path = "${path.module}/sagemaker_hook_function.zip"
}

# Execution role for the bridge Lambda.
resource "aws_iam_role" "sagemaker_hook" {
  name = "${local.name_prefix}-sagemaker-hook-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "sagemaker_hook_basic" {
  role       = aws_iam_role.sagemaker_hook.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "sagemaker_hook_vpc" {
  count      = length(var.vpc_subnet_ids) > 0 ? 1 : 0
  role       = aws_iam_role.sagemaker_hook.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "sagemaker_hook" {
  name = "${local.name_prefix}-sagemaker-hook-policy"
  role = aws_iam_role.sagemaker_hook.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          # Invoke ONLY the consumer-supplied classification endpoint.
          Effect   = "Allow"
          Action   = ["sagemaker:InvokeEndpoint"]
          Resource = var.classification_endpoint_arn
        },
        {
          # Read page artifacts referenced as S3 URIs in the LambdaHook payload.
          Effect = "Allow"
          Action = ["s3:GetObject"]
          Resource = compact([
            "${var.input_bucket_arn}/*",
            "${var.output_bucket_arn}/*",
            "${local.working_bucket_arn}/*",
          ])
        }
      ],
      var.encryption_key_arn != null ? [
        {
          Effect   = "Allow"
          Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
          Resource = var.encryption_key_arn
        }
      ] : []
    )
  })
}

resource "aws_cloudwatch_log_group" "sagemaker_hook" {
  name              = "/aws/lambda/${local.bridge_function_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.encryption_key_arn

  tags = local.common_tags
}

# Wait for the bridge Lambda execution role + inline policy to propagate before
# the synchronous CreateFunction call validates role access. Same IAM
# eventual-consistency guard used across the wrapper.
resource "time_sleep" "wait_for_iam_propagation" {
  depends_on = [
    aws_iam_role.sagemaker_hook,
    aws_iam_role_policy.sagemaker_hook,
    aws_iam_role_policy_attachment.sagemaker_hook_basic,
  ]

  create_duration = "30s"
}

resource "aws_lambda_function" "sagemaker_hook" {
  function_name = local.bridge_function_name
  role          = aws_iam_role.sagemaker_hook.arn
  runtime       = "python3.12"
  handler       = "index.lambda_handler"
  timeout       = 300
  memory_size   = 512
  kms_key_arn   = var.encryption_key_arn

  filename         = data.archive_file.sagemaker_hook.output_path
  source_code_hash = data.archive_file.sagemaker_hook.output_base64sha256

  # Attach the shared base layer per conventions.
  layers = compact([var.base_layer_arn])

  environment {
    variables = {
      SAGEMAKER_ENDPOINT_NAME = element(split("/", var.classification_endpoint_arn), 1)
      LOG_LEVEL               = var.log_level != null ? var.log_level : "INFO"
    }
  }

  dynamic "vpc_config" {
    for_each = local.vpc_config != null ? [local.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  tracing_config {
    mode = var.lambda_tracing_mode
  }

  depends_on = [
    time_sleep.wait_for_iam_propagation,
    aws_cloudwatch_log_group.sagemaker_hook,
  ]

  tags = local.common_tags
}

# =============================================================================
# Delegate document processing to the shared engine (non-BDA pipeline branch).
# =============================================================================

module "engine" {
  source = "../unified-processor"

  # Engine naming: the engine resources adopt the façade's name so the former
  # monolith resource names are preserved across the refactor (see moved.tf).
  name = var.name

  # ---------------------------------------------------------------------------
  # Façade ↔ engine delegation: SageMaker-UDOP is the non-BDA pipeline branch,
  # with classification overridden to the LambdaHook bridge.
  # ---------------------------------------------------------------------------
  use_bda         = false
  bda_project_arn = null

  # Force classification through the LambdaHook seam. The engine sets
  # `classification.model = coalesce(classification_model_id, model_id)`, so
  # pinning this to "LambdaHook" routes the pipeline's classification step to the
  # bridge Lambda (whose ARN is carried in config.classification.model_lambda_hook_arn).
  classification_model_id = "LambdaHook"

  # Pre-grant Step Functions InvokeFunction on the bridge Lambda. Must be the
  # bare function name starting with "GENAIIDP-".
  lambda_hook_classification = local.bridge_function_name

  # API wiring
  enable_api      = var.enable_api
  api_id          = var.api_id
  api_arn         = var.api_arn
  api_graphql_url = var.api_graphql_url

  # Shared environment ARNs
  input_bucket_arn        = var.input_bucket_arn
  output_bucket_arn       = var.output_bucket_arn
  working_bucket_arn      = local.working_bucket_arn
  configuration_table_arn = var.configuration_table_arn
  tracking_table_arn      = var.tracking_table_arn
  concurrency_table_arn   = var.concurrency_table_arn

  # Processing-environment configuration
  metric_namespace   = var.metric_namespace
  log_level          = var.log_level
  log_retention_days = var.log_retention_days

  # Encryption
  encryption_key_arn = var.encryption_key_arn

  # VPC configuration
  vpc_subnet_ids         = var.vpc_subnet_ids
  vpc_security_group_ids = var.vpc_security_group_ids

  # Lambda layers
  idp_common_layer_arn = var.idp_common_layer_arn
  base_layer_arn       = var.base_layer_arn
  evaluation_layer_arn = var.evaluation_layer_arn

  # Model configuration
  extraction_model_id        = var.extraction_model_id
  classification_max_workers = var.classification_max_workers
  ocr_max_workers            = var.ocr_max_workers

  # Evaluation (derived from the baseline bucket name supplied by the root)
  evaluation_enabled             = local.evaluation_enabled
  evaluation_baseline_bucket_arn = local.evaluation_baseline_bucket_arn
  evaluation_model_id            = var.evaluation_model_id

  # Summarization
  is_summarization_enabled = var.summarization_model_id != null
  summarization_model_id   = var.summarization_model_id

  # Concurrency
  max_processing_concurrency = var.max_processing_concurrency

  # Document processing configuration (with the LambdaHook bridge ARN injected)
  config = local.config_with_hook

  # Lambda tracing configuration
  lambda_tracing_mode = var.lambda_tracing_mode

  tags = var.tags
}
